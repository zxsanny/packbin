# Go package

## 1. High-Level Overview

**Purpose**: Pack and unpack a caller-owned scheme for Go programs, with the same bytes as the other six packages.

**Architectural Pattern**: stateless clear pack and unpack over an immutable `Scheme`, plus a `PackSession` the caller holds (as the TypeScript package). Hand-written walkers, no code generation (ADR-001).

**Upstream dependencies**: none inside the repo. Outside: the Go standard library and `golang.org/x/crypto` (ChaCha20, session only). `go.mod` names `go 1.26.0`, the direct requirement `golang.org/x/crypto v0.58.0` and `golang.org/x/sys` as indirect; no cgo. The suite check requires that the packages the build uses come from the main module and x/crypto only.

**Downstream consumers**: Go programs, fetched with `go get github.com/zxsanny/packbin/go@vX.Y.Z` from the git tag `go/vX.Y.Z` (ADR-004). There is no registry upload; the README has the install and the examples (`README.md`, Example, Go).

**Layout**: module `github.com/zxsanny/packbin/go` in `go/`, one package `packbin`, no `internal/` split. `go/doc.go` is the package documentation and the list of the whole API; `go/example_test.go` holds the `Example` tests whose text is the README's Go code.

## 2. Interfaces

Same shape as TypeScript (`components/02_typescript_package/description.md` §2): a scheme built from fields by order id, pack, and unpack with first-byte dispatch over a scheme list.

| Area | API |
|------|-----|
| Scheme | `NewScheme(typeNumber int, fields ...Field) (*Scheme, error)`; an `*Error` of kind `InvalidScheme` naming the field id, never a panic. `(*Scheme).TypeNumber()`, `Limits()`, `WithLimits(Limits) (*Scheme, error)` |
| Pack, unpack | `Pack(s, row) ([]byte, error)`, `Unpack(buf, schemes...) (any, error)`, `UnpackMap(buf, schemes...) (map[string]any, error)` |
| Fields | `U8`..`U64`, `I8`..`I64`, `F32`, `F64`, `Bytes`, `Be`, `Bool`, `Utf8`, `Flags`, `FlagByte(name).Bit`, `Eq`, `When`, `Group`, `Nested`, `Repeat`, `Times`, `Sized`, `U2` with `Slot`, `Bits`, `Packed`, `List`, `Dict`; a list or dict has no id |
| Typed rows | `Bind[T, V](field, get func(*T) V, set func(*T, V))` binds a value field, a slot, a group, a nested row, a list, a dict or a round to a member of the struct `T`; a bound scheme packs a `*T` or a `T` and `Unpack` returns a `*T` |
| Limits | `Limits{MaxRounds, MaxSlots, MaxBytes}`, `DefaultLimits()`, `DefaultMaxRounds` 65 535, `DefaultMaxSlots` 1 048 576, `DefaultMaxBytes` 16 777 216; `WithLimits` returns a copy, takes all three values and refuses a value below 1 with `InvalidScheme` |
| Errors | `*Error{Kind, Field, Name, Needed, Left, Actual, Reason}`; kinds `ShortPacket`, `TrailingBytes`, `UnknownType`, `BadValue`, `InvalidScheme`, `PackRefused`, `TooMany`; `errors.Is` sentinels (`ErrShortPacket`, ...). A refused pack returns nil bytes |
| Session | `LoadSession(seed) (*PackSession, error)` (`SeedSize` 32), `Start()`, `StartWith(nonce)` (`NonceSize` 16, for tests), `Join(nonce)`, `Pack(s, row)`, `Unpack(payload, schemes...)`, `UnpackMap(...)` (`contracts/library/pack-session.md`) |

Rows: a typed struct bound by getter and setter closures, or `map[string]any`. A nil pointer, slice or map is no value; an empty slice is a value with 0 items (G-5). In a map row an integer field takes any Go integer type that holds the value, a float field any Go integer or float, `Bytes` and `Sized` a `[]byte`, `Bits` and `Packed` a slice of integers, a `Bool` a bool. `UnpackMap` gives each value the Go type of its field, so a row it returned packs again to the same bytes.

## 3. Rules

