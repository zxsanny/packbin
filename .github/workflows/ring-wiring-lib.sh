#!/usr/bin/env bash
# Shared by ring-wiring.test.sh and ring-wiring-rows.test.sh (sourced after `set -euo pipefail`;
# it runs nothing): a temp directory removed when the sourcing script exits, and the failure counter with fail().
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}
