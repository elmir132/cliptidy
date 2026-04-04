import Foundation

/// Pure text cleaning. No clipboard, no UI, no I/O: everything here is deterministic
/// and unit-tested.
public enum TextCleaner {
    public static func clean(_ input: String, options: CleanOptions = .standard) -> String {
        var text = normalizeLineEndings(input)
        if options.normalizeUnicodeSpaces { text = normalizeUnicodeSpaces(text) }
        if options.straightenQuotes { text = straightenQuotes(text) }

        var lines: [Line] = []
        var inFence = false
        var previousBlank = false

        for raw in text.components(separatedBy: "\n") {
            let isFenceLine = raw.trimmingCharacters(in: .whitespaces).hasPrefix("```")
            if isFenceLine {
                inFence.toggle()
                if options.stripCodeFences {
                    previousBlank = false
                    continue
                }
                if options.protectCodeBlocks {
                    lines.append(Line(text: trimTrailing(raw), kind: .code))
                    previousBlank = false
                    continue
                }
            } else if inFence && options.protectCodeBlocks {
                lines.append(Line(text: raw, kind: .code))
                previousBlank = false
                continue
            }
            let cleaned = cleanLine(raw, options: options)
            if cleaned.isEmpty {
                if !(options.collapseBlankLines && previousBlank) {
                    lines.append(Line(text: "", kind: .blank))
                }
                previousBlank = true
            } else {
                lines.append(Line(text: cleaned, kind: .text))
                previousBlank = false
            }
        }

        while lines.first?.kind == .blank { lines.removeFirst() }
        while lines.last?.kind == .blank { lines.removeLast() }

        var result = lines
        if options.unwrapParagraphs { result = unwrap(result) }
        return result.map(\.text).joined(separator: "\n")
    }

    // MARK: - Pieces (internal so tests can reach them)

    struct Line: Equatable {
        enum Kind { case text, blank, code }
        var text: String
        var kind: Kind
        static func == (lhs: Line, rhs: Line) -> Bool { lhs.text == rhs.text }
    }

    static func normalizeLineEndings(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{0085}", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{2029}", with: "\n")
    }

    /// Exotic spaces become " ". Zero-width space, word joiner, byte-order mark and soft
    /// hyphen are removed. Zero-width (non-)joiners are deliberately kept: emoji sequences
    /// and several scripts need them.
    static func normalizeUnicodeSpaces(_ text: String) -> String {
        let spaces: Set<Unicode.Scalar> = [
            "\u{00A0}", "\u{1680}", "\u{2000}", "\u{2001}", "\u{2002}", "\u{2003}", "\u{2004}",
            "\u{2005}", "\u{2006}", "\u{2007}", "\u{2008}", "\u{2009}", "\u{200A}", "\u{202F}",
            "\u{205F}", "\u{3000}",
        ]
        let invisible: Set<Unicode.Scalar> = ["\u{200B}", "\u{2060}", "\u{FEFF}", "\u{00AD}"]
        var out = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if invisible.contains(scalar) { continue }
            out.append(spaces.contains(scalar) ? " " : scalar)
        }
        return String(out)
    }

    static func straightenQuotes(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
    }

    static func trimTrailing(_ line: String) -> String {
        var end = line.endIndex
        while end > line.startIndex, line[line.index(before: end)] == " " || line[line.index(before: end)] == "\t" {
            end = line.index(before: end)
        }
        return String(line[..<end])
    }

    static func cleanLine(_ raw: String, options: CleanOptions) -> String {
        let leading = options.indentation == .keep ? String(raw.prefix(while: { $0 == " " || $0 == "\t" })) : ""
        var body = String(raw.dropFirst(leading.count)).trimmingCharacters(in: .whitespaces)
        if body.isEmpty { return "" }
        if options.collapseSpaces {
            body = body.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
        }
        return leading + body
    }

    private static let structural = try! NSRegularExpression(
        pattern: #"^\s*([-*+•]\s|\d+[.)]\s|#{1,6}\s|>|\|)"#)

    static func looksStructural(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..., in: line)
        return structural.firstMatch(in: line, range: range) != nil
    }

    /// Join runs of ordinary text lines into one line each. A run that contains any
    /// list item, heading, quote or table row is kept line by line, because guessing
    /// there would damage the structure.
    static func unwrap(_ lines: [Line]) -> [Line] {
        var out: [Line] = []
        var group: [Line] = []

        func flush() {
            guard !group.isEmpty else { return }
            if group.contains(where: { looksStructural($0.text) }) {
                out.append(contentsOf: group)
            } else {
                out.append(Line(text: group.map(\.text).joined(separator: " "), kind: .text))
            }
            group.removeAll()
        }

        for line in lines {
            if line.kind == .text {
                group.append(line)
            } else {
                flush()
                out.append(line)
            }
        }
        flush()
        return out
    }
}
