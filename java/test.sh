#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$root/.." && pwd)"
main_out="$root/out/main"
test_out="$root/out/test"

rm -rf "$root/out"
mkdir -p "$main_out" "$test_out"

main_sources=()
while IFS= read -r -d '' f; do
  main_sources+=("$f")
done < <(find "$root/src/main/java" -name '*.java' -print0 | sort -z)

test_sources=()
while IFS= read -r -d '' f; do
  test_sources+=("$f")
done < <(find "$root/src/test" -name '*.java' -print0 | sort -z)

javac -encoding UTF-8 -d "$main_out" "${main_sources[@]}"
javac -encoding UTF-8 -cp "$main_out" -d "$test_out" "${test_sources[@]}"

cd "$repo"
java -cp "$main_out:$test_out" packbin.PackbinTest
