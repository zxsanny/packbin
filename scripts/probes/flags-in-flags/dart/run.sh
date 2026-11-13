#!/usr/bin/env bash
# Dart probe of AZ-4251 (see ../README.md). The probe is copied to a temporary directory beside a pubspec
# that names the package by its path in this checkout, then resolved and run there; nothing is written
# into the checkout. The package has no dependency, so the resolve needs no network.
# Exit codes: 0 the probe ran (whatever it found), 1 no dart on PATH, or the resolve or the run failed.
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

cd "$work"
dart pub get </dev/null >&2
dart run probe.dart </dev/null
