# Loop 24 batch 01 report (wave 1: Go core, CI suite)

Date: 2026-10-13. Intake `0db6534`. Workers own disjoint paths; package suites only (no per-batch review, owner rule).

| Worker | Spec | Owns | Result |
|--------|------|------|--------|
| go core | AZ-2440 | `go/**` | 54 tests + 60 subtests pass under `-race`; `gofmt -l` 0, `go vet` 0; coverage 89.9%; AC-10 82 ms typed / 78 ms map (no race), 580 / 447 ms with `-race` |
| ci suite | AZ-2448 | `run-suite.sh`, `run-suite.test.sh`, `report-row.test.sh`, `test.yml` scaffold job, both compose files | hermetic tests pass; mutation checks catch each removed gate; real `go` service on a scratch module PASS (74 s with a 60 s fuzz) |

Parent: `docker compose -f docker-compose.test.yml run --rm go` on the real tree → `go,go suite,11000,PASS` (fuzz step prints its named skip: no `FuzzUnpack` until AZ-2444).

CI-parity: PASS — `report-row.test.sh`, `fixtures/hostile/cases.test.sh`, `run-suite.test.sh`, `cpp/embedded/lib.test.sh`, `ring-wiring.test.sh`, the `go` compose suite. The six suites have no source change. `publish-gate.test.sh` (Docker-heavy; its structure checks do not read the changed lines) runs at step 11.

Worker slips: none (`git diff --cached` empty after each join).

## Public API (AZ-2440, for the chain)

`NewScheme(typeNumber int, fields ...Field) (*Scheme, error)`; `Pack(s *Scheme, row any) ([]byte, error)`; `Unpack(buf []byte, schemes ...*Scheme) (any, error)`; `UnpackMap(...) (map[string]any, error)`; field constructors `U8`..`U64`, `I8`..`I64`, `F32`, `F64` `(id, name)`, `Bytes(id, name, size)`, `Bool`, `Be(f)`, `Flags(anchor, members...)`, `FlagByte(name).Bit(f)`, `Eq(id, value)`, `When(anchor, cond, members...)`; typed rows `Bind[T, V](f, get, set)`; errors `*Error{Kind, Field, Name, Needed, Left, Actual, Reason}` with kinds named as the hostile vocabulary and `errors.Is` sentinels. Reserved in `go/doc.go`: `Repeat`, `Times`, `Group`, `Nested`, `Sized`, `U2`/`Slot`, `Bits`, `Packed`, `Utf8`, `List`, `Dict`, `WithLimits`/`Limits`, `TooMany`, `PackSession`.

## Discovered during implementation

