# Total review — loop 26 (Swift package, `b81102f..HEAD`)

One total review at high effort, before step 11, over 175 files / 17.9 k lines (3.8 k lines of Swift source read in full for the unpack, session, cipher, limits, pack and value paths; the new shell, workflow and compose changes read; tests sampled through their mutation proofs). Verdict: **PASS_WITH_WARNINGS** — 0 Critical, 0 High, 3 Medium, 5 Low; 2 fixed, 6 skipped (carried to the loop 27 handoff).

| # | Severity | Category | Finding | Outcome |
|---|----------|----------|---------|---------|
| 1 | Medium | correctness | `swift` (6) and `swift-min` (5.9) shared one SwiftPM cache volume while `loop-tests.sh` runs both in parallel | fixed: `swiftpm-cache` and `swiftpm-cache-min` (`docker-compose.test.yml`) |
| 2 | Medium | correctness | `publish.yml` `timeout-minutes: 60` can be exceeded by the 30 min Go proxy window plus the 30 min Swift window | fixed: 120 |
| 3 | Medium | correctness | scaffold job: thread sanitizer in Docker on `ubuntu-latest` may need `vm.mmap_rnd_bits=28`; nine suites inside 60 min | skipped: unproven until the first CI run; loop 27 handoff |
| 4 | Medium | test-coverage | the release consumer check resolves with the runner's Swift only; a Swift 5.9 consumer (swift-asn1 1.7.3 needs tools 6.1) is never exercised | skipped: handoff |
| 5 | Low | test-coverage | no peak-memory figure for the max-slots unpack in Swift (Go measured 625 MB, D8) | skipped: handoff (measure F10 and the wide round) |
| 6 | Low | efficiency | `ChaCha20.fill` allocates two arrays per 64-byte block | skipped: handoff |
| 7 | Low | altitude | public `PackSession.start(_ nonce:)` invites key-stream reuse (Go has `StartWith`, "for tests") | skipped: owner API decision (open decision O3) |
| 8 | Low | docs-accuracy | README names Linux and CI results before any Linux or `swift:5.9` run | skipped: reword after the first CI run |

Read and found sound: every read in `Reader` goes through `take` (size checked against the bytes left, no negative size reaches it: counts below 0 or above `Int.max` are unreadable, byte sizes are checked at construction); `packed` width is 1 or 2 so the mask shift cannot trap; list and dict items must read at least one byte so a count of 65 535 cannot be walked for no input; dict keys are compared by Swift `String` and a normalization duplicate is refused; ChaCha20 uses wrapping arithmetic and refuses data past block 2^32 - 1; the session position 2^64 - 1 is refused; `PackSession` spends positions as TypeScript and C#; no `try!`, `as!`, force unwrap, `fatalError` or `precondition` in `swift/Sources`; the new shell uses `|| true` only on expected-failure `grep -c` and no `2>/dev/null` appears in the diff.
