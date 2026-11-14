#!/usr/bin/env bash
# Java probe of AZ-4291 (scheme depth; see DepthProbe.java). The package sources and the probe are compiled
# into a temporary directory that is removed on exit; nothing is written into the repository. Each shape and
# depth runs in its own JVM through ../case.sh with a 60 s limit, so a stack overflow or a hang is one line.
# The JVM has its default stack on purpose. stdout: one probe line per case. Exit 0 when the probe ran.
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

javac --release 17 -encoding UTF-8 -d "$out" "${sources[@]}" "$here/DepthProbe.java" >&2 </dev/null

for shape in when group; do
  for depth in 1000 5000 50000; do
    bash "$here/../case.sh" java "$shape-$depth" 60 java -cp "$out" DepthProbe "$shape" "$depth"
  done
done
