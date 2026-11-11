#!/usr/bin/env bash
# Builds the Dart drivers of the ring: ring-dart.sh <scratch dir> compiles the handoff driver and the position program
# of .github/workflows/drivers/handoff-dart (the package under test by path) with `dart compile exe`, the output in
# <scratch dir>, never in the repository. The binaries are <scratch dir>/handoff-dart and <scratch dir>/position.
# ring-dart.sh --version prints the version of the Dart that builds them (ring-toolchains.sh checks it).
#
# The build runs on a copy of dart/ (pubspec.yaml and lib/) and of the driver, kept in <scratch dir>/src with the layout
# of the repository, because `dart pub get` writes .dart_tool and pubspec.lock next to a pubspec: a read-only repository
# (the publish gate mounts it so) and a clean one both stay as they are.
#
# It rebuilds only when a source or manifest of the package or of the driver is newer than the stamp a finished build
# leaves in <scratch dir>, so ring-lib.sh can call it before every driver command (as the swift case does).
#
# With `dart` on PATH it builds with it on the owner's Mac (the local toolchain) and on a Linux host whose Dart is the
# pinned one. On a Linux host (the ring job) with another Dart, or none, it builds in the dart:$RING_DART image (default:
# the tool-pins.txt `dart` pin, the Dart suite image), so the binaries are built with the toolchain the suite uses; a
# compiled executable carries the Dart runtime, so it runs on the host. The container sees the scratch dir at the host
# path and runs as the caller.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
driver="$here/drivers/handoff-dart"
tag="${RING_DART:-$(bash "$here/tool-pin.sh" dart)}"

version_of() { sed -n 's/.*Dart SDK version: \([0-9][0-9.]*\).*/\1/p' <<< "$1" | sed -n 1p; }

# Whether the dart on PATH builds the drivers: always on a host that is not Linux (the owner's Mac); on Linux only when it
# is the pinned version, compared to the precision of the pin as ring-toolchains.sh does.
use_local_dart() {
  command -v dart > /dev/null || return 1
  [ "$(uname -s)" != Linux ] && return 0
  local fields found
  fields="$(awk -F. '{ print NF }' <<< "$tag")"
  found="$(version_of "$(dart --version 2>&1)" | cut -d. -f1-"$fields")"
  [ "$found" = "$tag" ]
}

if [ "${1:-}" = --version ]; then
  if use_local_dart; then
    full="$(dart --version 2>&1)"
  else
    full="$(docker run --rm -i "dart:$tag" dart --version 2>&1 < /dev/null)"
  fi
  version="$(version_of "$full")"
  if [ -z "$version" ]; then
    echo "ring-dart.sh: no Dart version in: $full" >&2
    exit 1
  fi
  echo "$version"
  exit 0
fi

scratch="${1:?scratch dir}"
# A scratch dir another local user made could hold their binaries, which the ring would then run.
if [ -e "$scratch" ] && [ ! -O "$scratch" ]; then
  echo "ring-dart.sh: $scratch is not owned by $(id -un); pass a scratch dir of your own" >&2
  exit 1
fi
handoff="$scratch/handoff-dart"
position="$scratch/position"
stamp="$scratch/ring-dart.built"
if [ -x "$handoff" ] && [ -x "$position" ] && [ -f "$stamp" ] && [ -z "$(find "$root/dart/pubspec.yaml" "$root/dart/lib" \
  "$driver" "$here/ring-dart.sh" \( -name .dart_tool -o -name pubspec.lock \) -prune -o -type f -newer "$stamp" -print -quit)" ]; then
  exit 0
fi
rm -f "$stamp"

mkdir -p "$scratch"
scratch="$(cd "$scratch" && pwd)"
stamp="$scratch/ring-dart.built"
# The stamp gets the time the build starts, so a source saved during the build is newer than it.
touch "$stamp.new"
rm -rf "$scratch/src"
mkdir -p "$scratch/src/dart" "$scratch/src/.github/workflows/drivers" "$scratch/home"
cp -R "$root/dart/pubspec.yaml" "$root/dart/lib" "$scratch/src/dart/"
cp -R "$driver" "$scratch/src/.github/workflows/drivers/"
rm -rf "$scratch/src/.github/workflows/drivers/handoff-dart/.dart_tool" "$scratch/src/.github/workflows/drivers/handoff-dart/pubspec.lock"
work="$scratch/src/.github/workflows/drivers/handoff-dart"
# The build log goes to stderr: ring-lib.sh compares the stdout of a pack call with the expected hex.
steps='dart pub get && dart compile exe bin/handoff_dart.dart -o "$1/handoff-dart" && dart compile exe bin/position.dart -o "$1/position"'
if use_local_dart; then
  (cd "$work" && HOME="$scratch/home" bash -c "$steps" _ "$scratch" >&2)
  mv "$stamp.new" "$stamp"
  exit 0
fi

if [ "$(uname -s)" != Linux ]; then
  echo "ring-dart.sh: no usable dart on PATH; the dart:$tag image builds Linux binaries only, not for $(uname -s)" >&2
  exit 1
fi
# C3 (AZ-2627): CI keeps <scratch dir> between runs and says whether it restored it (PACKBIN_DART_CACHE hit or miss);
# the line reaches the ring's timing notice (ring-prepare.sh wait).
if [ -n "${PACKBIN_DART_CACHE:-}" ]; then echo "ring-dart: cache $PACKBIN_DART_CACHE" >&2; fi
docker run --rm -i --user "$(id -u):$(id -g)" -e HOME="$scratch/home" -v "$scratch:$scratch" -w "$work" "dart:$tag" \
  bash -c "$steps" _ "$scratch" < /dev/null >&2
mv "$stamp.new" "$stamp"
