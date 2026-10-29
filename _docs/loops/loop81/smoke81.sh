#!/usr/bin/env bash
# Loop 81 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop81/smoke81.sh
# What the loop delivered (AZ-3378): the frame ring refuses a key that is not 32 bytes and a msg_id that is not 8 bytes in all
# 8 languages (15 rows); the loader writes "-" for an empty key or id; the Rust (key, msg_id) and C++ (msg_id) drivers print
# BadValue themselves. Needs python3.10+, Docker (the C++ driver is built in gcc:16 through ring-cxx.sh, Go and Swift in their
# images), dotnet, a JDK 26 (SMOKE81_JDK_BIN, default ~/.local/share/packbin-jdk26/bin when it exists), cargo, node with
# typescript/node_modules (npm ci), perl; no ruby (four scaffold scripts that need it are WAIVED by the owner, 2026-10-29); about 20 to 30 minutes on a quiet host
# (check `uptime` first). The publish gate runs inside step 8 and fails when anything in the repository changes while it runs,
# so write no file in the repo meanwhile. SMOKE81_STEPS="1 2 3" runs only those steps (a trial run, never the gate's result).
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
work="$(mktemp -d)"
keep="${TMPDIR:-/tmp}/smoke81-failed-logs"
steps="${SMOKE81_STEPS:-1 2 3 4 5 6 7 8 9}"
fails=0
cleanup() {
  if [ "$fails" -ne 0 ]; then rm -rf "$keep"; cp -R "$work" "$keep"; echo "smoke81: logs kept in $keep"; fi
  rm -rf "$work"
}
trap cleanup EXIT
want() { case " $steps " in *" $1 "*) return 0 ;; esac; return 1; }
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2${4:+ [$4]}"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
}
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }
py3="$(command -v python3.14 || command -v python3)"
mkdir -p "$work/bin" && ln -s "$py3" "$work/bin/python3" && export PATH="$work/bin:$PATH"
jdk_bin="${SMOKE81_JDK_BIN:-$HOME/.local/share/packbin-jdk26/bin}"
if [ -x "$jdk_bin/javac" ]; then export PATH="$jdk_bin:$PATH"; fi
if [ "$(uname -s)" = Darwin ]; then
  PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)"; export PACKBIN_CXX_SYSROOT
elif command -v docker > /dev/null; then
  export RING_GCC=16 CXX="$root/.github/workflows/ring-cxx.sh" # the compiler of CI (GCC 16), as the ring job
fi
export LOOP_TESTS_PYTHON="$py3"
export PACKBIN_RING_WORK="$work/ring" # fresh driver builds: a kept work dir reuses old C# and C++ binaries
cases=fixtures/frame/ring-cases.txt
n_refusals="$(grep -cE '^(open|verify|refuse-seal|refuse-open|refuse-mac) ' "$cases")"
start="$(git log --format=%h -n 1 --grep='^Start: ring-key-id-length-refusals')"

# 1. No application source is dirty (the smoke runs at the commit before the close commit; _docs/ waits for it).
if want 1; then
  code=0
  dirty="$(git status --porcelain -- . ':(exclude)_docs')"
  [ -z "$dirty" ] || code=1
  [ -n "$start" ] || { echo "no start commit"; code=1; }
  step 1 "no application source is dirty" "$code" "$(printf '%s' "$dirty" | head -n 3)"
fi

# 2. AZ-3378 AC-5, AC-6: the self-test (stand-in drivers) passes with its three new cases.
if want 2; then
  code=0
  limit 300 bash .github/workflows/ring-frame.test.sh > "$work/selftest.out" 2>&1 < /dev/null || code=1
  grep -q '^ring-frame.test: all passed$' "$work/selftest.out" || code=1
  for c in id-padded key-aborts empty-key-and-id-keep-fields; do
    grep -q "^PASS $c\$" "$work/selftest.out" || { echo "no PASS $c"; code=1; }
  done
  [ "$(grep -c '^PASS' "$work/selftest.out")" -eq 37 ] || { echo "not 37 PASS lines"; code=1; }
  ! grep -q '^FAIL' "$work/selftest.out" || { echo "a FAIL line"; code=1; }
  step 2 "self-test passes: id-padded, key-aborts, empty key and id keep their fields" "$code" "$(grep -c '^PASS' "$work/selftest.out") PASS"
