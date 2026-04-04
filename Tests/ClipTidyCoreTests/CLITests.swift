import Testing
@testable import ClipTidyCore

@Suite struct CLIParsingTests {
    @Test func defaultsToStdinWithStandardOptions() throws {
        let c = try parseCLI([])
        #expect(c.mode == .stdin)
        #expect(c.options == .standard)
    }

    @Test func presetSelectsOptions() throws {
        #expect(try parseCLI(["--preset", "code"]).options == .code)
        #expect(try parseCLI(["-p", "prose"]).options == .prose)
    }

    @Test func flagsOverridePresetWhateverTheOrder() throws {
        let before = try parseCLI(["--unwrap", "--preset", "code"])
        let after = try parseCLI(["--preset", "code", "--unwrap"])
        #expect(before == after)
        #expect(before.options.unwrapParagraphs)
        #expect(before.options.indentation == .keep)
    }

    @Test func eachFlagChangesTheMatchingOption() throws {
        #expect(try parseCLI(["--keep-indent"]).options.indentation == .keep)
        #expect(try parseCLI(["--strip-fences"]).options.stripCodeFences)
        #expect(try parseCLI(["--clean-code-blocks"]).options.protectCodeBlocks == false)
        #expect(try parseCLI(["--keep-blank-lines"]).options.collapseBlankLines == false)
        #expect(try parseCLI(["--no-collapse-spaces"]).options.collapseSpaces == false)
        #expect(try parseCLI(["--straight-quotes"]).options.straightenQuotes)
    }

    @Test func modes() throws {
        #expect(try parseCLI(["--clipboard"]).mode == .clipboard)
        #expect(try parseCLI(["-h"]).mode == .help)
        #expect(try parseCLI(["--version"]).mode == .version)
    }

    @Test func errors() {
        #expect(throws: CLIError.unknownFlag("--bogus")) { try parseCLI(["--bogus"]) }
        #expect(throws: CLIError.missingValue("--preset")) { try parseCLI(["--preset"]) }
        #expect(throws: CLIError.unknownPreset("zzz")) { try parseCLI(["-p", "zzz"]) }
    }
}

@Suite struct CLIRunTests {
    struct Result { var status: Int32; var out: String; var err: String }

    func run(_ args: [String], stdin: String = "", board: PasteboardProviding? = nil) -> Result {
        var out = "", err = ""
        let status = runCLI(arguments: args, readStdin: { stdin },
                            stdout: { out += $0 }, stderr: { err += $0 }, pasteboard: board)
        return Result(status: status, out: out, err: err)
    }

    @Test func stdinIsCleanedWithATrailingNewline() {
        let r = run([], stdin: "  a   b  \n\n\n")
        #expect(r.status == 0 && r.out == "a b\n" && r.err == "")
    }

    @Test func emptyResultPrintsNothing() {
        let r = run([], stdin: "  \n ")
        #expect(r.status == 0 && r.out == "")
    }

    @Test func helpAndVersion() {
        #expect(run(["--help"]).out.contains("USAGE"))
        #expect(run(["--version"]).out == "cliptidy \(clipTidyVersion)\n")
    }

    @Test func usageErrorsExitWithTwo() {
        let r = run(["--bogus"])
        #expect(r.status == 2 && r.err.contains("unknown option --bogus"))
        #expect(run(["-p", "zzz"]).status == 2)
        #expect(run(["-p"]).status == 2)
    }

    @Test func clipboardModeReportsAndRewrites() {
        let board = FakePasteboard("a    b")
        let r = run(["--clipboard"], board: board)
        #expect(r.status == 0 && r.err.contains("cleaned clipboard"))
        #expect(board.string == "a b")
    }

    @Test func clipboardModeStatusCodes() {
        #expect(run(["--clipboard"], board: FakePasteboard("clean")).status == 0)
        #expect(run(["--clipboard"], board: FakePasteboard("  ")).status == 1)
        #expect(run(["--clipboard"], board: FakePasteboard(nil)).status == 1)
        #expect(run(["--clipboard"], board: nil).status == 1)
    }
}
