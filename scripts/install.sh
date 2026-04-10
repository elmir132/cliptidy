#!/bin/bash
# Copies the built app to ~/Applications and the CLI to ~/.local/bin. Run build-app.sh first.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d dist/ClipTidy.app ] || { echo "Run scripts/build-app.sh first" >&2; exit 1; }

mkdir -p "$HOME/Applications" "$HOME/.local/bin"
rm -rf "$HOME/Applications/ClipTidy.app"
cp -R dist/ClipTidy.app "$HOME/Applications/ClipTidy.app"
cp dist/cliptidy "$HOME/.local/bin/cliptidy"
echo "Installed ~/Applications/ClipTidy.app and ~/.local/bin/cliptidy"
echo "Open it with: open ~/Applications/ClipTidy.app"