| # | Spec ref | Finding | Proposed handling | Status |
|---|----------|---------|-------------------|--------|
| 1 | AZ-2440 AC-5 | A bool given a non-bool map value (`{"on": 1}`, `"yes"`): TypeScript clears the bit silently | owner Go-1 B: Go refuses (AZ-2441 worker); probe the five at assessment | clear |
| 2 | AZ-2440, int-range | A whole float for an integer field (`{"n": 5.0}`): TypeScript packs (JS cannot tell 5.0 from 5); Go refuses as C# since loop 21 — so a `json.Unmarshal` map (all numbers float64) is refused for integer fields | owner Go-2 A: refuse (as C#); README note | clear |
| 3 | AZ-2440 | A split bit inside a false `when`, member given (`u8 k; m; when(k==1){bit m{u8 a}}; bit m{u8 b}`, k=0, a=5, b=6): TypeScript packs `01000306` (a's bit set, no `a`), the unpacked row repacks `01000206`; Go copies it (pinned) | owner Go-3: copy TypeScript, pinned; probe all six at assessment | clear |
| 4 | AZ-2440 | u64/i64 above 2^53: Go integers are exact and pack (the TypeScript refusal is JS-only) | none | clear |
| 5 | AZ-2440 | A ninth `flags` member is reported by `NewScheme` (TypeScript throws at `flags()`) | none | clear |
| 6 | AZ-2440 | Anchored `group` had no owning task | added to AZ-2441 (now 5 points) | clear |
| 7 | AZ-2448 AC-3 | Without `go/go.mod` Go fails; the six skip with a PASS row | kept (no silent pass); loop 25 handoff: align the six? | unclear |
| 8 | AZ-2448, GO-11 | `go list -m all` always lists x/crypto's own requirements; `go mod tidy` adds `golang.org/x/sys // indirect`; `go get` writes `go 1.26.0` | GO-11 amended to direct requirements + built-package modules | clear |
| 9 | AZ-2448 | `publish-readonly.test.sh` `RO_SERVICES` lists six | AZ-2450 adds `go` (spec amended) | clear |
| 10 | AZ-2448 | module-layout "workflows" note for `run-suite.sh go` | step 13 | clear |

## Batch 01 part 2 (AZ-2441, wave 2 start)

| Worker | Spec | Result |
|--------|------|--------|
| go chain | AZ-2441 (scheme checks, anchored group, Go-1 B) | 73 tests + 201 subtests pass under `-race`; gofmt/vet clean; coverage 95.9%; files ≤ 299 lines. Parent re-ran the Go suite: ok |

Construction order now matches TypeScript (type number, ids, flag bits, presence marks, member names, references, binding). `Group(anchor, name, members...)` built for flags members, flag-byte bits, `when` members, nested; typed rows bind a struct or `*struct` (nil = no value), an empty group binds `bool`/`*bool`.

| # | Spec ref | Finding | Proposed handling | Status |
|---|----------|---------|-------------------|--------|
| 11 | AZ-2441 AC-4, G-4, U26 | Row shape of a group in the map form. TypeScript (parent probe): pack reads the group's nested object when given, else the flat keys (both `{a:1,b:2}` and `{a:1,g:{b:2}}` pack `010102`; nested wins over a flat duplicate); unpack always gives flat keys, for anchored and unanchored groups. Go (from the parent's prompt, which read U26 too widely): nested map only, both ways; a flat key is ignored, so under `flags` flat `{c:2}` packs `0100` where TypeScript refuses `missing a` | owner Go-4 A (2026-10-13): nested maps both ways; pack refuses a flat key naming a group member when the group map is absent (AZ-2442 worker); README states the TypeScript difference | clear |
| 12 | AZ-2441 | Empty anchored group: its anchor must be the next id but takes none (`Flags(0, Group(0,"mark")), U8(0,"n")`), as TypeScript | probe the five at assessment | unclear |
| 13 | AZ-2440 bug fixed in AZ-2441 | Typed unpack with two `when` branches sharing a name with different kinds (u8 x / bytes(2) x) could reflect-panic or truncate; `fillRow` now fills only the member whose type matches what unpack read | none (test `TestTypedWhenBranchesOfDifferentKindsFillOnlyTheRead`) | clear |
| 14 | AZ-2441 | Message texts differ in form (`1e+20` vs the long integer, Go type names); refused-vs-built outcomes agree | none | clear |
| 15 | AZ-2441 | AC-7 speed under load average 79 failed once with `-race -cover`, passed on rerun (670/506 ms race, 105/96 ms plain) | watch at step 11; the run-suite go step uses `-race` | clear |

## Batch 01 part 3 (AZ-2442, wave 2)

| Worker | Spec | Result |
|--------|------|--------|
| go chain | AZ-2442 (repeat, times, sized, u2, bits, packed; Go-4 A) | 114 tests + 592 subtests pass under `-race`; gofmt/vet clean; coverage 94.5%; files <= 340 lines. Parent re-ran the Go suite: ok |

API added: `Repeat`, `Times`, `Sized`, `U2`/`Slot`, `Bits`, `Packed`; `Bind` takes slots, sized/bits/packed (`[]byte`), and a round bound to a slice `[]E` / `[]*E` of a struct. `UnpackMap` gives rounds as `[]any` per name, nil for a skipped round. One place each where a round starts (`packer.rounds`, `reader.rounds`) for AZ-2444 to charge.

