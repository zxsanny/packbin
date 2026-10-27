#!/usr/bin/env bash
# Loop 76 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop76/smoke76.sh
# Needs Docker (one rust:1.98 run), dotnet 10, a JDK 17+, cargo, python3.10+ and node 22 on PATH; about 10 minutes on a quiet host
# (check `uptime` first). Step 11 of the loop (scripts/loop-tests.sh --all) is the total run; this script re-checks what the
# loop delivered (hygiene items 1 to 7 of _docs/02_task_plans/hygiene-after-frame-ports/), none of which the total run exercises.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
base=a50e750
work="$(mktemp -d)"
keep="${TMPDIR:-/tmp}/smoke76-failed-logs"
fails=0
burners=""
cleanup() {
  [ -z "$burners" ] || kill $burners 2> /dev/null || true
  if [ "$fails" -ne 0 ]; then rm -rf "$keep"; cp -R "$work" "$keep"; echo "smoke76: logs kept in $keep"; fi
  rm -rf "$work"
}
trap cleanup EXIT
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2${4:+ [$4]}"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
}
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }
py3="$(command -v python3.14 || command -v python3)"
mkdir -p "$work/bin" && ln -s "$py3" "$work/bin/python3" && export PATH="$work/bin:$PATH"

# 1. No application source is dirty (the smoke runs at the commit before the close commit; _docs/ waits for it).
code=0
dirty="$(git status --porcelain -- . ':(exclude)_docs')"
[ -z "$dirty" ] || code=1
step 1 "no application source is dirty" "$code" "$(printf '%s' "$dirty" | head -n 3)"

# 2. AZ-3330: the timing selftest has no printf pipe, still catches a mutated alpha line, prints the evidence, and passes 20 times under 12 CPU burners.
code=0
st=.github/workflows/publish-timing.selftest.sh
[ "$(grep -c "printf '%s\\\\n' .*| grep" "$st")" -eq 0 ] || { echo "printf pipes remain"; code=1; }
[ "$(wc -l < "$st")" -le 500 ] || code=1
limit 120 bash "$st" > "$work/st.out" 2> "$work/st.err" < /dev/null || code=1
[ "$(grep -c '^FAIL' "$work/st.err")" -eq 0 ] || code=1
cp -R .github/workflows "$work/wf"
sed -i.bak '/timed_say "publish-gate: \$timed_current took/s/took/tooks/' "$work/wf/publish-timing.test.sh"
if limit 120 bash "$work/wf/publish-timing.selftest.sh" > "$work/mut.out" 2> "$work/mut.err" < /dev/null; then code=1; echo "mutant passed"; fi
grep -q '^FAIL: alpha has no timing line' "$work/mut.err" || { echo "no alpha message"; code=1; }
grep -q 'captured output:' "$work/mut.err" && grep -q '| publish-gate: alpha tooks' "$work/mut.err" || { echo "no captured output"; code=1; }
for i in $(seq 1 12); do perl -e 'alarm 600; 1 while 1' & burners="$burners $!"; done
bad=0
for i in $(seq 1 20); do limit 120 bash "$st" > /dev/null 2> "$work/load$i.err" < /dev/null || bad=$((bad + 1)); done
kill $burners 2> /dev/null; burners=""
[ "$bad" -eq 0 ] || { echo "$bad of 20 loaded runs failed"; code=1; }
step 2 "timing selftest: 0 printf pipes, mutant caught with evidence, 20 of 20 loaded runs pass" "$code" "$(wc -l < "$st") lines"

