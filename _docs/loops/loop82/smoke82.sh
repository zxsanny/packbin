#!/usr/bin/env bash
# Loop 82 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop82/smoke82.sh
# What the loop delivered (AZ-3381 to AZ-3386): the CI scripts no longer use Ruby. One reader (scripts/ci/yaml_get.py, PyYAML
# pinned in tool-pins.txt) feeds the ported checkers; publish-precheck.sh (release path) uses the standard library; the `if:`
# evaluator is a parser without eval. Needs python3 with PyYAML and bash; Docker, dotnet, cargo, node with typescript/node_modules and a JDK 26 (SMOKE82_JDK_BIN, default ~/.local/share/packbin-jdk26/bin) for step 7; NO ruby is needed (and none must be
# on PATH: step 2 refuses a PATH with ruby). SMOKE82_STEPS="1 2 3" runs only those steps (a trial run, never the loop's result).
# The publish gate inside step 7 fails when anything in the repository changes while it runs: write no file in the repo meanwhile.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
work="$(mktemp -d)"
keep="${TMPDIR:-/tmp}/smoke82-failed-logs"
steps="${SMOKE82_STEPS:-1 2 3 4 5 6 7 8}"
fails=0
cleanup() {
  if [ "$fails" -ne 0 ]; then rm -rf "$keep"; cp -R "$work" "$keep"; echo "smoke82: logs kept in $keep"; fi
  rm -rf "$work"
}
trap cleanup EXIT
want() { case " $steps " in *" $1 "*) return 0 ;; esac; return 1; }
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2${4:+ [$4]}"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
}
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }
wf=.github/workflows
reader="$root/scripts/ci"
py3="$(command -v python3.14 || command -v python3)"
mkdir -p "$work/bin" && ln -s "$py3" "$work/bin/python3" && export PATH="$work/bin:$PATH"
# the ring stage needs a JDK (a user-directory tarball on the Linux dev host), the C++ driver builds in gcc:16 through ring-cxx.sh
jdk_bin="${SMOKE82_JDK_BIN:-$HOME/.local/share/packbin-jdk26/bin}"
if [ -x "$jdk_bin/javac" ]; then export PATH="$jdk_bin:$PATH"; fi
if [ "$(uname -s)" = Darwin ]; then
  PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"; export PACKBIN_CXX_SYSROOT
elif command -v docker > /dev/null; then
  export RING_GCC=16 CXX="$root/.github/workflows/ring-cxx.sh"
fi
export LOOP_TESTS_PYTHON="$py3"
export PACKBIN_RING_WORK="$work/ring"

# 1. No application source is dirty (the smoke runs at the commit before the close commit; _docs/ waits for it).
if want 1; then
  code=0
  dirty="$(git status --porcelain -- . ':(exclude)_docs')"
  [ -z "$dirty" ] || code=1
  step 1 "no application source is dirty" "$code" "$(printf '%s' "$dirty" | head -n 3)"
fi

# 2. AZ-3386 AC-1: no ruby on PATH and none named in the CI scripts, workflows or pins file.
if want 2; then
  code=0
  if command -v ruby > /dev/null; then echo "ruby is on PATH: this host does not prove the port"; code=1; fi
  hits="$(grep -rniE 'r[u]by' --include='*.sh' --include='*.yml' --include='*.py' --include='tool-pins.txt' "$wf" scripts || true)"
  [ -z "$hits" ] || { echo "$hits" | head -n 3; code=1; }
  step 2 "no ruby on PATH, 0 mentions in .github/workflows and scripts" "$code"
fi