| # | Spec ref | Finding | Proposed handling | Status |
|---|----------|---------|-------------------|--------|
| 16 | AZ-2442, Go-4 | A group inside a round: TypeScript slices the lists inside a lone group object per round (`{k:[1,2], row:{v:[7,8]}}` packs `0101070208`); Go takes one map per round (`"row": []any{map{v:7}, map{v:8}}`, same bytes); a lone map goes to every round and a list inside it is refused | README sentence with the Go-4 note (AZ-2451) | clear |
| 17 | AZ-2442 | Typed `Times`: a count that differs from the slice length is refused as C# does; the map form keeps the TypeScript rules | pinned; README (AZ-2451) | clear |
| 18 | AZ-2442 | A row of a `flags` `times` whose bit is clear while the count is above 0 unpacks, then repacks with `missing pt` (as TypeScript) | AZ-2444: `FuzzUnpack` must not assert that unpacked rows repack (spec amended) | clear |
| 19 | AZ-2442 | u64/i64 counts above 2^53: Go integers are exact, so these are real counts (a short packet) where TypeScript says unreadable | none (JS-only precision, as row 4) | clear |
| 20 | AZ-2442 | `[]byte` is a byte run, never a round list; `[]uint8{1,2}` for a u8 member in a round is refused (use `[]any` or `[]int`) | README (AZ-2451) | clear |
| 21 | AZ-2442 | `reached` is keyed per round node; per list element it must be scoped | AZ-2443 spec amended | clear |
| 22 | AZ-2442 | A huge `times` count with a lone scalar loops on pack until AZ-2444 | AZ-2444 | clear |

## Batch 01 part 4 (AZ-2443, wave 2)

| Worker | Spec | Result |
|--------|------|--------|
| go chain | AZ-2443 (utf8, list, dict, nested rows) | about 165 tests + 741 subtests pass under `-race`; gofmt/vet clean; coverage 96.7%; files <= 320 lines; about 78k random schemes: 0 panics. Parent re-ran the Go suite: ok |

API added: `Utf8(id, name)`, `Nested(name, members...)`, `List(name, element)`, `Dict(name, element)`; `Bind` takes `string`/`*string`, `[]E`, `map[string]E`, a struct or `*struct` for a `Nested`/`Flags` element. A list or dict has no id; an element is its own scope for ids, references, names and flag bytes; `UnpackMap` gives `string`, `[]any`, `map[string]any`. `reached` is keyed by (row map, round node).

| # | Spec ref | Finding | Proposed handling | Status |
|---|----------|---------|-------------------|--------|
| 23 | AZ-2443 AC-3, Go-4 | A `Nested` row has its own name scope: member names may repeat an outer name (TypeScript's unanchored group flattens names and refuses "declared inside a group and outside it"; C# also gives a nested row its own scope). The anchored `Group` still refuses a shared name | README line (AZ-2451); probe at assessment | clear |
| 24 | AZ-2443 | `u2` or a `Slot` as a list/dict element: TypeScript builds (the slot name becomes the element name; with 2 slots the second reads from the outer row); Go refuses every `u2` element | assessment: a refused-vs-built difference, owner row if a single-slot `u2` should build | unclear |
| 25 | AZ-2443 | `[]byte` for a `List` in a map row is refused (TypeScript: a `Uint8Array` is not an Array); a typed `[]byte` member bound to `List(U8)` works | README (AZ-2451) | clear |
| 26 | AZ-2443 | Pack of a Go string that is not valid UTF-8 is refused naming the field (JS strings cannot hold it); unpack refuses invalid UTF-8 in a string or dict key as TypeScript, short-packet shape, needed 0 | none | clear |
| 27 | AZ-2443 | A list or dict inside a lone group map given once for every round is refused (TypeScript slices per round) | Go-4 row 16 | clear |
| 28 | AZ-2443 | Items of a `Nested`/`Flags` element in a map row are `map[string]any` only (TypeScript: any object); dict maps accept any map with string-kinded keys; keys sort in UTF-8 byte order | none | clear |
| 29 | AZ-2443 | `-race -cover` together fails the AC-7 speed test on this host, also on a pristine `git archive HEAD` copy; plain and `-race` pass (plain 111/105 ms) | step 11 runs `-race` only (run-suite) | clear |
