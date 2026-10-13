---
loop: 24
branch: dev
---

# Go core: module, scalars, flags, when, errors, dispatch, typed and map rows

**Task**: AZ-2440_go_core
**Name**: Go core: module, scalars, flags, when, errors, dispatch, typed and map rows
**Description**: The Go module and the clear pack/unpack walker for the scalar kinds, flags and `when`, with typed-struct and map rows.
**Complexity**: 5 points
**Dependencies**: None
**Component**: go
**Tracker**: AZ-2440
**Epic**: AZ-2222

## Problem

Go services cannot pack or unpack packbin. The first slice gives them the module (`github.com/zxsanny/packbin/go`, `go 1.26`, MIT) and the walker for the AC-1 position row and the scalar data types, with errors as values.

Feature ACs and scenarios: `_docs/02_task_plans/go-package/` (GO-1, GO-2 (scalar kinds), GO-8, GO-11, GO-12 (scalars), GO-14, GO-15; scenarios S1, S3, S4, S5).

## Outcome

- Go packs and unpacks the AC-1 row and the README integer, float, fixed-bytes, big-endian, bool, flags and `when` examples with 0 mismatched bytes.
- Rows are typed structs bound by getter/setter closures, or `map[string]any`; nil pointer = no value, a stored 0 is a value (G-4, G-5).
- Short, trailing and unknown-type buffers return an error value and no row.

## Scope

### Included

- `go/go.mod` (`module github.com/zxsanny/packbin/go`, `go 1.26`), `go/LICENSE` (MIT), the package `packbin` public API skeleton (scheme, fields by order id, `Pack`, unpack with first-byte dispatch over a scheme list).
- Kinds: u8..u64, i8..i64, f32, f64, fixed bytes, big-endian integers, bool (under flags/flag-byte bit only), `flags`, `flagByte(...).bit`, `when` with `eq`.
- Error values: short packet (field, needed, left), trailing bytes, unknown type number, bad value; pack refusals naming the field id.
- Speed test (AC-10) and the concurrency test.
- Owns (exclusive write): `go/**`

### Excluded

- Construction checks beyond what the walker needs to run (AZ-2441)
- Rounds, counted kinds (AZ-2442)
- utf8, list, dict (AZ-2443)
- Limits (AZ-2444)
- Session (AZ-2445)

## Acceptance Criteria

**AC-1: Golden bytes**
Given the AC-1 row (type 64, sid 1, lat 500000000, lon 300000000, profile 1, motion flags clear) as a typed struct and as a map
When packed
Then the bytes are `4001000065cd1d00a3e1110100` (`fixtures/golden.hex`, read as a file); unpack gives the five fields and 0 motion fields

**AC-2: README scalar examples**
Given each README example for integers, floats, fixed bytes, big-endian, bool, flags and `when`
When packed and unpacked
Then the README hex both ways; mismatched bytes 0

**AC-3: Short and trailing**
Given a buffer that ends inside a field, one with 1 trailing byte, and one whose first byte names no scheme
When unpacked
Then an error value naming the field, needed and left (short), trailing, or unknown type; row nil; no panic

**AC-4: No value and zero**
Given a flags member given as a nil pointer, and one given as a pointer to 0
When packed
Then the nil member's bit is clear and adds 0 bytes; the 0 member's bit is set and the 0 is written

**AC-5: Invalid Go values**
Given a nil row, a nil map, a map value of the wrong Go type, and an integer out of its field's range
When packed
Then an error naming the field id; bytes nil; panics 0

**AC-6: Concurrent use**
Given one built scheme
When 8 goroutines run 10 000 pack-then-unpack round trips each under `go test -race`
Then races 0; mismatches 0

**AC-7: Speed**
Given the AC-1 row
When 100 000 pack-then-unpack round trips run on one core
Then ≤ 1 second (AC-10)

**AC-8: Module**
Given `go/go.mod` and `go/LICENSE`
When inspected and `go vet`/`gofmt -l` run
Then `go 1.26`; 0 or 1 direct requirement (`golang.org/x/crypto`; its indirect `golang.org/x/sys` allowed); cgo files 0; MIT; vet findings 0; unformatted files 0

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | golden row typed and map | golden hex both ways |
| AC-2 | README scalar table | README hex |
| AC-3 | short/trailing/unknown | error value, nil row |
| AC-4 | nil vs 0 flags member | bit clear vs set |
| AC-5 | nil row/map, wrong type, out of range | error naming id |
| AC-6 | 8 goroutines x 10 000 | 0 races |
| AC-7 | AC-10 loop | ≤ 1 s |
| AC-8 | go.mod, LICENSE, vet, gofmt | as stated |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | `fixtures/golden.hex` | Go suite in `golang:1.27` | golden hex | AC-1, AC-3 |

## Constraints

- Go copies TypeScript at HEAD row for row (loop 24 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Go follows the five. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import of another package. Standard library plus `golang.org/x/crypto` only (G-3). No cgo.
- Go runs only in Docker on the owner's Mac: `docker run --rm -v "$PWD":/src -w /src/go golang:1.27 go test -race ./...` (G-2).
- Errors are values; no panic escapes `Pack`, `Unpack` or scheme construction on any input.

## Risks & Mitigation

**Risk 1: API shape fixed early**
- *Risk*: AZ-2441 to AZ-2447 build on this API; a late change ripples through every Go test.
- *Mitigation*: AZ-2440 writes the public API for every kind (stubs that refuse are not allowed: kinds not built yet are simply absent) and documents it in package docs; later tasks add kinds, they do not rename.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (size, `problem.md`) | parent | resolved | Low |
