import Testing
@testable import ClipTidyCore

@Suite struct TextCleanerTests {
    func clean(_ s: String, _ o: CleanOptions = .standard) -> String { TextCleaner.clean(s, options: o) }

    // MARK: whitespace

    @Test func normalizesLineEndings() {
        #expect(clean("a\r\nb\rc\u{2028}d\u{2029}e") == "a\nb\nc\nd\ne")
    }

    @Test func trimsLinesAndCollapsesSpaces() {
        #expect(clean("  hello   world \t ") == "hello world")
        #expect(clean("a\t\tb") == "a b")
    }

    @Test func collapsesBlankRunsButKeepsOneBlankLine() {
        #expect(clean("a\n\n\n\nb") == "a\n\nb")
        #expect(clean("a\n   \n\t\nb") == "a\n\nb")
    }

    @Test func removesLeadingAndTrailingBlankLines() {
        #expect(clean("\n\n  a  \n\n\n") == "a")
    }

    @Test func emptyAndWhitespaceOnlyInputGiveEmptyOutput() {
        #expect(clean("") == "")
        #expect(clean(" \n\t \r\n ") == "")
    }

    @Test func keepBlankLinesOption() {
        var o = CleanOptions.standard
        o.collapseBlankLines = false
        #expect(clean("a\n\n\nb", o) == "a\n\n\nb")
    }

    @Test func noCollapseSpacesOption() {
        var o = CleanOptions.standard
        o.collapseSpaces = false
        #expect(clean("a    b", o) == "a    b")
    }

    // MARK: indentation

    @Test func removesIndentationByDefault() {
        #expect(clean("    indented\n\tmore") == "indented\nmore")
    }

    @Test func keepIndentationKeepsLeadingWhitespaceButStillCleansTheRest() {
        var o = CleanOptions.standard
        o.indentation = .keep
        #expect(clean("    a    b   \n\tc", o) == "    a b\n\tc")
    }

    // MARK: code fences

    @Test func codeInsideFencesIsLeftUntouchedAndFencesAreKeptByDefault() {
        let input = "Before   text\n```swift\nfunc f() {\n    let  x = 1\n\n\n    return   \n}\n```\nAfter"
        #expect(clean(input) == "Before text\n```swift\nfunc f() {\n    let  x = 1\n\n\n    return   \n}\n```\nAfter")
    }

    @Test func stripFencesDropsMarkerLinesButKeepsTheCodeUntouched() {
        var o = CleanOptions.standard
        o.stripCodeFences = true
        let input = "Before\n```swift\nfunc f() {\n    let  x = 1\n\n\n    return\n}\n```\nAfter"
        #expect(clean(input, o) == "Before\nfunc f() {\n    let  x = 1\n\n\n    return\n}\nAfter")
    }

    @Test func unterminatedFenceKeepsTheRestVerbatim() {
        #expect(clean("a\n```\n  x   y\n\n\nz") == "a\n```\n  x   y\n\n\nz")
    }

    @Test func protectionCanBeSwitchedOffSoCodeIsCleanedLikeText() {
        var o = CleanOptions.standard
        o.protectCodeBlocks = false
        #expect(clean("```\n  a   b\n```", o) == "```\na b\n```")
    }

    @Test func indentedFenceIsRecognised() {
        var o = CleanOptions.standard
        o.stripCodeFences = true
        #expect(clean("  ```\ncode\n  ```", o) == "code")
        #expect(clean("  ```\n  code\n  ```") == "  ```\n  code\n  ```")
    }

    @Test func strippingFencesThenCleaningAgainReflowsTheCode() {
        // Documented limitation: after the markers are gone the code is plain text.
        var o = CleanOptions.standard
        o.stripCodeFences = true
        let once = clean("```\n    indented\n```", o)
        #expect(once == "    indented")
        #expect(clean(once, o) == "indented")
    }

    @Test func fencesWithKeepIndentationAndStripAreStable() {
        var o = CleanOptions.code
        o.stripCodeFences = true
        let once = clean("```\n    indented\n```", o)
        #expect(clean(once, o) == once)
    }

    // MARK: unicode

    @Test func exoticSpacesBecomeNormalSpaces() {
        #expect(clean("a\u{00A0}b\u{2003}c\u{202F}d\u{3000}e") == "a b c d e")
    }

