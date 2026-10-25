# Traceability matrix — loop 69 (AZ-3200 to AZ-3204)

| AC | Behavior | Status | Test IDs |
|----|----------|--------|----------|
| AZ-3200 AC-1 | every byte of frame mode is determined by the contract | Covered | FT-X-157 (E1 to E5 recomputed by `independent_check.py`, written from the contract text) |
| AZ-3200 AC-2 | E1 to E5 follow from the contract | Covered | FT-X-157; 5 of 5 match |
| AZ-3200 AC-3 | stream mode unchanged | Covered | contract diff (stream text kept); default Rust suite 831 passed; session tests 13 and 22 passed |
| AZ-3200 AC-4 | scope recorded (ADR-008, R-08 exception) | Covered | ADR-008, `restrictions.md`, `problem.md`, `acceptance_criteria.md`, `architecture.md` |
| AZ-3200 AC-5 | open order and refusals | Covered | FT-X-158 (replay before MAC, no plaintext before the tag, window untouched on failure) |
| AZ-3200 AC-6 | uniqueness rule in bold | Covered | README "Frame session", contract, rustdoc of `seal_frame` |
| AZ-3201 AC-1 | Rust rows match | Covered | FT-X-156 (`crypto_vectors_tests`, 5 passed) |
| AZ-3201 AC-2 | tests not vacuous | Covered | FT-X-156 (`check-vectors.test.sh` 7 PASS; Rust one-byte-flip test) |
| AZ-3201 AC-3, AC-4 | published rows; pure-Python ChaCha20 | Covered | FT-X-156 (`check_vectors.py`: 27 rows) |
| AZ-3202 AC-1 | every row reproduces, coverage complete | Covered | FT-X-157 (`check_vectors.py`: 170 rows) |
| AZ-3202 AC-2 | independent recomputation | Covered | FT-X-157 (`independent_check.py`: 8 rows) |
| AZ-3202 AC-3 | check not vacuous | Covered | FT-X-157 (`check-vectors.test.sh`: body, tag, result, results corrupted) |
| AZ-3202 AC-4 | generator deterministic | Covered | FT-X-157 (two runs identical, equal to the committed file) |
| AZ-3203 AC-1 | vectors in both feature sets | Covered | FT-X-157 |
| AZ-3203 AC-2 | tampering gives no plaintext | Covered | FT-X-158 |
| AZ-3203 AC-3 | replay before crypto | Covered | FT-X-158 |
| AZ-3203 AC-4 | previous slot | Covered | FT-X-158 |
| AZ-3203 AC-5 | MAC-only | Covered | FT-X-157, FT-X-158 (`MacKey` 68 B) |
| AZ-3203 AC-6 | cost per message | Covered | FT-X-158 (counters: at most 4 blocks, 6 compressions) |
| AZ-3203 AC-7 | stream unchanged | Covered | default suite, session tests; ring in step 11 |
| AZ-3203 AC-8 | refusals and hostile input | Covered | FT-X-159 |
| AZ-3203 AC-9 | sizes | Covered | FT-X-159 (16 B, 68 B, 588 B frame-only) |
| AZ-3204 AC-1 | device image | Covered | FT-X-160 (19,772 B, 1,896 B; round trip and verify on the device) |
| AZ-3204 AC-2 | feature switch | Covered | FT-X-160 (four sets identical; `stream_hits`) |
| AZ-3204 AC-3 | docs record it | Covered | README example (runs as a doc test), component description, embedded README |
| Assessment69 D1 | open with `ad` of 256 bytes is `TooLong` | Covered | contract, fixture row `refuse.open.ad256`, `frame_hostile_tests` |
| Assessment69 R1 | CI flash of the `frame` set may exceed the Mac figure by 2 to 4% | Open | read the CI figure after the push |
