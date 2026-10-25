# Loop 69 smoke — checks

LOCAL_URL: none (frame mode of the Rust package, fixtures and the device image under QEMU; nothing to open)
Branch: dev
Script: `smoke69.sh` in this folder (`bash _docs/loops/loop69/smoke69.sh`, about 5 minutes cold, a few seconds with warm Docker and cargo caches).

## Checks

- [x] 1. AZ-3201 AC-2 to AC-4, AZ-3202 AC-1 to AC-4: the crypto and frame vector checks pass, the generator is deterministic, corrupted copies fail
- [x] 2. AZ-3203 AC-1 to AC-9, AZ-3204 AC-3: the Rust frame tests pass in the CI toolchain (fixture without and with std, crate tests, doc example, primitive vectors)
- [x] 3. AZ-3203 AC-7: the stream session tests pass (nostd without and with std, std)
- [x] 4. AZ-3204 AC-1, AC-2: the embedded stage passes; `frame` 19,772 B flash and 1,896 B stack; base, text, ecc and session unchanged
- [x] 5. AZ-3200 AC-3, AC-4, AC-6: contract 2.0.0, ADR-008 indexed, R-08 exception, the uniqueness rule in the README
- [x] 6. AZ-3200 AC-3: every 1.0.0 line of the stream contract is still there

## Result

Agent run 2026-10-25 at `9d97fe2` plus the uncommitted close documents (owner rule 2026-10-12): **6/6 steps passed**, after step 11 (10 passed, 4 skipped as unchanged, 0 failed, 834 s).

## Agent walk

No browser (no UI). The first run of step 6 failed on a line of the contract that this loop changed on purpose (the consumer list); the script now skips that line and the second run passed 6/6.

## For the operator

- CI of the push: read the `embedded-arm` job and its `rust-embedded` figures first (the CI runner reported 2 to 4% more flash than this Mac in loop 68: the `frame` set is 19,772 B here against the bound of 20,480 B).
- Real nRF52840 (cycle counts, memory map) is not covered by QEMU.
