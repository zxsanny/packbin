# Feature assessment — loop 26 (Swift package, AZ-2223)

FEATURE ASSESSMENT loop 26 round 1: CLARIFY — 12 covered / 0 out-of-scope / 0 gap-clear / 3 gap-unclear

Inputs read: `swift-package/scenarios.md` (S1 to S12), `problem.md`, `acceptance_criteria.md` (SW-1 to SW-16), batch reports 1 to 10 (discoveries tables), `implementation_completeness_loop26_report.md`, `review26.md`, `parity_differences.md`. Per owner preference (one assessment round per loop, no chained rounds) the open rows go to the loop 27 handoff instead of an immediate `new-task --clarify`.

## Coverage matrix

| id | scenario | status | AC | test | production code |
|----|----------|--------|----|------|-----------------|
| S1 | an app packs a row, any ring language unpacks it | covered | AZ-2522 AC-1, SW-7 | the 136 hand-off lines of `language-pair.sh`; 114 hand-offs + 3 refusals run against six languages (the 22 Go hand-offs run at step 11) | `swift/Sources/Packbin/Pack.swift`, `Unpack.swift`, `drivers/handoff-swift` |
| S2 | hostile or truncated packet | covered | AZ-2513 AC-3, AZ-2519 AC-1, SW-4 | `ShortTrailingTests`, `HostileTests` (65 cases), `FuzzTests` | `Reader.take` and the checked reads in `Unpack*.swift`, `Collection*.swift` |
| S3 | many tasks, one scheme | covered | AZ-2513 AC-6, SW-14 | `ConcurrencyTests` (8 x 10 000, thread sanitizer) | immutable `Scheme`/`Node` |
| S4 | pack fails halfway | covered | AZ-2513 AC-5, SW-15 | `InvalidValueTests` | `Packer` (no partial output) |
| S5 | wrong value type or missing key | covered | AZ-2513 AC-5 | `InvalidValueTests`, `NoTrapTests` | `Values.swift`, `Place.swift` |
| S6 | limits and one past | covered | AZ-2517 AC-1, SW-5 | `LimitEdgeTests`, `RoundLimitTests`, `PackBudgetTests` | `Limits.swift` |
| S7 | packets from v0.2.2 of the other packages | covered | AZ-2522 AC-1 | ring payloads, `CollectionReadmeTests`, golden | the whole walker |
| S8 | typed struct and `[String: Any]` give the same bytes | covered | AZ-2516 AC-3, AC-5, SW-12 | `NestedRowTests`, `CollectionNoValueTests`, `GoldenTests` | `Bind.swift`, `Place.swift` |
| S9 | a bad version was tagged | covered | AZ-2523 AC-3, SW-16 | `publish-swift.test.sh` (moved tag fails at once, refs unchanged) | `publish-swift.sh` |
| S10 | the publish re-runs for the same tag | covered | AZ-2523 AC-3 | `publish-swift.test.sh` (re-run on the same commit passes; real `swift package resolve`) | `publish-swift.sh` |
| S11 | a new app adds the package | covered | AZ-2523 AC-2, AZ-2518 AC-5, SW-10, SW-11 | real consumer resolve + build against a tagged local bare repo; `DependencyTests` | `Package.swift`, `publish-swift.sh` |
| S12 | two clients, same seed, different values | covered | AZ-2518 AC-2, SW-6 | `SessionTests` (C# ciphertext `b55d0a29...`), `ChaCha20Tests` (RFC 8439) | `PackSession.swift`, `ChaCha20.swift` |

## Gaps

| id | status | plain-language question | options | source |
|----|--------|-------------------------|---------|--------|
| O1 | gap-unclear | A flat key placed beside a group (or nested row) that is given is not read by Swift or Go (`{g:{a:1}, b:2}` is refused "missing b", or ignored where the member is not needed: `{k:0,c:3,g:{mode:0}}` packs `0100010000`), where TypeScript reads the flat key. Keep that? | A keep (extends the decided Go-4 A; Go behaves the same) · B refuse an unread flat key in Swift and Go | batch 8, `ParityProbeTests` |
| O2 | gap-unclear | With a name shared by the outer row and a nested row that is not given (`{k:0,c:3}`), Swift packs `010000`, Go refuses with U11, TypeScript cannot build the scheme. Which wins? | A keep Swift and document · B align Swift to Go (refuse) | batch 8 |
| O3 | gap-unclear | `PackSession.start(_ nonce:)` is public: an app that passes a repeated value reuses the key stream (no tag). Go has `StartWith`, documented "for tests". Hide it (SPI) in Swift? | A keep public with the warning (as Go) · B make it SPI | `review26.md` #7 |

Not intent gaps, carried to the handoff as risks proven only by the first CI run: the Linux swift-crypto path, `swift:5.9` library build, thread sanitizer under Docker (`vm.mmap_rnd_bits`), Foundation `NSNumber` Bool/integer split on Linux, the 22 Go-Swift ring hand-offs, scaffold job time, a Swift 5.9 consumer resolve, peak memory of the max-slots unpack.

## Not walked

- tvOS and watchOS (not built; `PackSession` is `@available(tvOS 14, watchOS 7, *)`).
- Android, Windows and WASI link `swift-crypto` by the manifest's condition; none is built or tested.
- An Apple-platform CI job (out of scope in `problem.md`).