fi

# 3. AZ-3378 AC-1, AC-2: the real ring, all 8 languages, with the 15 new refusal rows.
if want 3; then
  code=0
  [ "$n_refusals" -eq 58 ] || { echo "refusal rows: $n_refusals, wanted 58"; code=1; }
  limit 900 bash .github/workflows/ring-frame.sh > "$work/ring.out" 2> "$work/ring.err" < /dev/null || code=1
  grep -q '^ring-frame: 64 pairs, mismatched: 0$' "$work/ring.out" || { echo "no 64-pair total"; code=1; }
  [ "$(grep -c "^refusals [a-z]*: $n_refusals rows, 0 mismatched$" "$work/ring.out")" -eq 8 ] || { echo "not 8 clean refusal lines of $n_refusals rows"; code=1; }
  step 3 "real ring: 64 pairs and 8 x $n_refusals refusals, 0 mismatched" "$code" "$(tail -n 1 "$work/ring.out")"
fi

# 4. AZ-3378 AC-3, AC-4, AC-7: the real drivers answer BadValue for every wrong-length line, in all 8 languages.
if want 4; then
  code=0
  limit 900 bash .github/workflows/ring-frame-drivers.test.sh > "$work/drivers.out" 2>&1 < /dev/null || code=1
  grep -q '^ring-frame-drivers: all passed (8 languages, 276 checks)$' "$work/drivers.out" || { echo "not 276 checks passed in 8 languages"; code=1; }
  ! grep -q '^FAIL' "$work/drivers.out" || { echo "a FAIL line"; code=1; }
  step 4 "driver script: 276 checks, BadValue for a wrong key or msg_id in 8 languages" "$code" "$(tail -n 1 "$work/drivers.out")"
fi

# 5. AZ-3378 AC-5, AC-6: not vacuous. Scratch copies of HEAD with one part of the loop put back to the start commit: the
# loader (the empty-token case fails), the rows (id-padded, key-aborts and the empty-token case fail), the Rust and C++
# drivers (the driver script fails 18 Rust and 6 C++ checks).
if want 5; then
  code=0
  for v in loader rows drivers; do mkdir -p "$work/$v/packbin" && git archive HEAD | tar -x -C "$work/$v/packbin"; done
  git show "$start:scripts/frame/ring_frame.py" > "$work/loader/packbin/scripts/frame/ring_frame.py" || code=1
  git show "$start:fixtures/frame/ring-cases.txt" > "$work/rows/packbin/fixtures/frame/ring-cases.txt" || code=1
  git show "$start:.github/workflows/drivers/handoff-rust/src/frame.rs" > "$work/drivers/packbin/.github/workflows/drivers/handoff-rust/src/frame.rs" || code=1
  git show "$start:.github/workflows/drivers/handoff.cpp" > "$work/drivers/packbin/.github/workflows/drivers/handoff.cpp" || code=1
  rc=0
  limit 300 bash "$work/loader/packbin/.github/workflows/ring-frame.test.sh" > "$work/mut-loader.out" 2>&1 < /dev/null || rc=$?
  [ "$rc" -eq 1 ] || { echo "the loop-start loader exited $rc, wanted 1"; code=1; }
  grep -q '^FAIL empty-key-and-id-keep-fields:' "$work/mut-loader.out" || { echo "no FAIL empty-key-and-id-keep-fields with the old loader"; code=1; }
  rc=0
  limit 300 bash "$work/rows/packbin/.github/workflows/ring-frame.test.sh" > "$work/mut-rows.out" 2>&1 < /dev/null || rc=$?
  [ "$rc" -eq 1 ] || { echo "the loop-start rows exited $rc, wanted 1"; code=1; }
  for c in id-padded key-aborts empty-key-and-id-keep-fields; do grep -q "^FAIL $c:" "$work/mut-rows.out" || { echo "no FAIL $c with the old rows"; code=1; }; done
  [ "$(grep -c '^FAIL' "$work/mut-rows.out")" -eq 3 ] || { echo "not exactly 3 FAIL lines with the old rows"; code=1; }
  rc=0
  (cd "$work/drivers/packbin" && PACKBIN_RING_WORK="$work/drivers/work" CXX="${CXX:-c++}" RING_FRAME_LANGS="rust cpp" \
    limit 900 bash .github/workflows/ring-frame-drivers.test.sh > "$work/mut-drivers.out" 2>&1 < /dev/null) || rc=$?
  [ "$rc" -eq 1 ] || { echo "the loop-start drivers exited $rc, wanted 1"; code=1; }
  grep -q '^ring-frame-drivers: failed in: rust cpp$' "$work/mut-drivers.out" || { echo "not failed in rust and cpp"; code=1; }
  [ "$(grep -c '^FAIL rust ' "$work/mut-drivers.out")" -eq 18 ] || { echo "not 18 Rust FAIL lines"; code=1; }
  [ "$(grep -c '^FAIL cpp ' "$work/mut-drivers.out")" -eq 6 ] || { echo "not 6 C++ FAIL lines"; code=1; }
  step 5 "the start-commit loader, rows and drivers each fail the new checks" "$code" "loader $(grep -c '^FAIL' "$work/mut-loader.out") FAIL, rows $(grep -c '^FAIL' "$work/mut-rows.out"), drivers $(grep -c '^FAIL' "$work/mut-drivers.out")"
