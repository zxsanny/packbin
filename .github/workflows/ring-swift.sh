#!/usr/bin/env bash
# Builds the Swift drivers of the ring: ring-swift.sh <scratch dir> builds the package in
# .github/workflows/drivers/handoff-swift (the handoff driver and the position program, on the root package by
# path) with `swift build -c release`, the build output in <scratch dir>, never in the repository. The
# binaries are <scratch dir>/release/handoff-swift and <scratch dir>/release/position.
# ring-swift.sh --version prints the version of the Swift that builds them (ring-toolchains.sh checks it).
#
# It rebuilds only when a source or manifest of the package (Package.swift, Package.resolved, swift/Sources) or
# of the driver package is newer than the stamp a finished build leaves in <scratch dir>, so language-pair.sh can
# call it before every driver command (as the go case does). The stamp, not the binaries: a build that finds
# nothing to compile leaves them old, and every later call would build again.
#
# With `swift` on PATH it builds with it on the owner's Mac (the local toolchain) and on a Linux host whose Swift is
# the pinned one. On a Linux host (the ring job) with another Swift, or none, it builds in the swift:$RING_SWIFT
# image (default: the tool-pins.txt `swift` pin, the Swift suite image) with the Swift runtime linked in
# (--static-swift-stdlib), so the binaries run on the host: ubuntu-latest carries a newer Swift than the pin (6.4
# against 6.3.3 on 2026-10-15) and the ring must build with the toolchain the suites use. The container sees the
# repo and the scratch dir at the host paths and runs as the caller.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
driver="$here/drivers/handoff-swift"
tag="${RING_SWIFT:-$(bash "$here/tool-pin.sh" swift)}"

version_of() { sed -n 's/.*Swift version \([0-9][0-9.]*\).*/\1/p' <<< "$1" | sed -n 1p; }

# Whether the swift on PATH builds the drivers: always on a host that is not Linux (the owner's Mac); on Linux only
# when it is the pinned version, compared to the precision of the pin as ring-toolchains.sh does.
use_local_swift() {
  command -v swift > /dev/null || return 1
  [ "$(uname -s)" != Linux ] && return 0
  local fields found
  fields="$(awk -F. '{ print NF }' <<< "$tag")"
  found="$(version_of "$(swift --version 2>&1)" | cut -d. -f1-"$fields")"
  [ "$found" = "$tag" ]
}

if [ "${1:-}" = --version ]; then
  if use_local_swift; then
    full="$(swift --version 2>&1)"
  else
    full="$(docker run --rm -i "swift:$tag" swift --version 2>&1 < /dev/null)"
  fi
  version="$(version_of "$full")"
  if [ -z "$version" ]; then
    echo "ring-swift.sh: no Swift version in: $full" >&2
    exit 1
  fi
  echo "$version"
  exit 0
fi

scratch="${1:?scratch dir}"
# A scratch dir another local user made could hold their binaries, which the ring would then run.
if [ -e "$scratch" ] && [ ! -O "$scratch" ]; then
  echo "ring-swift.sh: $scratch is not owned by $(id -un); pass a scratch dir of your own" >&2
  exit 1
fi
handoff="$scratch/release/handoff-swift"
position="$scratch/release/position"
stamp="$scratch/ring-swift.built"
if [ -x "$handoff" ] && [ -x "$position" ] && [ -f "$stamp" ] && [ -z "$(find "$root/Package.swift" \
  "$root/Package.resolved" "$root/swift/Sources" "$driver" \( -name .build -o -name .swiftpm \) -prune \
  -o -type f -newer "$stamp" -print -quit)" ]; then
  exit 0
fi
rm -f "$stamp"

mkdir -p "$scratch"
scratch="$(cd "$scratch" && pwd)"
stamp="$scratch/ring-swift.built"
# The stamp gets the time the build starts, so a source saved during the build is newer than it.
touch "$stamp.new"
# The build log goes to stderr: language-pair.sh compares the stdout of a pack call with the expected hex.
if use_local_swift; then
  swift build -c release --package-path "$driver" --scratch-path "$scratch" >&2
  mv "$stamp.new" "$stamp"
  exit 0
fi

if [ "$(uname -s)" != Linux ]; then
  echo "ring-swift.sh: no usable swift on PATH; the swift:$tag image builds Linux binaries only, not for $(uname -s)" >&2
  exit 1
fi
mounts=(-v "$root:$root")
case "$scratch" in
  "$root" | "$root"/*) ;;
  *) mounts+=(-v "$scratch:$scratch") ;;
esac
build=(swift build -c release --static-swift-stdlib --package-path "$driver" --scratch-path "$scratch")
if [ -z "${PACKBIN_SWIFT_CACHE:-}" ]; then
  docker run --rm -i --user "$(id -u):$(id -g)" -e HOME="$scratch/home" "${mounts[@]}" -w "$driver" "swift:$tag" \
    "${build[@]}" < /dev/null >&2
else
  # C3 (AZ-2627): CI keeps <scratch dir> between runs (PACKBIN_SWIFT_CACHE hit or miss) and its C compiles go through
  # ccache, kept in <scratch dir>/ccache: the container starts as root to install it, swift-ccache.sh runs the build as
  # the caller, so the binaries are the caller's as above, and prints its hits and misses.
  echo "ring-swift: cache $PACKBIN_SWIFT_CACHE" >&2
  docker run --rm -i -e HOME="$scratch/home" "${mounts[@]}" -w "$driver" "swift:$tag" \
    bash "$here/swift-ccache.sh" run "$scratch/ccache" "$(id -u)" "$(id -g)" "${build[@]}" < /dev/null >&2
fi
mv "$stamp.new" "$stamp"
