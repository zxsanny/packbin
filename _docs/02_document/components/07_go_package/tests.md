# Test Specification — Go package

Added in loop 24 (AZ-2222, AZ-2440 to AZ-2451). Same shape as [the TypeScript tests.md](../02_typescript_package/tests.md): the project acceptance criteria AC-1 to AC-16 first, then the blackbox, performance, security and acceptance tests, then the Go-specific criteria GO-1 to GO-16. Scenario ids FT-X-83 to FT-X-112 are in [blackbox-tests-17](../../tests/blackbox-tests-17-loop24-go-package.md); the AC to test map for all packages is [traceability-matrix.md](../../tests/traceability-matrix.md). Every test below is in `go/*_test.go` and runs in the `go` service of `docker-compose.test.yml` (`golang:1.27`; Go is not installed on the owner's Mac). Test names carry the AC number of their task spec (a `TestAC1...` is AC-1 of its task, not of the project).

## Acceptance Criteria Traceability

| AC ID | Acceptance Criterion | Test IDs | Coverage |
|-------|---------------------|----------|----------|
| AC-1 | Position pack is the 13-byte hex | IT-01, AT-01 | Covered |
| AC-2 | Unpack returns those fields and 0 motion fields | IT-02, AT-01 | Covered |
| AC-3 | This package's bytes match the shared golden hex | IT-03 | Covered (in the ring: full `language-pair.sh` run not done at loop 24 sync) |
| AC-4 | Clear bit adds 0 bytes; flags 0x20 adds 2 | IT-04 | Covered |
| AC-5 | A stored 0 is written | IT-05 | Covered |
| AC-6 | Conditional group adds 0 bytes or its width | IT-06 | Covered |
| AC-7 | Repeat yields one value per group; 1 leftover byte is an error | IT-07 | Covered |
| AC-8 | Short field names field, needed, left, and returns 0 values | IT-08, ST-01 | Covered |
| AC-9 | Trailing bytes are an error and 0 values | IT-09 | Covered |
| AC-10 | 100000 round trips ≤ 1 second on one core | PT-01 | Covered |
| AC-11 | This package's tests run on every push and pull request | AT-02 | Covered locally in Docker; first Ubuntu runner run unproven |
| AC-12 | A matching tag publishes this package, with 0 manual uploads | AT-03, ST-02 | Covered hermetically (`publish-go.test.sh`); no tag pushed, live proxy check NOT RUN |
| AC-13 | The first tag includes this package with the other five | AT-03 | History: the first tag predates Go; a tag after the Go release pushes `go/vX.Y.Z` with the six packages (ADR-004) |
| AC-14 | A golden mismatch publishes 0 packages, including this one | AT-04 | Covered |
| AC-15 | This package absent from the tagged tree publishes 0 packages | AT-05 | Covered (`absent go`) |
| AC-16 | This published package declares MIT | AT-06 | Covered (`go/LICENSE` checked by the build phase and `TestAC8LicenseIsMIT`) |

## Blackbox Tests

| Test | Traces to | What it proves | Go tests |
|------|-----------|----------------|----------|
| IT-01 Position pack | AC-1 | `Pack` of type 64, sid 1, latitude 500000000, longitude 300000000, profile 1 gives `4001000065cd1d00a3e1110100`, 13 bytes, mismatched bytes 0, typed and map | `TestAC1GoldenTyped`, `TestAC1GoldenMap` (read `fixtures/golden.hex` through `helpers_test.go`) |
| IT-02 Position unpack | AC-2 | `Unpack` of that hex gives the five fields and 0 motion fields; the typed and the map form agree | `TestAC1GoldenTyped`, `TestAC1MapAndTypedUnpackAgree` |
| IT-03 Bytes match the golden hex | AC-3 | the packed bytes equal the shared fixture; the ring hands the same bytes to and from the other six | `TestAC1GoldenTyped`; ring: `language-pair.sh`, `publish-position.sh go` |
| IT-04 Flags width | AC-4 | a clear bit adds 0 bytes, flags 0x20 on a `u16` at bit 5 adds 2; eight bits pack in both forms | `TestFlagsWidthPresentZeroAndAbsence`, `TestEightFlagBitsPackBothForms`, `TestAC2ReadmeScalarExamples` |
| IT-05 A stored zero is written | AC-5 | a present 0 sets the bit; a nil pointer or an absent key does not and adds 0 bytes | `TestAC4NilPointerIsNoValueZeroIsValue`, `TestAC4MapNilAndAbsentAreNoValue` |
| IT-06 Conditional group | AC-6 | a `when` that does not match adds 0 bytes, a match adds the group width | `TestWhenOnASetFlagBitMatchesTrue`, `TestWhenComparesByValueAcrossGoTypes`, `TestAC1PackbinWhenGroupWidthAndRepeatOnGroupBoundary` |
| IT-07 Repeat on a group boundary | AC-7 | whole groups unpack one value per group; one leftover byte is an error and 0 values | `TestAC1PackbinWhenGroupWidthAndRepeatOnGroupBoundary`, `TestAC1ReadmeRoundExamples`, `TestAC2LargeRepeatKeepsOneEntryPerRound` |
| IT-08 Short field | AC-8 | a buffer that ends inside a field returns `ShortPacket` naming the field, `Needed` and `Left`, no row | `TestAC3ShortPacketNamesFieldNeededLeft`, `TestAC1FieldsShortBuffersNameTheMember` |
| IT-09 Trailing bytes | AC-9 | bytes left after the list give `TrailingBytes` and no row | `TestAC3TrailingBytesGiveNoRow` |

## Performance Tests

### PT-01: Position round trips on one core

**Traces to**: AC-10 (GO-8). 100 000 pack-then-unpack round trips of the AC-1 row, typed and as a map, `GOMAXPROCS(1)`, the fastest of up to three passes, finish in ≤ 1 second. `TestAC7SpeedRoundTrips` asserts the bound only without the race detector (it skips it under `-race`, about 5x slower); `run-suite.sh go` runs the test a second time without `-race`. Compose run after the review fixes: 160 ms typed, 128 ms map (82 and 78 ms in the worker run; 580 and 447 ms with `-race`, not asserted). It failed twice under host load 79 to 87 before the move: run it on a quiet host.

## Security Tests

### ST-01: A short buffer returns no value

**Traces to**: AC-8. `TestAC3ShortPacketNamesFieldNeededLeft` and `TestUnpackOfCollectionsRefusesWhatItCannotRead`: the call returns the error and no row; the error names the field, needed and left. The 65 hostile cases and `FuzzUnpack` extend this to hostile counts, lengths and rounds (GO-4, GO-5; NFT-SEC-04).

### ST-02: The published module has no registry token

**Traces to**: AC-12. Go has no archive and no registry credential: the tag is pushed with the job's `GITHUB_TOKEN` through the `GIT_ASKPASS` path of `publish-lib.sh` (`git_push`), and the module holds the library only (`go/` with `LICENSE`). `publish-go.test.sh` runs with every registry credential unset.

## Acceptance Tests

| Test | Traces to | Steps and expected result |
|------|-----------|---------------------------|
| AT-01 Caller pack and unpack | AC-1, AC-2 | `Pack` the position value: `4001000065cd1d00a3e1110100`; `Unpack` that hex: the five fields, 0 motion fields (`ExamplePack_typed`, `ExamplePack_map` print the README hex) |
| AT-02 Tests run on push and pull request | AC-11 | the `scaffold` job runs the `go` service; a failing Go test fails the job and the `report.csv` row (`run-suite.test.sh` G5 to G8) |
| AT-03 A matching tag publishes this package | AC-12, AC-13 | a tag with a passing golden check gets `go/vX.Y.Z` at the same commit, then `go list -m` through `proxy.golang.org` answers; manual uploads 0 (`publish-go.test.sh`; live run NOT RUN) |
| AT-04 A golden mismatch publishes nothing | AC-14 | a wrong Go byte in the position program: the gate prints the mismatch, 0 packages, 0 Go tags (`publish-gate.test.sh` Go gate rows) |
| AT-05 Absent from the tree publishes nothing | AC-15 | a tree without `go/`: `absent go`, no Go tag, the other packages publish |
| AT-06 The published package declares MIT | AC-16 | `go/LICENSE` is the MIT text; non-MIT identifiers 0 (`publish-check.py go-tag`, `TestAC8LicenseIsMIT`). Rollback: retract the version in the next `go.mod`, never delete or move the tag |

## Go criteria GO-1 to GO-16 (loop 24)

Each criterion, its tests and the scenario that carries it (FT-X ids in [blackbox-tests-17](../../tests/blackbox-tests-17-loop24-go-package.md)).

| GO | Tests | Scenario |
|----|-------|----------|
| GO-1 golden bytes | `golden_test.go` | FT-X-83 |
| GO-2 data types, short and trailing | `golden_test.go`, `readme_rounds_test.go`, `collections_readme_test.go`, `errors_test.go`, `ints_test.go` | FT-X-84 |
| GO-3 TypeScript parity rows | `parity_bigint_test.go`, `parity_loop20_test.go`, `parity_flags_when_test.go`, `parity_fields_test.go`, `parity_reference_test.go`, `u11_test.go`, `split_rounds_test.go`, `round_lists_test.go` | FT-X-85, FT-X-86 |
| GO-4 65 hostile cases | `hostile_loader_test.go` (10 unpack, 2 limit, 15 construct), `hostile_pack_test.go` (38 pack), `fixtures/hostile/check-cases.sh` | FT-X-87 |
| GO-5 round limits, fuzz | `limits_test.go`, `limits_pack_test.go`, `limits_raised_test.go`, `limits_width_test.go`, `limits_cost_test.go`, `fuzz_unpack_test.go` (`FuzzUnpack` 60 s in `run-suite.sh go`) | FT-X-88 |
| GO-6 session | `session_test.go`, `session_hostile_test.go` | FT-X-89 |
| GO-7 ring | `language-pair.sh` Go lines, `ring-wiring.test.sh` | FT-X-90 |
| GO-8 speed | `speed_test.go` | FT-X-91 |
| GO-9 CI suite | `run-suite.test.sh`, `report-row.test.sh`, the `go` compose service | FT-X-92 |
| GO-10 release | `publish-go.test.sh`, `publish-gate.test.sh`, `publish-check.py go-tag` | FT-X-93 |
| GO-11 dependencies | `module_test.go`, `run-suite.sh` `go_deps` | FT-X-94 |
| GO-12 no value | `novalue_test.go`, `u11_test.go`, `group_test.go`, `nested_test.go` | FT-X-95 |
| GO-13 README | `example_test.go` | FT-X-96 |
| GO-14 concurrency | `concurrency_test.go` | FT-X-97 |
| GO-15 invalid Go values | `invalid_test.go`, `ints_test.go`, `nil_scheme_test.go` | FT-X-98 |
| GO-16 tags never move | `publish-go.test.sh` | FT-X-99 |

## Round Limits (AZ-2444, loop 24)

All run in the `go` service. The Go suite reaches the same rows as the TypeScript table above: `maxRounds` rounds are accepted and round `maxRounds` + 1 is refused with its byte unread; the slot total is shared by every field of one call and charged where a round starts; `WithLimits` returns a copy, keeps the type number and refuses a value below 1; each scheme in a dispatch uses its own limits. The hostile `limit` cases (`repeat_rounds_over_limit`, `times_rounds_over_limit`) give `TooMany` with `needed` 0 and the bytes left.

## Loops 19 and later

See [tests-by-loop.md](tests-by-loop.md) (loop 24 section).

## Test Data Management

**Required test data**:

| Data Set | Description | Source | Size |
|----------|-------------|--------|------|
| position | the 13-byte hex and the five fields | `fixtures/golden.hex`, read by `helpers_test.go` | 13 bytes |
| flags | flags 0x00 and 0x20 with a `u16` at bit 5 | the same fixture rows and the README examples | under 1 KB |
| short | a buffer that ends inside a field | inline in the tests | under 1 KB |
| hostile | the 65 cases of `fixtures/hostile/cases.txt` | read by path by the Go loaders | 65 cases |
| fuzz seeds | `go/testdata/fuzz/FuzzUnpack/` (56 files): golden, ring payloads, hostile unpack and limit packets | committed | 4000 bytes in all |
| session | seed bytes 1..32, value `01` + 15 zero bytes | inline in `session_test.go` | 48 bytes |

**Setup procedure**:
1. `docker compose -f docker-compose.test.yml run --rm go` (builds nothing on the host; Go is not installed on the owner's Mac)
2. The fixture is mounted read-only at `/fixture/golden.hex`; the tests read `../fixtures/golden.hex`. Do not copy the hex into a second list

**Teardown procedure**:
1. Discard the container
2. Do not leave a registry token on disk (Go has none)

**Data isolation strategy**: each test builds its own scheme and row in memory; a built `Scheme` is immutable and shared only by the concurrency test. There is no database and no shared mutable fixture.
