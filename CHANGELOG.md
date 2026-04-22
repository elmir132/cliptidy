# Changelog

## 0.1.0

First release.

- Menu-bar app with global shortcuts Control+Option+Command+V and Control+Option+Command+Space that clean the text on the clipboard in place.
- Cleaning: trim lines, collapse repeated spaces and blank lines, fix non-breaking and invisible characters, optional quote straightening, optional joining of hard-wrapped paragraphs, optional removal of ``` marker lines. Code inside ``` blocks is never changed.
- Presets (standard, code, prose) and individual toggles in the menu, remembered between launches.
- Launch at login toggle.
- `cliptidy` command-line tool: stdin to stdout, or `--clipboard` to clean in place.
- Text that is not text (images, files) and whitespace-only text are never written over the clipboard.
