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
| 11 | AZ-2441 AC-4, G-4, U26 | Row shape of a group in the map form. TypeScript (parent probe): pack reads the group's nested object when given, else the flat keys (both `{a:1,b:2}` and `{a:1,g:{b:2}}` pack `010102`; nested wins over a flat duplicate); unpack always gives flat keys, for anchored and unanchored groups. Go (from the parent's prompt, which read U26 too widely): nested map only, both ways; a flat key is ignored, so under `flags` flat `{c:2}` packs `0100` where TypeScript refuses `missing a` | owner row Go-4 | unclear |
| 12 | AZ-2441 | Empty anchored group: its anchor must be the next id but takes none (`Flags(0, Group(0,"mark")), U8(0,"n")`), as TypeScript | probe the five at assessment | unclear |
| 13 | AZ-2440 bug fixed in AZ-2441 | Typed unpack with two `when` branches sharing a name with different kinds (u8 x / bytes(2) x) could reflect-panic or truncate; `fillRow` now fills only the member whose type matches what unpack read | none (test `TestTypedWhenBranchesOfDifferentKindsFillOnlyTheRead`) | clear |
| 14 | AZ-2441 | Message texts differ in form (`1e+20` vs the long integer, Go type names); refused-vs-built outcomes agree | none | clear |
| 15 | AZ-2441 | AC-7 speed under load average 79 failed once with `-race -cover`, passed on rerun (670/506 ms race, 105/96 ms plain) | watch at step 11; the run-suite go step uses `-race` | clear |
