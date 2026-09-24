#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
drivers="$root/.github/workflows/drivers"
user_hex="07007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465"
nested_hex="020003006d61700100010002006f7007006770735f666978050073746f72650200010002006f70040072656164010002006f7005007772697465"
position_hex="4001000065cd1d00a3e1110100"

run_lang() {
  local lang="$1"
  shift
  case "$lang" in
    csharp)
      dotnet run --project "$drivers/csharp/Handoff.csproj" -- "$@"
      ;;
    typescript)
      node --experimental-strip-types "$drivers/handoff.ts" "$@"
      ;;
    python)
      PYTHONPATH="$root/python/src${PYTHONPATH:+:$PYTHONPATH}" python3 "$drivers/handoff.py" "$@"
      ;;
    rust)
      cargo run --quiet --manifest-path "$drivers/handoff-rust/Cargo.toml" -- "$@"
      ;;
    cpp)
      local bin="${PACKBIN_CPP_HANDOFF:-/tmp/packbin-handoff}"
      local sdk="${PACKBIN_CXX_SYSROOT:-}"
      local flags=(-std=c++17 -O2 -Wall -Wextra -Werror -I"$root/cpp/include")
      if [ -n "$sdk" ]; then
        flags+=(-isysroot "$sdk" -I"$sdk/usr/include/c++/v1")
      fi
      "${CXX:-c++}" "${flags[@]}" -o "$bin" \
        "$drivers/handoff.cpp" "$root/cpp/src/field.cpp" "$root/cpp/src/packbin.cpp" "$root/cpp/src/counted.cpp" \
        "$root/cpp/src/walk_common.cpp" "$root/cpp/src/walk.cpp" "$root/cpp/src/unpack_walk.cpp"
      "$bin" "$@"
      ;;
    java)
      local out="${PACKBIN_JAVA_HANDOFF:-/tmp/packbin-handoff-java}"
      if [ ! -f "$out/Handoff.class" ]; then
        rm -rf "$out"
        mkdir -p "$out"
        local sources=()
        while IFS= read -r -d '' f; do
          sources+=("$f")
        done < <(find "$root/java/src/main/java" -name '*.java' -print0 | sort -z)
        javac -encoding UTF-8 -d "$out" "${sources[@]}" "$drivers/Handoff.java"
      fi
      java -cp "$out" Handoff "$@"
      ;;
    *)
      echo "unknown language: $lang" >&2
      exit 1
      ;;
  esac
}

handoff() {
  local producer="$1"
  local consumer="$2"
  local kind="$3"
  local expect="$4"
  local packed
  packed="$(run_lang "$producer" "pack-$kind" | tr -d '[:space:]')"
  if [ "$packed" != "$expect" ]; then
    echo "$producer pack-$kind mismatch" >&2
    exit 1
  fi
  run_lang "$consumer" "unpack-$kind" "$packed"
}

handoff csharp typescript user "$user_hex"
handoff typescript python user "$user_hex"
handoff python rust user "$user_hex"
handoff rust java user "$user_hex"
handoff java cpp user "$user_hex"
handoff cpp csharp user "$user_hex"

handoff csharp typescript nested "$nested_hex"
handoff typescript python nested "$nested_hex"
handoff python rust nested "$nested_hex"
handoff rust java nested "$nested_hex"
handoff java cpp nested "$nested_hex"
handoff cpp csharp nested "$nested_hex"

for lang in csharp typescript python rust cpp java; do
  got="$(bash "$root/.github/workflows/publish-position.sh" "$lang" | tr -d '[:space:]')"
  if [ "$got" != "$position_hex" ]; then
    echo "$lang position mismatch" >&2
    exit 1
  fi
done

echo "language pairs passed"
