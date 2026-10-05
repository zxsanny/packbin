#!/usr/bin/env bash
# ESP-IDF targets (espressif/idf image): build only. Sourced by run.sh after lib.sh.
set -euo pipefail

target_esp() {
  local chip="$1" dir="$build/$1" log="$build/$1.build.log"
  command -v idf.py > /dev/null || fail "idf.py not on PATH (not the ESP-IDF image)"
  mkdir -p "$build"
  rm -rf "$dir"
  echo "ESP-IDF $(idf.py --version)"
  IDF_COMPONENT_MANAGER=0 idf.py -C "$here/esp" -B "$dir" -D SDKCONFIG="$dir/sdkconfig" \
    -D SDKCONFIG_DEFAULTS="$here/esp/sdkconfig.defaults" set-target "$chip" build 2>&1 \
    | tee "$log"
  local status=${PIPESTATUS[0]}
  if [ "$status" -ne 0 ]; then
    fail "idf.py build exit $status"
    return 1
  fi
  # The compile line of every packbin source (core component + all-kinds scheme).
  python3 - "$dir/compile_commands.json" "$dir/core-commands.txt" <<'PY'
import json, sys
with open(sys.argv[1]) as f:
    entries = json.load(f)
with open(sys.argv[2], "w") as out:
    for e in entries:
        if "/src/core/" in e["file"] or "/embedded/common/" in e["file"]:
            out.write(e["file"] + "\t" + e.get("command", " ".join(e.get("arguments", []))) + "\n")
PY
  local file cmd std flag checked=0
  while IFS=$'\t' read -r file cmd || [ -n "${file:-}" ]; do
    std="$(printf '%s\n' "$cmd" | grep -o -e '-std=[^ ]*' | tail -n 1)"
    [ "$std" = "-std=c++17" ] || fail "$(basename "$file") compiles with $std"
    for flag in -fno-exceptions -fno-rtti -Os -Wall -Wextra -Werror; do
      case " $cmd " in
        *" $flag "*) ;;
        *) fail "$(basename "$file") compiles without $flag" ;;
      esac
    done
    checked=$((checked + 1))
  done < "$dir/core-commands.txt"
  [ "$checked" -eq 5 ] || fail "expected 5 packbin sources in the build and found $checked"
  local warnings
  warnings=$(count_warnings "$log")
  echo "$chip: $checked packbin sources with the AC-1 flags; build warnings: $warnings"
  [ "$warnings" -eq 0 ] || fail "$warnings build warning(s)"
  local bin
  bin=$(wc -c < "$dir/packbin_embedded.bin")
  note "AC-1 $chip ESP-IDF $(idf.py --version | awk '{ print $NF }') 0 errors 0 warnings; app image ${bin} B"
}

target_esp32s3() { target_esp esp32s3; }
target_esp32c3() { target_esp esp32c3; }
