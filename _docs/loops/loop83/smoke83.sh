#!/usr/bin/env bash
# Loop 83 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop83/smoke83.sh
# What the loop delivered (AZ-3387 to AZ-3389): handoff.cpp split under 500 lines, one module for the ring-wiring checkers' helpers
# (scripts/ci/workflow_yaml.py), 14 ring rows that put a wrong-length key or msg_id before a second refusal.
# Needs python3 (3.10+), bash, rsync, Docker (gcc:16, Go, Swift), dotnet, cargo, node and a JDK 26 (SMOKE83_JDK_BIN, default
# ~/.local/share/packbin-jdk26/bin). SMOKE83_STEPS="1 2" runs only those steps (a trial run, never the loop's result).
# Steps 4 and 6 run the whole ring and write nothing in the repository.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
work="$(mktemp -d)"
keep="${TMPDIR:-/tmp}/smoke83-failed-logs"
steps="${SMOKE83_STEPS:-1 2 3 4 5 6 7 8}"
fails=0
cleanup() {
  if [ "$fails" -ne 0 ]; then rm -rf "${keep:?}"; cp -R "$work" "$keep"; echo "smoke83: logs kept in $keep"; fi
  rm -rf "${work:?}"
}
trap cleanup EXIT
want() { case " $steps " in *" $1 "*) return 0 ;; esac; return 1; }
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2${4:+ [$4]}"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
}
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }
wf=.github/workflows
drivers="$wf/drivers"
jdk_bin="${SMOKE83_JDK_BIN:-$HOME/.local/share/packbin-jdk26/bin}"
if [ -x "$jdk_bin/javac" ]; then export PATH="$jdk_bin:$PATH"; fi
export MSBUILDDISABLENODEREUSE=1 PACKBIN_RING_WORK="$work/ring"

# 1. No application source is dirty (the smoke runs at the commit before the close commit; _docs/ waits for it).
if want 1; then
  code=0
  dirty="$(git status --porcelain -- . ':(exclude)_docs')"
  [ -z "$dirty" ] || code=1
  step 1 "no application source is dirty" "$code" "$(printf '%s' "$dirty" | head -n 3)"
fi

# 2. AZ-3387 AC-1, AC-4: every driver source is at most 500 lines and the compile line names the three driver sources.
if want 2; then
  code=0
  long="$(wc -l "$drivers"/*.cpp "$drivers"/*.hpp | awk '$2 != "total" && $1 > 500')"
  [ -z "$long" ] || { echo "$long"; code=1; }
  for f in handoff.cpp handoff_ecc.cpp handoff_frame.cpp; do grep -qF "\"\$drivers/$f\"" "$wf/ring-lib.sh" || { echo "ring-lib.sh does not compile $f"; code=1; }; done
  grep -q '|| return' "$wf/ring-lib.sh" || { echo "ring-lib.sh lost || return"; code=1; }
  step 2 "driver sources at most 500 lines, compile line names the three, || return kept" "$code" "$(wc -l "$drivers"/handoff*.cpp | tail -n 1)"
fi

# 3. AZ-3387 AC-2: the merged driver sources build with -Wall -Wextra -Werror on GCC 16.
if want 3; then
  code=0
  out="$(limit 600 docker run --rm -v "$PWD":/src -w /src gcc:16 sh -c \
    "g++ -std=c++17 -O2 -Wall -Wextra -Werror -Icpp/include -o /tmp/hx $drivers/handoff.cpp $drivers/handoff_ecc.cpp $drivers/handoff_frame.cpp cpp/src/core/values.cpp cpp/src/core/pack.cpp cpp/src/core/unpack.cpp cpp/src/core/crypto.cpp cpp/src/core/frame.cpp && /tmp/hx pack-user && echo BUILD-OK" < /dev/null 2>&1)" || code=1
  case "$out" in *BUILD-OK*) ;; *) echo "$out" | tail -n 5; code=1 ;; esac
  step 3 "gcc:16 -Werror builds the split driver" "$code"
fi

# 4. AZ-3387 AC-3 and AZ-3389 AC-3: the ring (64 pairs, 0 mismatched, 72 refusal rows in each of 8 languages), the pairs, the ECC ring.
if want 4; then
  code=0
  limit 1200 bash "$wf/ring-frame.sh" < /dev/null > "$work/ring-frame.log" 2>&1 || { tail -n 8 "$work/ring-frame.log"; code=1; }
  grep -q '^ring-frame: 64 pairs, mismatched: 0$' "$work/ring-frame.log" || { echo "ring-frame: not 64 pairs / 0 mismatched"; code=1; }
  rows="$(grep -c '^refusals [a-z]*: 72 rows, 0 mismatched$' "$work/ring-frame.log")"
  [ "$rows" -eq 8 ] || { echo "refusal lines with 72 rows: $rows of 8"; code=1; }
  limit 1200 bash "$wf/language-pair.sh" < /dev/null > "$work/pair.log" 2>&1 || { tail -n 5 "$work/pair.log"; code=1; }
  limit 1200 bash "$wf/ring-ecc.sh" < /dev/null > "$work/ecc.log" 2>&1 || { tail -n 5 "$work/ecc.log"; code=1; }
  step 4 "ring-frame 64 pairs / 0 mismatched / 72 refusal rows x 8, language-pair, ring-ecc" "$code" "$(tail -n 1 "$work/ecc.log")"
fi