# 3. AZ-3329: the C# probe project builds without CS7022, runs edges (64 PASS, 0 FAIL), and the ns20 probe still builds.
code=0
cp -R fixtures/hostile/fuzz/csharp "$work/probe-cs"
limit 600 env MSBUILDDISABLENODEREUSE=1 dotnet build -c Release -p:PackbinSrc="$PWD/csharp" -o "$work/probe-cs/out" "$work/probe-cs/PackbinProbe.csproj" > "$work/cs-build.log" 2>&1 < /dev/null || code=1
! grep -q 'CS7022' "$work/cs-build.log" || code=1
limit 300 "$work/probe-cs/out/PackbinProbe" "$PWD" edges > "$work/cs-edges.log" 2>&1 < /dev/null || code=1
[ "$(grep -c '^PASS' "$work/cs-edges.log")" -eq 64 ] && [ "$(grep -c '^FAIL' "$work/cs-edges.log")" -eq 0 ] || code=1
cp -R fixtures/hostile/fuzz/csharp/ns20 "$work/probe-ns20"
limit 600 env MSBUILDDISABLENODEREUSE=1 dotnet build -c Release -p:PackbinSrc="$PWD/csharp" -o "$work/probe-ns20/out" "$work/probe-ns20/Ns20Utf8Probe.csproj" > "$work/ns20-build.log" 2>&1 < /dev/null || code=1
step 3 "C# probe: build without CS7022, edges 64 PASS 0 FAIL, ns20 probe builds" "$code" "$(grep -c '^PASS' "$work/cs-edges.log") PASS"

# 4. AZ-3329: the Java edges probe, 65 PASS and 0 FAIL.
code=0
mkdir -p "$work/probe-java"
limit 300 javac --release 17 -encoding UTF-8 -d "$work/probe-java" java/src/main/java/packbin/*.java fixtures/hostile/fuzz/java/packbin/*.java > "$work/javac.log" 2>&1 < /dev/null || code=1
limit 300 java -Xmx1g -cp "$work/probe-java" packbin.AuditProbe "$PWD" edges > "$work/java-edges.log" 2>&1 < /dev/null || code=1
[ "$(grep -c '^PASS' "$work/java-edges.log")" -eq 65 ] && [ "$(grep -c '^FAIL' "$work/java-edges.log")" -eq 0 ] || code=1
step 4 "Java edges probe: 65 PASS, 0 FAIL" "$code" "$(grep -c '^PASS' "$work/java-edges.log") PASS"

# 5. AZ-3331: the tests of all 8 Rust feature sets compile; the frame set passes; one run in the Docker toolchain.
code=0
export CARGO_TARGET_DIR="$work/rust-target"
sets=("" "alloc" "text" "ecc" "text,ecc" "frame" "text,ecc,frame")
for fs in "${sets[@]}"; do
  if [ -z "$fs" ]; then args=(--no-default-features); else args=(--no-default-features --features "$fs"); fi
  (cd rust && limit 900 cargo test "${args[@]}" --no-run > "$work/cargo-${fs:-none}.log" 2>&1 < /dev/null) || { echo "set '${fs:-none}' did not compile"; code=1; }
done
(cd rust && limit 900 cargo test --no-run > "$work/cargo-default.log" 2>&1 < /dev/null) || { echo "default set did not compile"; code=1; }
(cd rust && limit 900 cargo test --no-default-features --features frame --no-fail-fast > "$work/cargo-frame-run.log" 2>&1 < /dev/null) || code=1
limit 1200 docker run --rm -e CARGO_TARGET_DIR=/tmp/target-rust-smoke -v "$PWD":/src -v packbin-cargo-reg:/usr/local/cargo/registry -w /src/rust rust:1.98 \
  cargo test --no-default-features --features frame --no-run > "$work/cargo-docker.log" 2>&1 < /dev/null || code=1
unset CARGO_TARGET_DIR
step 5 "Rust: 8 of 8 feature sets compile their tests; frame set passes; Docker rust:1.98 frame set compiles" "$code" "$(grep -E '^test result: ok' "$work/cargo-frame-run.log" | sed -E 's/.* ok\. ([0-9]+) passed.*/\1/' | paste -sd+ - | bc) frame tests passed"

# 6. AZ-3332: the 10 frame types in the DocC list; the stale os_random reason gone; the vcpkg line and README untouched.
code=0
miss=""
for t in FrameSession FrameConfig FrameDirection FrameDirections FrameSlot FrameOpened MsgContext Freshness ReplayWindow MacKey; do
  grep -q "^- \`\`$t\`\`" swift/Sources/Packbin/Packbin.docc/Packbin.md || miss="$miss $t"
