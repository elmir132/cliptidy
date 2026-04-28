# Changelog

## 0.1.0

First release.

- Menu-bar app with global shortcuts Control+Option+Command+V and Control+Option+Command+Space that clean the text on the clipboard in place.
- Cleaning: trim lines, collapse repeated spaces and blank lines, fix non-breaking and invisible characters, optional quote straightening, optional joining of hard-wrapped paragraphs (only lines that look full, so headings and sign-offs stay put), optional Markdown line breaks, optional removal of ``` marker lines. Code inside ``` blocks and tab-separated spreadsheet rows are never changed.
- Undo for the last clean (Control+Option+Command+Z or the menu), kept in memory only and refused if the clipboard changed since.
- Presets (standard, code, prose) and individual toggles in the menu, remembered between launches.
- Launch at login toggle.
- `cliptidy` command-line tool: stdin to stdout, or `--clipboard` to clean in place.
- Text that is not text (images, files) and whitespace-only text are never written over the clipboard.
