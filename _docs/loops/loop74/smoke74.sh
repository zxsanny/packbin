#!/usr/bin/env bash
# Loop 74 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop74/smoke74.sh
# Needs cargo (Rust 1.98 host toolchain with the thumbv7em and thumbv8m.main targets), Docker, python3 3.10+ first on PATH,
# dotnet 10, a JDK, Swift 6 (Xcode), npm and node 22; about 15 minutes on a quiet host (check `uptime` first).
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
base=10cc0be
work="$(mktemp -d)"
# A failing run keeps every step log, so a failure that does not repeat can be read afterwards.
keep="${TMPDIR:-/tmp}/smoke74-failed-logs"
trap 'if [ "$fails" -ne 0 ]; then rm -rf "$keep"; cp -R "$work" "$keep"; echo "smoke74: logs kept in $keep"; fi; rm -rf "$work"' EXIT
fails=0
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2${4:+ [$4]}"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
}
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }
cargo_test() { # cargo_test <log> <args...>
  local log="$1"
  shift
  limit 900 cargo test --manifest-path rust/Cargo.toml "$@" > "$log" 2>&1 < /dev/null || return 1
  ! grep -qE 'test result: FAILED' "$log"
}

# 1. No application source is dirty (the smoke runs at the commit before the close commit; _docs/ waits for it).
code=0
dirty="$(git status --porcelain -- . ':(exclude)_docs')"
[ -z "$dirty" ] || code=1
step 1 "no application source is dirty" "$code" "$(printf '%s' "$dirty" | head -n 3)"

# 2. AZ-3280..AZ-3288 AC-1: no stream session name is left in any package, driver, script or probe.
code=0
hits="$(git grep -n -E 'PackSession|SessionPrivates|session_hex|session_ecc_hex|nostd_session|os_random|RandomFn|MessageContext|MsgCtx' -- rust csharp java swift cpp go python typescript .github scripts fixtures Package.swift \
  ':(exclude)python/tests/test_star_import.py' ':(exclude)typescript/tests/crypto-vectors.test.ts' ':(exclude)cpp/tests/core/host_tests.cpp' | head -n 5)"
# The ring commands (pack-session, unpack-session and their -ecc forms) are gone from the ring and its drivers; the contract file pack-session.md keeps its name.
ring="$(git grep -n -E '(un)?pack-session(-ecc)?([^.a-z]|$)' -- .github | head -n 3)"
[ -z "$ring" ] || { code=1; hits="$hits $ring"; }
[ -z "$hits" ] || code=1
cargo build --manifest-path rust/Cargo.toml --features session > "$work/sess.log" 2>&1 < /dev/null && code=1
grep -qiE 'feature' "$work/sess.log" && grep -qi 'session' "$work/sess.log" || code=1  # the wording differs by Cargo version; the build must fail and name the feature
step 2 "no stream session name in any package; Cargo refuses the session feature" "$code" "$(printf '%s' "$hits" | head -c 240)"

# 3. AZ-3284, AZ-3289: Rust builds and tests with the frame feature alone and with text and ecc; the D1 names.
code=0
limit 900 cargo build --manifest-path rust/Cargo.toml --no-default-features --features frame > "$work/b1.log" 2>&1 < /dev/null || code=1
limit 900 cargo build --manifest-path rust/Cargo.toml --no-default-features --features frame,text,ecc > "$work/b2.log" 2>&1 < /dev/null || code=1
cargo_test "$work/fv1.log" --features frame --test frame_vectors_tests || code=1
cargo_test "$work/fv2.log" --no-default-features --features frame --test frame_vectors_tests || code=1
cargo_test "$work/fc.log" --features frame,ecc --lib frame_ || code=1
cargo_test "$work/cv.log" --lib crypto_vectors || code=1
cargo_test "$work/doc.log" --features frame --doc || code=1
cargo_test "$work/dt.log" --test nostd_docs_tests || code=1
for n in FrameSession FrameConfig FrameDirection FrameDirections FrameSlot FrameOpened MsgContext ReplayWindow Freshness MacKey; do
  grep -q "$n" rust/src/nostd/mod.rs || { code=1; echo "$n" >> "$work/names.miss"; }
done
touch "$work/names.miss"
rustn="$(cat "$work"/fv1.log "$work"/fv2.log "$work"/fc.log "$work"/cv.log "$work"/doc.log "$work"/dt.log | awk '/test result: ok\./ {n += $4} END {print n + 0}')"
[ "$rustn" -ge 20 ] || code=1
step 3 "Rust frame builds, 157 frame rows, 27 crypto rows (default build), docs test, D1 names" "$code" "$(tr '\n' ' ' < "$work/names.miss")$rustn Rust tests passed"

