# Test Specification — Swift package

Added in loop 26 (AZ-2223, AZ-2513 to AZ-2524). Same shape as [the Go tests.md](../07_go_package/tests.md): the project acceptance criteria AC-1 to AC-16 first, then the blackbox, performance, security and acceptance tests, then the Swift-specific criteria SW-1 to SW-16. Scenario ids FT-X-124 to FT-X-155 are in [blackbox-tests-19](../../tests/blackbox-tests-19-loop26-swift-package.md); the SW rows are in [traceability-matrix-loops-24-26.md](../../tests/traceability-matrix-loops-24-26.md) and the AC to test map for all packages is [traceability-matrix.md](../../tests/traceability-matrix.md). Every test below is a swift-testing `@Test` in `swift/Tests/PackbinTests/*.swift`, named `Suite.function`; it runs with `swift test` at the repository root on the owner's Mac (Swift 6.3.3, the flags of `_docs/AGENT_GOTCHAS.md`) and in the `swift` service of `docker-compose.test.yml` (`swift:6.3.3`). The suite is 335 tests in 55 suites.

## Acceptance Criteria Traceability

| AC ID | Acceptance Criterion | Test IDs | Coverage |
|-------|---------------------|----------|----------|
| AC-1 | Position pack is the 13-byte hex | IT-01, AT-01 | Covered |
| AC-2 | Unpack returns those fields and 0 motion fields | IT-02, AT-01 | Covered |
| AC-3 | This package's bytes match the shared golden hex | IT-03 | Covered (the step 11 ring passed, the Go-Swift hand-offs included) |
| AC-4 | Clear bit adds 0 bytes; flags 0x20 adds 2 | IT-04 | Covered |
| AC-5 | A stored 0 is written | IT-05 | Covered |
| AC-6 | Conditional group adds 0 bytes or its width | IT-06 | Covered |
| AC-7 | Repeat yields one value per group; 1 leftover byte is an error | IT-07 | Covered |
| AC-8 | Short field names field, needed, left, and returns 0 values | IT-08, ST-01 | Covered |
| AC-9 | Trailing bytes are an error and 0 values | IT-09 | Covered |
| AC-10 | 100000 round trips ≤ 1 second on one core | PT-01 | Covered (release build) |
| AC-11 | This package's tests run on every push and pull request | AT-02 | Covered on the Mac and in the `swift:6.3.3` container; first Ubuntu runner run unproven |
| AC-12 | A matching tag publishes this package, with 0 manual uploads | AT-03, ST-02 | Covered hermetically (`publish-swift.test.sh`, a real resolve against a local bare repository); Swift has no upload: a consumer resolve check; no tag pushed |
| AC-13 | The first tag includes this package with the other five | — | History: the first tag predates Swift; Swift adds no package and no tag (ADR-005) |
| AC-14 | A golden mismatch publishes 0 packages, including this one | AT-04 | Covered |
| AC-15 | This package absent from the tagged tree publishes 0 packages | AT-05 | Covered (`absent swift`: no Swift check, the others publish) |
| AC-16 | This published package declares MIT | AT-06 | Covered (root `LICENSE`, `ManifestTests.license_atTheRepositoryRootIsMIT`, `publish-check.py swift-check`) |

## Blackbox Tests

