#!/usr/bin/env bash
# Builds one C++ distribution target into $PACKBIN_OUT/artifacts/<target>/: the vcpkg port and the
# Arduino library as local clones with their commits (and tag) prepared, the PlatformIO and ESP-IDF
# component as packed archives. Clones only read the remote; publish-upload.sh pushes and uploads.
# Usage: publish-embedded.sh vcpkg|platformio|esp-idf|arduino
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=publish-lib.sh
source "$here/publish-lib.sh"

target="${1:?target}"
root="$(publish_root)"
version="${PACKBIN_VERSION:?PACKBIN_VERSION is required}"
version="${version#v}"
out="${PACKBIN_OUT:?PACKBIN_OUT is required}"
dest="$out/artifacts/$target"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$dest"

# A clone of branch $2 of remote $1 in $3, or an empty repository on that branch.
open_registry() {
  local url="$1" branch="$2" reg="$3" heads
  heads="$(git ls-remote --heads "$url" "$branch")"
  if [ -n "$heads" ]; then
    git clone --branch "$branch" --single-branch "$url" "$reg"
  else
    mkdir -p "$reg"
    git -C "$reg" init -b "$branch"
  fi
  git -C "$reg" config user.email "packbin@users.noreply.github.com"
  git -C "$reg" config user.name "packbin"
}

# A copy of cpp/ with this version in library.json and idf_component.yml.
stage_cpp() {
  cp -a "$root/cpp/." "$work/cpp"
  rm -rf "$work/cpp/build"
  python3 - "$work/cpp" "$version" <<'PY'
import json, re, sys
from pathlib import Path
cpp, version = Path(sys.argv[1]), sys.argv[2]
lib = cpp / "library.json"
data = json.loads(lib.read_text())
data["version"] = version
lib.write_text(json.dumps(data, indent=2) + "\n")
idf = cpp / "idf_component.yml"
idf.write_text(re.sub(r'(?m)^version: ".*"$', f'version: "{version}"', idf.read_text(), count=1))
PY
}

# The port carries what it builds (owner decision 2026-10-06): the host CMakeLists.txt, include/, src/ and
# LICENSE are vendored into ports/packbin, so installing it downloads nothing from a tag archive.
stage_vcpkg_port() {
  local port="$1/ports/packbin"
  rm -rf "$port"
  mkdir -p "$port/include" "$1/versions/p-"
  cp "$root/cpp/CMakeLists.txt" "$port/CMakeLists.txt"
  cp "$root/LICENSE" "$port/LICENSE"
  cp -R "$root/cpp/include/packbin" "$port/include/packbin"
  cp -R "$root/cpp/src" "$port/src"
  cat > "$port/vcpkg.json" <<EOF
{
  "name": "packbin",
  "version": "$version",
  "description": "Pack and unpack a caller-owned field list",
  "license": "MIT",
  "homepage": "https://github.com/zxsanny/packbin",
  "dependencies": [
    { "name": "vcpkg-cmake", "host": true },
    { "name": "vcpkg-cmake-config", "host": true }
  ]
}
EOF
  cat > "$port/portfile.cmake" <<'EOF'
vcpkg_check_linkage(ONLY_STATIC_LIBRARY)
vcpkg_cmake_configure(
  SOURCE_PATH "${CURRENT_PORT_DIR}"
  OPTIONS "-DPACKBIN_VERSION=${VERSION}")
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME packbin CONFIG_PATH lib/cmake/packbin)
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
vcpkg_install_copyright(FILE_LIST "${CURRENT_PORT_DIR}/LICENSE")
EOF
}

record_vcpkg_version() {
  python3 - "$1" "$2" "$3" <<'PY'
import json, sys
from pathlib import Path
reg, version, tree = sys.argv[1:]
root = Path(reg)
baseline_path = root / "versions" / "baseline.json"
port_path = root / "versions" / "p-" / "packbin.json"
baseline = json.loads(baseline_path.read_text()) if baseline_path.exists() else {"default": {}}
baseline.setdefault("default", {})["packbin"] = {"baseline": version, "port-version": 0}
baseline_path.parent.mkdir(parents=True, exist_ok=True)
baseline_path.write_text(json.dumps(baseline, indent=2) + "\n")
history = json.loads(port_path.read_text()) if port_path.exists() else {"versions": []}
versions = [item for item in history.get("versions", []) if item.get("version") != version]
versions.insert(0, {"git-tree": tree, "port-version": 0, "version": version})
port_path.write_text(json.dumps({"versions": versions}, indent=2) + "\n")
PY
}

build_vcpkg() {
  local reg="$dest/reg" tree
  open_registry "$(vcpkg_url)" vcpkg "$reg"
  stage_vcpkg_port "$reg"
  git -C "$reg" add ports/packbin
  if ! git -C "$reg" diff --cached --quiet; then
    git -C "$reg" commit -m "port packbin $version"
  fi
  tree="$(git -C "$reg" rev-parse "HEAD:ports/packbin")"
  record_vcpkg_version "$reg" "$version" "$tree"
  git -C "$reg" add versions
  if ! git -C "$reg" diff --cached --quiet; then
    git -C "$reg" commit -m "version packbin $version"
  fi
}

# The Arduino Library Manager reads library.properties at a repository root, so the layout
# goes to its own branch and an `arduino-<version>` tag, like the vcpkg port.
build_arduino() {
  local reg="$dest/reg"
  open_registry "$(arduino_url)" arduino "$reg"
  find "$reg" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  bash "$here/stage-arduino.sh" "$work/layout" "$version"
  cp -a "$work/layout/." "$reg/"
  git -C "$reg" add -A
  if ! git -C "$reg" diff --cached --quiet; then
    git -C "$reg" commit -m "packbin $version"
  fi
  git -C "$reg" tag -f "arduino-$version"
}

build_platformio() {
  stage_cpp
  ensure_tool pio platformio
  pio pkg pack "$work/cpp" --output "$dest"
}

build_idf_component() {
  stage_cpp
  ensure_tool compote idf-component-manager
  compote component pack --project-dir "$work/cpp" --name packbin --version "$version" \
    --dest-dir "$work/idf"
  cp "$work/idf/packbin_$version.tgz" "$dest/"
}

case "$target" in
  vcpkg) build_vcpkg ;;
  platformio) build_platformio ;;
  esp-idf) build_idf_component ;;
  arduino) build_arduino ;;
  *)
    echo "unknown target: $target" >&2
    exit 1
    ;;
esac