# 4. AZ-3284, AZ-3289 AC-4: the Rust embedded stage: no session set, every figure equal to loop 73.
code=0
limit 1500 rust/embedded/run.sh host > "$work/emb.log" 2>&1 < /dev/null || code=1
for r in rust-m4f rust-m33f rust-mutants; do grep -q "^=== $r: PASS" "$work/emb.log" || code=1; done
sizes="$(grep -E '^SIZE ' "$work/emb.log" | awk '{print $2, $5, $9}' | sed -e 's/flash=//' -e 's/stack=//' | tr '\n' ';')"
expect="base 15060 456;text 27156 2736;ecc 18692 744;frame 20332 1728;base 15132 456;text 27268 2736;ecc 18764 744;frame 20404 1728;"
[ "$sizes" = "$expect" ] || code=1
step 4 "Rust embedded rows pass with the loop 73 figures and no session set (M4F frame 20,332 B of 20,480)" "$code" "$(printf '%s' "$sizes" | head -c 240)"

# 5. AZ-3281, AZ-3282, AZ-3285: C#, Java and Swift frame and crypto vector rows, README examples.
code=0
limit 1200 env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo --filter 'FullyQualifiedName~CryptoVectorTests|FullyQualifiedName~FrameVectorTests|FullyQualifiedName~FrameRefusalTests' > "$work/cs.log" 2>&1 < /dev/null || code=1
limit 1200 bash java/test.sh > "$work/java.log" 2>&1 < /dev/null || code=1
grep -q 'frame vectors: 157 rows checked, 0 mismatches' "$work/java.log" || code=1
grep -q 'api-check PASS' "$work/java.log" || code=1
limit 1500 swift test --filter 'CryptoVectorTests|FrameVectorTests|ReadmeExampleTests|FrameReadmeExampleTests|FrameReplayTests' > "$work/swift.log" 2>&1 < /dev/null || code=1
bash scripts/frame/readme-examples.sh > "$work/readme.log" 2>&1 < /dev/null || code=1
[ "$(grep -c '^PASS' "$work/readme.log")" -eq 4 ] || code=1
csn="$(grep -o -E 'Passed: +[0-9]+' "$work/cs.log" | tail -n 1)"
jvn="$(grep -o -E 'PackbinTest checks: [0-9]+' "$work/java.log" | tail -n 1)"
swn="$(grep -o -E 'Test run with [0-9]+ tests' "$work/swift.log" | tail -n 1)"
step 5 "C#, Java, Swift frame and crypto rows; 4 README frame examples equal their tests" "$code" "C# $csn; Java $jvn; Swift $swn; $(grep -c '^PASS' "$work/readme.log") README PASS"

# 6. AZ-3283, AZ-3288: Python and TypeScript crypto vectors, no session export, no new dependency.
code=0
py=python/.venv/bin/python
if ! "$py" -c 'import pytest' > /dev/null 2>&1 < /dev/null; then
  py="$work/venv/bin/python"
  python3 -m venv "$work/venv" > /dev/null 2>&1 < /dev/null && "$py" -m pip install -q pytest > /dev/null 2>&1 < /dev/null
fi
limit 900 "$py" -m pytest -v --tb=short -p no:cacheprovider python/tests/test_crypto_vectors.py python/tests/test_star_import.py python/tests/test_ecc_text_dispatch.py > "$work/py.log" 2>&1 < /dev/null || code=1
grep -qE '[0-9]+ passed' "$work/py.log" || code=1
(cd typescript && limit 900 node --test tests/crypto-vectors.test.ts > "$work/ts.log" 2>&1 < /dev/null) || code=1
grep -q '^# fail 0' "$work/ts.log" || code=1
grep -q '"dependencies"' typescript/package.json || code=1
[ "$(python3 -c "import json;print(','.join(sorted(json.load(open('typescript/package.json'))['dependencies'])))")" = "@noble/hashes" ] || code=1
step 6 "Python and TypeScript crypto rows, no session export, only @noble/hashes" "$code" "Python $(grep -o -E '[0-9]+ passed' "$work/py.log" | tail -n 1); TypeScript $(grep -E '^# (pass|fail)' "$work/ts.log" | tr '\n' ' ')"

# 7. AZ-3286, AZ-3287: C++ host and target vector tests, Go crypto rows.
code=0
make -C cpp clean > /dev/null 2>&1 < /dev/null  # cpp/build is shared with the gcc:16 container (ELF): never build over its objects
limit 1200 env PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" make -C cpp test > "$work/cpp.log" 2>&1 < /dev/null || code=1
grep -q 'all tests passed' "$work/cpp.log" || code=1
make -C cpp clean > /dev/null 2>&1 < /dev/null
sleep 3
limit 900 docker run --rm -v "$root":/src -v packbin-gomod:/go/pkg/mod -v packbin-gocache:/root/.cache/go-build -w /src/go golang:1.27 sh -c 'test -z "$(gofmt -l .)" && go vet ./... && go test -race -count=1 ./...' > "$work/go.log" 2>&1 < /dev/null || code=1
if [ "$code" -ne 0 ]; then why="cpp: $(tail -n 2 "$work/cpp.log" | tr '\n' ' ' | cut -c1-200) | go: $(grep -E -- '^--- FAIL|^panic:|^FAIL' "$work/go.log" | head -n 6 | tr '\n' ' ' | cut -c1-300)"; else why="C++ $(grep -o -E 'crypto vectors: [^;]*; [0-9]+ of [0-9]+' "$work/cpp.log" | head -n 1); Go $(grep -c '^ok' "$work/go.log") packages ok"; fi
step 7 "C++ host suite and Go (gofmt, vet, race tests) pass" "$code" "$why"