# 5. AZ-3388 AC-1, AC-4, AC-6: the 12 definitions live once, both checkers run isolated from another directory, the helper tests pass.
if want 5; then
  code=0
  pat='^(def (to_s|inspect|first_set|dig|steps_of|code_lines|runs)\b|(FLAGS|CACHE_USES|SHA_PIN|ASCII_SPACE|STRING_ESCAPES) =)'
  a="$(grep -c -E "$pat" "$wf/ring-wiring-check.py")"; b="$(grep -c -E "$pat" "$wf/ring-wiring-swift-check.py")"; m="$(grep -c -E "$pat" scripts/ci/workflow_yaml.py)"
  [ "$a $b $m" = "0 0 12" ] || { echo "definitions in the two checkers and the module: $a $b $m (want 0 0 12)"; code=1; }
  (cd / && python3 -I "$root/$wf/ring-wiring-check.py" "$root/$wf/test.yml" "$root/docker-compose.test.yml" < /dev/null) || { echo "ring-wiring-check.py failed isolated"; code=1; }
  pin="$(grep -i '^swift' "$wf/tool-pins.txt" | head -n 1 | awk '{print $NF}')"
  for t in scripts/ci/workflow_yaml.test.sh scripts/ci/yaml_get.test.sh "$wf/publish-pins.test.sh"; do
    limit 600 bash "$t" < /dev/null > "$work/t.log" 2>&1 || { echo "$t"; tail -n 3 "$work/t.log"; code=1; }
  done
  grep -q 'workflow_yaml.test.sh' "$wf/test.yml" || { echo "test.yml has no step for workflow_yaml.test.sh"; code=1; }
  step 5 "12 definitions once (0 0 12), checkers run under python3 -I from /, helper, reader and pins tests pass, CI step present" "$code" "swift pin ${pin:-?}"
fi

# 6. AZ-3387 AC-5, AZ-3388 AC-2, AZ-3389 AC-5: the wiring and ring tests, the rows, the readers.
if want 6; then
  code=0
  n="$(grep -c '^refuse-' fixtures/frame/ring-cases.txt)"
  [ "$n" -eq 56 ] || { echo "refuse rows: $n (want 56)"; code=1; }
  for t in ring-wiring.test.sh ring-wiring-rows.test.sh ring-wiring-swift.test.sh ring-lib.test.sh ring-frame.test.sh ring-frame-drivers.test.sh ring-ecc.test.sh ring-prepare.test.sh publish-jobs.test.sh publish-workflow.test.sh; do
    limit 900 bash "$wf/$t" < /dev/null > "$work/t.log" 2>&1 || { echo "$t"; tail -n 3 "$work/t.log"; code=1; }
  done
  step 6 "56 refuse rows; ten wiring, ring and publish tests pass" "$code"
fi

# 7. AZ-3389 AC-4: a Python package that checks the key length after the size checks fails the ring on the new rows (in a copy).
if want 7; then
  code=0
  mkdir -p "$work/mut/.github" "$work/mut/scripts" "$work/mut/fixtures"
  rsync -a --exclude target --exclude obj --exclude bin --exclude .build "$wf" "$work/mut/.github/"
  rsync -a python "$work/mut/"; rsync -a scripts/frame scripts/crypto scripts/ci "$work/mut/scripts/"; rsync -a fixtures/frame "$work/mut/fixtures/"
  (cd "$work/mut" && python3 -I "$root/_docs/loops/loop83/mut-python-key-order.py" < /dev/null) || { echo "the mutation did not apply"; code=1; }
  (cd "$work/mut" && RING_FRAME_LANGS=python limit 600 bash .github/workflows/ring-frame.sh < /dev/null > "$work/mut.log" 2>&1); mrc=$?
  [ "$mrc" -ne 0 ] || { echo "the ring passed with the reordered key check"; code=1; }
  hits="$(grep -cE 'python: R\.(seal|open)\.(key33|id7)\.[a-z0-9]+ (seal|open) gave (TooLong|BufferFull), wanted BadValue' "$work/mut.log")"
  [ "$hits" -ge 1 ] || { tail -n 8 "$work/mut.log"; echo "no new row caught the reordering"; code=1; }
  diff -rq python "$work/mut/python" > /dev/null 2>&1 && { echo "copy equals the tree: nothing mutated"; code=1; }
  git diff --quiet -- python || { echo "the real python/ changed"; code=1; }
  step 7 "reordered key check fails the ring on a new row (mutation in a copy; real tree untouched)" "$code" "exit $mrc, $hits new-row lines"
fi

# 8. Syntax of the touched scripts and size of every touched source.
if want 8; then
  code=0
  for f in "$wf/ring-lib.sh" "$wf/ring-frame.test.sh" scripts/ci/workflow_yaml.test.sh "$0"; do bash -n "$f" || { echo "bash -n $f"; code=1; }; done
  python3 -m py_compile "$wf/ring-wiring-check.py" "$wf/ring-wiring-swift-check.py" scripts/ci/workflow_yaml.py || code=1
  big="$(wc -l "$wf/ring-wiring-check.py" "$wf/ring-wiring-swift-check.py" scripts/ci/workflow_yaml.py "$drivers"/handoff*.cpp "$drivers"/handoff_common.hpp | awk '$2 != "total" && $1 > 500')"
  [ -z "$big" ] || { echo "$big"; code=1; }
  step 8 "bash -n, py_compile, no touched source over 500 lines" "$code"
fi

echo "smoke83: $(echo "$steps" | wc -w) steps run, $fails failed"
[ "$fails" -eq 0 ]
