#!/usr/bin/env bash
# Rust probe of AZ-4291 (scheme depth). Builds a copy of this crate in a temporary directory against
# the rust/ package of this checkout and runs it once per case (API, shape, depth) through
# ../case.sh, so a stack overflow, abort or hang is one `crashed:` line. Nothing is written into the
# repository. The build is `release` (what a user ships; the stack frames of a debug build are several
# times larger, so a deep scheme overflows there much earlier): PROBE_PROFILE=debug builds that instead.
# stdout: 12 lines, the map API (`rust`, `when-1000` ...) then the heap-free `nostd` API
# (`when-1000-nostd` ...). stderr: every build message. Exit 0 when the probes ran.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../../.." && pwd)"
case_sh="$here/../case.sh"

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

# The copy sits where this folder sits under the root, beside a link to the package, so the relative
# path in Cargo.toml reaches rust/ and cargo writes its Cargo.lock beside the copy, not in the tree.
copy="$out/${here#"$root"/}"
mkdir -p "$copy"
cp -R "$here/Cargo.toml" "$here/src" "$copy/"
ln -s "$root/rust" "$out/rust"

# The host default toolchain may be older than the crate needs.
export RUSTUP_TOOLCHAIN="${RUSTUP_TOOLCHAIN:-1.98}"
export CARGO_TARGET_DIR="$out/target"

profile="${PROBE_PROFILE:-release}"
case "$profile" in
  release) cargo build --release --manifest-path "$copy/Cargo.toml" </dev/null >&2 ;;
  debug) cargo build --manifest-path "$copy/Cargo.toml" </dev/null >&2 ;;
  *) echo "run.sh: PROBE_PROFILE is release or debug, not $profile" >&2; exit 2 ;;
esac
bin="$out/target/$profile/probe"

for api in map nostd; do
  suffix=""
  [ "$api" = nostd ] && suffix="-nostd"
  for shape in when group; do
    for depth in 1000 5000 50000; do
      bash "$case_sh" rust "$shape-$depth$suffix" 60 "$bin" "$api" "$shape" "$depth"
    done
  done
done
