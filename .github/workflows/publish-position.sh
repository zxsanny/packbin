#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=publish-lib.sh
source "$here/publish-lib.sh"

lang="${1:?language}"
root="$(publish_root)"
drivers="$here/drivers"

if ! language_present "$root" "$lang"; then
  echo "absent $lang" >&2
  exit 2
fi

case "$lang" in
  csharp)
    dotnet run --project "$drivers/csharp/Position.csproj" -v q --nologo
    ;;
  typescript)
    node --experimental-strip-types "$drivers/position.ts"
    ;;
  python)
    PYTHONPATH="$root/python/src${PYTHONPATH:+:$PYTHONPATH}" python3 "$drivers/position.py"
    ;;
  rust)
    CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-/tmp/packbin-position-rust}" \
      cargo run --quiet --manifest-path "$drivers/rust/Cargo.toml"
    ;;
  cpp)
    bin="${PACKBIN_CPP_BIN:-/tmp/packbin-position}"
    g++ -std=c++17 -O2 -Wall -Wextra -Werror -I"$root/cpp/include" -o "$bin" \
      "$drivers/position.cpp" "$root/cpp/src/field.cpp" "$root/cpp/src/packbin.cpp"
    "$bin"
    ;;
  java)
    out="${PACKBIN_JAVA_OUT:-/tmp/packbin-position-java}"
    rm -rf "$out"
    mkdir -p "$out"
    sources=()
    while IFS= read -r -d '' f; do
      sources+=("$f")
    done < <(find "$root/java/src/main/java" -name '*.java' -print0 | sort -z)
    javac -encoding UTF-8 -d "$out" "${sources[@]}" "$drivers/Position.java"
    java -cp "$out" Position
    ;;
  *)
    echo "unknown language: $lang" >&2
    exit 1
    ;;
esac
