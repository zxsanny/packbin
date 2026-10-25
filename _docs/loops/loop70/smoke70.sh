#!/usr/bin/env bash
# Loop 70 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop70/smoke70.sh
# Needs Docker with the packbin-embedded image and a host rustup with toolchain 1.98 and the targets
# thumbv7em-none-eabihf and thumbv8m.main-none-eabihf; about 1 minute with a warm cache.
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
}
# size <log> <row> <set> prints "flash stack" of a SIZE line inside a row.
size() {
  awk -v row="$2" -v set="$3" '/^=== rust-/ { cur = $2; sub(":", "", cur) }
    cur == row && $1 == "SIZE" && $2 == set { for (i = 1; i <= NF; i++) { if ($i ~ /^flash=/) { f = $i; sub("flash=", "", f) } if ($i ~ /^stack=/) { s = $i; sub("stack=", "", s) } } print f, s; exit }' "$1"
}

# 1. AZ-3231 AC-1, AC-2, AC-3, AC-4: the libraries for both targets (CI toolchain) and the stage with its three rows.
code=0
rm -rf rust/embedded/build rust/embedded/build-m33f
RUSTUP_TOOLCHAIN=1.98 bash rust/embedded/run.sh libs > "$work/libs.log" 2>&1 < /dev/null || code=1
[ -f rust/embedded/build-m33f/frame/thumbv8m.main-none-eabihf/release/libpackbin_probe.a ] || code=1
mkdir -p test-results
docker compose -f docker-compose.test.yml run --rm rust-embedded > "$work/stage.log" 2>&1 < /dev/null || code=1
grep -q 'rust embedded stage: 0 target(s) failed' "$work/stage.log" || code=1
for r in rust-m4f rust-m33f rust-mutants; do grep -q "^=== $r: PASS" "$work/stage.log" || code=1; done
[ "$(grep -c '^GOLDEN_OK 1' "$work/stage.log")" -ge 10 ] || code=1
step 1 "libraries for both targets; rust-m4f, rust-m33f, rust-mutants PASS; golden decoded by 10 images" "$code" "$(tail -n 2 "$work/stage.log" | cut -c1-200)"

# 2. AZ-3231 AC-5: every set on the M33F image equals its pin and is under 65,536 B / 8,192 B.
code=0
for set in base text ecc session frame; do
  got="$(size "$work/stage.log" rust-m33f "$set")"
  pin="$(awk -v s="$set" '$1 == s && $1 !~ /^#/ { print $2, $3 }' rust/embedded/limits-m33f.txt)"
  set -- $got
  { [ -n "$got" ] && [ "$got" = "$pin" ] && [ "$1" -le 65536 ] && [ "$2" -le 8192 ]; } || { code=1; echo "$set: got '$got' pin '$pin'" >> "$work/pins.log"; }
done
step 2 "five M33F sets equal their pins and are under 64 KB / 8 KB" "$code" "$(cat "$work/pins.log" 2>/dev/null)"

# 3. AZ-3231 AC-6: a pin one byte low fails the row.
code=0
sed 's/^frame 20236 /frame 20235 /' rust/embedded/limits-m33f.txt > test-results/limits-low.txt
docker compose -f docker-compose.test.yml run --rm -e PACKBIN_RUST_EMBEDDED_LIMITS_M33F=/test-results/limits-low.txt rust-embedded > "$work/low.log" 2>&1 < /dev/null
grep -q 'FAIL frame: flash 20236 B over 20235 B' "$work/low.log" || code=1
grep -q 'rust embedded stage: 1 target(s) failed' "$work/low.log" || code=1
rm -f test-results/limits-low.txt
step 3 "a frame pin of 20235 B fails the row naming the figure" "$code" "$(grep 'FAIL frame' "$work/low.log" | head -n 1 | cut -c1-200)"

# 4. AZ-3231 AC-7: the M4F row is as before.
code=0
want="base 15060 456 text 27156 2736 ecc 18692 744 session 18812 1528 frame 20164 1752"
got=""
for set in base text ecc session frame; do got="$got $set $(size "$work/stage.log" rust-m4f "$set")"; done
[ "${got# }" = "$want" ] || code=1
git diff --quiet 31b233b -- rust/embedded/limits.txt || code=1
step 4 "M4F figures (Rust 1.98.1) and limits.txt unchanged" "$code" "got:${got}"

# 5. AZ-3231 AC-8, AC-10: harness self-tests, CI installs both targets, source untouched.
code=0
bash rust/embedded/checks.test.sh > "$work/checks.log" 2>&1 < /dev/null || code=1
bash cpp/embedded/run-parts.test.sh > "$work/parts.log" 2>&1 < /dev/null || code=1
grep -q 'rustup target add thumbv7em-none-eabihf thumbv8m.main-none-eabihf' .github/workflows/test.yml || code=1
[ -z "$(git diff --name-only 31b233b -- rust/src cpp/src/core cpp/include)" ] || code=1
step 5 "checks.test.sh, run-parts.test.sh pass; test.yml installs both targets; rust/src, cpp core untouched" "$code" "$(tail -n 1 "$work/checks.log")"

echo "smoke70: $fails failed"
[ "$fails" -eq 0 ]
