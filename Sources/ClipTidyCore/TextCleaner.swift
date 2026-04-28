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
            if options.protectTables && isTabularRow(raw) {
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
        if options.keepMarkdownLineBreaks && raw.hasSuffix("  ") {
            body += "  "
        }
        return leading + body
    }

    private static let tabular = try! NSRegularExpression(pattern: #"\S[ \t]*\t[ \t]*\S"#)

    /// A row with a tab between two pieces of visible text: spreadsheet cells.
    /// A leading tab is indentation and a trailing tab is stray whitespace; neither counts.
    static func isTabularRow(_ line: String) -> Bool {
        tabular.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) != nil
    }

    private static let structural = try! NSRegularExpression(
        pattern: #"^\s*([-*+•]\s|\d+[.)]\s|#{1,6}\s|>|\|)"#)

    static func looksStructural(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..., in: line)
        return structural.firstMatch(in: line, range: range) != nil
    }

    /// A line shorter than this is never treated as a wrapped line.
    static let minimumWrapWidth = 30
    /// A line is "full" when it reaches this share of the longest line in its paragraph.
    static let fullLineShare = 0.6

    /// Join hard-wrapped lines. Within a run of ordinary text lines, a line is joined to
    /// the next one only if it looks full: at least `minimumWrapWidth` characters and at
    /// least `fullLineShare` of the longest line in the run. Short lines (headings, names,
    /// sign-offs) and lines that end a Markdown hard break are never joined to the next.
    /// A run that contains any list item, marked heading, quote or table row is kept line
    /// by line, because guessing there would damage the structure.
    static func unwrap(_ lines: [Line]) -> [Line] {
        var out: [Line] = []
        var group: [Line] = []

        func flush() {
            guard !group.isEmpty else { return }
            defer { group.removeAll() }
            if group.contains(where: { looksStructural($0.text) }) {
                out.append(contentsOf: group)
                return
            }
            let longest = group.map { $0.text.count }.max() ?? 0
            let threshold = max(minimumWrapWidth, Int((Double(longest) * fullLineShare).rounded(.up)))
            var current = group[0].text
            for index in 1..<group.count {
                let previous = group[index - 1].text
                let joinable = previous.count >= threshold && !previous.hasSuffix("  ")
                if joinable {
                    current += " " + group[index].text
                } else {
                    out.append(Line(text: current, kind: .text))
                    current = group[index].text
                }
            }
            out.append(Line(text: current, kind: .text))
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
