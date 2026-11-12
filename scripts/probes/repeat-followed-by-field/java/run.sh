#!/usr/bin/env bash
# Java probe of AZ-4206 (see ../README.md). The package sources and the probe are compiled into a
# temporary directory that is removed on exit; nothing is written into the repository. Compiler
# messages and the lines of the second ways of writing a scheme go to stderr; stdout holds one probe
# line per shape. Exit 0 when the probe ran, whatever it found; non-zero when the build or the run failed.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../../.." && pwd)"

command -v javac >/dev/null || { echo "javac not found" >&2; exit 1; }
command -v java >/dev/null || { echo "java not found" >&2; exit 1; }

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

sources=()
while IFS= read -r -d '' file; do
  sources+=("$file")
done < <(find "$root/java/src/main/java" -name '*.java' -print0)
# Tested before the array is expanded: bash 3.2 calls an empty "${sources[@]}" an unbound variable under set -u.
if [[ "${#sources[@]}" -eq 0 ]]; then
  echo "no Java source found under $root/java/src/main/java" >&2
  exit 1
fi

javac --release 17 -encoding UTF-8 -d "$out" "${sources[@]}" "$here/RepeatProbe.java" >&2 </dev/null
java -cp "$out" RepeatProbe </dev/null