Go copies TypeScript row for row (loop 24 fit decision 4), except the documented TypeScript-only exceptions (U6, the bigint `times` count split), where it follows the five. A disagreement found while porting is reported, not decided in the task.

- A built `Scheme` is immutable and safe for concurrent `Pack` and `Unpack` from any number of goroutines (GO-14); a `PackSession` is for one goroutine at a time.
- Errors are values. No input makes `Pack`, `Unpack`, `UnpackMap` or `NewScheme` panic (GO-15). An unreadable value found by unpack is a short-packet-shaped error with `Needed` 0, as in TypeScript; a round past a limit is `TooMany`.
- The round limits are charged where a round starts (`packer.rounds`, `reader.rounds`), before its bytes are read; pack refuses a count or list above `MaxRounds`, charges `MaxSlots` per round and checks `MaxBytes` before every write. The slot width of a round is TypeScript's; a `Nested` row is a scope of its own and charges the width of its own members.
- Session: C# ciphertext `b55d0a29c56c203712b241232e` and TypeScript's keyed first-packet vectors are the checks. `LoadSession` copies the seed (the caller's slice is not wiped); the copy and the derived key block are zeroed once the session opens. A failed `Pack` spends no counter position; every `Unpack` spends one. A packet over 2^38 bytes is refused (x/crypto counter overflow).

## 4. Decisions

`_docs/02_task_plans/go-package/problem.md` G-1 to G-6 (owner, 2026-10-13): module path and tag layout, Go 1.26 minimum with Docker-only local runs, `x/crypto` as the one dependency, rows as bound structs plus the map form, nil and empty slices, publish as a tag after the golden gate. ADR-001, ADR-004.

Loop 24 owner decisions that make Go differ from TypeScript (`_docs/loops/loop24/notes24.md`; the README states them under Example, Go, "Go rows", and in its Loop 24 notes):

- **Go-4 A**: a group in a map row is a nested `map[string]any` both ways (TypeScript packs nested or flat and unpacks flat). A flat key that names a member of a group whose map is not given is refused. A group in a round takes one map a round; a list or dict inside a lone group map given for every round is refused.
- **Go-1 B**: a non-bool value for a `Bool` in a map row is refused (TypeScript clears the bit).
- **Go-2 A**: a whole float for an integer field is refused, as C# since loop 21; a `json.Unmarshal` map needs typed rows or integer values.
- **Go-3**: a split flag bit inside a false `when` with its member given packs as TypeScript does (`01 00 03 06`; the unpacked row repacks to `01 00 02 06`), pinned by a test; the five others are probed at assessment.
- Also decided while porting, without a TypeScript counterpart: a typed `Times` refuses a count that differs from the slice length (as C#); `[]byte` is a byte run and never a list or a round list; a `Nested` row has its own name scope; `WithLimits` takes all three limits; `NewScheme` refuses the hostile schemes `zero_progress_repeat_bool` and `zero_progress_repeat_when`; u64 and i64 are exact above 2^53.

Open (assessment, not decided): the empty anchored group's anchor, `u2` as a list or dict element (Go refuses it, TypeScript builds it), the slot width of a `Nested` row against Java's, `empty-round-body` row 22 (`TrailingBytes` against the short-packet shape), `BadValue` from unpack, the `run-suite.sh go` fail-without-`go.mod` against the six skips, and the AC-7 speed bound under a loaded host.

## 5. Tests

`go test -race ./...` in `go/` (about 25 s): golden, parity rows of TypeScript, the hostile vectors (`fixtures/hostile/cases.txt`, 65 cases), session vectors, concurrency (8 goroutines), `FuzzUnpack` (60 s in `run-suite.sh go`), and the six `Example` tests whose output is the README text. `docker compose -f docker-compose.test.yml run --rm go` is the suite as CI runs it.

Peak memory (loop 25, AZ-2475): `go/mem_test.go`, behind the build tag `packbin_memtest` and so outside `go test ./...`, samples the heap in use during the unpack in `golang:1.27` (one run each, about 10 %): the F10 packet (4.26 MB, `MaxSlots` 4,194,304) peaks at about 625 MB and a 1 MiB wide-round packet (16,128 rounds of 65 one-byte members, the defaults) at about 94 MB. Run it with `go test -tags packbin_memtest -v -run TestMem -count=1 ./...`.
