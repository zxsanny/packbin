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

work=""
trap '[ -z "$work" ] || rm -rf "$work"' EXIT

# Copies the repo paths $@ (relative) into a fresh $work, keeping their relative layout.
copy_to_work() {
  local rel
  work="$(mktemp -d)"
  for rel in "$@"; do
    mkdir -p "$work/$(dirname "$rel")"
    cp -a "$root/$rel" "$work/$rel"
  done
}

case "$lang" in
  csharp)
    # dotnet builds in the project folders, so it runs on a copy that keeps the layout the driver
    # references (../../../../csharp); the repo itself may be read-only.
    copy_to_work "csharp" ".github/workflows/drivers/csharp"
    rm -rf "$work/csharp/bin" "$work/csharp/obj" "$work/.github/workflows/drivers/csharp/bin" \
      "$work/.github/workflows/drivers/csharp/obj"
    dotnet run --project "$work/.github/workflows/drivers/csharp/Position.csproj" -v q --nologo
    ;;
  typescript)
    # npm ci writes node_modules next to package.json, so without one it runs on a copy that keeps
    # the layout position.ts imports (../../../typescript/src). It runs after a cd: with --prefix, npm
    # refuses the lock file ("Missing: ... from lock file") when the path has a symlink, and macOS
    # mktemp -d lands in /var, a link to /private/var.
    if [ -d "$root/typescript/node_modules/@noble/hashes" ]; then
      node --experimental-strip-types "$drivers/position.ts"
    else
      copy_to_work "typescript" ".github/workflows/drivers/position.ts"
      (cd "$work/typescript" && npm ci >&2)
      node --experimental-strip-types "$work/.github/workflows/drivers/position.ts"
    fi
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
    sdk="${PACKBIN_CXX_SYSROOT:-}"
    flags=(-std=c++17 -O2 -Wall -Wextra -Werror -I"$root/cpp/include")
    if [ -n "$sdk" ]; then
      flags+=(-isysroot "$sdk" -I"$sdk/usr/include/c++/v1")
    fi
    "${CXX:-g++}" "${flags[@]}" -o "$bin" \
      "$drivers/position.cpp" "$root/cpp/src/core/values.cpp" "$root/cpp/src/core/pack.cpp" \
      "$root/cpp/src/core/unpack.cpp" "$root/cpp/src/core/session.cpp" "$root/cpp/src/os_random.cpp"
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