| Test | Traces to | What it proves | Swift tests |
|------|-----------|----------------|-------------|
| IT-01 Position pack | AC-1 | `pack` of type 64, sid 1, latitude 500000000, longitude 300000000, profile 1 gives `4001000065cd1d00a3e1110100`, 13 bytes, mismatched bytes 0, typed and map | `GoldenTests.pack_typedGoldenRow_givesGoldenHexAndUnpacksBack`, `GoldenTests.pack_mapGoldenRow_givesGoldenHexAndUnpacksToFiveFields` |
| IT-02 Position unpack | AC-2 | `unpack` of that hex gives the five fields and 0 motion fields; the typed and the map form agree | `GoldenTests.pack_typedGoldenRow_givesGoldenHexAndUnpacksBack`, `GoldenTests.pack_typedAndMapWithHeading_agree` |
| IT-03 Bytes match the golden hex | AC-3 | the packed bytes equal the shared fixture; the ring hands the same bytes to and from the other seven | `GoldenTests`; ring: `language-pair.sh`, `publish-position.sh swift` |
| IT-04 Flags width | AC-4 | a clear bit adds 0 bytes, a set bit adds the field's width; flags in both forms | `NoValueTests.pack_getterReturnsNilOrZero_clearsOrSetsTheBit`, `ReadmeScalarTests.packAndUnpack_readmeRow_giveReadmeHex`, `FlagFormTests.packAndUnpack_splitByteWithBool_giveTypeScriptHex` |
| IT-05 A stored zero is written | AC-5 | a present 0 sets the bit; `nil` or an absent key does not and adds 0 bytes | `NoValueTests.pack_mapMemberGivenZero_setsTheBitAndWritesZero`, `NoValueTests.pack_mapMemberWithNoValue_leavesTheBitClear` |
| IT-06 Conditional group | AC-6 | a `when` that does not match adds 0 bytes, a match adds the group width | `FlagFormTests.packAndUnpack_whenOnABool_matchesOnlyASetBit`, `EqCheckTests.pack_eqOnABoolOrAnInteger_givesTypeScriptHex`, `ParityFieldsTests.pack_whenGroupWidthAndRepeatOnGroupBoundary_giveTypeScriptLengths` |
| IT-07 Repeat on a group boundary | AC-7 | whole groups unpack one value per group; one leftover byte is an error and 0 values | `ParityFieldsTests.pack_whenGroupWidthAndRepeatOnGroupBoundary_giveTypeScriptLengths`, `ReadmeRoundTests.packAndUnpack_readmeRoundExample_givesTheReadmeHexBothWays`, `RoundTripTests.unpackMap_largeRepeat_keepsOneEntryPerRoundForEveryName` |
| IT-08 Short field | AC-8 | a buffer that ends inside a field throws `.short` naming the field, `needed` and `left`, no row | `ShortTrailingTests.unpack_unreadableBuffer_throwsNamingFieldNeededLeft`, `ParityFieldsTests.unpack_bufferCutShort_namesTheMemberWithNeededAndLeftAndGivesNoRow` |
| IT-09 Trailing bytes | AC-9 | bytes left after the list throw `.trailing` and no row | `ShortTrailingTests.unpack_unreadableBuffer_throwsNamingFieldNeededLeft` (case "one trailing byte") |

## Performance Tests

### PT-01: Position round trips on one core

**Traces to**: AC-10 (SW-8). 100 000 pack-then-unpack round trips of the AC-1 row, typed and as a map, finish in ≤ 1 second in a release build. `SpeedTests.roundTrips_hundredThousandGoldenRows_takeAtMostOneSecond`; `run-suite.sh swift` asserts it in its release step (`swift_speed`), the debug run makes one pass and the thread-sanitizer run does not run it. Worker runs on the Mac in release: 0.37 s typed, 0.19 s map (AZ-2513), 0.40 s and 0.22 s (AZ-2517). The step 11 release speed run in the `swift:6.3.3` container passed.

## Security Tests

### ST-01: A short buffer returns no value

**Traces to**: AC-8. `ShortTrailingTests.unpack_unreadableBuffer_throwsNamingFieldNeededLeft` and `CollectionHostileTests.unpack_countOrLengthPastTheBuffer_throwsShortWithNoRow`: the call throws and returns no row; the error names the field, needed and left. The 65 hostile cases, the random-buffer tests and `FuzzTests` extend this to hostile counts, lengths and rounds with 0 traps (SW-4, SW-5; NFT-SEC-05).