fi

# 6. Wiring: the ring wiring rows and ring-lib tests (the two that do not need ruby).
if want 6; then
  code=0
  for t in .github/workflows/ring-wiring-rows.test.sh .github/workflows/ring-lib.test.sh; do
    limit 600 bash "$t" > "$work/$(basename "$t").out" 2>&1 < /dev/null || { echo "$t failed"; code=1; }
  done
  step 6 "ring wiring rows and ring-lib tests pass" "$code"
fi

# 7. The scaffold stage of scripts/loop-tests.sh command by command (same order, same commands), without the four scripts that
# call ruby (WAIVED by the owner on 2026-10-29: this host has no ruby; CI's scaffold job runs them).
if want 7; then
  code=0
  n=0
  scaffold_run() { # scaffold_run <label> <command...>
    local label="$1" rc=0
    shift
    n=$((n + 1))
    limit 900 "$@" > "$work/scaffold.$n.out" 2>&1 < /dev/null || rc=$?
    [ "$rc" -eq 0 ] || { echo "scaffold command $n ($label) exited $rc: $(tail -n 3 "$work/scaffold.$n.out" | tr '\n' '|' | cut -c1-240)"; code=1; }
  }
  export MSBUILDDISABLENODEREUSE=1 DOTNET_NOLOGO=1
  scaffold_run "golden.hex line" grep -qx 4001000065cd1d00a3e1110100 fixtures/golden.hex
  scaffold_run "hostile cases.test" bash fixtures/hostile/cases.test.sh
  scaffold_run "hostile check-cases" bash fixtures/hostile/check-cases.sh
  scaffold_run "text check-vectors.test" bash fixtures/text/check-vectors.test.sh
  scaffold_run "text check-emitted.test" bash scripts/text/check-emitted.test.sh
  scaffold_run "text check-emitted" bash scripts/text/check-emitted.sh
  scaffold_run "crypto check-vectors.test" bash fixtures/crypto/check-vectors.test.sh
  scaffold_run "frame check-vectors.test" bash fixtures/frame/check-vectors.test.sh
  scaffold_run "ecc check-vectors.test" bash fixtures/ecc/check-vectors.test.sh
  scaffold_run "ecc check-contract" bash fixtures/ecc/check-contract.sh
  scaffold_run "ecc fuzz_reference" python3 -I scripts/ecc/fuzz_reference.py
  scaffold_run "ring-ecc.test" bash .github/workflows/ring-ecc.test.sh
  scaffold_run "ring-frame.test" bash .github/workflows/ring-frame.test.sh
  scaffold_run "cpp embedded lib.test" bash cpp/embedded/lib.test.sh
  scaffold_run "cpp embedded run-parts.test" bash cpp/embedded/run-parts.test.sh
  scaffold_run "rust embedded checks.test" bash rust/embedded/checks.test.sh
  scaffold_run "ring-wiring-rows.test" bash .github/workflows/ring-wiring-rows.test.sh
  scaffold_run "ring-lib.test" bash .github/workflows/ring-lib.test.sh
  scaffold_run "ring-prepare.test" bash .github/workflows/ring-prepare.test.sh
  scaffold_run "loop-tests.test" bash scripts/loop-tests.test.sh
  [ "$n" -eq 20 ] || { echo "ran $n scaffold commands, wanted 20"; code=1; }
  step 7 "scaffold stage: 20 commands pass; WAIVED (owner 2026-10-29): report-row, run-suite, ring-wiring, ring-wiring-swift tests (ruby)" "$code"
