#!/usr/bin/env bash
# Loop 84 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop84/smoke84.sh
# What the loop delivered (AZ-3390 to AZ-3393): the scaffold wiring check requires the yaml_get and workflow_yaml test steps,
# all_kinds.cpp is split in two parts (M33F flash pin 25,760 B), the id-padded ring test no longer depends on the 5-line cap,
# the Python version of test.yml lives in RING_PYTHON only.
# Needs python3 (3.10+), bash, rsync, Docker (gcc:16 and the embedded image build of loop-tests.sh), a JDK 26
# (SMOKE84_JDK_BIN, default ~/.local/share/packbin-jdk26/bin), dotnet, cargo, node, go. SMOKE84_STEPS="1 2" runs only those
# steps (a trial run, never the loop's result). Step 3 runs the cpp and ARM stages of scripts/loop-tests.sh.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
work="$(mktemp -d)"
keep="${TMPDIR:-/tmp}/smoke84-failed-logs"
steps="${SMOKE84_STEPS:-1 2 3 4 5 6 7}"
fails=0
cleanup() {
  if [ "$fails" -ne 0 ]; then rm -rf "${keep:?}"; cp -R "$work" "$keep"; echo "smoke84: logs kept in $keep"; fi
  rm -rf "${work:?}"
}
trap cleanup EXIT
want() { case " $steps " in *" $1 "*) return 0 ;; esac; return 1; }
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2${4:+ [$4]}"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
}
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }
wf=.github/workflows
common=cpp/embedded/common
jdk_bin="${SMOKE84_JDK_BIN:-$HOME/.local/share/packbin-jdk26/bin}"
if [ -x "$jdk_bin/javac" ]; then export PATH="$jdk_bin:$PATH"; fi
export MSBUILDDISABLENODEREUSE=1 PACKBIN_RING_WORK="$work/ring" LOOP_TESTS_PYTHON="${LOOP_TESTS_PYTHON:-$(command -v python3)}"

# 1. No application source is dirty (the smoke runs at the commit before the close commit; _docs/ waits for it).
if want 1; then
  code=0
  dirty="$(git status --porcelain -- . ':(exclude)_docs')"
  [ -z "$dirty" ] || code=1
  step 1 "no application source is dirty" "$code" "$(printf '%s' "$dirty" | head -n 3)"
fi

# 2. AZ-3391 AC-1, AC-3: every part of the embedded common sources is at most 500 lines; each consumer names both parts; the pin.
if want 2; then
  code=0
  long="$(wc -l "$common"/*.cpp "$common"/*.hpp | awk '$2 != "total" && $1 > 500')"
  [ -z "$long" ] || { echo "$long"; code=1; }
  for f in cpp/Makefile cpp/embedded/arm.sh cpp/embedded/esp/main/CMakeLists.txt; do
    grep -qF all_kinds_rounds "$f" || { echo "$f does not name all_kinds_rounds"; code=1; }
  done
  [ "$(grep -c 'all_kinds_rounds.o' cpp/embedded/arm.sh)" -ge 4 ] || { echo "arm.sh: fewer than 4 lines name all_kinds_rounds.o"; code=1; }
  grep -qx 'm33f_flash_pin=25760' cpp/embedded/lib.sh || { echo "m33f_flash_pin is not 25760"; code=1; }
  step 2 "embedded common sources at most 500 lines, 3 consumers name both parts, M33F flash pin 25,760" "$code" "$(wc -l "$common"/all_kinds*.cpp | tr '\n' ' ')"
fi

# 3. AZ-3391 AC-2, AC-5: the host build and tests (gcc:16 -Werror) and the ARM stage (6 rows, M33F against the raised pin).
if want 3; then
  code=0
  limit 1800 bash scripts/loop-tests.sh --only cpp,cpp-embedded-arm --all < /dev/null > "$work/lt.log" 2>&1 || { tail -n 12 "$work/lt.log"; code=1; }
  grep -q '^RESULT 2 passed, 0 skipped as unchanged, 0 failed' "$work/lt.log" || { echo "loop-tests did not report 2 passed"; code=1; }
  step 3 "loop-tests cpp and cpp-embedded-arm stages pass" "$code" "$(grep '^RESULT' "$work/lt.log")"
