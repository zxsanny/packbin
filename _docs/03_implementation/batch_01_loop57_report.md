# Batch 01 report — loop 57

Tasks: AZ-3151 (flash search), AZ-3152 (held-when fold retry), AZ-3153 (corpus guards), AZ-3154 (flash pin). Two workers: C++ (AZ-3151, AZ-3152, AZ-3154), loaders (AZ-3153). Review: one total review at the end of the loop (owner rule). Commits: c3bc899 (C++), 98670c3 (loaders). CI-parity: PASS (host `make -C cpp test`, `gcc:16 make test`, arm embedded stage exit 0; Go `golang:1.27` gofmt, vet, `-race`; Rust `cargo test` and the nostd features run; Swift 422 tests); the full CI mirror is the one step 11 run.

## Results

| Task | Status | Evidence |
|------|--------|----------|
| AZ-3151 | Done | `keys_ascending` inline byte loop replaces `memcmp` (92 B in the image, loop 20 B): flash 8,080 B to 8,008 B (72 B saved), stack unchanged |
| AZ-3152 | Done, kept | `held_of` (NOINLINE) decides When / FlagBit for both walkers; flash 8,032 B (+24 B over AZ-3151, 48 B under the 8,080 B limit); stack net: deepest 504, flag chain unpack 476 / pack 384, plain 288 / 348, round 432 / 436. Try A (`unpack_range`) 7,976 B flash but 580 B flag chain: restored |
| AZ-3153 | Done | broken-copy proofs for AC-6 (unused unpack and limit handler named), AC-7 (run to skip and skip to run named), AC-8 (34-line corpus passes; malformed line fails Swift), AC-9 (one Go helper, old messages) |
| AZ-3154 | Done | `flash_pin=8032`; a copy with pin 8,031 B fails: `flash 8032 B measured is over the pin of 8031 B`; real stage PASS `8032 B of 8192 (pin 8032 B)` |

Margins after the batch: flash 160 B (8,032 B of 8,192 B); stack net 504 B deepest, margin 8 B unchanged; avr-uno 15,532 B (was 15,608 B); NO_TEXT probe pack 384 B, unpack 328 B (was 336 B).

## Discovered during implementation

| Spec ref | Discovery | Proposed handling | clear / unclear |
|----------|-----------|-------------------|-----------------|
| AZ-3152 AC-3 | The fold kept is one decision function (`held_of`), not one function that walks the children; `unpack_children` still has its loop and `unpack_one` its case | accepted by the AC wording only if "one function" means the handling decision; feature-assess decides | unclear |
| AZ-3152 | A function with 4 or more real arguments cannot be tail-called from `unpack_one` (sret pushes the last argument to the stack): helpers keep 3 arguments (`w, i, obj`) | gotcha line | clear |
| AZ-3151 | The probe table is about 524 B (14 entries of 36 B); dropping `item` and `count` from `Field` would save about 8 B per entry | candidate, not a spec (`Field` layout change) | clear |
| AZ-3153 | The Rust nostd count check shares the loader's line filter, so it guards the literal, not a parse drop; Swift's check catches a dropped line | accepted | clear |
| AZ-3153 | Fixtures alone cannot move a nostd case between run and skip; AC-7 was shown by editing the copy's `nostd_support/hostile.rs` | accepted | clear |

## Commands

C++ worker: `make -C cpp test` host (after `make -C cpp clean`), `gcc:16 make test`, `docker compose -f docker-compose.test.yml run --rm cpp-embedded` exit 0 (m0plus, m3-qemu 287 of 287, m4f, s390x 287 of 287, avr-uno PASS). Loader worker: Go container ok (73.5 s), Rust lib 542 passed and doc-tests 3, nostd hostile 6 + hostile pack 3, Swift 422 tests in 72 suites.
