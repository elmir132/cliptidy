#!/bin/bash
# End-to-end check of the command-line tool using real pipes. Does not touch the clipboard.
set -euo pipefail
cd "$(dirname "$0")/.."
CLI=${1:-dist/cliptidy}
fail() { echo "FAIL: $1" >&2; exit 1; }

out=$(printf '  hello   world  \n\n\n\nbye\n' | "$CLI")
[ "$out" = $'hello world\n\nbye' ] || fail "basic clean (got: $out)"

out=$(printf 'wrapped\nline\n' | "$CLI" --unwrap)
[ "$out" = "wrapped line" ] || fail "unwrap"

out=$(printf '```\n    keep   me\n```\n' | "$CLI")
[ "$out" = $'```\n    keep   me\n```' ] || fail "code protected"

out=$(printf '```\n    keep   me\n```\n' | "$CLI" --strip-fences)
[ "$out" = "    keep   me" ] || fail "strip fences"

[ "$("$CLI" --version)" = "cliptidy $(grep -o '"[0-9][0-9.]*"' Sources/ClipTidyCore/Version.swift | tr -d '"')" ] || fail "version"

set +e
"$CLI" --bogus >/dev/null 2>&1; [ $? -eq 2 ] || fail "unknown flag should exit 2"
"$CLI" -p nope >/dev/null 2>&1; [ $? -eq 2 ] || fail "unknown preset should exit 2"
set -e

echo "cli smoke test passed"