fi

# 4. AZ-3390, AZ-3393: the wiring check on the real files, on copies with a step deleted, a 3.13 version, a literal version.
if want 4; then
  code=0
  (cd / && python3 -I "$root/$wf/ring-wiring-check.py" "$root/$wf/test.yml" "$root/docker-compose.test.yml" < /dev/null) || { echo "ring-wiring-check.py failed on the real files"; code=1; }
  [ "$(grep -c -E 'scripts/ci/(yaml_get|workflow_yaml)\.test\.sh' "$wf/ring-wiring-check.py")" -eq 2 ] || { echo "SCAFFOLD_SCRIPTS lacks the two entries"; code=1; }
  [ "$(grep -c '3\.14' "$wf/test.yml")" -eq 1 ] || { echo "test.yml names 3.14 $(grep -c '3\.14' "$wf/test.yml") times (want 1)"; code=1; }
  python3 - "$wf/test.yml" "$work" <<'PY' || code=1
import re, sys
src, work = sys.argv[1], sys.argv[2]
text = open(src).read()
def drop(name):
    return re.sub(r"      - name: %s\n        run: [^\n]*\n" % re.escape(name), "", text)
open(work + "/no-reader.yml", "w").write(drop("CI YAML reader"))
open(work + "/no-helpers.yml", "w").write(drop("CI workflow helpers"))
open(work + "/py313.yml", "w").write(text.replace('RING_PYTHON: "3.14"', 'RING_PYTHON: "3.13"'))
open(work + "/literal.yml", "w").write(re.sub(r"(scaffold:(?:.|\n)*?python-version: )\$\{\{ env.RING_PYTHON \}\}", r'\g<1>"3.14"', text, count=1))
PY
  for pair in "no-reader:yaml_get.test.sh" "no-helpers:workflow_yaml.test.sh" "py313:RING_PYTHON" "literal:RING_PYTHON"; do
    f="${pair%%:*}"; want_msg="${pair#*:}"
    cmp -s "$wf/test.yml" "$work/$f.yml" && { echo "$f.yml equals the real file"; code=1; }
    out="$(python3 -I "$wf/ring-wiring-check.py" "$work/$f.yml" docker-compose.test.yml < /dev/null)"; rc=$?
    [ "$rc" -eq 1 ] || { echo "$f: exit $rc (want 1)"; code=1; }
    case "$out" in *"$want_msg"*) ;; *) echo "$f: message lacks $want_msg: $out"; code=1 ;; esac
  done
  for t in ring-wiring.test.sh ring-wiring-rows.test.sh ring-wiring-swift.test.sh publish-pins.test.sh; do
    limit 600 bash "$wf/$t" < /dev/null > "$work/t.log" 2>&1 || { echo "$t"; tail -n 3 "$work/t.log"; code=1; }
    [ "$t" != ring-wiring.test.sh ] || [ "$(grep -c 'rejects:' "$work/t.log")" -eq 42 ] || { echo "ring-wiring.test.sh: not 42 rejects"; code=1; }
  done
  limit 300 bash scripts/ci/yaml_get.test.sh < /dev/null > /dev/null 2>&1 || { echo "yaml_get.test.sh"; code=1; }
  limit 300 bash scripts/ci/workflow_yaml.test.sh < /dev/null > /dev/null 2>&1 || { echo "workflow_yaml.test.sh"; code=1; }
  step 4 "wiring check: real files clean; deleted steps, 3.13 and a literal version rejected; 42 mutants; 3.14 once" "$code"
fi

