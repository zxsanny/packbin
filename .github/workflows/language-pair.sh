#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
drivers="$root/.github/workflows/drivers"
# The C# and C++ drivers are built once a run into a private directory (mode 700), never into a predictable /tmp
# path another local user could pre-create (the F24 pattern of the Java driver below).
work="${PACKBIN_RING_WORK:-$(mktemp -d)}" && mkdir -p -m 700 "$work" # PACKBIN_RING_WORK: kept for ring-ecc.sh to reuse the builds
[ -n "${PACKBIN_RING_WORK:-}" ] || trap 'rm -rf "$work"' EXIT
swift_ring="${PACKBIN_SWIFT_RING:-/tmp/packbin-ring-swift}" # ring-swift.sh output, kept between runs as Go's
user_hex="01062bfcfee119b20200030ba818078a8b1ca4ed51800300056b6aa330b00100032b0128036ae9c80400032b012808106770735f66697803ea04800348516404ca25f0000200032b0128048bbc2c80"
nested_hex="010200036ae9c8010001000209f908106770735f66697804ca25f000020001000209f9032b012801000209f9048bbc2c80"
position_hex="4001000065cd1d00a3e1110100"
session_hex="b55d0a29c56c203712b241232e"
# EC-10 (AZ-2739): the same position row under the same session with 4 parity bytes: the padded bytes above, then
# the 4 parity bytes of scripts/ecc/eccfmt.py over them. Derived apart from every package, from position_hex alone:
# HKDF-SHA256 (seed bytes 1..32, salt the 16-byte nonce, info "packbin"), the first 32 output bytes as the ChaCha20
# key (RFC 8439; first packet: the 12-byte nonce is 0, block counter 0) XORed onto position_hex, then
# eccfmt.parity(padded, 4).
session_ecc_hex="b55d0a29c56c203712b241232e2ce30c57"
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
dictgroup_hex="01020002107801020210790304"
listflags_hex="010300010100020200"
# The same packets with the last element cut short: its second value (or the flags item's u16) is missing.
listgroup_short_hex="010200010203"
dictgroup_short_hex="010200021078010202107903"
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
      if [ ! -f "$out/Handoff.class" ] || [ ! -f "$out/HandoffElements.class" ] || [ ! -f "$out/HandoffEcc.class" ] \
        || [ -n "$(find "$root/java/src/main/java" "$drivers/Handoff.java" "$drivers/HandoffElements.java" "$drivers/HandoffEcc.java" -newer "$out/Handoff.class" -print -quit)" ]; then
        rm -rf "$out"
        mkdir -p "$out"
        local sources=()
        while IFS= read -r -d '' f; do
          sources+=("$f")
        done < <(find "$root/java/src/main/java" -name '*.java' -print0 | sort -z)
        javac -encoding UTF-8 -d "$out" "${sources[@]}" "$drivers/Handoff.java" "$drivers/HandoffElements.java" "$drivers/HandoffEcc.java" || return
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
    swift)
      # ring-swift.sh builds only when a source is newer than the binaries; `|| return` as at the cpp case.
      bash "$root/.github/workflows/ring-swift.sh" "$swift_ring" || return
      "$swift_ring/release/handoff-swift" "$@"
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
# Swift (AZ-2522): the same lines, Go included, after each kind's Go lines (ring-wiring-swift.test.sh).
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
handoff swift csharp user "$user_hex"
handoff csharp swift user "$user_hex"
handoff swift typescript user "$user_hex"
handoff typescript swift user "$user_hex"
handoff swift python user "$user_hex"
handoff python swift user "$user_hex"
handoff swift rust user "$user_hex"
handoff rust swift user "$user_hex"
handoff swift java user "$user_hex"
handoff java swift user "$user_hex"
handoff swift cpp user "$user_hex"
handoff cpp swift user "$user_hex"
handoff swift go user "$user_hex"
handoff go swift user "$user_hex"

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
handoff swift csharp nested "$nested_hex"
handoff csharp swift nested "$nested_hex"
handoff swift typescript nested "$nested_hex"
handoff typescript swift nested "$nested_hex"
handoff swift python nested "$nested_hex"
handoff python swift nested "$nested_hex"
handoff swift rust nested "$nested_hex"
handoff rust swift nested "$nested_hex"
handoff swift java nested "$nested_hex"
handoff java swift nested "$nested_hex"
handoff swift cpp nested "$nested_hex"
handoff cpp swift nested "$nested_hex"
handoff swift go nested "$nested_hex"
handoff go swift nested "$nested_hex"

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
handoff swift csharp boolflag "$boolflag_hex"
handoff csharp swift boolflag "$boolflag_hex"
handoff swift typescript boolflag "$boolflag_hex"
handoff typescript swift boolflag "$boolflag_hex"
handoff swift python boolflag "$boolflag_hex"
handoff python swift boolflag "$boolflag_hex"
handoff swift rust boolflag "$boolflag_hex"
handoff rust swift boolflag "$boolflag_hex"
handoff swift java boolflag "$boolflag_hex"
handoff java swift boolflag "$boolflag_hex"
handoff swift cpp boolflag "$boolflag_hex"
handoff cpp swift boolflag "$boolflag_hex"
handoff swift go boolflag "$boolflag_hex"
handoff go swift boolflag "$boolflag_hex"

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
handoff swift csharp booltrue "$booltrue_hex"
handoff csharp swift booltrue "$booltrue_hex"
handoff swift typescript booltrue "$booltrue_hex"
handoff typescript swift booltrue "$booltrue_hex"
handoff swift python booltrue "$booltrue_hex"
handoff python swift booltrue "$booltrue_hex"
handoff swift rust booltrue "$booltrue_hex"
handoff rust swift booltrue "$booltrue_hex"
handoff swift java booltrue "$booltrue_hex"
handoff java swift booltrue "$booltrue_hex"
handoff swift cpp booltrue "$booltrue_hex"
handoff cpp swift booltrue "$booltrue_hex"
handoff swift go booltrue "$booltrue_hex"
handoff go swift booltrue "$booltrue_hex"

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
handoff swift csharp bitwhen "$bitwhen_hex"
handoff csharp swift bitwhen "$bitwhen_hex"
handoff swift typescript bitwhen "$bitwhen_hex"
handoff typescript swift bitwhen "$bitwhen_hex"
handoff swift python bitwhen "$bitwhen_hex"
handoff python swift bitwhen "$bitwhen_hex"
handoff swift rust bitwhen "$bitwhen_hex"
handoff rust swift bitwhen "$bitwhen_hex"
handoff swift java bitwhen "$bitwhen_hex"
handoff java swift bitwhen "$bitwhen_hex"
handoff swift cpp bitwhen "$bitwhen_hex"
handoff cpp swift bitwhen "$bitwhen_hex"
handoff swift go bitwhen "$bitwhen_hex"
handoff go swift bitwhen "$bitwhen_hex"

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
handoff csharp swift roundflags "$roundflags_hex"
handoff swift typescript roundflags "$roundflags_hex"
handoff typescript swift roundflags "$roundflags_hex"
handoff swift rust roundflags "$roundflags_hex"
handoff rust swift roundflags "$roundflags_hex"
handoff swift java roundflags "$roundflags_hex"
handoff java swift roundflags "$roundflags_hex"
handoff swift cpp roundflags "$roundflags_hex"
handoff cpp swift roundflags "$roundflags_hex"
handoff swift go roundflags "$roundflags_hex"
handoff go swift roundflags "$roundflags_hex"

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
handoff csharp swift roundwhen "$roundwhen_hex"
handoff swift typescript roundwhen "$roundwhen_hex"
handoff typescript swift roundwhen "$roundwhen_hex"
handoff swift rust roundwhen "$roundwhen_hex"
handoff rust swift roundwhen "$roundwhen_hex"
handoff swift java roundwhen "$roundwhen_hex"
handoff java swift roundwhen "$roundwhen_hex"
handoff swift cpp roundwhen "$roundwhen_hex"
handoff cpp swift roundwhen "$roundwhen_hex"
handoff swift go roundwhen "$roundwhen_hex"
handoff go swift roundwhen "$roundwhen_hex"

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
handoff swift typescript listgroup "$listgroup_hex"
handoff typescript swift listgroup "$listgroup_hex"
handoff swift python listgroup "$listgroup_hex"
handoff python swift listgroup "$listgroup_hex"
handoff swift java listgroup "$listgroup_hex"
handoff java swift listgroup "$listgroup_hex"
handoff swift csharp listgroup "$listgroup_hex"
handoff csharp swift listgroup "$listgroup_hex"
handoff swift go listgroup "$listgroup_hex"
handoff go swift listgroup "$listgroup_hex"

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
handoff swift typescript dictgroup "$dictgroup_hex"
handoff typescript swift dictgroup "$dictgroup_hex"
handoff swift python dictgroup "$dictgroup_hex"
handoff python swift dictgroup "$dictgroup_hex"
handoff swift java dictgroup "$dictgroup_hex"
handoff java swift dictgroup "$dictgroup_hex"
handoff swift csharp dictgroup "$dictgroup_hex"
handoff csharp swift dictgroup "$dictgroup_hex"
handoff swift go dictgroup "$dictgroup_hex"
handoff go swift dictgroup "$dictgroup_hex"

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
handoff swift typescript listflags "$listflags_hex"
handoff typescript swift listflags "$listflags_hex"
handoff swift python listflags "$listflags_hex"
handoff python swift listflags "$listflags_hex"
handoff swift java listflags "$listflags_hex"
handoff java swift listflags "$listflags_hex"
handoff swift csharp listflags "$listflags_hex"
handoff csharp swift listflags "$listflags_hex"
handoff swift go listflags "$listflags_hex"
handoff go swift listflags "$listflags_hex"

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
# Swift refuses them too; its loop is apart because ring-wiring.test.sh edits the exact line of the one above.
for kind in listgroup dictgroup listflags; do
  short="${kind}_short_hex"
  if ! run_lang swift "unpack-$kind-short" "${!short}"; then
    echo "swift unpack-$kind-short failed: it read a short element or the driver crashed (see the output above)" >&2
    exit 1
  fi
