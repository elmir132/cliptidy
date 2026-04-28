import Testing
@testable import ClipTidyCore

@Suite struct TableProtectionTests {
    func clean(_ s: String, _ o: CleanOptions = .standard) -> String { TextCleaner.clean(s, options: o) }

    @Test func tabSeparatedRowsSurviveExactly() {
        let sheet = "name\tqty\tprice\napple\t3\t1.20\nbanana\t\t0.50"
        #expect(clean(sheet) == sheet)
    }

    @Test func emptyTrailingCellsAreKept() {
        #expect(clean("a\tb\t\nc\td\t") == "a\tb\t\nc\td\t")
    }

    @Test func surroundingTextIsStillCleaned() {
        #expect(clean("  intro   line  \nx\ty\n\n\n\noutro") == "intro line\nx\ty\n\noutro")
    }

    @Test func aLeadingTabAloneIsIndentationNotATable() {
        #expect(clean("\tindented   text") == "indented text")
    }

    @Test func aTrailingTabIsJustWhitespace() {
        #expect(clean("hello   world \t ") == "hello world")
    }

    @Test func spacesAroundTheTabStillCountAsACell() {
        #expect(clean("a \t b") == "a \t b")
    }

    @Test func protectionCanBeSwitchedOff() {
        var o = CleanOptions.standard
        o.protectTables = false
        #expect(clean("a\t\tb", o) == "a b")
    }

    @Test func tableRowsAreNeverJoinedByUnwrap() {
        var o = CleanOptions.standard
        o.unwrapParagraphs = true
        let sheet = "a very long first column value here\tx\nanother very long first column value\ty"
        #expect(clean(sheet, o) == sheet)
    }

    @Test func protectedRowsAreStable() {
        let once = clean("x\ty\t\n")
        #expect(clean(once) == once)
    }
}

@Suite struct ConservativeUnwrapTests {
    func prose(_ s: String) -> String { TextCleaner.clean(s, options: .prose) }

    @Test func unmarkedHeadingStaysOnItsOwnLine() {
        #expect(prose("Introduction\nThis paper studies how people use clipboards\nin great detail.")
                == "Introduction\nThis paper studies how people use clipboards in great detail.")
    }

    @Test func signOffStaysSeparate() {
        #expect(prose("Best,\nElmir") == "Best,\nElmir")
        #expect(prose("Thanks for your help.\n\nBest,\nElmir") == "Thanks for your help.\n\nBest,\nElmir")
    }

    @Test func shortLinesAreNeverJoined() {
        #expect(prose("roses are red\nviolets are blue") == "roses are red\nviolets are blue")
    }

    @Test func aTypicalWrappedParagraphIsJoined() {
        let wrapped = """
        Hard wrapping is common when text is copied out of a PDF or an old
        email, because the lines break at a fixed width and not at the end
        of a sentence, which makes the result awkward to reflow.
        """
        let expected = "Hard wrapping is common when text is copied out of a PDF or an old email, because the lines break at a fixed width and not at the end of a sentence, which makes the result awkward to reflow."
        #expect(prose(wrapped) == expected)
    }

    @Test func knownLimitationRunningUnwrapTwiceCanJoinParagraphsThatHaveNoBlankLineBetweenThem() {
        // Documented, not desired: after the first pass the paragraph's last short line is
        // buried inside a long merged line, so a second pass sees a "full" line and joins on.
        let input = "This first line is long enough to be considered a full wrapped line here\nend.\nHeading\nThe body text that follows the heading is also quite long, really."
        let once = prose(input)
        #expect(once == "This first line is long enough to be considered a full wrapped line here end.\nHeading\nThe body text that follows the heading is also quite long, really.")
        #expect(prose(once) != once)
    }

    @Test func aTwoSpaceHardBreakStopsJoining() {
        var o = CleanOptions.prose
        o.keepMarkdownLineBreaks = true
        let input = "This line is long enough to count as a full wrapped line  \nSecond line of the same paragraph continues here."
        #expect(TextCleaner.clean(input, options: o) == input)
    }
}

@Suite struct MarkdownBreakTests {
    @Test func trailingSpacesAreRemovedByDefault() {
        #expect(TextCleaner.clean("one  \ntwo") == "one\ntwo")
    }

    @Test func hardBreaksAreKeptAsExactlyTwoSpacesWhenAsked() {
        var o = CleanOptions.standard
        o.keepMarkdownLineBreaks = true
        #expect(TextCleaner.clean("one     \ntwo  \nthree ", options: o) == "one  \ntwo  \nthree")
    }

