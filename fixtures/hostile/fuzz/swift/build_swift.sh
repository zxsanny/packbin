#!/bin/bash
# build_swift.sh <repo checkout> <empty work dir> [release|debug|asan]: lays out the probe package
# (the HEAD sources of swift/Sources/Packbin, the probe .swift files, Package.swift.txt) in the work dir and builds
# it there, never in the repository. The binary path is printed last.
set -euo pipefail
REPO=$1; D=$2; MODE=${3:-release}
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$D/Sources/Probe"
[ -d "$D/swift/Sources/Packbin" ] || git -C "$REPO" archive HEAD swift/Sources/Packbin | tar -x -C "$D"
rm -f "$D/Sources/Probe/"*.swift
cp "$HERE/audit41_probe/"*.swift "$D/Sources/Probe/"
cp "$HERE/audit41_probe/Package.swift.txt" "$D/Package.swift"
case "$MODE" in
  release) swift build -c release --package-path "$D" --scratch-path "$D/.build-release" < /dev/null
           echo "$D/.build-release/release/Probe" ;;
  debug)   swift build -c debug --package-path "$D" --scratch-path "$D/.build-debug" < /dev/null
           echo "$D/.build-debug/debug/Probe" ;;
  asan)    swift build -c debug -Xswiftc -sanitize=address --package-path "$D" --scratch-path "$D/.build-asan" < /dev/null
           echo "$D/.build-asan/debug/Probe" ;;
  *) echo "mode: release, debug or asan" >&2; exit 2 ;;
esac
