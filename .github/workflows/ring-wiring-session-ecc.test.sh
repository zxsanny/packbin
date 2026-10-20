#!/usr/bin/env bash
# Wiring check of the all-language session-ecc stage of the cross-language ring (AZ-2739 AC-3, moved here from
# ring-wiring-swift.test.sh by AZ-2744): a driver without the protected session command, or one that packs other
# bytes, ends the ring with exit 1 and one line that names the language. The stage is the text of language-pair.sh from
# its comment to the done of its loop, run with a stand-in run_lang that misbehaves for one language: BAD (missing:
# exit 2 and no output; other: other bytes).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

session_ecc_failure_checks() {
  local stage="$tmp/session-ecc-stage.sh" lang mode out rc want
  sed -n '/^# A driver without the protected session command/,/^done$/p' "$here/language-pair.sh" > "$stage"
  if ! grep -qF 'pack-session-ecc' "$stage"; then fail "language-pair.sh has no stage that packs session-ecc"; return; fi
  for lang in none csharp typescript python rust cpp java swift go; do
    for mode in missing other; do
      rc=0
      out="$(BAD="$lang" MODE="$mode" STAGE="$stage" bash -c 'set -euo pipefail; session_ecc_hex=aa
        run_lang() { if [ "$1" != "$BAD" ]; then echo aa; elif [ "$MODE" = missing ]; then return 2; else echo bb; fi; }
        source "$STAGE"' 2>&1)" || rc=$?
      want="$lang pack-session-ecc failed"; [ "$mode" = other ] && want="$lang pack-session-ecc mismatch"
      if [ "$lang" = none ]; then
        [ "$rc" -eq 0 ] && [ -z "$out" ] || fail "the session-ecc stage failed for eight good drivers: exit $rc, [$out]"
      elif [ "$rc" -ne 1 ] || [ "$out" != "$want" ]; then
        fail "the session-ecc stage, $mode driver $lang: exit $rc, [$out], expected exit 1 and [$want]"
      fi
    done
  done
  echo "rejects: a driver without pack-session-ecc or with other bytes, each of the eight named"
}

session_ecc_failure_checks

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "session-ecc ring wiring checks passed"
