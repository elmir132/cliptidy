import Foundation

public enum CLIError: Error, Equatable {
    case unknownFlag(String)
    case missingValue(String)
    case unknownPreset(String)
}

public struct CLIConfig: Equatable {
    public enum Mode: Equatable { case stdin, clipboard, help, version }
    public var mode: Mode = .stdin
    public var options: CleanOptions = .standard
}

public let cliHelp = """
    cliptidy: clean up messy text.

    USAGE
      cliptidy [options] < input.txt > output.txt     clean text from stdin
      cliptidy --clipboard [options]                  clean the clipboard in place

    OPTIONS
      -p, --preset NAME      standard (default), code or prose
          --keep-indent      keep leading whitespace of each line
          --strip-fences     remove ``` lines (code between them is untouched)
          --clean-code-blocks
                             also clean text inside ``` blocks
          --keep-blank-lines do not collapse repeated blank lines
          --no-collapse-spaces
                             keep runs of spaces inside lines
          --unwrap           join hard-wrapped lines into paragraphs
          --straight-quotes  replace curly quotes with straight ones
          --clipboard        operate on the clipboard instead of stdin
      -h, --help             show this help
      -v, --version          show the version

    Flags are applied after the preset, whatever their order.
    Exit status: 0 success, 1 nothing to clean on the clipboard, 2 usage error.
    """

public func parseCLI(_ args: [String]) throws -> CLIConfig {
    var config = CLIConfig()
    var overrides: [(inout CleanOptions) -> Void] = []
    var index = 0

    func value(for flag: String) throws -> String {
        index += 1
        guard index < args.count else { throw CLIError.missingValue(flag) }
        return args[index]
    }

    while index < args.count {
        let arg = args[index]
        switch arg {
        case "-h", "--help": config.mode = .help
        case "-v", "--version": config.mode = .version
        case "--clipboard": config.mode = .clipboard
        case "-p", "--preset":
            let name = try value(for: arg)
            guard let preset = CleanOptions.preset(named: name) else { throw CLIError.unknownPreset(name) }
            config.options = preset
        case "--keep-indent": overrides.append { $0.indentation = .keep }
        case "--strip-fences": overrides.append { $0.stripCodeFences = true }
        case "--clean-code-blocks": overrides.append { $0.protectCodeBlocks = false }
        case "--keep-blank-lines": overrides.append { $0.collapseBlankLines = false }
        case "--no-collapse-spaces": overrides.append { $0.collapseSpaces = false }
        case "--unwrap": overrides.append { $0.unwrapParagraphs = true }
        case "--straight-quotes": overrides.append { $0.straightenQuotes = true }
        default: throw CLIError.unknownFlag(arg)
        }
        index += 1
    }
    for apply in overrides { apply(&config.options) }
    return config
}

/// Runs the CLI with injected I/O so it can be tested without a terminal.
public func runCLI(
    arguments: [String],
    readStdin: () -> String,
    stdout: (String) -> Void,
    stderr: (String) -> Void,
    pasteboard: PasteboardProviding?
) -> Int32 {
    let config: CLIConfig
    do {
        config = try parseCLI(arguments)
    } catch CLIError.unknownFlag(let flag) {
        stderr("cliptidy: unknown option \(flag)\n\(cliHelp)\n")
        return 2
    } catch CLIError.missingValue(let flag) {
        stderr("cliptidy: \(flag) needs a value\n")
        return 2
    } catch CLIError.unknownPreset(let name) {
        stderr("cliptidy: unknown preset '\(name)' (use \(CleanOptions.presetNames.joined(separator: ", ")))\n")
        return 2
    } catch {
        stderr("cliptidy: \(error)\n")
        return 2
    }

    switch config.mode {
    case .help:
        stdout(cliHelp + "\n")
        return 0
    case .version:
        stdout("cliptidy \(clipTidyVersion)\n")
        return 0
    case .stdin:
        let cleaned = TextCleaner.clean(readStdin(), options: config.options)
        if !cleaned.isEmpty { stdout(cleaned + "\n") }
        return 0
    case .clipboard:
        guard let pasteboard else {
            stderr("cliptidy: no clipboard available on this platform\n")
            return 1
        }
        switch ClipboardCleaner(pasteboard: pasteboard).run(options: config.options) {
        case .cleaned(let before, let after):
            stderr("cleaned clipboard: \(before) -> \(after) characters\n")
            return 0
        case .unchanged:
            stderr("clipboard already clean\n")
            return 0
        case .empty:
            stderr("clipboard is empty\n")
            return 1
        case .noText:
            stderr("clipboard has no text\n")
            return 1
        }
    }
}