fi

# 8. The other two stages the files of this loop can change (loop-tests.sh covers()): ring and publish-gate, through the runner.
if want 8; then
  code=0
  stamps="$work/stamps"
  mkdir -p "$stamps"
  lt_log="${SMOKE81_LT_LOG:-$work/lt.out}"
  limit 3000 env LOOP_TESTS_STAMPS="$stamps" scripts/loop-tests.sh --only ring,publish-gate > "$lt_log" 2>&1 < /dev/null || code=1
  grep -q '^RESULT 2 passed, [0-9]* skipped as unchanged, 0 failed' "$lt_log" || { echo "no RESULT line with 2 passed, 0 failed"; code=1; }
  for s in ring publish-gate; do grep -q "^STAGE $s: PASS" "$lt_log" || { echo "stage $s did not pass"; code=1; }; done
  cp "$lt_log" "$work/lt.out" 2> /dev/null || true
  step 8 "loop-tests: ring and publish-gate pass" "$code" "$(grep '^RESULT' "$lt_log" | tail -n 1)"
fi

# 9. Lint and size: shellcheck on the changed scripts (the local binary, else the koalaman/shellcheck image), Python compiles,
# no touched source file went over 500 lines (handoff.cpp was over before: 631 at loop 79, split excluded there).
if want 9; then
  code=0
  if command -v shellcheck > /dev/null; then
    shellcheck -S warning .github/workflows/ring-frame.test.sh .github/workflows/ring-frame-drivers.test.sh || code=1
  elif command -v docker > /dev/null; then
    docker run --rm -v "$root:/mnt:ro" -w /mnt koalaman/shellcheck:stable -S warning -x \
      .github/workflows/ring-frame.test.sh .github/workflows/ring-frame-drivers.test.sh || code=1
  else
    echo "no shellcheck and no docker"; code=1
  fi
  python3 -I -m py_compile scripts/frame/ring_frame.py || code=1
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    now="$(wc -l < "$f")"
    was="$(git show "$start:$f" 2> /dev/null | wc -l)" || was=0
    if [ "$now" -gt 500 ] && [ "$was" -le 500 ]; then echo "$f grew from $was to $now lines"; code=1; fi
  done < <(git diff --name-only "$start"..HEAD -- . ':(exclude)_docs' ':(exclude)fixtures')
  step 9 "shellcheck clean, Python compiles, no touched source file over 500 lines" "$code"
fi

echo "smoke81: $fails failed"
echo "smoke81: WAIVED by the owner on 2026-10-29 (no ruby on this host; CI's scaffold job runs them): report-row.test.sh run-suite.test.sh ring-wiring.test.sh ring-wiring-swift.test.sh"
[ "$fails" -eq 0 ]