done

for lang in csharp typescript python rust cpp java swift go; do
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
handoff swift csharp session "$session_hex"
handoff csharp swift session "$session_hex"
handoff swift typescript session "$session_hex"
handoff typescript swift session "$session_hex"
handoff swift python session "$session_hex"
handoff python swift session "$session_hex"
handoff swift rust session "$session_hex"
handoff rust swift session "$session_hex"
handoff swift java session "$session_hex"
handoff java swift session "$session_hex"
handoff swift cpp session "$session_hex"
handoff cpp swift session "$session_hex"
handoff swift go session "$session_hex"
handoff go swift session "$session_hex"

# A driver without the protected session command fails here, named, before any pair reads it.
for lang in csharp typescript python rust cpp java swift go; do
  if ! got="$(run_lang "$lang" "pack-session-ecc" | tr -d '[:space:]')"; then
    echo "$lang pack-session-ecc failed" >&2
    exit 1
  fi
  if [ "$got" != "$session_ecc_hex" ]; then
    echo "$lang pack-session-ecc mismatch" >&2
    exit 1
  fi
done

handoff csharp typescript session-ecc "$session_ecc_hex"
handoff typescript python session-ecc "$session_ecc_hex"
handoff python rust session-ecc "$session_ecc_hex"
handoff rust java session-ecc "$session_ecc_hex"
handoff java cpp session-ecc "$session_ecc_hex"
handoff cpp csharp session-ecc "$session_ecc_hex"
handoff go csharp session-ecc "$session_ecc_hex"
handoff csharp go session-ecc "$session_ecc_hex"
handoff go typescript session-ecc "$session_ecc_hex"
handoff typescript go session-ecc "$session_ecc_hex"
handoff go python session-ecc "$session_ecc_hex"
handoff python go session-ecc "$session_ecc_hex"
handoff go rust session-ecc "$session_ecc_hex"
handoff rust go session-ecc "$session_ecc_hex"
handoff go java session-ecc "$session_ecc_hex"
handoff java go session-ecc "$session_ecc_hex"
handoff go cpp session-ecc "$session_ecc_hex"
handoff cpp go session-ecc "$session_ecc_hex"
handoff swift csharp session-ecc "$session_ecc_hex"
handoff csharp swift session-ecc "$session_ecc_hex"
handoff swift typescript session-ecc "$session_ecc_hex"
handoff typescript swift session-ecc "$session_ecc_hex"
handoff swift python session-ecc "$session_ecc_hex"
handoff python swift session-ecc "$session_ecc_hex"
handoff swift rust session-ecc "$session_ecc_hex"
handoff rust swift session-ecc "$session_ecc_hex"
handoff swift java session-ecc "$session_ecc_hex"
handoff java swift session-ecc "$session_ecc_hex"
handoff swift cpp session-ecc "$session_ecc_hex"
handoff cpp swift session-ecc "$session_ecc_hex"
handoff swift go session-ecc "$session_ecc_hex"
handoff go swift session-ecc "$session_ecc_hex"

for lang in csharp typescript python rust cpp java swift go; do
  got="$(bash "$root/.github/workflows/publish-position.sh" "$lang" | tr -d '[:space:]')"
  if [ "$got" != "$position_hex" ]; then
    echo "$lang position mismatch" >&2
    exit 1
  fi
done

echo "language pairs passed"
