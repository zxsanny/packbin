#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
drivers="$root/.github/workflows/drivers"
user_hex="0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465"
nested_hex="01020003006d61700100010002006f7007006770735f666978050073746f72650200010002006f70040072656164010002006f7005007772697465"
position_hex="4001000065cd1d00a3e1110100"
session_hex="b55d0a29c56c203712b241232e"
# flags { bool on }: the bit is set only for true (README, bool).
boolflag_hex="0100"
booltrue_hex="0101"
# u8 k; split flag byte m; when(k == 1) { m.bit(u8 v) }, row {k:0, v:5}: the bit is set although the
# when is not taken, and unpack never reads it (project AC-4). Python writes it as a flag_byte split.
bitwhen_hex="010001"
# repeat(flags(bool on, u8 n)), on [true, false, true], n [1, 2, 3]: a clear bit is never read, so the
# aligned entry is null (AZ-2087, AZ-2091). C# only produces: no public C# API reads an aligned round
# row yet (AZ-2092). Python joins with AZ-2134.
roundflags_hex="01030102020303"
# repeat(u8 k, when(k == 1, u8 v)), k [1, 2], v [9]: v unpacks aligned as [9, null]. Same omissions.
roundwhen_hex="01010902"

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
        "$drivers/handoff.cpp" "$root/cpp/src/core/values.cpp" "$root/cpp/src/core/pack.cpp" \
        "$root/cpp/src/core/unpack.cpp" "$root/cpp/src/core/session.cpp" "$root/cpp/src/os_random.cpp"
      "$bin" "$@"
      ;;
    java)
      local out="${PACKBIN_JAVA_HANDOFF:-/tmp/packbin-handoff-java}"
      # Rebuild when the driver or any package source is newer than the last build.
      if [ ! -f "$out/Handoff.class" ] || [ -n "$(find "$root/java/src/main/java" "$drivers/Handoff.java" -newer "$out/Handoff.class" -print -quit)" ]; then
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

handoff csharp typescript boolflag "$boolflag_hex"
handoff typescript python boolflag "$boolflag_hex"
handoff python rust boolflag "$boolflag_hex"
handoff rust java boolflag "$boolflag_hex"
handoff java cpp boolflag "$boolflag_hex"
handoff cpp csharp boolflag "$boolflag_hex"

handoff csharp typescript booltrue "$booltrue_hex"
handoff typescript python booltrue "$booltrue_hex"
handoff python rust booltrue "$booltrue_hex"
handoff rust java booltrue "$booltrue_hex"
handoff java cpp booltrue "$booltrue_hex"
handoff cpp csharp booltrue "$booltrue_hex"

handoff csharp typescript bitwhen "$bitwhen_hex"
handoff typescript python bitwhen "$bitwhen_hex"
handoff python rust bitwhen "$bitwhen_hex"
handoff rust java bitwhen "$bitwhen_hex"
handoff java cpp bitwhen "$bitwhen_hex"
handoff cpp csharp bitwhen "$bitwhen_hex"

handoff csharp typescript roundflags "$roundflags_hex"
handoff typescript rust roundflags "$roundflags_hex"
handoff rust java roundflags "$roundflags_hex"
handoff java cpp roundflags "$roundflags_hex"
handoff cpp typescript roundflags "$roundflags_hex"

handoff csharp typescript roundwhen "$roundwhen_hex"
handoff typescript rust roundwhen "$roundwhen_hex"
handoff rust java roundwhen "$roundwhen_hex"
handoff java cpp roundwhen "$roundwhen_hex"
handoff cpp typescript roundwhen "$roundwhen_hex"

for lang in csharp typescript python rust cpp java; do
  got="$(run_lang "$lang" "pack-session" | tr -d '[:space:]')"
  if [ "$got" != "$session_hex" ]; then
    echo "$lang pack-session mismatch" >&2
    exit 1
  fi
done

handoff csharp typescript session "$session_hex"
handoff typescript python session "$session_hex"
handoff python rust session "$session_hex"
handoff rust java session "$session_hex"
handoff java cpp session "$session_hex"
handoff cpp csharp session "$session_hex"

for lang in csharp typescript python rust cpp java; do
  got="$(bash "$root/.github/workflows/publish-position.sh" "$lang" | tr -d '[:space:]')"
  if [ "$got" != "$position_hex" ]; then
    echo "$lang position mismatch" >&2
    exit 1
  fi
done

echo "language pairs passed"
