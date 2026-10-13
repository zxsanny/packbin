#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
drivers="$root/.github/workflows/drivers"
# The C# and C++ drivers are built once a run into a private directory (mode 700), never into a predictable /tmp
# path another local user could pre-create (the F24 pattern of the Java driver below).
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
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
# AZ-2239: a list of group, a dict of group and a list of flags (AZ-2102), each element u8 a and u8 b (u16 b in
# the flags): [{a:1,b:2},{a:3,b:4}]; {y:{a:3,b:4}, x:{a:1,b:2}} written in unsigned key order; and
# [{a:1},{},{b:2}], where a missing value is a clear flag bit.
listgroup_hex="01020001020304"
dictgroup_hex="01020001007801020100790304"
listflags_hex="010300010100020200"
# The same packets with the last element cut short: its second value (or the flags item's u16) is missing.
listgroup_short_hex="010200010203"
dictgroup_short_hex="010200010078010201007903"
listflags_short_hex="0103000101000202"

run_lang() {
  local lang="$1"
  shift
  case "$lang" in
    csharp)
      # `dotnet run` costs about 2 s a call even when nothing changed (40 calls in the ring): build once a run and
      # run the dll. The build goes to stderr: handoff() compares the stdout of a pack call with the expected hex.
      if [ ! -f "$work/csharp/Handoff.dll" ]; then
        dotnet build "$drivers/csharp/Handoff.csproj" --nologo -v q -o "$work/csharp" >&2 || return
      fi
      dotnet "$work/csharp/Handoff.dll" "$@"
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
      local bin="${PACKBIN_CPP_HANDOFF:-$work/cpp-handoff}"
      local sdk="${PACKBIN_CXX_SYSROOT:-}"
      local flags=(-std=c++17 -O2 -Wall -Wextra -Werror -I"$root/cpp/include")
      if [ -n "$sdk" ]; then
        flags+=(-isysroot "$sdk" -I"$sdk/usr/include/c++/v1")
      fi
      # Compile once a run (it was compiled on every call, about 2 s each, 32 calls); a PACKBIN_CPP_HANDOFF path
      # given by the caller is compiled on every call, as before. `|| return` on the compile: handoff() runs
      # run_lang under `if`, where set -e is off, and a stale binary must not stand in for a build that failed.
      if [ -n "${PACKBIN_CPP_HANDOFF:-}" ] || [ ! -x "$bin" ]; then
        "${CXX:-c++}" "${flags[@]}" -o "$bin" \
          "$drivers/handoff.cpp" "$root/cpp/src/core/values.cpp" "$root/cpp/src/core/pack.cpp" \
          "$root/cpp/src/core/unpack.cpp" "$root/cpp/src/core/session.cpp" "$root/cpp/src/os_random.cpp" \
          || return
      fi
      "$bin" "$@"
      ;;
    java)
      local out="${PACKBIN_JAVA_HANDOFF:-/tmp/packbin-handoff-java}"
      # Rebuild when a driver file or any package source is newer than the last build, or a driver class is missing.
      if [ ! -f "$out/Handoff.class" ] || [ ! -f "$out/HandoffElements.class" ] \
        || [ -n "$(find "$root/java/src/main/java" "$drivers/Handoff.java" "$drivers/HandoffElements.java" -newer "$out/Handoff.class" -print -quit)" ]; then
        rm -rf "$out"
        mkdir -p "$out"
        local sources=()
        while IFS= read -r -d '' f; do
          sources+=("$f")
        done < <(find "$root/java/src/main/java" -name '*.java' -print0 | sort -z)
        javac -encoding UTF-8 -d "$out" "${sources[@]}" "$drivers/Handoff.java" "$drivers/HandoffElements.java" || return
      fi
      java -cp "$out" Handoff "$@"
      ;;
    go)
      # ring-go.sh builds the driver (host go, or the golang image for the host OS on a machine without Go) and
      # only when a source is newer than the binary; `|| return` for the reason given at the cpp case.
      local gobin="${PACKBIN_GO_HANDOFF:-/tmp/packbin-handoff-go}"
      bash "$root/.github/workflows/ring-go.sh" "$gobin" . || return
      "$gobin" "$@"
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
  if ! packed="$(run_lang "$producer" "pack-$kind" | tr -d '[:space:]')"; then
    echo "$producer pack-$kind failed" >&2
    exit 1
  fi
  if [ "$packed" != "$expect" ]; then
    echo "$producer pack-$kind mismatch" >&2
    exit 1
  fi
  if ! run_lang "$consumer" "unpack-$kind" "$packed"; then
    echo "$consumer unpack-$kind failed on the bytes packed by $producer" >&2
    exit 1
  fi
}