# 3. AZ-3381 AC-1 to AC-5: the reader, the pin, the three one-liners.
if want 3; then
  code=0
  limit 120 bash scripts/ci/yaml_get.test.sh > "$work/reader.out" 2>&1 < /dev/null || code=1
  grep -q '^yaml_get.test.sh: all checks passed$' "$work/reader.out" || { echo "reader test not green"; code=1; }
  [ "$(bash $wf/tool-pin.sh pyyaml)" = "$(grep '^pyyaml==' $wf/tool-pins.txt | cut -d= -f3)" ] || { echo "pyyaml pin differs"; code=1; }
  [ "$(grep -c '^pyyaml==' $wf/tool-pins.txt)" -eq 1 ] || { echo "not exactly one pyyaml pin"; code=1; }
  for s in report-row run-suite; do
    limit 300 bash $wf/$s.test.sh > "$work/$s.out" 2>&1 < /dev/null || { echo "$s.test.sh failed: $(tail -n 2 "$work/$s.out")"; code=1; }
  done
  step 3 "reader test, one pin, report-row.test.sh, run-suite.test.sh (with the swift file)" "$code"
fi

# 4. AZ-3382 AC-1 to AC-6: the release path, standard library only.
if want 4; then
  code=0
  limit 300 bash $wf/publish-precheck.test.sh > "$work/precheck.out" 2>&1 < /dev/null || code=1
  grep -q '^publish-precheck checks passed$' "$work/precheck.out" || { echo "precheck test not green"; code=1; }
  [ "$(grep -c '^precheck tests reject:' "$work/precheck.out")" -eq 11 ] || { echo "not 11 mutants rejected"; code=1; }
  # a failed run must not give green=true; the same script with the conclusion check removed must
  mkdir -p "$work/bin"
  printf '#!/bin/sh\ncat "$PRECHECK_BODY"\n' > "$work/bin/curl" && chmod +x "$work/bin/curl"
  sha=2cade74a9c111422f864e59c5175aac09c6e0bad
  printf '{"workflow_runs":[{"id":7,"path":".github/workflows/test.yml","event":"push","status":"completed","conclusion":"failure","head_sha":"%s","head_branch":"dev","head_repository":{"full_name":"zxsanny/packbin"}}]}' "$sha" > "$work/red.json"
  run_pre() { PATH="$work/bin:$PATH" PRECHECK_BODY="$work/red.json" PACKBIN_REPO=zxsanny/packbin PACKBIN_SHA=$sha GITHUB_OUTPUT="$work/pre.out" bash "$1" > /dev/null 2> "$work/pre.err" < /dev/null; }
  : > "$work/pre.out"; run_pre $wf/publish-precheck.sh
  [ "$(cat "$work/pre.out")" = "green=false" ] || { echo "a red run gave: $(cat "$work/pre.out")"; code=1; }
  sed 's/and r.get("conclusion") == "success"//' $wf/publish-precheck.sh | sed '/r.get("conclusion") == "success"/d' > "$work/pre-mutant.sh"
  if cmp -s "$work/pre-mutant.sh" $wf/publish-precheck.sh; then echo "the mutant did not change the script"; code=1; else
    : > "$work/pre.out"; run_pre "$work/pre-mutant.sh"
    [ "$(cat "$work/pre.out")" = "green=true" ] || { echo "the mutant (no conclusion check) did not give green=true: $(cat "$work/pre.out")"; code=1; }
  fi
  step 4 "precheck: 11 of 11 mutants rejected, a red run is not green, the same script without its conclusion check is" "$code"
fi

# 5. AZ-3383, AZ-3384, AZ-3385: the ported checkers on the real files and on broken copies.
if want 5; then
  code=0
  for s in publish-jobs ring-wiring ring-wiring-rows ring-wiring-swift; do
    limit 600 bash $wf/$s.test.sh > "$work/$s.out" 2>&1 < /dev/null || { echo "$s.test.sh failed: $(tail -n 2 "$work/$s.out")"; code=1; }
  done
  [ "$(grep -c '^layout check rejects:' "$work/publish-jobs.out")" -eq 115 ] || { echo "publish-jobs: not 115 rejects"; code=1; }
  python3 -I $wf/publish-workflow-structure.py $wf/test.yml $wf/publish.yml > "$work/struct.out" 2>&1 || { echo "real workflows: $(cat "$work/struct.out")"; code=1; }
  # broken copies: a character the parser must refuse, a gate job without a timeout, a job without the PyYAML install
  sed "0,/needs.precheck.result == 'success'/s//needs.precheck.result == 'success';/" $wf/publish.yml > "$work/publish.yml"
  cmp -s "$work/publish.yml" $wf/publish.yml && { echo "publish.yml copy unchanged"; code=1; }
  python3 -I $wf/publish-workflow-structure.py $wf/test.yml "$work/publish.yml" > "$work/struct2.out" 2>&1 && { echo "a ';' in an if: was accepted"; code=1; }
  grep -q 'unsupported term' "$work/struct2.out" || { echo "the refusal does not say unsupported term: $(cat "$work/struct2.out")"; code=1; }
  grep -v 'timeout-minutes: 45' $wf/test.yml > "$work/test-notimeout.yml"
  python3 -I $wf/publish-jobs-layout.py "$work/test-notimeout.yml" $wf/publish-gate.test.sh > "$work/layout.out" 2>&1 && { echo "a gate job without a timeout was accepted"; code=1; }
  step 5 "publish-jobs (115 rejects), ring-wiring x3 pass; a ';' in an if:, a job without timeout are refused" "$code"
