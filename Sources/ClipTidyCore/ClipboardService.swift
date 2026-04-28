import Foundation

/// Cleans the clipboard and remembers the text it replaced, so the last clean can be undone.
///
/// The original is kept in memory only; it is never written to disk or logged. Undo is
/// offered only while the clipboard still holds exactly the text this service wrote, so
/// it can never overwrite something the user copied afterwards.
public final class ClipboardService {
    private let pasteboard: PasteboardProviding
    private var original: String?
    private var written: String?

    public init(pasteboard: PasteboardProviding) {
        self.pasteboard = pasteboard
    }

    @discardableResult
    public func clean(options: CleanOptions) -> CleanOutcome {
        let before = pasteboard.readString()
        let outcome = ClipboardCleaner(pasteboard: pasteboard).run(options: options)
        if case .cleaned = outcome {
            original = before
            written = pasteboard.readString()
        }
        return outcome
    }

    public var canRestore: Bool {
        guard original != nil, let written else { return false }
        return pasteboard.readString() == written
    }

    /// Puts the text from before the last clean back. Returns false if there is nothing
    /// to restore or the clipboard has changed since.
    @discardableResult
    public func restore() -> Bool {
        guard canRestore, let original else { return false }
        pasteboard.writeString(original)
        self.original = nil
        self.written = nil
        return true
    }
}