done
[ -z "$miss" ] || code=1
grep -F -- '- The port is for Linux and macOS only' _docs/02_document/adr/003_cpp-vcpkg-git-registry.md | grep -q 'os_random' && code=1
grep -F -- '- The vcpkg port is static only' _docs/02_document/components/05_cpp_package/description.md | grep -q 'os_random' && code=1
git diff --quiet "$base" HEAD -- .github/workflows/publish-embedded.sh .github/workflows/publish-vcpkg.test.sh README.md || code=1
grep -q '"supports": "linux | osx"' _docs/02_document/adr/003_cpp-vcpkg-git-registry.md || code=1
step 6 "DocC lists 10 of 10 frame types; no os_random reason; vcpkg supports line, its check and README unchanged" "$code" "missing:$miss"

# 7. AZ-3333: no stale name; the C# tests list the same count; the renamed fuzz probes exit 0.
code=0
hits="$(git grep -n 'TopRangeAndSessionTests\|EccSessionTextTests\|fuzz_ecc_session' -- . ':(exclude)_docs/loops' ':(exclude)_docs/02_tasks/done' ':(exclude)_docs/03_implementation' ':(exclude)_docs/02_task_plans/hygiene-after-frame-ports' | cut -d: -f1)"
[ "$hits" = "_docs/02_document/components/01_csharp_package/tests-by-loop.md" ] || { echo "stale names: $hits"; code=1; }
limit 900 env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo --list-tests > "$work/cs-list.log" 2>&1 < /dev/null || code=1
count="$(grep -c '^    ' "$work/cs-list.log")"
[ "$count" -eq 4220 ] || { echo "listed C# tests: $count, expected 4220"; code=1; }
limit 300 "$py3" -I -B fixtures/hostile/fuzz/python/fuzz_ecc.py "$PWD" 1 2 > "$work/fuzz-py.log" 2>&1 < /dev/null || code=1
(cd typescript && limit 300 node ../fixtures/hostile/fuzz/typescript/fuzz_ecc.ts "$PWD/.." 1 2 > "$work/fuzz-ts.log" 2>&1 < /dev/null) || code=1
step 7 "no stale 'Session' name (1 history row), C# lists 4,220 tests, both fuzz probes exit 0" "$code" "listed $count"

# 8. Nothing normative moved: frame, crypto, hostile cases and the contract are unchanged since the base.
code=0
git diff --quiet "$base" HEAD -- fixtures/frame fixtures/crypto fixtures/hostile/cases.txt fixtures/ecc fixtures/golden.hex _docs/02_document/contracts || code=1
step 8 "frame, crypto, ECC, hostile-case fixtures, golden hex and the contracts unchanged since $base" "$code"

# 9. No touched source file grew past 500 lines (a new file over 500 lines counts).
code=0
long=""
for f in $(git diff --name-only --diff-filter=AM "$base" HEAD -- csharp java swift rust cpp go python typescript .github scripts fixtures | grep -E '\.(rs|cs|java|swift|cpp|hpp|go|py|ts|sh)$'); do
  [ -f "$f" ] || continue
  n="$(wc -l < "$f")"
  [ "$n" -gt 500 ] || continue
  old="$(git show "$base:$f" 2>/dev/null | wc -l)"
  [ "$n" -le "$old" ] || long="$long $f:$old->$n"
done
[ -z "$long" ] || code=1
step 9 "no touched source file grew past 500 lines" "$code" "$long"

# 10. AZ-3334: the Python and TypeScript edges probes accept NFD before NFC and print so; 0 FAIL, exit 0.
code=0
limit 300 "$py3" -I -B fixtures/hostile/fuzz/python/edges.py "$PWD" > "$work/edges-py.log" 2>&1 < /dev/null || code=1
(cd typescript && limit 300 node ../fixtures/hostile/fuzz/typescript/edges.ts "$PWD/.." > "$work/edges-ts.log" 2>&1 < /dev/null) || code=1
for l in "$work/edges-py.log" "$work/edges-ts.log"; do
  grep -q "INFO keys NFC 'é' and NFD 'e+U+0301': accepted as two keys" "$l" || { echo "NFC/NFD info line wrong in $l"; code=1; }
  [ "$(grep -c '^FAIL' "$l")" -eq 0 ] || code=1
done
step 10 "Python and TypeScript edges probes: NFC/NFD case accepted (NFD first), 0 FAIL" "$code"

echo "smoke76: $fails failed"
[ "$fails" -eq 0 ]
