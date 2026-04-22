# ClipTidy

![build](https://github.com/elmir132/cliptidy/actions/workflows/ci.yml/badge.svg)

A small macOS menu-bar app that cleans up the text on your clipboard with one shortcut. Copy messy text, press **⌃⌥⌘V**, paste clean text.

It fixes what makes pasted text annoying: stray spaces and tabs, long runs of blank lines, non-breaking and invisible characters, hard-wrapped paragraphs from PDFs and emails, curly quotes. Code inside Markdown ``` blocks is never touched.

There is also a command-line tool, `cliptidy`, for pipes and scripts.

Everything runs locally. No network access, no analytics, and the clipboard is read only when you trigger a clean.

## What it does

| Before | After (standard) |
|---|---|
| `␣␣Hello␣␣␣world␣␣` | `Hello world` |
| three or more blank lines in a row | one blank line |
| `a` + non-breaking space + `b` | `a b` |
| zero-width space, byte-order mark, soft hyphen | removed |
| code in a fenced block, with its indentation | unchanged |

Optional, switched on in the menu or by the **prose** preset:

- join hard-wrapped lines back into paragraphs (lists, headings, quotes and tables are left alone)
- straighten curly quotes
- remove the ``` marker lines themselves

If the clipboard holds an image or files, or only whitespace, ClipTidy leaves it alone. If the text is already clean it does not rewrite it. Cleaned text is written back as **plain text**, so rich formatting is dropped.

## Install

ClipTidy is built from source. It needs macOS 13+ and a Swift 6 toolchain (Xcode 16 or newer).

```bash
git clone https://github.com/elmir132/cliptidy.git
cd cliptidy
make install        # builds, then copies ClipTidy.app to ~/Applications and cliptidy to ~/.local/bin
open ~/Applications/ClipTidy.app
```

The app is ad-hoc signed and not notarized. A copy you build yourself runs normally; a copy downloaded from somewhere else would be blocked by Gatekeeper until you approve it in System Settings.

## Use

- **⌃⌥⌘V** or **⌃⌥⌘Space** cleans the clipboard. The menu-bar icon shows ✓ when it worked and ✗ when there was nothing to clean.
- **Preset** in the menu picks standard, code or prose. **Options** has one toggle per setting. Choices are remembered.
- **Launch at Login** adds the app to your login items. Install the app in `/Applications` or `~/Applications` first.

| Preset | Indentation | Spaces | Blank lines | Join wrapped lines | Straight quotes |
|---|---|---|---|---|---|
| standard | removed | collapsed | collapsed | no | no |
| code | kept | kept | kept | no | no |
| prose | removed | collapsed | collapsed | yes | yes |

All presets protect code between ``` fences.

### Command line

```bash
pbpaste | cliptidy | pbcopy            # clean text from stdin
cliptidy --clipboard                   # clean the clipboard in place
cliptidy -p prose < article.txt        # presets: standard, code, prose
cliptidy --unwrap --straight-quotes    # individual options; run `cliptidy --help`
```

Exit status: 0 success, 1 nothing to clean on the clipboard, 2 usage error.

## How it is built

```
Sources/
  ClipTidyCore/   cleaning rules, options, clipboard logic, CLI logic (no UI)
  ClipTidyApp/    menu-bar app: AppDelegate (menu, settings), HotKeys (Carbon hotkeys)
  ClipTidyCLI/    the thin `cliptidy` executable
Tests/            55 tests on the core
scripts/          build-app.sh, install.sh, smoke-cli.sh
```

The cleaner is a pure function from text and options to text, so it is easy to test. The shortcuts use the Carbon hotkey API, which needs **no Accessibility permission**.

Design decisions worth knowing:

- **Code blocks are protected, and the ``` lines are kept by default.** If the markers were removed, the code would become ordinary text and a second press of the shortcut would strip its indentation. Removing the markers is an explicit option, and the tests document that it should be used once.
- **Cleaning is idempotent** for the default settings and the three presets: cleaning already-clean text changes nothing. The tests check this on fixed samples and on 300 pseudo-random inputs.
- **Zero-width joiners are kept.** They hold emoji sequences and some scripts together, so only zero-width space, word joiner, byte-order mark and soft hyphen are removed.

## Tests

```bash
swift test          # 55 tests (Swift Testing)
make smoke          # builds, then end-to-end checks of the CLI with real pipes
```

## Limitations

- **The global shortcut is not covered by automated tests.** The cleaning logic, the clipboard logic, the settings and the CLI are tested; whether macOS delivers ⌃⌥⌘V to the app is something I could only check by hand. If another app has registered the same shortcut, which app receives it is up to macOS.
- The shortcuts are fixed. They cannot be changed in the app yet.
- **Launch at Login** is implemented with `SMAppService` and has not been exercised on a clean machine.
- Plain text only: rich text, images and files are not cleaned.
- No app icon yet; the menu bar uses a system symbol.
- No prebuilt, notarized download.
- With a Command Line Tools-only setup, `swift test` can intermittently fail with a "TestingMacros plugin not found" error. Re-running it or using a full Xcode install avoids this.

## AI assistance

ClipTidy grew out of a personal clipboard helper (an AppleScript and Swift prototype, itself built with AI assistants). This product version, with the core library, tests, CLI and packaging, was developed with AI assistance (Claude Code). I specified the behaviour and reviewed the result.

## License

MIT