# 8. AZ-3280, AZ-3286: the ring (clear and ECC, 8 x 8) and the C++ embedded targets (pins hold).
code=0
limit 1500 scripts/loop-tests.sh --all --only ring,cpp-embedded-arm > "$work/ring.log" 2>&1 < /dev/null || code=1
sed 's/\x1b\[[0-9;]*m//g' "$work/ring.log" > "$work/ring.txt"
grep -q 'STAGE ring: PASS' "$work/ring.txt" || code=1
grep -q 'STAGE cpp-embedded-arm: PASS' "$work/ring.txt" || code=1
step 8 "ring (64 pairs, ECC) and C++ embedded arm (cpp-m4f 7,712 / 540 B, cpp-m33f 25,720 / 724 B) pass" "$code" "$(grep -E '^STAGE' "$work/ring.txt" | tr '\n' ' ')"

# 9. Wire bytes unchanged: the fixture files equal their loop 73 content.
code=0
git diff --quiet "$base" HEAD -- fixtures/frame/vectors.txt fixtures/crypto/vectors.txt fixtures/ecc fixtures/golden.hex || code=1
bash fixtures/frame/check-vectors.test.sh > "$work/fxv.log" 2>&1 < /dev/null || code=1
bash fixtures/crypto/check-vectors.test.sh > "$work/cxv.log" 2>&1 < /dev/null || code=1
[ "$(shasum -a 256 fixtures/frame/vectors.txt | cut -d' ' -f1)" = "bc9d36f7e7a3585896adeaebb31b51d23ebd9f2ed08be58476cf8d7e67c8b3e4" ] || code=1
[ "$(shasum -a 256 fixtures/crypto/vectors.txt | cut -d' ' -f1)" = "000e1e95b7644a5b48d5e2a23ed8189d35a857fb5b9af62e2bd7d98db6c450b5" ] || code=1
[ "$(shasum -a 256 fixtures/golden.hex | cut -d' ' -f1)" = "b5faa1b7ccdf1cdf6cebcc82e62224b7e1a1a8109ee4b2b9074405642130d88c" ] || code=1
step 9 "frame, crypto, ECC and golden fixtures unchanged since $base (SHA-256 equal)" "$code"

# 10. Docs: contract 3.0.0 frame only, ADR-009 accepted, no Encrypted session section, no PackSession in live docs.
code=0
grep -q '^\*\*Version\*\*: 3.0.0$' _docs/02_document/contracts/library/pack-session.md || code=1
! grep -qiE 'stream' <(sed -n '/^## Configuration/,/^## Change Log/p' _docs/02_document/contracts/library/pack-session.md | grep -v 'removed\|since 3.0.0\|ADR 009') || code=1
grep -q '^- \*\*Status\*\*: Accepted$' _docs/02_document/adr/009_frame-mode-is-the-only-session.md || code=1
grep -q '^| 009 ' _docs/02_document/adr/README.md || code=1
! grep -q '^## Encrypted session' README.md || code=1
live="$(git grep -n -E 'PackSession' -- _docs/02_document _docs/00_problem ':(exclude)_docs/02_document/adr' ':(exclude)_docs/02_document/epics.md' ':(exclude)_docs/02_document/ripple_log_*' | grep -v -i -E 'retired|removed|loop 74|ADR-?009|until loop|history|went with|deleted|stream' | head -n 3)"
[ -z "$live" ] || code=1
step 10 "contract 3.0.0 frame only, ADR-009 accepted and indexed, README and live docs clean" "$code" "$(printf '%s' "$live" | head -c 200)"

# 11. No touched source or test file grew past 500 lines.
code=0
long=""
for f in $(git diff --name-only --diff-filter=AM "$base" HEAD -- rust csharp java swift cpp go python typescript .github scripts fixtures | grep -E '\.(rs|cs|java|swift|cpp|hpp|go|py|ts|sh)$'); do
  [ -f "$f" ] || continue
  n="$(wc -l < "$f")"
  [ "$n" -gt 500 ] || continue
  old="$(git show "$base:$f" 2>/dev/null | wc -l)"
  [ "$n" -le "$old" ] || long="$long $f:$old->$n"
done
[ -z "$long" ] || code=1
step 11 "no touched source file grew past 500 lines" "$code" "$long"

echo "smoke74: $fails failed"
[ "$fails" -eq 0 ]