    @Test func keptBreaksAreStable() {
        var o = CleanOptions.standard
        o.keepMarkdownLineBreaks = true
        let once = TextCleaner.clean("a   \nb", options: o)
        #expect(TextCleaner.clean(once, options: o) == once)
    }
}

@Suite struct OptionToggleTests {
    @Test func everyToggleFlipsExactlyItsOwnSetting() {
        let base = CleanOptions.standard
        for toggle in OptionToggle.allCases {
            let flipped = toggle.toggled(base)
            #expect(flipped != base, "\(toggle) changed nothing")
            #expect(toggle.isOn(in: flipped) != toggle.isOn(in: base))
            for other in OptionToggle.allCases where other != toggle {
                #expect(other.isOn(in: flipped) == other.isOn(in: base), "\(toggle) also changed \(other)")
            }
        }
    }

    @Test func togglingTwiceRestoresTheOriginal() {
        for preset in [CleanOptions.standard, .code, .prose] {
            for toggle in OptionToggle.allCases {
                #expect(toggle.toggled(toggle.toggled(preset)) == preset)
            }
        }
    }

    @Test func titlesAreUniqueAndNotEmpty() {
        let titles = OptionToggle.allCases.map(\.title)
        #expect(Set(titles).count == titles.count)
        #expect(titles.allSatisfy { !$0.isEmpty })
    }

    @Test func rawValuesRoundTrip() {
        for toggle in OptionToggle.allCases {
            #expect(OptionToggle(rawValue: toggle.rawValue) == toggle)
        }
    }

    @Test func everyOptionFieldIsReachableFromAToggle() {
        // 10 toggles for the 10 independent switches in CleanOptions.
        #expect(OptionToggle.allCases.count == 10)
    }

    @Test func togglingAwayFromAPresetClearsTheMatchingPreset() {
        let changed = OptionToggle.straightenQuotes.toggled(.standard)
        #expect(changed.matchingPreset == nil)
        #expect(OptionToggle.straightenQuotes.toggled(changed).matchingPreset == "standard")
    }
}

@Suite struct ClipboardServiceTests {
    @Test func restoreBringsBackTheOriginal() {
        let board = FakePasteboard("  messy   text  ")
        let service = ClipboardService(pasteboard: board)
        service.clean(options: .standard)
        #expect(board.string == "messy text")
        #expect(service.canRestore)
        #expect(service.restore())
        #expect(board.string == "  messy   text  ")
    }

    @Test func restoreWorksOnlyOnce() {
        let board = FakePasteboard("a    b")
        let service = ClipboardService(pasteboard: board)
        service.clean(options: .standard)
        #expect(service.restore())
        #expect(!service.restore())
        #expect(!service.canRestore)
    }

    @Test func restoreRefusesWhenTheUserCopiedSomethingElseMeanwhile() {
        let board = FakePasteboard("a    b")
        let service = ClipboardService(pasteboard: board)
        service.clean(options: .standard)
        board.string = "something new the user copied"
        #expect(!service.canRestore)
        #expect(!service.restore())
        #expect(board.string == "something new the user copied")
    }

    @Test func nothingToRestoreBeforeAnyClean() {
        let service = ClipboardService(pasteboard: FakePasteboard("x"))
        #expect(!service.canRestore)
        #expect(!service.restore())
    }

    @Test func aNoOpCleanDoesNotReplaceTheRestorePoint() {
        let board = FakePasteboard("a    b")
        let service = ClipboardService(pasteboard: board)
        service.clean(options: .standard)          // "a b", original remembered
        service.clean(options: .standard)          // unchanged
        #expect(service.restore())
        #expect(board.string == "a    b")
    }

    @Test func emptyAndNonTextClipboardsAreNeverRestorePoints() {
        let blank = FakePasteboard("   ")
        let one = ClipboardService(pasteboard: blank)
        one.clean(options: .standard)
        #expect(!one.canRestore)

        let image = FakePasteboard(nil)
        let two = ClipboardService(pasteboard: image)
        two.clean(options: .standard)
        #expect(!two.canRestore)
    }
}

@Suite struct NewCLIFlagTests {
    @Test func newFlagsMapToOptions() throws {
        #expect(try parseCLI(["--collapse-tabs"]).options.protectTables == false)
        #expect(try parseCLI(["--keep-markdown-breaks"]).options.keepMarkdownLineBreaks)
    }

    @Test func spreadsheetDataSurvivesTheCLI() {
        var out = ""
        let status = runCLI(arguments: [], readStdin: { "a\tb\n1\t2" },
                            stdout: { out += $0 }, stderr: { _ in }, pasteboard: nil)
        #expect(status == 0 && out == "a\tb\n1\t2\n")
    }
}
