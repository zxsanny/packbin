# Loop 70 smoke — checks

LOCAL_URL: none (a build target of the Rust embedded stage under QEMU; nothing to open)
Branch: dev
Script: `smoke70.sh` in this folder (`bash _docs/loops/loop70/smoke70.sh`, about 20 s with warm caches; needs Docker with the `packbin-embedded` image and rustup toolchain 1.98 with both targets).

## Checks

- [x] 1. AZ-3231 AC-1 to AC-4: libraries for both targets (CI toolchain); `rust-m4f`, `rust-m33f`, `rust-mutants` PASS; the golden fixture decodes on 10 images
- [x] 2. AZ-3231 AC-5: the five M33F sets equal their pins and are under 64 KB of flash and 8 KB of stack
- [x] 3. AZ-3231 AC-6: a frame pin one byte low (20235 B) fails the row naming the figure
- [x] 4. AZ-3231 AC-7: the M4F figures (Rust 1.98.1) and `limits.txt` are unchanged
- [x] 5. AZ-3231 AC-8, AC-10: `checks.test.sh` and `run-parts.test.sh` pass; `test.yml` installs both targets; `rust/src`, `cpp/src/core`, `cpp/include` untouched

## Result

Agent run 2026-10-25 at `cd44868` (owner rule 2026-10-12): **5/5 steps passed**, after step 11 (first run at `7e4fe18`: rust, scaffold, ring, publish-gate passed, `rust-embedded` failed on the toolchain; fixed in `cd44868`, rerun of rust, rust-embedded, ring passed).

## Agent walk

No browser (no UI).

## For the operator

- CI of the push: read the `embedded-arm` job and its `rust-m33f` figures against `limits-m33f.txt` (pins equal the Rust 1.98.1 figures; a CI figure above a pin is a named blocker, not a raised pin).
- Real nRF54L15 (non-secure 128 KiB image, cycle counts) is not covered by QEMU.
