#!/usr/bin/env bash
# Loop 73 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop73/smoke73.sh
# Needs cargo (host toolchain and Rust 1.98 with the thumbv7em and thumbv8m.main targets), Docker and python3; about
# 6 minutes on a quiet host (check `uptime` first).
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
claim=72beacb
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
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

# 2. AZ-3275 AC-1.1 to 1.3: one wipe helper with one unsafe block; no black_box wipe; frame forbids unsafe.
code=0
unsafe_hits="$(grep -rn 'unsafe {' rust/src)"
[ "$(printf '%s\n' "$unsafe_hits" | grep -c .)" -eq 1 ] || code=1
printf '%s' "$unsafe_hits" | grep -q '^rust/src/session_core/wipe.rs:' || code=1
grep -q 'SAFETY:' rust/src/session_core/wipe.rs || code=1
grep -q 'write_volatile' rust/src/session_core/wipe.rs || code=1
grep -q 'compiler_fence(Ordering::SeqCst)' rust/src/session_core/wipe.rs || code=1
grep -q '^#!\[forbid(unsafe_code)\]' rust/src/nostd/frame/mod.rs || code=1
# AC-2.4: compress ends by wiping its schedule window.
awk '/^fn compress/,/^}/' rust/src/session_core/sha256.rs | grep -q 'wipe::wipe(&mut w);' || code=1
boxes="$(grep -rn black_box rust/src | grep -v '^rust/src/timing_support.rs:' | grep -v 'black_box(diff) == 0')"
[ -z "$boxes" ] || code=1
step 2 "one volatile wipe helper, one unsafe block, no black_box wipe, frame forbids unsafe, compress wipes its schedule" "$code" "$(printf '%s %s' "$unsafe_hits" "$boxes" | head -c 240)"

# 3. AC-1.4, AC-2.3, AC-3.3: the helper test, RFC 5869, RFC 8439 and the 27 primitive rows.
code=0
cargo_test "$work/lib.log" --features frame,session,ecc --lib -- session_core crypto_vectors || code=1
for t in wipe_zeroes_bytes_and_words rfc5869_case_1 rfc8439_block_vector every_hkdf256_row_matches every_hmac256_row_matches every_sha256_row_matches every_chacha_row_matches; do
  grep -qE "$t \.\.\. ok" "$work/lib.log" || { code=1; echo "$t" >> "$work/lib.miss"; }
done
touch "$work/lib.miss"
step 3 "helper test, RFC 5869, RFC 8439 and the primitive vector rows pass" "$code" "$(tr '\n' ' ' < "$work/lib.miss")"

# 4. AC-7: the 157 frame rows (with and without std), the heap-free and std session tests.
code=0
cargo_test "$work/fv1.log" --features frame --test frame_vectors_tests || code=1
cargo_test "$work/fv2.log" --no-default-features --features frame --test frame_vectors_tests || code=1
cargo_test "$work/ns1.log" --no-default-features --features session --test nostd_session_tests || code=1
cargo_test "$work/ns2.log" --features session,ecc --test nostd_session_tests || code=1
cargo_test "$work/ss.log" --test session_tests || code=1
cargo_test "$work/fc.log" --features frame,session,ecc --lib frame_ || code=1
step 4 "frame vectors, frame core, heap-free and std session tests pass" "$code" "$(grep -hE 'test result' "$work"/fv*.log "$work"/ns*.log "$work/ss.log" "$work/fc.log" | awk '{print $4}' | tr '\n' ' ')"

# 5. AC-5: the Rust embedded stage passes; base, text and ecc keep their figures; session and frame are within bounds.
code=0
limit 1500 rust/embedded/run.sh host > "$work/emb.log" 2>&1 < /dev/null || code=1
grep -q '^=== rust-m4f: PASS' "$work/emb.log" || code=1
grep -q '^=== rust-m33f: PASS' "$work/emb.log" || code=1
grep -q '^=== rust-mutants: PASS' "$work/emb.log" || code=1
sizes="$(grep -E '^SIZE ' "$work/emb.log" | awk '{print $2, $5, $9}' | sed -e 's/flash=//' -e 's/stack=//' | tr '\n' ';')"
expect="base 15060 456;text 27156 2736;ecc 18692 744;session 18844 1504;frame 20332 1728;base 15132 456;text 27268 2736;ecc 18764 744;session 18916 1504;frame 20404 1728;"
[ "$sizes" = "$expect" ] || code=1
step 5 "Rust embedded rows pass with the loop 73 figures (M4F frame 20,332 B of 20,480)" "$code" "$(printf '%s' "$sizes" | head -c 240)"

