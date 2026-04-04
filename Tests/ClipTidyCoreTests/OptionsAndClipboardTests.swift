import Foundation
import Testing
@testable import ClipTidyCore

final class FakePasteboard: PasteboardProviding {
    var string: String?
    private(set) var writes = 0
    init(_ string: String?) { self.string = string }
    func readString() -> String? { string }
    func writeString(_ s: String) { string = s; writes += 1 }
}

@Suite struct CleanOptionsTests {
    @Test func presetsAreFoundCaseInsensitively() {
        #expect(CleanOptions.preset(named: "CODE") == .code)
        #expect(CleanOptions.preset(named: "Prose") == .prose)
        #expect(CleanOptions.preset(named: "nope") == nil)
    }

    @Test func eachPresetMatchesItselfAndNoOther() {
        #expect(CleanOptions.standard.matchingPreset == "standard")
        #expect(CleanOptions.code.matchingPreset == "code")
        #expect(CleanOptions.prose.matchingPreset == "prose")
    }

    @Test func customCombinationMatchesNoPreset() {
        var o = CleanOptions.standard
        o.straightenQuotes = true
        #expect(o.matchingPreset == nil)
    }

    @Test func codableRoundTrip() throws {
        var o = CleanOptions.prose
        o.indentation = .keep
        let data = try JSONEncoder().encode(o)
        #expect(try JSONDecoder().decode(CleanOptions.self, from: data) == o)
    }
}

@Suite struct OptionsStoreTests {
    func makeDefaults() -> UserDefaults {
        let name = "cliptidy-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func missingValueGivesStandard() {
        #expect(OptionsStore(defaults: makeDefaults()).load() == .standard)
    }

    @Test func saveThenLoad() {
        let store = OptionsStore(defaults: makeDefaults())
        store.save(.prose)
        #expect(store.load() == .prose)
    }

    @Test func corruptValueFallsBackToStandard() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "cleanOptions.v1")
        #expect(OptionsStore(defaults: defaults).load() == .standard)
    }

    @Test func storedValueFromAnOlderVersionWithMissingKeysFallsBack() {
        let defaults = makeDefaults()
        defaults.set(Data(#"{"collapseSpaces":true}"#.utf8), forKey: "cleanOptions.v1")
        #expect(OptionsStore(defaults: defaults).load() == .standard)
    }
}

@Suite struct ClipboardCleanerTests {
    @Test func messyTextIsRewritten() {
        let board = FakePasteboard("  hello   world  \n\n\n")
        let outcome = ClipboardCleaner(pasteboard: board).run(options: .standard)
        #expect(outcome == .cleaned(before: 20, after: 11))
        #expect(board.string == "hello world")
    }

    @Test func alreadyCleanTextIsNotWrittenBack() {
        let board = FakePasteboard("already clean")
        #expect(ClipboardCleaner(pasteboard: board).run(options: .standard) == .unchanged)
        #expect(board.writes == 0)
    }

    @Test func whitespaceOnlyClipboardIsNeverOverwritten() {
        let board = FakePasteboard("   \n\t ")
        #expect(ClipboardCleaner(pasteboard: board).run(options: .standard) == .empty)
        #expect(board.writes == 0)
        #expect(board.string == "   \n\t ")
    }

    @Test func nonTextClipboardIsLeftAlone() {
        let board = FakePasteboard(nil)
        #expect(ClipboardCleaner(pasteboard: board).run(options: .standard) == .noText)
        #expect(board.writes == 0)
    }

    @Test func runningTwiceWritesOnlyOnce() {
        let board = FakePasteboard("a    b")
        let cleaner = ClipboardCleaner(pasteboard: board)
        _ = cleaner.run(options: .standard)
        #expect(cleaner.run(options: .standard) == .unchanged)
        #expect(board.writes == 1)
    }
}