fi

# 6. AZ-3381 AC-3 and AZ-3386 AC-3: a missing module, file or a job without the install is a named failure.
if want 6; then
  code=0
  out="$(python3 -I -c 'import sys; sys.modules["yaml"] = None; sys.path.insert(0, sys.argv[1]); import yaml_get' "$reader" 2>&1)"; rc=$?
  { [ "$rc" -eq 2 ] && grep -q 'PyYAML is required to parse the workflow YAML' <<< "$out"; } || { echo "no module: rc=$rc $out"; code=1; }
  out="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import yaml_get; yaml_get.load(sys.argv[2])' "$reader" "$work/none.yml" 2>&1)"; rc=$?
  { [ "$rc" -eq 2 ] && grep -q 'cannot read' <<< "$out"; } || { echo "no file: rc=$rc $out"; code=1; }
  awk 'skip > 0 { skip--; next } /^      - name: PyYAML$/ && !done { done = 1; skip = 1; next } { print }' $wf/test.yml > "$work/test-nopip.yml"
  out="$(python3 -I $wf/publish-pins-install.py "$work/test-nopip.yml" 2>&1)"; rc=$?
  { [ "$rc" -eq 1 ] && grep -q 'without setup-python and the pinned PyYAML install' <<< "$out"; } || { echo "no install: rc=$rc $out"; code=1; }
  step 6 "no PyYAML, no file and a job without the install each fail with their cause" "$code"
fi

# 7. The loop's test stages: scaffold, ring and the publish gate (the gate runs the workflow, pins and static groups here).
if want 7; then
  code=0
  limit 2400 bash scripts/loop-tests.sh --only scaffold,ring,publish-gate --all > "$work/stages.out" 2>&1 < /dev/null || code=1
  grep -E '^(STAGE|RESULT)' "$work/stages.out" | sed 's/^/  /'
  grep -q '^RESULT 3 passed' "$work/stages.out" || { echo "not 3 passed stages"; code=1; }
  step 7 "scripts/loop-tests.sh --only scaffold,ring,publish-gate --all" "$code" "$(grep '^RESULT' "$work/stages.out")"
fi

# 8. Size and syntax: every touched CI file is at or under 500 lines, bash -n and py_compile are clean.
if want 8; then
  code=0
  for f in $wf/*.sh scripts/ci/*.sh scripts/loop-tests.sh scripts/loop-tests.test.sh; do
    bash -n "$f" || { echo "bash -n: $f"; code=1; }
  done
  for f in $wf/*.py scripts/ci/*.py; do
    python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$f" || { echo "syntax: $f"; code=1; }
  done
  for f in $wf/publish-*.sh $wf/ring-wiring*.sh $wf/run-suite*.sh $wf/report-row.test.sh $wf/*.py scripts/ci/*; do
    [ -f "$f" ] || continue
    [ "$(wc -l < "$f")" -le 500 ] || { echo "over 500 lines: $f"; code=1; }
  done
  step 8 "bash -n and syntax clean, no touched CI file over 500 lines" "$code"
fi

echo "smoke82: $fails failed"
exit "$fails"
