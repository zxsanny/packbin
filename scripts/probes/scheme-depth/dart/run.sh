#!/usr/bin/env bash
# Dart probe of AZ-4291 (see ../README.md). The probe is copied to a temporary directory beside a pubspec
# that names the package by its path in this checkout, then resolved and run there; nothing is written
# into the checkout. The package has no dependency, so the resolve needs no network. One process per shape
# and depth, through ../case.sh, so a stack overflow or a hang is one line.
# Exit codes: 0 the probe ran (whatever it found), 1 no dart on PATH, or the resolve failed.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../../.." && pwd)"

if ! command -v dart >/dev/null; then
  printf 'dart probe: no dart on PATH (the package needs Dart 3.13 or newer)\n' >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cp "$here/probe.dart" "$work/probe.dart"
# A single-quoted YAML string: a quote in the path is doubled. The quote is in a variable because
# bash 3.2 (macOS) keeps the backslashes of \' inside a quoted ${var//pattern/text}.
package="$root/dart"
q="'"
printf "name: packbin_probe\npublish_to: none\nenvironment:\n  sdk: ^3.13.0\ndependencies:\n  packbin:\n    path: '%s'\n" \
  "${package//$q/$q$q}" >"$work/pubspec.yaml"

(cd "$work" && dart pub get </dev/null >&2)
# A probe that does not compile must stop the run here, not show as six crashed cases.
(cd "$work" && dart run probe.dart when 1 </dev/null >/dev/null)

for shape in when group; do
  for depth in 1000 5000 50000; do
    bash "$here/../case.sh" dart "$shape-$depth" 60 dart run "$work/probe.dart" "$shape" "$depth"
  done
done