handoff csharp typescript user "$user_hex"
handoff typescript python user "$user_hex"
handoff python rust user "$user_hex"
handoff rust java user "$user_hex"
handoff java cpp user "$user_hex"
handoff cpp csharp user "$user_hex"
# Go (AZ-2449) joins every kind both ways with each member of that kind's ring: the handoff lines with go as the
# producer and as the consumer follow the kind's chain (C# only produces roundflags and roundwhen, so for those two
# kinds C# has no line with go as the producer). ring-wiring.test.sh fails when one is missing.
handoff go csharp user "$user_hex"
handoff csharp go user "$user_hex"
handoff go typescript user "$user_hex"
handoff typescript go user "$user_hex"
handoff go python user "$user_hex"
handoff python go user "$user_hex"
handoff go rust user "$user_hex"
handoff rust go user "$user_hex"
handoff go java user "$user_hex"
handoff java go user "$user_hex"
handoff go cpp user "$user_hex"
handoff cpp go user "$user_hex"

handoff csharp typescript nested "$nested_hex"
handoff typescript python nested "$nested_hex"
handoff python rust nested "$nested_hex"
handoff rust java nested "$nested_hex"
handoff java cpp nested "$nested_hex"
handoff cpp csharp nested "$nested_hex"
handoff go csharp nested "$nested_hex"
handoff csharp go nested "$nested_hex"
handoff go typescript nested "$nested_hex"
handoff typescript go nested "$nested_hex"
handoff go python nested "$nested_hex"
handoff python go nested "$nested_hex"
handoff go rust nested "$nested_hex"
handoff rust go nested "$nested_hex"
handoff go java nested "$nested_hex"
handoff java go nested "$nested_hex"
handoff go cpp nested "$nested_hex"
handoff cpp go nested "$nested_hex"

handoff csharp typescript boolflag "$boolflag_hex"
handoff typescript python boolflag "$boolflag_hex"
handoff python rust boolflag "$boolflag_hex"
handoff rust java boolflag "$boolflag_hex"
handoff java cpp boolflag "$boolflag_hex"
handoff cpp csharp boolflag "$boolflag_hex"
handoff go csharp boolflag "$boolflag_hex"
handoff csharp go boolflag "$boolflag_hex"
handoff go typescript boolflag "$boolflag_hex"
handoff typescript go boolflag "$boolflag_hex"
handoff go python boolflag "$boolflag_hex"
handoff python go boolflag "$boolflag_hex"
handoff go rust boolflag "$boolflag_hex"
handoff rust go boolflag "$boolflag_hex"
handoff go java boolflag "$boolflag_hex"
handoff java go boolflag "$boolflag_hex"
handoff go cpp boolflag "$boolflag_hex"
handoff cpp go boolflag "$boolflag_hex"

handoff csharp typescript booltrue "$booltrue_hex"
handoff typescript python booltrue "$booltrue_hex"
handoff python rust booltrue "$booltrue_hex"
handoff rust java booltrue "$booltrue_hex"
handoff java cpp booltrue "$booltrue_hex"
handoff cpp csharp booltrue "$booltrue_hex"
handoff go csharp booltrue "$booltrue_hex"
handoff csharp go booltrue "$booltrue_hex"
handoff go typescript booltrue "$booltrue_hex"
handoff typescript go booltrue "$booltrue_hex"
handoff go python booltrue "$booltrue_hex"
handoff python go booltrue "$booltrue_hex"
handoff go rust booltrue "$booltrue_hex"
handoff rust go booltrue "$booltrue_hex"
handoff go java booltrue "$booltrue_hex"
handoff java go booltrue "$booltrue_hex"
handoff go cpp booltrue "$booltrue_hex"
handoff cpp go booltrue "$booltrue_hex"

handoff csharp typescript bitwhen "$bitwhen_hex"
handoff typescript python bitwhen "$bitwhen_hex"
handoff python rust bitwhen "$bitwhen_hex"
handoff rust java bitwhen "$bitwhen_hex"
handoff java cpp bitwhen "$bitwhen_hex"
handoff cpp csharp bitwhen "$bitwhen_hex"
handoff go csharp bitwhen "$bitwhen_hex"
handoff csharp go bitwhen "$bitwhen_hex"
handoff go typescript bitwhen "$bitwhen_hex"
handoff typescript go bitwhen "$bitwhen_hex"
handoff go python bitwhen "$bitwhen_hex"
handoff python go bitwhen "$bitwhen_hex"
handoff go rust bitwhen "$bitwhen_hex"
handoff rust go bitwhen "$bitwhen_hex"
handoff go java bitwhen "$bitwhen_hex"
handoff java go bitwhen "$bitwhen_hex"
handoff go cpp bitwhen "$bitwhen_hex"
handoff cpp go bitwhen "$bitwhen_hex"

handoff csharp typescript roundflags "$roundflags_hex"
handoff typescript rust roundflags "$roundflags_hex"
handoff rust java roundflags "$roundflags_hex"
handoff java cpp roundflags "$roundflags_hex"
handoff cpp typescript roundflags "$roundflags_hex"
handoff csharp go roundflags "$roundflags_hex"
handoff go typescript roundflags "$roundflags_hex"
handoff typescript go roundflags "$roundflags_hex"
handoff go rust roundflags "$roundflags_hex"
handoff rust go roundflags "$roundflags_hex"
handoff go java roundflags "$roundflags_hex"
handoff java go roundflags "$roundflags_hex"
handoff go cpp roundflags "$roundflags_hex"
handoff cpp go roundflags "$roundflags_hex"