# 6. AC-6.1, AC-6.3: pad::xor over 1 MiB and MacKey::tag in release against the claim commit (3 runs each, smallest).
code=0
for side in base head; do
  rev="$claim"
  [ "$side" = head ] && rev=HEAD
  mkdir -p "$work/$side" "$work/bench-$side/src"
  git archive "$rev" rust | tar -x -C "$work/$side"
  printf '\n#[doc(hidden)]\npub fn bench_pad_xor(key: &[u8; 32], packet: u64, data: &mut [u8]) {\n    session_core::pad::xor(key, packet, data)\n}\n' >> "$work/$side/rust/src/lib.rs"
  printf '[package]\nname = "padbench"\nversion = "0.1.0"\nedition = "2021"\n\n[dependencies]\npackbin = { path = "../%s/rust", features = ["frame"] }\n\n[workspace]\n' "$side" > "$work/bench-$side/Cargo.toml"
  cat > "$work/bench-$side/src/main.rs" <<'EOF'
use std::hint::black_box;
use std::time::Instant;

fn main() {
    let key = [7u8; 32];
    let mut data = vec![0u8; 1 << 20];
    packbin::bench_pad_xor(&key, 0, &mut data);
    let start = Instant::now();
    for packet in 0..32u64 {
        packbin::bench_pad_xor(black_box(&key), packet, black_box(&mut data));
    }
    let pad = start.elapsed().as_secs_f64() / 32.0;
    let key = packbin::nostd::MacKey::derive(&[7u8; 32], 1, b"bench").expect("derive");
    let message = [0x42u8; 32];
    let mut tag = [0u8; 8];
    let start = Instant::now();
    for i in 0..200_000u32 {
        key.tag(&[black_box(&message), &i.to_le_bytes()], &mut tag).expect("tag");
        black_box(&tag);
    }
    println!("{:.6} {:.9}", pad, start.elapsed().as_secs_f64() / 200_000.0);
}
EOF
  (cd "$work/bench-$side" && limit 600 cargo build --quiet --release < /dev/null > "$work/bench-$side.log" 2>&1) || code=1
done
if [ "$code" -eq 0 ]; then
  for i in 1 2 3; do
    for side in base head; do "$work/bench-$side/target/release/padbench" < /dev/null >> "$work/$side.times"; done
  done
  ratio="$(python3 - "$work/base.times" "$work/head.times" <<'EOF'
import sys
base = [l.split() for l in open(sys.argv[1])]
head = [l.split() for l in open(sys.argv[2])]
pad = min(float(r[0]) for r in head) / min(float(r[0]) for r in base)
mac = min(float(r[1]) for r in head) / min(float(r[1]) for r in base)
print(f"{pad:.3f} {mac:.3f}")
EOF
)"
  python3 -c "import sys; p, m = map(float, '$ratio'.split()); sys.exit(0 if p <= 1.15 and m <= 1.10 else 1)" || code=1
fi
step 6 "stream pad at most 1.15x and MacKey::tag at most 1.10x the claim commit" "$code" "pad, MAC ratios ${ratio:-none}"

# 7. AC-7: wire bytes unchanged: the fixture checks pass and fixtures/ is untouched since the claim.
code=0
bash fixtures/frame/check-vectors.test.sh > "$work/fxv.log" 2>&1 < /dev/null || code=1
bash fixtures/crypto/check-vectors.test.sh > "$work/cxv.log" 2>&1 < /dev/null || code=1
git diff --quiet "$claim" -- fixtures || code=1
step 7 "frame and crypto fixture checks pass; fixtures/ unchanged since $claim" "$code"

# 8. AC-5.3, AC-8: pins, gotcha line, Rust description and module layout name the change.
code=0
grep -q '^session 18916 1504$' rust/embedded/limits-m33f.txt || code=1
grep -q '^frame 20404 1728$' rust/embedded/limits-m33f.txt || code=1
grep -q 'session 18,916 / 1,504, frame 20,404 / 1,728; loop 73, AZ-3275' _docs/AGENT_GOTCHAS.md || code=1
grep -q '^- \*\*Key wipes\*\* (loop 73, AZ-3275' _docs/02_document/components/04_rust_package/description.md || code=1
grep -q 'L73-1' _docs/02_document/components/04_rust_package/description.md || code=1
grep -q '`wipe.rs`, the one volatile wipe' _docs/02_document/module-layout.md || code=1
step 8 "M33F pins, gotcha line, Rust description and module layout updated" "$code"

# 9. No touched source or test file is over 500 lines.
code=0
long=""
for f in $(git diff --name-only "$claim" HEAD -- rust/src); do
  [ -f "$f" ] || continue
  n="$(wc -l < "$f")"
  [ "$n" -le 500 ] || long="$long $f:$n"
done
[ -z "$long" ] || code=1
step 9 "no touched Rust source file is over 500 lines" "$code" "$long"

echo "smoke73: $fails failed"
[ "$fails" -eq 0 ]
