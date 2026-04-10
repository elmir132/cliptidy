#!/bin/bash
# Builds dist/ClipTidy.app (ad-hoc signed) and dist/cliptidy (the command-line tool).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(grep -o '"[0-9][0-9.]*"' Sources/ClipTidyCore/Version.swift | tr -d '"')
swift build -c release --product ClipTidyApp
swift build -c release --product cliptidy
BIN=$(swift build -c release --show-bin-path)

APP="dist/ClipTidy.app"
rm -rf "$APP" dist/cliptidy
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/ClipTidyApp" "$APP/Contents/MacOS/ClipTidy"
sed "s/__VERSION__/$VERSION/g" resources/Info.plist.template > "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
cp "$BIN/cliptidy" dist/cliptidy

echo "Built $APP and dist/cliptidy (version $VERSION)"
