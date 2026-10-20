#!/usr/bin/env bash
# The runner of the cross-language ring, sourced by language-pair.sh and read by ring-ecc.sh (AZ-2744): the work
# directory and driver paths, run_lang (builds and starts the driver of one language) and handoff (one pair, one kind).
# It has no rows and runs nothing when sourced. root is two levels above this file.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
drivers="$root/.github/workflows/drivers"
# The C# and C++ drivers are built once a run into a private directory (mode 700), never into a predictable /tmp
# path another local user could pre-create (the F24 pattern of the Java driver below).
work="${PACKBIN_RING_WORK:-$(mktemp -d)}" && mkdir -p -m 700 "$work" # PACKBIN_RING_WORK: kept for ring-ecc.sh to reuse the builds
[ -n "${PACKBIN_RING_WORK:-}" ] || trap 'rm -rf "$work"' EXIT
swift_ring="${PACKBIN_SWIFT_RING:-/tmp/packbin-ring-swift}" # ring-swift.sh output, kept between runs as Go's

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
