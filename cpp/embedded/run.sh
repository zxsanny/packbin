#!/usr/bin/env bash
# Embedded target driver (feature AC-13). One report row per target in test-results/report.csv.
#
#   cpp/embedded/run.sh            from the repo root on a host with Docker: builds the embedded image
#   cpp/embedded/run.sh host       and runs both stages through docker-compose.test.yml
#   cpp/embedded/run.sh host arm   the image build and the arm stage only
#   cpp/embedded/run.sh host esp [PART]
#                                  the ESP stage only; PART is core, packages or all (default all). CI runs
#                                  the arm stage and the two ESP parts as three jobs (AZ-2607)
#   cpp/embedded/run.sh arm        inside packbin-embedded: Cortex-M0+, Cortex-M4F (size/stack),
#                                  Cortex-M3 on QEMU mps2-an385, s390x big-endian under QEMU user
#   cpp/embedded/run.sh esp        inside espressif/idf: the ESP32-S3 and ESP32-C3 builds and the three
#                                  examples; PACKBIN_ESP_PART (core, packages; unset or all = every
#                                  target) runs one part
#   cpp/embedded/run.sh list arm | list esp [PART]
#                                  the target ids of a stage or part, one per line; runs nothing
#
# On GitHub Actions (GITHUB_ACTIONS=true) the host form ends, whether the stages passed or not, with ONE
# ::notice line holding the seconds of every target this run reported: the check-run annotations of a
# job are readable without a token, its log is not (AZ-2607).
#
# Exit code: 0 when every target passed, 1 when any target failed, 2 on usage errors.
set -euo pipefail

stage="${1:-host}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The targets, listed once. Fields: stage|part|id|report name|function. The order is the run order. A part
# is a subset of the ESP stage that runs as its own CI job; the arm stage has no parts.
embedded_table() {
  printf '%s\n' \
    'arm|-|cpp-m0plus|C++ core Cortex-M0+ build (AC-1 AC-2 link)|target_m0plus' \
    'arm|-|cpp-m3-qemu|C++ core Cortex-M3 QEMU mps2-an385 (AC-2 AC-3 AC-6)|target_m3' \
    'arm|-|cpp-m4f|C++ core Cortex-M4F size and stack (AC-1 AC-5)|target_m4f' \
    'arm|-|cpp-s390x|C++ core big-endian s390x QEMU user (AC-4)|target_s390x' \
    'esp|core|cpp-esp32s3|C++ core ESP32-S3 ESP-IDF build (AC-1)|target_esp32s3' \
    'esp|core|cpp-esp32c3|C++ core ESP32-C3 ESP-IDF build (AC-1)|target_esp32c3' \
    'esp|packages|cpp-example-esp-idf|C++ ESP-IDF example from the packed component|target_example_esp_idf' \
    'esp|core|cpp-example-esp32-arduino|C++ Arduino-ESP32 example from the library layout|target_example_esp32_arduino' \
    'esp|packages|cpp-example-pico|C++ Pico PlatformIO example from the package archive|target_example_pico'
}

# The table rows of a stage; for the ESP stage only those of one part unless the part is all.
select_rows() {
  embedded_table | awk -F'|' -v stage="$1" -v part="$2" '$1 == stage && (part == "all" || $2 == part)'
}

esp_parts() {
  embedded_table | awk -F'|' '$1 == "esp" && !seen[$2]++ { printf "%s, ", $2 } END { print "all" }'
}

usage() {
  echo "usage: $0 [host [arm | esp [PART]]] | arm | esp | list arm | list esp [PART]  (PART: $(esp_parts))" >&2
  exit 2
}

# A part of the ESP stage is all or one named in the table; anything else is a usage error.
check_esp_part() {
  if [ "$1" != all ] && [ -z "$(select_rows esp "$1")" ]; then
    echo "$0: unknown ESP part '$1' (expected $(esp_parts))" >&2
    exit 2
  fi
}

list_ids() {
  local list_stage="$1" part="${2:-all}"
  case "$list_stage" in
    arm) [ "$part" = all ] || usage ;;
    esp) check_esp_part "$part" ;;
    *) usage ;;
  esac
  select_rows "$list_stage" "$part" | cut -d'|' -f3
}

