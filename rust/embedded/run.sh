#!/usr/bin/env bash
# Embedded stage of the heap-free Rust API (AZ-2751): the probe is built for thumbv7em-none-eabihf, linked
# into the C++ stage's QEMU image, run on a Cortex-M4F, measured, and checked for the heap and for panic
# paths.
#
#   rust/embedded/run.sh libs     the static libraries with the host cargo (the target must be installed:
#                                 rustup target add thumbv7em-none-eabihf)
#   rust/embedded/run.sh host     libs, then the image stage in packbin-embedded through
#                                 docker-compose.test.yml (the default)
#   rust/embedded/run.sh image    inside packbin-embedded: link, QEMU run, sizes, link checks, report rows
#
# Exit code: 0 when every target passed, 1 when one failed, 2 on usage errors.
set -euo pipefail

rust_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$rust_here/../.." && pwd)"
stage="${1:-host}"

build_libs() {
  local set features
  command -v cargo > /dev/null || { echo "run.sh: cargo is not installed" >&2; exit 1; }
  # The list is read on fd 3: cargo must not be able to read (and drop) the lines that follow.
  while IFS='|' read -r -u 3 set features; do
    build_one "$set" "$features"
  done 3< <(awk '!/^#/ && NF' "$rust_here/feature-sets.txt")
  # Probes with a seeded defect: the link checks must reject them (target_rust_mutants).
  build_one mutant-panic seed_panic
  build_one mutant-heap seed_heap
}

build_one() {
  # No --locked: the probe's lock file names only packbin and the probe, and a version bump of packbin (the
  # release commit) would make --locked fail on the very run that publishes.
  local set="$1" features="$2" args=()
  [ -z "$features" ] || args=(--features "$features")
  echo "=== cargo build $set (features: ${features:-none}) ==="
  CARGO_TARGET_DIR="$rust_here/build/$set" cargo build --release --target thumbv7em-none-eabihf \
    --manifest-path "$rust_here/probe/Cargo.toml" ${args[@]+"${args[@]}"}
}

case "$stage" in
  libs) build_libs ;;
  host)
    build_libs
    compose=(docker compose -f "$repo/docker-compose.test.yml")
    mkdir -p "$repo/test-results"
    "${compose[@]}" build cpp-embedded
    "${compose[@]}" run --rm rust-embedded
    ;;
  image)
    # shellcheck source=../../cpp/embedded/lib.sh
    source "$repo/cpp/embedded/lib.sh"
    # shellcheck source=../../cpp/embedded/arm.sh
    source "$repo/cpp/embedded/arm.sh"
    # shellcheck source=target.sh
    source "$rust_here/target.sh"
    # Plain calls: run_target never returns non-zero, and an `||` list would turn errexit off inside it.
    run_target rust-m4f "Rust heap-free API Cortex-M4F link, QEMU, size and stack (AZ-2751)" target_rust_m4f
    run_target rust-mutants "Rust link checks reject a seeded panic path and a seeded heap call (AZ-2751)" target_rust_mutants
    echo "rust embedded stage: $failed target(s) failed"
    [ "$failed" -eq 0 ] || exit 1
    ;;
  *)
    echo "usage: $0 [libs | host | image]" >&2
    exit 2
    ;;
esac
