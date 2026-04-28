import Foundation

/// One on/off setting, as shown in the menu. Keeping this in the core means the menu is
/// generated from data and the toggling logic is unit-tested without any UI.
public enum OptionToggle: String, CaseIterable, Sendable {
    case keepIndentation
    case collapseSpaces
    case collapseBlankLines
    case protectCodeBlocks
    case stripCodeFences
    case protectTables
    case normalizeUnicodeSpaces
    case straightenQuotes
    case unwrapParagraphs
    case keepMarkdownLineBreaks

    public var title: String {
        switch self {
        case .keepIndentation: return "Keep indentation"
        case .collapseSpaces: return "Collapse repeated spaces"
        case .collapseBlankLines: return "Collapse blank lines"
        case .protectCodeBlocks: return "Leave ``` code blocks untouched"
        case .stripCodeFences: return "Remove ``` marker lines"
        case .protectTables: return "Leave spreadsheet (tab-separated) rows alone"
        case .normalizeUnicodeSpaces: return "Fix odd spaces and invisible characters"
        case .straightenQuotes: return "Straighten curly quotes"
        case .unwrapParagraphs: return "Join hard-wrapped lines"
        case .keepMarkdownLineBreaks: return "Keep Markdown line breaks (two trailing spaces)"
        }
    }

    public func isOn(in o: CleanOptions) -> Bool {
        switch self {
        case .keepIndentation: return o.indentation == .keep
        case .collapseSpaces: return o.collapseSpaces
        case .collapseBlankLines: return o.collapseBlankLines
        case .protectCodeBlocks: return o.protectCodeBlocks
        case .stripCodeFences: return o.stripCodeFences
        case .protectTables: return o.protectTables
        case .normalizeUnicodeSpaces: return o.normalizeUnicodeSpaces
        case .straightenQuotes: return o.straightenQuotes
        case .unwrapParagraphs: return o.unwrapParagraphs
        case .keepMarkdownLineBreaks: return o.keepMarkdownLineBreaks
        }
    }

    public func toggled(_ o: CleanOptions) -> CleanOptions {
        var o = o
        switch self {
        case .keepIndentation: o.indentation = o.indentation == .keep ? .remove : .keep
        case .collapseSpaces: o.collapseSpaces.toggle()
        case .collapseBlankLines: o.collapseBlankLines.toggle()
        case .protectCodeBlocks: o.protectCodeBlocks.toggle()
        case .stripCodeFences: o.stripCodeFences.toggle()
        case .protectTables: o.protectTables.toggle()
        case .normalizeUnicodeSpaces: o.normalizeUnicodeSpaces.toggle()
        case .straightenQuotes: o.straightenQuotes.toggle()
        case .unwrapParagraphs: o.unwrapParagraphs.toggle()
        case .keepMarkdownLineBreaks: o.keepMarkdownLineBreaks.toggle()
        }
        return o
    }
}