# The notice: one line per row this run appended to the report, then the total. A field of a line is
# escaped as GitHub's toolkit does (% first, then CR; the lines are joined by %0A). The title is built from
# the fixed words and part names of the table, which need no escaping.
host_notice() {
  local report="$host_report" lines
  [ "${GITHUB_ACTIONS:-}" = true ] || return 0
  [ -f "$report" ] || report=/dev/null
  # Cut from the end: a report name could hold a comma, the result and the milliseconds never do.
  lines="$(awk -F, -v skip="$host_rows_before" -v total="$SECONDS" '
    function esc(s) { gsub(/%/, "%25", s); gsub(/\r/, "%0D", s); return s }
    NR > skip && NF >= 5 && $1 != "Test ID" {
      printf "%sembedded: %s took %d s %s", (n++ ? "%0A" : ""), esc($1), ($(NF - 2) + 500) / 1000, esc($(NF - 1))
    }
    END { printf "%sembedded: total took %d s in %d targets", (n ? "%0A" : ""), total, n }
  ' "$report")"
  printf '::notice title=embedded %s timing::%s\n' "$host_label" "$lines"
}

# Runs on every exit of the host form: the notice, then the exit status the stages left.
host_exit() {
  local rc=$?
  set +e
  host_notice
  exit "$rc"
}

host_run() {
  local what="$1" part="$2" status=0 repo compose arm=1 esp=1
  case "$what" in
    "")
      [ -z "$part" ] || usage
      part=all
      host_label=all
      ;;
    arm)
      [ -z "$part" ] || usage
      esp=0
      host_label=arm
      ;;
    esp)
      part="${part:-all}"
      check_esp_part "$part"
      arm=0
      host_label=esp
      [ "$part" = all ] || host_label="esp $part"
      ;;
    *) usage ;;
  esac
  repo="$(cd "$here/../.." && pwd)"
  compose=(docker compose -f "$repo/docker-compose.test.yml")
  mkdir -p "$repo/test-results"
  host_report="$repo/test-results/report.csv"
  host_rows_before=0
  if [ -f "$host_report" ]; then host_rows_before="$(awk 'END { print NR }' "$host_report")"; fi
  trap host_exit EXIT
  if [ "$arm" -eq 1 ]; then
    "${compose[@]}" build cpp-embedded
    "${compose[@]}" run --rm cpp-embedded || status=1
  fi
  if [ "$esp" -eq 1 ]; then
    "${compose[@]}" run --rm -e "PACKBIN_ESP_PART=$part" cpp-embedded-esp || status=1
  fi
  exit "$status"
}

part=all
case "$stage" in
  host) host_run "${2:-}" "${3:-}" ;;
  list)
    list_ids "${2:-}" "${3:-}"
    exit 0
    ;;
  arm) ;;
  esp)
    part="${PACKBIN_ESP_PART:-all}"
    check_esp_part "$part"
    ;;
  *) usage ;;
esac

# shellcheck source=lib.sh
source "$here/lib.sh"
case "$stage" in
  arm)
    # shellcheck source=arm.sh
    source "$here/arm.sh"
    ;;
  esp)
    # shellcheck source=esp.sh
    source "$here/esp.sh"
    # shellcheck source=examples.sh
    source "$here/examples.sh"
    ;;
esac

# Plain calls: run_target never returns non-zero, and an `||` list would turn errexit off inside it.
run_rows() {
  local selected row id name fn rows=()
  selected="$(select_rows "$1" "$2")"
  while IFS= read -r row; do rows+=("$row"); done <<< "$selected"
  for row in "${rows[@]}"; do
    IFS='|' read -r _ _ id name fn <<< "$row"
    run_target "$id" "$name" "$fn"
  done
}
run_rows "$stage" "$part"

label="$stage"
[ "$part" = all ] || label="$stage $part"
echo "embedded stage $label: $failed target(s) failed"
[ "$failed" -eq 0 ] || exit 1
