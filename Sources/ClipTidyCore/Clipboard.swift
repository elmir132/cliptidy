import Foundation
#if canImport(AppKit)
import AppKit
#endif

public protocol PasteboardProviding: AnyObject {
    func readString() -> String?
    func writeString(_ string: String)
}

public enum CleanOutcome: Equatable, Sendable {
    /// The clipboard text was rewritten. Counts are characters.
    case cleaned(before: Int, after: Int)
    /// The text was already clean; the clipboard was not touched.
    case unchanged
    /// The clipboard held only whitespace; nothing was written.
    case empty
    /// The clipboard holds no text (an image or files, for example); it was left alone.
    case noText
}

/// Reads the clipboard, cleans the text and writes it back. Anything that is not text,
/// and any text that would come out empty, is never overwritten.
public struct ClipboardCleaner {
    public let pasteboard: PasteboardProviding

    public init(pasteboard: PasteboardProviding) {
        self.pasteboard = pasteboard
    }

    @discardableResult
    public func run(options: CleanOptions) -> CleanOutcome {
        guard let original = pasteboard.readString() else { return .noText }
        let cleaned = TextCleaner.clean(original, options: options)
        if cleaned.isEmpty { return .empty }
        if cleaned == original { return .unchanged }
        pasteboard.writeString(cleaned)
        return .cleaned(before: original.count, after: cleaned.count)
    }
}

#if canImport(AppKit)
public final class SystemPasteboard: PasteboardProviding {
    public init() {}

    public func readString() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    public func writeString(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
#endif
