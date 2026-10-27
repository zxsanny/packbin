# Tests by loop: go package

The Go package began in loop 24, so this file has one section. Same shape as [the TypeScript tests-by-loop.md](../02_typescript_package/tests-by-loop.md). The AC to test map is [tests.md](tests.md); the scenarios are FT-X-83 to FT-X-112 in [blackbox-tests-17](../../tests/blackbox-tests-17-loop24-go-package.md).

## Loop 24 Tests (AZ-2440 to AZ-2451)

Source: `_docs/03_implementation/batch_01_loop24_report.md` (batch 01 parts 1 to 6, batch 02 parts 1 to 5, review fixes), `_docs/loops/loop24/review24.md`, `assessment24.md`. The Go suite was written with the code, wave by wave: 54 tests and 60 subtests at AZ-2440, 73 and 201 at AZ-2441, 114 and 592 at AZ-2442, about 165 and 741 at AZ-2443, then the limits, session (retired in loop 74), hostile, parity and README tasks (later totals were not recorded). `go test -race` takes about 28 s on the owner's Mac in `golang:1.27`; coverage was 96.7% at the last measured part (AZ-2444); no Go file is longer than 390 lines; `gofmt -l` 0 files, `go vet` 0 findings. The step 11 result is not in this file. The grouping of test files by task below follows the subject of each file and the batch report; the AC numbers inside the test names are those of the task spec.

| Test file | Task | What it proves |
|-----------|------|----------------|
| `golden_test.go`, `helpers_test.go` | AZ-2440 | the position row typed and as a map packs `fixtures/golden.hex` and unpacks back; the README scalar examples |
| `errors_test.go`, `values_test.go`, `ints_test.go`, `invalid_test.go` | AZ-2440 | `ShortPacket` names field, needed, left; `TrailingBytes`; dispatch by first byte; integer ranges; a nil row, a nil map or a wrong Go type gives an error naming the field id with nil bytes; error kind names equal the hostile vocabulary |
| `concurrency_test.go`, `speed_test.go`, `race_on_test.go`, `race_off_test.go`, `module_test.go` | AZ-2440 | 8 goroutines x 10 000 round trips, 0 races; the AC-10 speed bound (asserted without `-race`); `go.mod`, no cgo, MIT license |
| `flags_test.go`, `when_test.go`, `scheme_test.go`, `novalue_test.go` | AZ-2440 | flags in both forms and the ninth bit refused, `when` by value, a nil pointer or slice is no value, owner Go-1 B (a non-bool for a `Bool` in a map row is refused), Go-3 (a split bit inside a false `when`, pinned) |
| `construct_test.go`, `group_test.go`, `group_typed_test.go`, `nil_scheme_test.go` | AZ-2441 | the TypeScript construction refusals, negative ids, the anchored `Group` in map and typed rows, Go-4 A (a flat key naming a member of an absent group is refused), nil-safe `TypeNumber` and `Limits` (review fix) |
| `round_*_test.go`, `flags_rounds_test.go`, `split_rounds_test.go`, `counts_test.go`, `lone_buffers_test.go`, `readme_rounds_test.go`, `u11_test.go` | AZ-2442 | `repeat`, `times`, `sized`, `u2`, `bits`, `packed` rows and refusals, U11 (a count behind a clear `when` with no value), the README round examples, the route fixture |
| `utf8_test.go`, `collections_*_test.go`, `list_elements_test.go`, `nested_test.go` | AZ-2443 | strings, lists, dicts, nested rows; an element is a scope of its own; typed and map rows give the same bytes; the ring payloads round trip; random schemes never panic |
| `limits_test.go`, `limits_pack_test.go`, `limits_raised_test.go`, `limits_width_test.go`, `limits_cost_test.go`, `fuzz_unpack_test.go`, `testdata/fuzz/FuzzUnpack/` | AZ-2444 | defaults and `WithLimits`; round and slot charges before bytes; the `maxBytes` budget; the F10 and wide-round packets at the default and a raised limit; `FuzzUnpack` 60 s with 0 failures (1.19 M execs in the compose run); a 1 MiB packet of any byte within the bound |
| `session_test.go`, `session_hostile_test.go` (retired in loop 74, ADR 009) | AZ-2445 | C# ciphertext `b55d0a29c56c203712b241232e`, TypeScript's keyed first-packet vectors, session AC-2 to AC-7, hostile session input (22 tests at the merge) |
| `hostile_loader_test.go`, `hostile_pack_test.go`, `hostile_pack_cases_test.go`, `hostile_refusals_test.go`, `hostile_schemes_test.go` | AZ-2446 | the 65 cases (10 unpack, 2 limit, 15 construct, 38 pack), each rule pinned with the whole Go text, wrong-rule self-tests, tables equal to `cases.txt`; `check-cases.sh` counts seven packages |
| `parity_bigint_test.go`, `parity_loop20_test.go`, `parity_flags_when_test.go`, `parity_fields_test.go`, `parity_reference_test.go` | AZ-2447 | 23 tests and about 330 subtests, 0 skips: the rows of the TypeScript loop 20 to 23 tables, the loop 18, 21 and 22 reference docs and FT-X-79, FT-X-80 and FT-X-81 in Go (FT-X-75 to 78 and 82 are C++, Rust and Python only); about 55 rows probed against TypeScript with node: all match; U6 follows the five |
| `example_test.go` | AZ-2451 | six `Example` tests whose output is the README Go text |
| `.github/workflows/run-suite.test.sh` (G1 to G10), `report-row.test.sh` | AZ-2448 | `run-suite.sh go` runs its steps in order and stops at the first failure, fails without `go/go.mod`, names a second module; seven services in the report |
| `.github/workflows/ring-wiring.test.sh`, `language-pair.sh` | AZ-2449 | 114 Go handoff line guards and mutations; 108 handoffs run by the worker, all pass |
| `.github/workflows/publish-go.test.sh`, `publish-gate.test.sh` | AZ-2450 | the tag at the same commit, a re-run, another commit, a proxy that never answers, build-phase refusals, the `final` tier, a wrong Go byte publishes nothing, `absent go`; 12 of 12 runs pass |