handoff csharp typescript roundwhen "$roundwhen_hex"
handoff typescript rust roundwhen "$roundwhen_hex"
handoff rust java roundwhen "$roundwhen_hex"
handoff java cpp roundwhen "$roundwhen_hex"
handoff cpp typescript roundwhen "$roundwhen_hex"
handoff csharp go roundwhen "$roundwhen_hex"
handoff go typescript roundwhen "$roundwhen_hex"
handoff typescript go roundwhen "$roundwhen_hex"
handoff go rust roundwhen "$roundwhen_hex"
handoff rust go roundwhen "$roundwhen_hex"
handoff go java roundwhen "$roundwhen_hex"
handoff java go roundwhen "$roundwhen_hex"
handoff go cpp roundwhen "$roundwhen_hex"
handoff cpp go roundwhen "$roundwhen_hex"

# AZ-2239, AZ-2307, AZ-2449: TypeScript, Python, Java, C# and Go take part in the listgroup, dictgroup and listflags rings. Rust
# refuses these schemes when it builds them (a list or dict element is one integer, float, bytes, utf8, list
# or dict; README upgrade notes, integrity_tests.rs) and C++ builds an invalid scheme for them (bind_element in
# table.hpp), so neither is run. A package that joins gets its handoff lines here and the commands in its driver;
# ring-wiring.test.sh fails when a C# or Go line below is missing.
handoff typescript python listgroup "$listgroup_hex"
handoff python java listgroup "$listgroup_hex"
handoff java csharp listgroup "$listgroup_hex"
handoff csharp typescript listgroup "$listgroup_hex"
handoff go typescript listgroup "$listgroup_hex"
handoff typescript go listgroup "$listgroup_hex"
handoff go python listgroup "$listgroup_hex"
handoff python go listgroup "$listgroup_hex"
handoff go java listgroup "$listgroup_hex"
handoff java go listgroup "$listgroup_hex"
handoff go csharp listgroup "$listgroup_hex"
handoff csharp go listgroup "$listgroup_hex"

handoff typescript python dictgroup "$dictgroup_hex"
handoff python java dictgroup "$dictgroup_hex"
handoff java csharp dictgroup "$dictgroup_hex"
handoff csharp typescript dictgroup "$dictgroup_hex"
handoff go typescript dictgroup "$dictgroup_hex"
handoff typescript go dictgroup "$dictgroup_hex"
handoff go python dictgroup "$dictgroup_hex"
handoff python go dictgroup "$dictgroup_hex"
handoff go java dictgroup "$dictgroup_hex"
handoff java go dictgroup "$dictgroup_hex"
handoff go csharp dictgroup "$dictgroup_hex"
handoff csharp go dictgroup "$dictgroup_hex"

handoff typescript python listflags "$listflags_hex"
handoff python java listflags "$listflags_hex"
handoff java csharp listflags "$listflags_hex"
handoff csharp typescript listflags "$listflags_hex"
handoff go typescript listflags "$listflags_hex"
handoff typescript go listflags "$listflags_hex"
handoff go python listflags "$listflags_hex"
handoff python go listflags "$listflags_hex"
handoff go java listflags "$listflags_hex"
handoff java go listflags "$listflags_hex"
handoff go csharp listflags "$listflags_hex"
handoff csharp go listflags "$listflags_hex"

# Each participant refuses a packet whose last element is short, and hands no row to its handler.
for lang in typescript python java csharp go; do
  for row in "listgroup $listgroup_short_hex" "dictgroup $dictgroup_short_hex" "listflags $listflags_short_hex"; do
    read -r kind short <<< "$row"
    if ! run_lang "$lang" "unpack-$kind-short" "$short"; then
      echo "$lang unpack-$kind-short failed: it read a short element or the driver crashed (see the output above)" >&2
      exit 1
    fi
  done
done

for lang in csharp typescript python rust cpp java go; do
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
handoff go csharp session "$session_hex"
handoff csharp go session "$session_hex"
handoff go typescript session "$session_hex"
handoff typescript go session "$session_hex"
handoff go python session "$session_hex"
handoff python go session "$session_hex"
handoff go rust session "$session_hex"
handoff rust go session "$session_hex"
handoff go java session "$session_hex"
handoff java go session "$session_hex"
handoff go cpp session "$session_hex"
handoff cpp go session "$session_hex"

for lang in csharp typescript python rust cpp java go; do
  got="$(bash "$root/.github/workflows/publish-position.sh" "$lang" | tr -d '[:space:]')"
  if [ "$got" != "$position_hex" ]; then
    echo "$lang position mismatch" >&2
    exit 1
  fi
done

echo "language pairs passed"