# 5. AZ-3392 AC-4: the ring (64 pairs, 0 mismatched, 72 refusal rows x 8) and its self-tests with the default cap.
if want 5; then
  code=0
  limit 1200 bash "$wf/ring-frame.sh" < /dev/null > "$work/ring-frame.log" 2>&1 || { tail -n 8 "$work/ring-frame.log"; code=1; }
  grep -q '^ring-frame: 64 pairs, mismatched: 0$' "$work/ring-frame.log" || { echo "ring-frame: not 64 pairs / 0 mismatched"; code=1; }
  rows="$(grep -c '^refusals [a-z]*: 72 rows, 0 mismatched$' "$work/ring-frame.log")"
  [ "$rows" -eq 8 ] || { echo "refusal lines with 72 rows: $rows of 8"; code=1; }
  for t in ring-frame.test.sh ring-frame-drivers.test.sh; do
    limit 900 bash "$wf/$t" < /dev/null > "$work/t.log" 2>&1 || { echo "$t"; tail -n 3 "$work/t.log"; code=1; }
  done
  step 5 "ring-frame 64 pairs / 0 mismatched / 72 refusal rows x 8; ring-frame and driver self-tests pass" "$code"
fi

# 6. AZ-3392 AC-3: with 10 rows sorted ahead of the id-padded needle (in a copy) the new test passes and the old one fails.
if want 6; then
  code=0
  mkdir -p "$work/cap/$wf" "$work/cap/scripts" "$work/cap/fixtures"
  rsync -a --include='*.sh' --include='*.py' --exclude='*' "$wf/" "$work/cap/$wf/"
  rsync -a scripts/frame scripts/crypto "$work/cap/scripts/"; rsync -a fixtures/frame "$work/cap/fixtures/"
  python3 - "$work/cap/fixtures/frame/ring-cases.txt" <<'PY' || code=1
import sys
p = sys.argv[1]
lines = open(p).read().split("\n")
at = next(i for i, l in enumerate(lines) if l.startswith("refuse-open R.open.id0 "))
src = next(l for l in lines if l.startswith("refuse-open R.open.id7 "))
extra = [src.replace("R.open.id7", "R.open.aa%02d" % n, 1) for n in range(10)]
lines[at:at] = extra
open(p, "w").write("\n".join(lines))
PY
  (cd "$work/cap" && limit 900 bash "$wf/ring-frame.test.sh" < /dev/null > "$work/new.log" 2>&1) || { grep -E '^FAIL' "$work/new.log" | head -n 3; code=1; }
  grep -q '^PASS id-padded' "$work/new.log" || { echo "new test: id-padded is not PASS with 10 extra rows"; code=1; }
  git show a925aa7:"$wf/ring-frame.test.sh" > "$work/cap/$wf/ring-frame.test.sh"
  (cd "$work/cap" && limit 900 bash "$wf/ring-frame.test.sh" < /dev/null > "$work/old.log" 2>&1); orc=$?
  grep -q '^FAIL id-padded' "$work/old.log" || { echo "old test: id-padded did not FAIL with 10 extra rows (exit $orc)"; code=1; }
  step 6 "id-padded passes with 10 extra rows ahead of its needle (HEAD's test fails the same copy)" "$code" "old test exit $orc"
fi

# 7. Syntax of the touched scripts, size of every touched source.
if want 7; then
  code=0
  for f in "$wf/ring-frame.sh" "$wf/ring-frame.test.sh" "$wf/ring-wiring.test.sh" cpp/embedded/arm.sh cpp/embedded/lib.sh "$0"; do bash -n "$f" || { echo "bash -n $f"; code=1; }; done
  python3 -m py_compile "$wf/ring-wiring-check.py" scripts/frame/ring_frame.py || code=1
  big="$(wc -l "$wf/ring-wiring-check.py" scripts/frame/ring_frame.py "$common"/*.cpp | awk '$2 != "total" && $1 > 500')"
  [ -z "$big" ] || { echo "$big"; code=1; }
  step 7 "bash -n, py_compile, no touched source over 500 lines" "$code"
fi

echo "smoke84: $(echo "$steps" | wc -w) steps run, $fails failed"
[ "$fails" -eq 0 ]
