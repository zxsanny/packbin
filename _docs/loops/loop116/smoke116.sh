#!/usr/bin/env bash
# Loop 116 smoke (AZ-4242, element-row probes in seven packages): one paste, PASS/FAIL per step.
# Run from the repository root on the project's Mac. Needs the probe tools of scripts/probes/element-row/README.md.
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
probe() { # out-file
  PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" RUSTUP_TOOLCHAIN=1.98 PACKBIN_PROBE_PYTHON=/opt/homebrew/bin/python3.13 \
    limit 900 bash scripts/probes/element-row/run.sh < /dev/null > "$1" 2> "$1.err"
}
s1() { # the whole probe runs and prints every package
  local start; start=$(date +%s)
  probe "$work/a.out" || return 1
  echo "$(wc -l < "$work/a.out" | tr -d ' ') lines in $(( $(date +%s) - start )) s, load $(sysctl -n vm.loadavg | awk '{print $2}')"
  [ "$(cut -f1 "$work/a.out" | sort -u | tr '\n' ' ')" = "cpp go java python rust swift typescript " ] &&
    [ "$(wc -l < "$work/a.out" | tr -d ' ')" -eq 168 ]
}
s2() { # a second run prints the same bytes and writes nothing into the checkout
  probe "$work/b.out" && cmp "$work/a.out" "$work/b.out" && [ -z "$(git status --porcelain)" ] && echo "identical, tree clean"
}
s3() { # every packet written equals TypeScript's: the same shape's packet, or (a coll- line) one of TypeScript's
  awk -F'\t' '
    $1 == "typescript" && $4 ~ /^[0-9a-f]+$/ { ref[$2] = $4; any[$4] = 1 }
    $1 != "typescript" && $4 ~ /^[0-9a-f]+$/ {
      base = $2; sub(/-(map|typed|nostd|unbound)$/, "", base); n++
      ok = (base in ref) ? (ref[base] == $4) : ($4 in any)
      if (!ok) { bad++; print "differs: " $1 " " $2 " " $4 }
    }
    END { print n " packets compared, " bad + 0 " differ"; exit (n > 0 && bad == 0) ? 0 : 1 }' "$work/a.out"
}
s4() { # the defects of the findings are what the probe prints
  local T=$'\t'
  grep -q "^java${T}other-row${T}built${T}threw: ClassCastException" "$work/a.out" &&
    grep -q -E "^java${T}coll-linkedlist${T}built${T}[0-9a-f]+${T}threw: ClassCastException" "$work/a.out" &&
    grep -q "^python${T}null-item${T}built${T}threw: TypeError" "$work/a.out" &&
    grep -q "^go${T}other-row${T}refused: " "$work/a.out" && grep -q "^swift${T}other-row${T}refused: " "$work/a.out" &&
    [ "$(grep -c "${T}threw: " "$work/a.out")" -eq 5 ] && echo "5 threw lines: java 4, python 1"
}
s5() { # no package source changed in this loop; the shell scripts are clean
  local changed
  changed=$(git diff --name-only 0d64971..HEAD | grep -v -E '^(_docs/|scripts/probes/element-row/)' || true)
  [ -z "$changed" ] || { echo "changed outside the probe: $changed"; return 1; }
  shellcheck scripts/probes/element-row/run.sh scripts/probes/element-row/*/run.sh && echo "no package file changed; shellcheck clean"
}
s6() { # the follow-ups exist: three queue items, D10 and D11
  [ -e _docs/02_tasks/backlog/python-null-item-in-element-row.md ] &&
    [ -e _docs/02_tasks/backlog/missing-member-message-by-name-java-python.md ] &&
    grep -q '^blocked_on: OPERATOR_TODO D10' _docs/02_tasks/backlog/java-element-row-raw-class-cast.md &&
    grep -q '^| D10 |' _docs/OPERATOR_TODO.md && grep -q '^| D11 |' _docs/OPERATOR_TODO.md && echo "3 items, D10, D11"
}
step "1. the element-row probe runs: 7 packages, 168 lines" s1
step "2. a second run is byte-identical and writes nothing" s2
step "3. every packet written equals TypeScript's for its shape" s3
step "4. the probe shows the Java and Python defects and Go / Swift refusing at build" s4
step "5. no package source changed; shellcheck clean" s5
step "6. queue items and decisions D10, D11 are written" s6
if [ "$fail" -eq 0 ]; then echo "smoke 116: 6/6 PASS"; else echo "smoke 116: FAIL (logs in $work)"; fi
[ "$fail" -eq 0 ] && rm -rf "$work"
exit "$fail"