### ST-02: The release check holds no registry token

**Traces to**: AC-12. Swift has no archive, no upload and no tag of its own: `swift-check` records the tag and commit and resolves a throwaway consumer of `https://github.com/zxsanny/packbin` at exactly `X.Y.Z` (ADR-005). `publish-swift.test.sh` runs against a local bare repository with no registry credential.

## Acceptance Tests

| Test | Traces to | Steps and expected result |
|------|-----------|---------------------------|
| AT-01 Caller pack and unpack | AC-1, AC-2 | `pack` the position value: `4001000065cd1d00a3e1110100`; `unpack` that hex: the five fields, 0 motion fields (`ReadmeExampleTests.typedSnippet_printsTheGoldenHexAndUnpacksTheRow`, `ReadmeExampleTests.mapSnippet_printsTheGoldenHexAndTheHeadingRow` print the README hex) |
| AT-02 Tests run on push and pull request | AC-11 | the `scaffold` job checks the Swift files and runs the `swift` service; a failing step fails the job and the `report.csv` row (`run-suite-swift.test.sh`, `run-suite.test.sh`) |
| AT-03 A matching tag is resolvable | AC-12 | a tag with a passing golden check: `swift-check`, the last target, resolves and builds a consumer pinned `exact` to the tag, retrying failures for up to 30 minutes; manual uploads 0 (`publish-swift.test.sh`; live run NOT RUN) |
| AT-04 A golden mismatch publishes nothing | AC-14 | a wrong Swift byte in the position program: the gate prints the mismatch, 0 packages, no Swift check (`publish-swift-gate.test.sh`) |
| AT-05 Absent from the tree publishes nothing for Swift | AC-15 | a tree without `Package.swift` or `swift/`: `absent swift`, no Swift check, the other packages and the Go tag publish |
| AT-06 The package declares MIT | AC-16 | the root `LICENSE` is the MIT text; non-MIT identifiers 0 (`publish-check.py swift-check`, `ManifestTests.license_atTheRepositoryRootIsMIT`). Rollback: the next patch version; a tag is never moved or deleted |

## Swift criteria SW-1 to SW-16 (loop 26)

Each criterion, its tests and the scenario that carries it (FT-X ids in [blackbox-tests-19](../../tests/blackbox-tests-19-loop26-swift-package.md)).

| SW | Tests | Scenario |
|----|-------|----------|
| SW-1 golden bytes | `GoldenTests` | FT-X-124 |
| SW-2 data types, short and trailing | `ReadmeScalarTests`, `ReadmeRoundTests`, `CollectionReadmeTests`, `ShortTrailingTests` | FT-X-125 |
| SW-3 TypeScript parity rows | `ParityLoop20Tests`, `ParityFlagsWhenTests`, `ParityFieldsTests`, `ParityReferenceTests`, `ParityBigintTests`, `ParityProbeTests`, `U11Tests`, `SchemeCheckTests`, `ConstructionTests`, `EqCheckTests`, `RoundValueTests`, `SplitRoundTests` | FT-X-126, FT-X-127 |
| SW-4 65 hostile cases | `HostileTests` (10 unpack, 2 limit, 15 construct, 38 pack, wrong-rule self-tests), `NoTrapTests`, `RoundNoTrapTests`, `fixtures/hostile/check-cases.sh` | FT-X-128 |
| SW-5 round limits, fuzz | `LimitSurfaceTests`, `RoundLimitTests`, `LimitEdgeTests`, `PackRoundCapTests`, `PackBudgetTests`, `SlotWidthTests`, `FuzzTests` (60 s in `run-suite.sh swift`) | FT-X-129 |
| SW-6 session (retired in loop 74, ADR 009), RFC 8439 | `ChaCha20Tests` (`SessionTests` and `SessionHostileTests` deleted in loop 74) | FT-X-130 (session part retired) |
| SW-7 ring | `language-pair.sh` Swift lines, `ring-wiring-swift.test.sh` | FT-X-131 |
| SW-8 speed | `SpeedTests` | FT-X-132 |
| SW-9 CI suite | `run-suite-swift.test.sh`, `run-suite.test.sh`, `report-row.test.sh`, the `swift` compose service | FT-X-133 |
| SW-10 release | `publish-swift.test.sh`, `publish-swift-gate.test.sh`, `publish-gate.test.sh`, `publish-check.py swift-check`, `ManifestTests` | FT-X-134 |
| SW-11 dependencies | `DependencyTests`, `ManifestTests.manifest_hasNoUnsafeFlagOrCTarget`, `run-suite.sh` `swift_deps` | FT-X-135 |
| SW-12 no value | `NoValueTests`, `U11Tests`, `CollectionNoValueTests`, `NestedRowTests`, `GroupRefusalTests`, `DictKeyTests` | FT-X-136 |
| SW-13 README | `ReadmeExampleTests` | FT-X-137 |
| SW-14 concurrency | `ConcurrencyTests` (thread-sanitizer run) | FT-X-138 |
| SW-15 invalid Swift values | `InvalidValueTests`, `NoTrapTests`, `NoValueTests` | FT-X-139 |
| SW-16 tags never move | `publish-swift.test.sh` | FT-X-140 |

