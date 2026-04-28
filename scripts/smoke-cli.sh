#!/bin/bash
# End-to-end check of the command-line tool using real pipes. Does not touch the clipboard.
set -euo pipefail
cd "$(dirname "$0")/.."
CLI=${1:-dist/cliptidy}
fail() { echo "FAIL: $1" >&2; exit 1; }

out=$(printf '  hello   world  \n\n\n\nbye\n' | "$CLI")
[ "$out" = $'hello world\n\nbye' ] || fail "basic clean (got: $out)"

out=$(printf 'a line that is long enough to count as wrapped\nand its continuation\n' | "$CLI" --unwrap)
[ "$out" = "a line that is long enough to count as wrapped and its continuation" ] || fail "unwrap (got: $out)"

out=$(printf 'wrapped\nline\n' | "$CLI" --unwrap)
[ "$out" = $'wrapped\nline' ] || fail "short lines must not be joined"

out=$(printf '```\n    keep   me\n```\n' | "$CLI")
[ "$out" = $'```\n    keep   me\n```' ] || fail "code protected"

out=$(printf '```\n    keep   me\n```\n' | "$CLI" --strip-fences)
[ "$out" = "    keep   me" ] || fail "strip fences"

out=$(printf 'name\tqty\napple\t3\n' | "$CLI")
[ "$out" = $'name\tqty\napple\t3' ] || fail "spreadsheet rows must keep their tabs"

out=$(printf 'Introduction\nThis paper studies how people use clipboards\nin great detail.\n' | "$CLI" -p prose)
[ "$out" = $'Introduction\nThis paper studies how people use clipboards in great detail.' ] || fail "heading must stay separate (got: $out)"

out=$(printf 'Best,\nElmir\n' | "$CLI" -p prose)
[ "$out" = $'Best,\nElmir' ] || fail "sign-off must stay separate"

out=$(printf 'line one  \nline two\n' | "$CLI" --keep-markdown-breaks)
[ "$out" = $'line one  \nline two' ] || fail "markdown hard break"

[ "$("$CLI" --version)" = "cliptidy $(grep -o '"[0-9][0-9.]*"' Sources/ClipTidyCore/Version.swift | tr -d '"')" ] || fail "version"

set +e
"$CLI" --bogus >/dev/null 2>&1; [ $? -eq 2 ] || fail "unknown flag should exit 2"
"$CLI" -p nope >/dev/null 2>&1; [ $? -eq 2 ] || fail "unknown preset should exit 2"
set -e

echo "cli smoke test passed"
