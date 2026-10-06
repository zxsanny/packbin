#!/usr/bin/env bash
# TypeScript position gate check (AZ-2238 AC-1, AC-2). publish-gate.test.sh runs it as a child process.
# publish-position.sh typescript on a tree without node_modules installs on its own work copy. The work
# copy's temp dir is reached through a symlink: a PATH shim makes `mktemp -d` return a path under one, the
# same shape as macOS /var/folders (/var is a link to /private/var), where `npm ci --prefix` used to fail
# with "Missing: typescript@... from lock file". Needs npm and its registry for the two locked packages,
# as npm_dist_checks does. Exit 0 when every check passes, 1 otherwise.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
copy="$tmp/copy"
real="$tmp/real"
link="$tmp/link"
bin="$tmp/bin"
mkdir -p "$copy/.github/workflows/drivers" "$real" "$bin"
ln -s "$real" "$link"
tar -C "$root" --exclude node_modules --exclude dist -cf - typescript | tar -C "$copy" -xf -
cp "$root/.github/workflows/drivers/position.ts" "$copy/.github/workflows/drivers/position.ts"
printf '#!/bin/sh\nexec "%s" -d "%s/work.XXXXXX"\n' "$(command -v mktemp)" "$link" > "$bin/mktemp"
chmod +x "$bin/mktemp"

# AC-1: the golden hex on stdout, the npm output on stderr.
if got="$(PATH="$bin:$PATH" SRC_ROOT="$copy" bash "$here/publish-position.sh" typescript 2> "$tmp/position.err")"; then
  want="$(tr -d '[:space:]' < "$root/fixtures/golden.hex")"
  got="$(tr -d '[:space:]' <<< "$got")"
  if [ "$got" != "$want" ]; then
    fail "AZ-2238 AC-1 position hex of a typescript tree without node_modules: expected [$want] got [$got]"
  fi
else
  fail "AZ-2238 AC-1 publish-position.sh typescript failed on a symlinked temp path: $(head -n 6 "$tmp/position.err")"
fi

# AC-2: the install ran on the work copy, which the script removed.
if [ -e "$copy/typescript/node_modules" ]; then
  fail "AZ-2238 AC-2 npm ci wrote typescript/node_modules into the tree it was given"
fi
kept="$(ls -A "$real")"
if [ -n "$kept" ]; then
  fail "AZ-2238 AC-2 the script left its temp directory behind: $kept"
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "npm position check passed"
