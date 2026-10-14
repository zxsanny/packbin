# loop 26 notes: what is not proven yet (for the loop 27 handoff)

Written at steps 12 and 13 (2026-10-14). Everything below passed nowhere yet, or only on the owner's Mac. Proven at step 11 and not repeated here: the Swift suite (335 tests in 55 suites) on the Mac, the `swift` stage in the `swift:6.3.3` container (620 s), the ring with the Go-Swift hand-offs, the scaffold stage, the full publish gate (1837 s; vcpkg checks NOT RUN, no vcpkg tool). Rows: `_docs/02_document/tests/blackbox-tests-19-loop26-swift-package.md` (FT-X-151 to FT-X-155, O1 to O3) and `tests/traceability-matrix-loops-24-26.md`.

## First CI run (the `dev` push)

- The `swift` service on the Ubuntu runner, including the Linux swift-crypto 4.3.1 session path there (it ran in the container on the Mac only).
- The ring job's Swift: `RING_SWIFT` is 6.3.3 and `ring-toolchains.sh` compares it exactly with the runner's Swift; the Swift version of `ubuntu-latest` is unknown (if it has none, `ring-swift.sh` builds in the `swift:6.3.3` image, a cold build of swift-crypto).
- The thread sanitizer under Docker on `ubuntu-latest` (ASLR; it may need `vm.mmap_rnd_bits=28`, review26 #3).
- Scaffold job time: the `swift` stage took 620 s and the publish gate test 1837 s on the Mac; the job's limit is 60 minutes.
- Loop 24's first CI run failed on a container detail the Mac could not show (Go as root on a runner-owned checkout, `notes24.md`); the Swift container and drivers have no runner run yet.

## Toolchain and consumers

- Swift 6.0, the declared minimum (owner decision 2026-10-14), was not run; only 6.3.3 (Mac and image).
- `Package.resolved` pins swift-asn1 1.7.3, which needs a Swift 6.1 toolchain: building this repository on Xcode 16.0 (Swift 6.0) is unproven.
- A consumer resolving the package on Swift 6.0 (review26 #4).
- tvOS, watchOS (`PackSession` is `@available(tvOS 14, watchOS 7, *)`), Android, Windows, WASI: not built.

## Not measured

- Peak memory of the max-slots unpack (the F10 packet and the default-limit wide round; Go: 625 MB and 94 MB) — review26 #5.
- `ChaCha20.fill` allocates two arrays per 64-byte block — review26 #6.

## Owner decisions (assessment26)

- O1: a flat key beside a given group or nested row is not read (Swift and Go); A keep / B refuse.
- O2: U11 with a shared name and the nested row not given: Swift packs `010000`, Go refuses; A keep Swift / B align to Go.
- O3: `PackSession.start(_ nonce:)` is public (review26 #7); A keep with the warning / B make it SPI.
- F44 (the tag ruleset on `v*` and `go/v*`) and the first tags (the first `vX.Y.Z` with Swift, the first `go/vX.Y.Z`): owner only. The live consumer resolve of `https://github.com/zxsanny/packbin` in `publish.yml` runs only on the first tag.

## File sizes at the cap

- `.github/workflows/ring-wiring.test.sh` is 500 lines; `language-pair.sh` is 494 (batch 7 recorded 500 when the Swift lines went in). The next language needs a table-driven ring or a split.
- `_docs/02_document/tests/traceability-matrix.md` was 529 lines; the rows of loops 24 to 26 moved to `traceability-matrix-loops-24-26.md` in this step.
