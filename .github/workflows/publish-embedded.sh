#!/usr/bin/env bash
# Publishes the C++ embedded packages for one version: PlatformIO, the ESP-IDF component
# registry and the Arduino library branch. Each registry runs only when its credential is set;
# otherwise it is skipped. Called by publish-registries.sh after the vcpkg port.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=publish-lib.sh
source "$here/publish-lib.sh"

if [ "${PACKBIN_PUBLISH:-}" != "1" ]; then
  echo "publish refused" >&2
  exit 1
fi

root="$(publish_root)"
version="${PACKBIN_VERSION:?PACKBIN_VERSION is required}"
version="${version#v}"
work="$(mktemp -d)"

# A copy of cpp/ with this version in library.json and idf_component.yml.
stage_cpp() {
  rm -rf "$work/cpp"
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

tools_venv() {
  if [ ! -x "$work/venv/bin/python" ]; then
    python3 -m venv "$work/venv"
  fi
  "$work/venv/bin/pip" install "$@"
}

publish_platformio() {
  if [ -z "${PLATFORMIO_AUTH_TOKEN:-}" ]; then
    echo "skip platformio"
    return
  fi
  tools_venv platformio
  "$work/venv/bin/pio" pkg publish "$work/cpp" --type library --no-interactive
}

publish_idf_component() {
  if [ -z "${IDF_COMPONENT_API_TOKEN:-}" ]; then
    echo "skip esp-idf component"
    return
  fi
  tools_venv idf-component-manager
  (
    cd "$work/cpp"
    "$work/venv/bin/compote" component upload --namespace zxsanny --name packbin \
      --version "$version"
  )
}

# The Arduino Library Manager reads library.properties at a repository root, so the layout
# goes to its own branch and an `arduino-<version>` tag, like the vcpkg port.
publish_arduino() {
  local url reg
  url="${ARDUINO_REGISTRY_URL:-https://github.com/zxsanny/packbin.git}"
  if [ -z "${GITHUB_TOKEN:-}" ] && [ -z "${ARDUINO_REGISTRY_URL:-}" ]; then
    echo "skip arduino"
    return
  fi
  reg="$work/arduino"
  if git ls-remote --heads "$url" arduino | grep -q .; then
    git clone --branch arduino --single-branch "$url" "$reg"
  else
    mkdir -p "$reg"
    git -C "$reg" init -b arduino
  fi
  git -C "$reg" config user.email "packbin@users.noreply.github.com"
  git -C "$reg" config user.name "packbin"
  find "$reg" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
  bash "$here/stage-arduino.sh" "$work/layout" "$version"
  cp -a "$work/layout/." "$reg/"
  git -C "$reg" add -A
  if ! git -C "$reg" diff --cached --quiet; then
    git -C "$reg" commit -m "packbin $version"
  fi
  push_branch "$reg" "$url" arduino "arduino-$version"
}

stage_cpp
publish_platformio
publish_idf_component
publish_arduino