    @Test func invisibleCharactersAreRemoved() {
        #expect(clean("zero\u{200B}width\u{FEFF}\u{2060}soft\u{00AD}hyphen") == "zerowidthsofthyphen")
    }

    @Test func zeroWidthJoinerInEmojiSequencesIsPreserved() {
        let family = "👨‍👩‍👧"
        #expect(clean("x \(family) y") == "x \(family) y")
    }

    @Test func normalizationCanBeSwitchedOff() {
        var o = CleanOptions.standard
        o.normalizeUnicodeSpaces = false
        #expect(clean("a\u{00A0}b", o) == "a\u{00A0}b")
    }

    @Test func nonLatinTextIsUnchanged() {
        #expect(clean("Привіт, світе! Salam dünya. 你好") == "Привіт, світе! Salam dünya. 你好")
    }

    // MARK: quotes

    @Test func straightensCurlyQuotes() {
        var o = CleanOptions.standard
        o.straightenQuotes = true
        #expect(clean("\u{201C}it\u{2019}s\u{201D} \u{2018}ok\u{2019}", o) == "\"it's\" 'ok'")
    }

    @Test func leavesQuotesAloneByDefault() {
        #expect(clean("\u{201C}hi\u{201D}") == "\u{201C}hi\u{201D}")
    }

    // MARK: unwrap

    @Test func unwrapJoinsHardWrappedParagraphs() {
        var o = CleanOptions.standard
        o.unwrapParagraphs = true
        #expect(clean("This is a\nwrapped line\nof text.\n\nSecond paragraph\nalso wrapped.", o)
                == "This is a wrapped line of text.\n\nSecond paragraph also wrapped.")
    }

    @Test(arguments: [
        "- one\n- two\n- three",
        "1. first\n2. second",
        "# Heading\ntext under it",
        "> quoted\n> lines",
        "| a | b |\n| c | d |",
        "intro line\n- item",
    ])
    func unwrapLeavesStructuredParagraphsAlone(_ input: String) {
        var o = CleanOptions.standard
        o.unwrapParagraphs = true
        #expect(clean(input, o) == input)
    }

    @Test func unwrapNeverTouchesCodeInsideFences() {
        var o = CleanOptions.standard
        o.unwrapParagraphs = true
        #expect(clean("a\nb\n```\nx\ny\n```\nc\nd", o) == "a b\n```\nx\ny\n```\nc d")
    }

    // MARK: presets

    @Test func codePresetKeepsCodeShape() {
        let input = "def f():\n    return  1   \n\n\n    pass"
        #expect(clean(input, .code) == "def f():\n    return  1\n\n\n    pass")
    }

    @Test func prosePresetStraightensAndUnwraps() {
        #expect(clean("\u{201C}It was a\nlong day.\u{201D}", .prose) == "\"It was a long day.\"")
    }

    // MARK: idempotence

    static let samples = [
        "  messy   text \r\n\r\n\r\n with\u{00A0}spaces\u{200B} ",
        "```swift\n  code   here\n```\n\n\nafter",
        "wrapped\nparagraph\n\n- list\n- items",
        "\u{201C}quoted\u{201D}\ntext",
        "",
        "   ",
        "single",
    ]

    @Test(arguments: samples, [CleanOptions.standard, .code, .prose])
    func cleaningTwiceEqualsCleaningOnce(_ sample: String, _ options: CleanOptions) {
        let once = TextCleaner.clean(sample, options: options)
        #expect(TextCleaner.clean(once, options: options) == once)
    }

    @Test func idempotentOnPseudoRandomInput() {
        var generator = SeededGenerator(seed: 42)
        let alphabet = Array("ab \t\n\r\u{00A0}\u{200B}-*#>|`1.\"\u{201C}\u{2019}")
        for _ in 0..<300 {
            let length = Int.random(in: 0...60, using: &generator)
            let s = String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
            for options in [CleanOptions.standard, .code, .prose] {
                let once = TextCleaner.clean(s, options: options)
                #expect(TextCleaner.clean(once, options: options) == once, "input: \(s.debugDescription)")
            }
        }
    }
}

struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
