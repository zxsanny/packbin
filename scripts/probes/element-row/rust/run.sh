#!/usr/bin/env bash
# Rust probe of AZ-4242 (see ../README.md). Builds a copy of this crate in a temporary directory
# against the rust/ package of this checkout and runs it; nothing is written into the repository.
# stdout: the probe lines. stderr: every build message.
# Exit 0 when the probe ran (whatever it found), non-zero when the build or the run failed.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../../.." && pwd)"

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

cargo build --manifest-path "$copy/Cargo.toml" </dev/null >&2
"$out/target/debug/probe" </dev/null
