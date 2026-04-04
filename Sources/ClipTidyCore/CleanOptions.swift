import Foundation

/// What `TextCleaner` should do. Every field is independent, so presets are just
/// named combinations.
public struct CleanOptions: Codable, Equatable, Sendable {
    public enum Indentation: String, Codable, Sendable {
        case remove
        case keep
    }

    /// Leading whitespace of each line: strip it, or keep it (useful for code and nested lists).
    public var indentation: Indentation = .remove
    /// Replace runs of spaces and tabs inside a line with one space.
    public var collapseSpaces: Bool = true
    /// Reduce several blank lines in a row to one.
    public var collapseBlankLines: Bool = true
    /// Leave everything between ``` fences exactly as it is, so code keeps its indentation.
    public var protectCodeBlocks: Bool = true
    /// Remove the ``` lines themselves. Off by default: once the markers are gone the code
    /// is ordinary text, so cleaning the same clipboard a second time would re-flow it.
    public var stripCodeFences: Bool = false
    /// Turn non-breaking and other exotic spaces into plain spaces, and remove invisible
    /// zero-width characters that break searching and diffing.
    public var normalizeUnicodeSpaces: Bool = true
    /// Replace curly quotes with straight ones.
    public var straightenQuotes: Bool = false
    /// Join lines that were hard-wrapped (PDFs, emails) back into paragraphs.
    /// Paragraphs that contain lists, headings, quotes or tables are left as they are.
    public var unwrapParagraphs: Bool = false

    public init() {}

    public static let standard = CleanOptions()

    public static var code: CleanOptions {
        var o = CleanOptions()
        o.indentation = .keep
        o.collapseSpaces = false
        o.collapseBlankLines = false
        return o
    }

    public static var prose: CleanOptions {
        var o = CleanOptions()
        o.straightenQuotes = true
        o.unwrapParagraphs = true
        return o
    }

    public static let presetNames = ["standard", "code", "prose"]

    public static func preset(named name: String) -> CleanOptions? {
        switch name.lowercased() {
        case "standard": return .standard
        case "code": return .code
        case "prose": return .prose
        default: return nil
        }
    }

    /// The preset these options equal exactly, if any (the menu shows it as selected).
    public var matchingPreset: String? {
        CleanOptions.presetNames.first { CleanOptions.preset(named: $0) == self }
    }
}
