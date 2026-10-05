#!/usr/bin/env bash
# Embedded target driver (feature AC-13). One report row per target in test-results/report.csv.
#
#   cpp/embedded/run.sh          from the repo root on a host with Docker: builds the embedded
#                                image and runs both stages through docker-compose.test.yml
#   cpp/embedded/run.sh arm      inside packbin-embedded: Cortex-M0+, Cortex-M4F (size/stack),
#                                Cortex-M3 on QEMU mps2-an385, s390x big-endian under QEMU user
#   cpp/embedded/run.sh esp      inside espressif/idf: ESP32-S3 and ESP32-C3 builds
#
# Exit code: 0 when every target passed, 1 when any target failed, 2 on usage errors.
set -euo pipefail

stage="${1:-host}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$stage" = host ]; then
  repo="$(cd "$here/../.." && pwd)"
  compose=(docker compose -f "$repo/docker-compose.test.yml")
  mkdir -p "$repo/test-results"
  "${compose[@]}" build cpp-embedded
  status=0
  "${compose[@]}" run --rm cpp-embedded || status=1
  "${compose[@]}" run --rm cpp-embedded-esp || status=1
  exit "$status"
fi

# shellcheck source=lib.sh
source "$here/lib.sh"

failed=0
run_stage_target() {
  run_target "$@" || failed=$((failed + 1))
}

case "$stage" in
  arm)
    # shellcheck source=arm.sh
    source "$here/arm.sh"
    run_stage_target cpp-m0plus "C++ core Cortex-M0+ build (AC-1 AC-2 link)" target_m0plus
    run_stage_target cpp-m3-qemu "C++ core Cortex-M3 QEMU mps2-an385 (AC-2 AC-3 AC-6)" target_m3
    run_stage_target cpp-m4f "C++ core Cortex-M4F size and stack (AC-1 AC-5)" target_m4f
    run_stage_target cpp-s390x "C++ core big-endian s390x QEMU user (AC-4)" target_s390x
    ;;
  esp)
    # shellcheck source=esp.sh
    source "$here/esp.sh"
    run_stage_target cpp-esp32s3 "C++ core ESP32-S3 ESP-IDF build (AC-1)" target_esp32s3
    run_stage_target cpp-esp32c3 "C++ core ESP32-C3 ESP-IDF build (AC-1)" target_esp32c3
    # shellcheck source=examples.sh
    source "$here/examples.sh"
    run_stage_target cpp-example-esp-idf "C++ ESP-IDF example from the packed component" \
      target_example_esp_idf
    run_stage_target cpp-example-esp32-arduino "C++ Arduino-ESP32 example from the library layout" \
      target_example_esp32_arduino
    run_stage_target cpp-example-pico "C++ Pico PlatformIO example from the package archive" \
      target_example_pico
    ;;
  *)
    echo "usage: $0 [arm|esp]" >&2
    exit 2
    ;;
esac

echo "embedded stage $stage: $failed target(s) failed"
[ "$failed" -eq 0 ] || exit 1
