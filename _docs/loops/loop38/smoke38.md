# Loop 38 smoke — checks

LOCAL_URL: none (a library; the proof is the test stages and CI)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close
- [x] 2. Step 11 stages at HEAD: none failed
- [x] 3. EC-5 end to end in Python: two wrong bytes with 4 parity bytes are repaired, a detect-only unpack refuses them
- [x] 4. EC-2, EC-6, EC-7, EC-15: reference vectors, contract table and the seeded bounds
- [x] 5. No source file this loop touched is over 500 lines
- [x] 6. Nothing is released

## Result

Agent run 2026-10-18 at `64db597` (owner rule 2026-10-12 in `deployment_procedures.md`): **6/6 steps passed**. Step 2 ran every stage at HEAD: 13 passed, 0 skipped, 0 failed, 1,264 s; typescript and go passed only on the serial retry (the first failure of each was a wall-clock check that ran beside other suites: `round-scope-cost` 2.4x against a 2x bound). The step 11 run before the commit (on the working tree at `9da878f`, 1,134 s) had found one real failure, the Swift README snippet test (the new README Swift block was not a registered snippet); it is fixed in `64db597`. Not run locally: the ESP32-S3, ESP32-C3, Pico and Arduino builds with ECC on (no image or toolchain here; the probe compiles on the host and for Cortex-M3), the vcpkg supports and consumer checks, and the `test.yml` median over two CI runs (AC-3 of AZ-2689).

## For the operator

- `main` was not pushed and no tag exists. The first `v*` tag, F44 and the `go/v*` tag are yours.
- `/feature-assess`, `/security` (AZ-2666, which now also covers the ECC decoders; notes in `_docs/05_security/ecc_decoder_notes_loop38.md`) and the retrospective for loops 35 to 38 are yours to run.
- Real messages (D5) still wait for your 100 to 200 messages; the ECC format does not depend on them.

## Script (`bash smoke38.sh`)

```bash
#!/usr/bin/env bash
# Loop 38 smoke (message error correction, AZ-2677): smoke38.sh. One line per step: [n/N] title, then
# PASS (Ns) <result> or FAIL with the reason. No network.
set -uo pipefail
repo=/Users/zxsanny/dev/zxsanny/packbin
cd "$repo" || exit 1
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
N=6 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; [ -f "$work/out.log" ] && tail -n 12 "$work/out.log" | sed 's/^/    | /'; }

step "No application source is dirty at the close"
if [ -z "$(git status --porcelain)" ]; then ok "tree clean at $(git rev-parse --short HEAD)"; else ko "dirty: $(git status --porcelain | head -3 | tr '\n' ' ')"; fi

step "Step 11 stages at HEAD (scripts/loop-tests.sh): none failed"
if PATH="/opt/homebrew/bin:$PATH" PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path)" scripts/loop-tests.sh < /dev/null > "$work/out.log" 2>&1; then ok "$(grep '^RESULT' "$work/out.log" | tail -1)"; else ko "loop-tests.sh failed"; fi

step "EC-5 end to end in Python: two wrong bytes with 4 parity bytes are repaired, a detect-only unpack refuses them"
cat > "$work/ecc.py" <<'PY'
from packbin import BinaryPacker, Scheme, u16
class Reading:
    def __init__(self): self.level = 0
reading = Scheme(2, Reading, u16(0, lambda row: row.level)).with_limits(parity=4)
row = Reading(); row.level = 7
raw = bytearray(BinaryPacker.pack(reading, row))
raw[1] ^= 0x55; raw[4] ^= 0x0F
got = []
fixed = BinaryPacker.unpack(bytes(raw), reading.on(got.append), limit=2)
plain = BinaryPacker.unpack(bytes(raw), reading.on(lambda r: None))
print(len(raw), fixed.ok, fixed.repaired, got[0].level, plain.ok, type(plain.error).__name__)
PY
if PYTHONPATH=python/src python/.venv/bin/python "$work/ecc.py" < /dev/null > "$work/out.log" 2>&1 && [ "$(cat "$work/out.log")" = "7 True 2 7 False Uncorrectable" ]; then ok "$(cat "$work/out.log")"; else ko "the Python example gave something else"; fi

step "EC-2, EC-6, EC-7, EC-15: reference vectors, contract table and the seeded bounds"
if fixtures/ecc/check-vectors.test.sh < /dev/null > "$work/out.log" 2>&1 && fixtures/ecc/check-contract.sh < /dev/null >> "$work/out.log" 2>&1 && python3 -I scripts/ecc/fuzz_reference.py < /dev/null >> "$work/out.log" 2>&1; then ok "$(grep -c PASS "$work/out.log") checks passed; $(grep 'EC-7' "$work/out.log")"; else ko "a reference check failed"; fi

step "No source file this loop touched is over 500 lines"
long="$(git diff --name-only d86553f HEAD | grep -vE '^_docs/|\.md$|vectors\.txt|ring-cases\.txt' | while read -r f; do [ -f "$f" ] && wc -l < "$f" | awk -v f="$f" '$1 > 500 {print $1, f}'; done)"
if [ -z "$long" ]; then ok "none over 500 lines"; else ko "$long"; fi

step "Nothing is released: no tag holds HEAD, main is not pushed"
if [ -z "$(git tag --contains HEAD)" ] && ! git merge-base --is-ancestor HEAD origin/main 2>/dev/null; then ok "no tag, main not pushed"; else ko "a tag holds HEAD, or main holds HEAD"; fi

printf '%d/%d steps passed\n' "$passed" "$N"
[ "$passed" -eq "$N" ]
```