Review fixes (commit `c9cc56a`): the speed bound is skipped under `-race` and run once more without it (`run-suite.sh go`), `FuzzUnpack` runs with `-fuzzminimizetime=0`, `nil_scheme_test.go`, the `StartWith` nonce warning in the doc comment.

Not run in loop 24: the live `proxy.golang.org` check, the first tag, the first Ubuntu runner run; the full `language-pair.sh`; a Go peak-memory figure (assessment D8). The open owner rows D1 to D7 are in the traceability matrix.

## Loop 74: the stream session is removed (AZ-3287, ADR 009)

Source: `_docs/03_implementation/batch_02_loop74_report.md`. The stream session tests are retired (deleted), the mixed files keep their non-session tests, and the frame and crypto rows did not move.

| Test | Task | What changed |
|------|------|--------------|
| `session_test.go`, `session_hostile_test.go`, `session_concurrent_test.go`, the fuzz seeds `testdata/fuzz/FuzzUnpack/ring_session_body` and `ring_session_packet` | AZ-3287 | retired with `session.go`: deleted |
| `crypto_vectors_test.go` (new) | AZ-3287 | the unexported `crypto.go` on the 27 rows of `fixtures/crypto/vectors.txt`; 6 of 6 mutant copies caught; refusals (key and nonce size, a stream past the last block counter, HKDF length) |
| `ecc_scheme_test.go` (20 to 12), `nil_scheme_test.go` (8 subtests to 6), `example_test.go` (6 to 5); `goldenFieldMismatches` moved to `helpers_test.go` | AZ-3287 | the non-session tests stay; the duplicate-type-before-parity-mix check runs on the clear `UnpackRepair` |

`golang:1.27`: `gofmt -l` 0 files, `go vet` 0, `go test -race` 325 passed and 1 skipped (355 before; 3,001 with subtests), `TestAC7SpeedRoundTrips` PASS, 60 s `FuzzUnpack` PASS; the module's one dependency is still `golang.org/x/crypto`.
