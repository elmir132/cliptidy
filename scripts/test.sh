#!/bin/bash
# Runs the test suite.
#
# Builds the tests first, then runs them with --skip-build. With only the Command Line Tools
# installed (no Xcode), or inside another sandbox, compiling the Swift Testing macros fails
# intermittently with "plugin for module 'TestingMacros' not found". The build step is
# therefore retried (up to 5 times) and the tests are NEVER run against a stale binary: if
# the build does not succeed, this script fails. With a normal Xcode install `swift test`
# works directly and this script is optional.
set -uo pipefail
cd "$(dirname "$0")/.."

built=0
for attempt in 1 2 3 4 5; do
  if swift build --build-tests --disable-sandbox >/tmp/cliptidy-build.log 2>&1; then
    built=1
    break
  fi
  echo "build attempt $attempt failed, retrying" >&2
done
if [ $built -ne 1 ]; then
  sed 's/\x1b\[[0-9;]*m//g' /tmp/cliptidy-build.log | grep -E "error:" | head -5 | cut -c1-300
  echo "Build failed; not running tests against a stale binary." >&2
  exit 1
fi

out=$(swift test --skip-build "$@" 2>&1); status=$?
echo "$out" | sed 's/\x1b\[[0-9;]*m//g' | grep -E "✘|error:|Test run with" | cut -c1-300
exit $status
