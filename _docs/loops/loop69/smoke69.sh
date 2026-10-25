#!/usr/bin/env bash
# Loop 69 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop69/smoke69.sh
# Needs Docker with the rust:1.98 and packbin-embedded images and a host cargo with the thumbv7em-none-eabihf target
# (the embedded libs are built with it); takes about 4 minutes with a warm cache.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
}

# 1. AZ-3201 AC-2..4, AZ-3202 AC-1..4: the vector files check, the generator is deterministic, corrupted copies fail.
code=0
bash fixtures/crypto/check-vectors.test.sh > "$work/crypto.log" 2>&1 < /dev/null || code=1
bash fixtures/frame/check-vectors.test.sh > "$work/frame.log" 2>&1 < /dev/null || code=1
grep -q 'frame vectors tests passed' "$work/frame.log" || code=1
step 1 "crypto and frame vector checks, determinism, corrupted copies fail" "$code" "$(tail -n 2 "$work/crypto.log" "$work/frame.log")"

# 2. AZ-3203 AC-1..AC-9, AZ-3204 AC-3: the frame tests in the CI toolchain, both feature sets, the doc example.
code=0
docker run --rm -v "$root":/src -v packbin-cargo-target:/cargo-target -e CARGO_TARGET_DIR=/cargo-target -w /src/rust rust:1.98 bash -c '
  set -e
  cargo test --no-default-features --features frame --test frame_vectors_tests 2>&1 | grep "^test result"
  cargo test --features frame --test frame_vectors_tests 2>&1 | grep "^test result"
  cargo test --features frame --lib frame_ 2>&1 | grep "^test result"
  cargo test --features frame,session,ecc --lib frame_ 2>&1 | grep "^test result"
  cargo test --features frame --doc 2>&1 | grep "^test result"
  cargo test --lib crypto_vectors 2>&1 | grep "^test result"' > "$work/rust.log" 2>&1 < /dev/null || code=1
[ "$(grep -c '^test result: ok' "$work/rust.log")" -eq 6 ] || code=1
step 2 "Rust frame tests: fixture without and with std, crate tests, doc example, primitive vectors" "$code" "$(tail -n 3 "$work/rust.log")"

# 3. AZ-3203 AC-7, AZ-3204 AC-1, AC-2: stream bytes unchanged (session tests), frame on the device within the limits, the four
#    existing sets identical to the figures measured before this loop.
code=0
docker run --rm -v "$root":/src -v packbin-cargo-target:/cargo-target -e CARGO_TARGET_DIR=/cargo-target -w /src/rust rust:1.98 bash -c '
  set -e
  cargo test --no-default-features --features session --test nostd_session_tests 2>&1 | grep "^test result"
  cargo test --features session,ecc --test nostd_session_tests 2>&1 | grep "^test result"
  cargo test --test session_tests 2>&1 | grep "^test result"' > "$work/stream.log" 2>&1 < /dev/null || code=1
[ "$(grep -c '^test result: ok' "$work/stream.log")" -eq 3 ] || code=1
step 3 "stream session tests pass (nostd without and with std, std)" "$code" "$(tail -n 3 "$work/stream.log")"

# 4. AZ-3204 AC-1, AC-2: the embedded stage.
code=0
(cd rust/embedded && bash run.sh libs > "$work/libs.log" 2>&1) || code=1
mkdir -p test-results
docker compose -f docker-compose.test.yml run --rm rust-embedded > "$work/embedded.log" 2>&1 < /dev/null || code=1
grep -q 'rust embedded stage: 0 target(s) failed' "$work/embedded.log" || code=1
size() { sed -n "s/^SIZE $1 ram=0 B flash=\([0-9]*\) B .* stack=\([0-9]*\) B .*/\1 \2/p" "$work/embedded.log" | head -n 1; }
[ "$(size base)" = "14700 456" ] || code=1
[ "$(size text)" = "26632 2760" ] || code=1
[ "$(size ecc)" = "17980 760" ] || code=1
[ "$(size session)" = "18404 1832" ] || code=1
frame="$(size frame)"
set -- $frame
{ [ -n "${1:-}" ] && [ "$1" -le 20480 ] && [ "${2:-9999}" -le 2048 ]; } || code=1
grep -q 'seeded panic defect caught' "$work/embedded.log" || code=1
step 4 "embedded stage: frame ${1:-?} B flash ${2:-?} B stack (limits 20480 / 2048); base, text, ecc, session unchanged" "$code" "$(tail -n 3 "$work/embedded.log" | cut -c1-200)"

# 5. AZ-3200 AC-3, AC-4, AC-6: the contract and the project files.
code=0
grep -q '^\*\*Version\*\*: 2.0.0' _docs/02_document/contracts/library/pack-session.md || code=1
grep -q 'ADR-008' _docs/00_problem/restrictions.md || code=1
grep -q '^| 008 |' _docs/02_document/adr/README.md || code=1
grep -q 'never seal two different messages with the same `msg_id`' README.md || code=1
step 5 "contract 2.0.0, ADR-008 indexed, R-08 exception, uniqueness rule in the README" "$code"

# 6. AZ-3200 AC-3: the stream text of the contract is as in 1.0.0 (every 1.0.0 line is still there).
code=0
git show 056b583:_docs/02_document/contracts/library/pack-session.md | sed -e '/^\*\*Version\*\*/d' -e '/^\*\*Last Updated\*\*/d' -e '/^One optional connection session/d' -e '/^TypeScript, Python, Rust, C++/d' \
  | while IFS= read -r line; do grep -qxF -- "$line" _docs/02_document/contracts/library/pack-session.md || { echo "missing: $line"; exit 1; }; done > "$work/contract.log" || code=1
step 6 "stream text of the contract unchanged since 056b583" "$code" "$(head -n 2 "$work/contract.log")"

echo "smoke69: $fails failed"
[ "$fails" -eq 0 ]
