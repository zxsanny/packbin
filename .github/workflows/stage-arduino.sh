#!/usr/bin/env bash
# Writes the Arduino library layout (library.properties and src/ at the root) for one version.
# Usage: stage-arduino.sh <destination directory> <version>
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
dest="${1:?destination directory}"
version="${2:?version}"
version="${version#v}"
cpp="$root/cpp"

rm -rf "$dest"
mkdir -p "$dest/src/packbin" "$dest/src/core" "$dest/examples/esp32_arduino"
sed "s/^version=.*/version=$version/" "$cpp/arduino/library.properties" >"$dest/library.properties"
cp "$cpp/arduino/packbin.h" "$dest/src/packbin.h"
# Headers only declare; src/os_random.cpp (the operating-system random source) is not copied.
cp "$cpp"/include/packbin/*.hpp "$dest/src/packbin/"
cp "$cpp"/src/core/*.cpp "$cpp"/src/core/*.hpp "$dest/src/core/"
cp "$cpp/examples/esp32_arduino/esp32_arduino.ino" "$dest/examples/esp32_arduino/"
cp "$root/LICENSE" "$dest/LICENSE"
cp "$root/README.md" "$dest/README.md"
echo "arduino layout $version in $dest"
