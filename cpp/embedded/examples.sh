#!/usr/bin/env bash
# The three README examples built from the packaged layouts, not from the source tree
# (AZ-2067 AC-1): the PlatformIO package archive, the Arduino library layout and the packed
# ESP-IDF component. Runs in the espressif/idf image. Sourced by run.sh after lib.sh.
set -euo pipefail

examples_tools() {
  local venv="$cache/examples-venv"
  # Toolchains live in the (gitignored) cache dir so a rerun does not download again.
  export ARDUINO_DIRECTORIES_DATA="$cache/arduino-data"
  export ARDUINO_DIRECTORIES_DOWNLOADS="$cache/arduino-downloads"
  export PLATFORMIO_CORE_DIR="$cache/platformio"
  if [ ! -x "$venv/bin/pio" ]; then
    python3 -m venv "$venv"
    "$venv/bin/pip" install --disable-pip-version-check platformio
  fi
  if [ ! -x "$cache/bin/arduino-cli" ]; then
    local arch version=1.1.1
    case "$(uname -m)" in
      x86_64) arch=64bit ;;
      aarch64 | arm64) arch=ARM64 ;;
      *) fail "no arduino-cli build for $(uname -m)" ;;
    esac
    mkdir -p "$cache/bin"
    curl -fsSL -o "$cache/arduino-cli.tar.gz" \
      "https://github.com/arduino/arduino-cli/releases/download/v${version}/arduino-cli_${version}_Linux_${arch}.tar.gz"
    tar -xzf "$cache/arduino-cli.tar.gz" -C "$cache/bin" arduino-cli
  fi
  export PATH="$venv/bin:$cache/bin:$PATH"
}

# Pico (PlatformIO, raspberrypi platform) against `pio pkg pack` of cpp/.
target_example_pico() {
  local dir="$build/example-pico"
  examples_tools
  rm -rf "$dir"
  mkdir -p "$dir/pkg"
  pio pkg pack "$cpp" --output "$dir/pkg"
  local archive
  archive="$(find "$dir/pkg" -name '*.tar.gz' | head -n 1)"
  if [ -z "$archive" ]; then
    fail "pio pkg pack wrote no archive"
    return 1
  fi
  cp -a "$cpp/examples/pico" "$dir/project"
  sed -i "s|^lib_deps = .*|lib_deps = file://$archive|" "$dir/project/platformio.ini"
  pio run -d "$dir/project" 2>&1 | tee "$dir/build.log"
  local status=${PIPESTATUS[0]}
  if [ "$status" -ne 0 ]; then
    fail "pio run exit $status"
    return 1
  fi
  [ "$(count_warnings "$dir/build.log")" -eq 0 ] || note "warnings in the Pico build (framework)"
  note "pico example built from $(basename "$archive")"
}

# ESP32 Arduino sketch against the staged Arduino library layout.
target_example_esp32_arduino() {
  local dir="$build/example-esp32-arduino"
  examples_tools
  rm -rf "$dir"
  bash "$root/.github/workflows/stage-arduino.sh" "$dir/packbin" 0.0.0
  arduino-cli core update-index \
    --additional-urls https://espressif.github.io/arduino-esp32/package_esp32_index.json
  arduino-cli core install esp32:esp32 \
    --additional-urls https://espressif.github.io/arduino-esp32/package_esp32_index.json
  arduino-cli compile --fqbn esp32:esp32:esp32 --library "$dir/packbin" \
    "$dir/packbin/examples/esp32_arduino" 2>&1 | tee "$dir/build.log"
  local status=${PIPESTATUS[0]}
  if [ "$status" -ne 0 ]; then
    fail "arduino-cli compile exit $status"
    return 1
  fi
  note "esp32 arduino example built from the staged library layout"
}

# ESP-IDF example against `compote component pack` of cpp/.
target_example_esp_idf() {
  local dir="$build/example-esp-idf"
  command -v idf.py > /dev/null || fail "idf.py not on PATH (not the ESP-IDF image)"
  rm -rf "$dir"
  mkdir -p "$dir"
  (cd "$cpp" && compote component pack --name packbin --version 0.0.0 --dest-dir "$dir/dist")
  local archive
  archive="$(find "$dir/dist" -name '*.tgz' | head -n 1)"
  if [ -z "$archive" ]; then
    fail "compote component pack wrote no archive"
    return 1
  fi
  mkdir -p "$dir/packbin"
  tar -xzf "$archive" -C "$dir/packbin"
  cp -a "$cpp/examples/esp_idf" "$dir/project"
  cat > "$dir/project/main/idf_component.yml" <<EOF
dependencies:
  zxsanny/packbin:
    path: $dir/packbin
EOF
  idf.py -C "$dir/project" -B "$dir/build" set-target esp32 build 2>&1 | tee "$dir/build.log"
  local status=${PIPESTATUS[0]}
  if [ "$status" -ne 0 ]; then
    fail "idf.py build exit $status"
    return 1
  fi
  note "esp-idf example built from $(basename "$archive")"
}
