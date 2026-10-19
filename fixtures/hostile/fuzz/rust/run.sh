#!/bin/sh
# packbin hostile-input probe, Rust (AZ-2666, loop 41): compact text decoder and message ECC unpack.
#
# Usage: sh run.sh <packbin checkout> <build dir> <debug|release> <command> [args...]
#   <packbin checkout>  a checkout (or `git archive HEAD rust fixtures` copy) holding rust/ and fixtures/
#   <build dir>         an empty directory outside the checkout; the probe crate and target go there
#   <command>           random <seed> <calls> | ecctime <calls> | textamp <one|list1m|list8m|controls|short>
#                       | edges
# The probe crate depends on <checkout>/rust by a path written into <build dir>/Cargo.toml at run time;
# nothing is written into the checkout (CARGO_TARGET_DIR is <build dir>/target). The debug profile keeps
# overflow checks on, so an integer overflow in the library panics and is counted.
# Each command prints its figures, CPU seconds and peak RSS, and exits 1 when an invariant is broken.
set -eu
[ $# -ge 4 ] || { echo "usage: sh run.sh <checkout> <build dir> <debug|release> <command> [args]" >&2; exit 2; }
checkout=$(cd "$1" && pwd)
build=$2
profile=$3
shift 3
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$build/src"
cp "$here"/*.rs "$build/src/"
cat > "$build/Cargo.toml" <<EOF
[package]
name = "packbin-hostile-probe"
version = "0.0.0"
edition = "2021"
publish = false

[dependencies]
packbin = { path = "$checkout/rust" }

[profile.release]
debug = false

[workspace]
EOF
flag=""
[ "$profile" = release ] && flag="--release"
CARGO_TARGET_DIR="$build/target" cargo build --quiet $flag --manifest-path "$build/Cargo.toml" </dev/null
exec "$build/target/$profile/packbin-hostile-probe" "$checkout" "$@" </dev/null