## Round Limits (AZ-2517, loop 26)

The Swift suite reaches the same rows as the TypeScript and Go tables: `maxRounds` rounds are accepted and round `maxRounds` + 1 is refused with its byte unread; the slot total is shared by every round field of one call and charged where a round starts; `withLimits` returns a scheme that keeps the type number and leaves the receiver unchanged, and refuses a value below 1; each scheme in a dispatch uses its own limits. The hostile `limit` cases give `.tooMany` with `needed` 0 and the bytes left. The single-threaded size tests do not run under the thread sanitizer.

## Loops 26 and later

See [tests-by-loop.md](tests-by-loop.md) (loop 26 section; loop 74 section: the stream session tests retired, ADR 009).

## Test Data Management

**Required test data**:

| Data Set | Description | Source | Size |
|----------|-------------|--------|------|
| position | the 13-byte hex and the five fields | `fixtures/golden.hex` | 13 bytes |
| flags | clear and set bits around fixed-width fields | the README examples and inline rows | under 1 KB |
| short | a buffer that ends inside a field, one trailing byte | inline in `ShortTrailingTests` | under 1 KB |
| hostile | the 65 cases of `fixtures/hostile/cases.txt` | read by path by the Swift loaders (`HostileLoader.swift` and siblings) | 65 cases |
| fuzz corpus | `fixtures/hostile/fuzz/corpus.txt`: 28 inputs (12 unpack and limit packets of `cases.txt`, 16 from Go's seed corpus) | committed | one line each |
| session (retired in loop 74, ADR 009); RFC 8439 | seed bytes 1..32, value `01` + 15 zero bytes (retired); RFC 8439 §2.3.2 and §2.4.2 | inline in `ChaCha20Tests.swift` (`SessionTests.swift` deleted) | under 1 KB |

**Setup procedure**:
1. On the Mac: `swift test` at the repository root with the `-F` and rpath flags of `_docs/AGENT_GOTCHAS.md`; one `swift build` or `swift test` at a time (SwiftPM locks `.build`)
2. On Linux: `docker compose -f docker-compose.test.yml run --rm swift` (`swift:6.3.3`; build output in `PACKBIN_SWIFT_SCRATCH` inside the container)

**Teardown procedure**:
1. Discard the container; the SwiftPM cache stays in the named volume `swiftpm-cache`
2. No registry token exists for Swift

**Data isolation strategy**: each test builds its own scheme and row in memory; a built `Scheme` is immutable and `Sendable` and is shared only by the concurrency test. There is no database and no shared mutable fixture.
