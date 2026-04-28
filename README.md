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
| spreadsheet rows (cells separated by tabs) | unchanged, so they still paste into a spreadsheet |

Optional, switched on in the menu or by the **prose** preset:

- join hard-wrapped lines back into paragraphs. Only lines that look full are joined, so a heading, a name or a sign-off such as `Best,` stays on its own line. Lists, quotes and tables are left alone
- straighten curly quotes
- remove the ``` marker lines themselves
- keep Markdown line breaks (two trailing spaces)

If the clipboard holds an image or files, or only whitespace, ClipTidy leaves it alone. If the text is already clean it does not rewrite it. Cleaned text is written back as **plain text**, so rich formatting is dropped.

**Undo:** ⌃⌥⌘Z (or *Restore Original* in the menu) puts back the text from before the last clean. The original is kept in memory only, never written to disk, and it is restored only if the clipboard still holds what ClipTidy wrote. It never overwrites something you copied afterwards.

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

- **⌃⌥⌘V** or **⌃⌥⌘Space** cleans the clipboard. **⌃⌥⌘Z** undoes the last clean. The menu-bar icon shows ✓ when it worked, ↩ after an undo, and ✗ when there was nothing to do.
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
cliptidy --collapse-tabs               # also clean spreadsheet rows (off by default)
```

Exit status: 0 success, 1 nothing to clean on the clipboard, 2 usage error.

## How it is built

```
Sources/
  ClipTidyCore/   cleaning rules, options, menu toggles, clipboard + undo logic, CLI logic (no UI)
  ClipTidyApp/    menu-bar app: AppDelegate (menu, settings), HotKeys (Carbon hotkeys)
  ClipTidyCLI/    the thin `cliptidy` executable
Tests/            87 tests on the core
scripts/          build-app.sh, install.sh, test.sh, smoke-cli.sh
```

The cleaner is a pure function from text and options to text, so it is easy to test. The shortcuts use the Carbon hotkey API, which needs **no Accessibility permission**.

Design decisions worth knowing:

- **Code blocks are protected, and the ``` lines are kept by default.** If the markers were removed, the code would become ordinary text and a second press of the shortcut would strip its indentation. Removing the markers is an explicit option, and the tests document that it should be used once.
- **Cleaning is idempotent** for the standard and code presets: cleaning already-clean text changes nothing, so pressing the shortcut twice is harmless. The tests check this on fixed samples and on 300 pseudo-random inputs. The one exception is the heuristic *join hard-wrapped lines* option: if two paragraphs have no blank line between them, a second pass can join them. A test documents this, and undo covers the mistake.
- **Menu toggles are data.** The menu is generated from `OptionToggle`, which lives in the core and is unit-tested, so the AppKit code stays thin.
- **Spreadsheet rows are recognised by a tab between two pieces of text.** A leading tab (indentation) or a trailing tab (stray whitespace) does not count.
- **Zero-width joiners are kept.** They hold emoji sequences and some scripts together, so only zero-width space, word joiner, byte-order mark and soft hyphen are removed.

## Tests

```bash
swift test          # 87 tests (Swift Testing)
make test           # same, via scripts/test.sh (see Limitations)
make smoke          # builds, then end-to-end checks of the CLI with real pipes
```

## Limitations

- **The global shortcut is not covered by automated tests.** The cleaning logic, the clipboard logic, the settings and the CLI are tested; whether macOS delivers ⌃⌥⌘V to the app is something I could only check by hand. If another app has registered the same shortcut, which app receives it is up to macOS.
- The shortcuts are fixed. They cannot be changed in the app yet.
- *Join hard-wrapped lines* is a heuristic (a line counts as wrapped if it is at least 30 characters and at least 60% of the longest line in its paragraph). It can miss a wrap and, rarely, join a line it should not. It is off unless you pick the prose preset or enable it.
- Rows with a single tab-separated column, or whose first cell is empty, look like indentation and are cleaned like ordinary text.
- **Launch at Login** is implemented with `SMAppService` and has not been exercised on a clean machine.
- Plain text only: rich text, images and files are not cleaned.
- No app icon yet; the menu bar uses a system symbol.
- No prebuilt, notarized download.
- With only the Command Line Tools installed, or inside another sandbox, a plain `swift test` can fail intermittently with "plugin for module 'TestingMacros' not found". The error goes away on a retry. `make test` builds the tests with `--disable-sandbox`, retries the build up to five times, and refuses to run tests against a stale binary. In my runs the second attempt succeeded. A normal Xcode install should not need this, but I have not tried it on one.

## AI assistance

ClipTidy grew out of a personal clipboard helper (an AppleScript and Swift prototype, itself built with AI assistants). This product version, with the core library, tests, CLI and packaging, was developed with AI assistance (Claude Code). I specified the behaviour and reviewed the result.

## License

MIT
