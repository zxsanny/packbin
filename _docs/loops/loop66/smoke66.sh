#!/usr/bin/env bash
# Loop 66 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop66/smoke66.sh
# Steps 1 and 2 take about 3 minutes together (the stub sleeps 5 s per proxy ask in step 1).
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
wf=".github/workflows"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
}

# 1. AC-1: the Go test passes with the go stub sleeping 5 s per call.
start=$SECONDS
out="$(GT_GO_DELAY=5 bash "$wf/publish-go.test.sh" 2>&1)"; code=$?
case "$out" in *"go release checks passed"*) ;; *) code=1 ;; esac
step 1 "AC-1 publish-go.test.sh with a 5 s stub, $((SECONDS - start)) s" "$code" "$(printf '%s' "$out" | tail -n 3)"

# 2. AC-2: a copy whose proxy_check stops after one try fails naming "asked once only".
mkdir -p "$work/t/.github" "$work/t/go"
cp -R "$wf" "$work/t/.github/workflows"
cp go/go.mod go/LICENSE "$work/t/go/"
python3 - "$work/t/.github/workflows/publish-go.sh" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.index("proxy_check() {")
needle = 'if [ "$SECONDS" -ge "$deadline" ]; then'
j = s.index(needle, i)
open(p, "w").write(s[:j] + "if true; then" + s[j + len(needle):])
PY
out="$(bash "$work/t/.github/workflows/publish-go.test.sh" 2>&1)"; code=$?
if [ "$code" -ne 0 ] && printf '%s' "$out" | grep -q 'AC-3 the proxy was asked once only'; then code=0; else code=1; fi
step 2 "AC-2 a one-try proxy_check is caught" "$code"

# 3. AC-3: a quiet host runs the Go test in at most 60 s (NOT RUN above load 8: that is not a pass).
load="$(uptime | sed 's/.*load averages*: *//' | awk '{print $1}' | tr -d ,)"
if [ "$(awk -v l="$load" 'BEGIN { print (l > 8) }')" = "1" ]; then
  echo "NOT RUN step 3: AC-3 quiet-host time (load $load above 8)"
else
  start=$SECONDS
  bash "$wf/publish-go.test.sh" > /dev/null 2>&1; code=$?
  [ "$((SECONDS - start))" -le 60 ] || code=1
  step 3 "AC-3 publish-go.test.sh in $((SECONDS - start)) s" "$code"
fi

# 4. AC-4: ph_quote shows a tool error 10 lines before the failure line; no failure message quotes 3 lines.
{ seq 1 29; echo 'ERROR: stub pip failed'; seq 31 39; echo 'build failed: python'; } > "$work/in.txt"
fn="$(awk '/^ph_quote\(\) \{$/ { on = 1 } on { print } on && /^\}$/ { exit }' "$wf/publish-phases.test.sh")"
code=1
if [ -n "$fn" ] && [ "$(bash -c "$fn"$'\n''ph_quote "$1"' _ "$work/in.txt" | grep -cx 'ERROR: stub pip failed')" = "1" ] \
  && ! grep -q 'tail -n 3' "$wf/publish-phases-failures.test.sh"; then code=0; fi
step 4 "AC-4 ph_quote keeps pip's error, no 3-line quote left" "$code"

# 5. The phase-split and timing self-test knows ph_quote is a harness helper.
out="$(bash "$wf/publish-timing.selftest.sh" 2>&1)"; code=$?
step 5 "publish-timing.selftest.sh" "$code" "$(printf '%s' "$out" | tail -n 3)"

echo "smoke66: $fails failed"
[ "$fails" -eq 0 ]
