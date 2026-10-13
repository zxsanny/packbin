# Feature assessment — loop 24

loop: 24
feature: go-package (AZ-2222; AZ-2440 to AZ-2451)
rounds: 1
verdict: CLARIFY
report_of_round: 1

## Round 1

**Date**: 2026-10-13
**Implement pass**: batch 01 (waves 1 to 4, parts 1 to 6) and batch 02 (parts 1 to 5), commits `a5b3736` to `14a3ec0`, review fixes `c9cc56a`; batch report `_docs/03_implementation/batch_01_loop24_report.md`.
**Verdict**: CLARIFY — 12 covered / 2 out-of-scope / 1 gap-clear / 7 gap-unclear. No re-entry round (owner rule: do not chain assessment rounds while the hopper grows; every gap row goes to the loop 25 handoff; the parent decides).

Input notes:
- Intent baseline: `_docs/02_task_plans/go-package/problem.md` (G-1 to G-6, out of scope), `acceptance_criteria.md` (GO-1 to GO-16), `scenarios.md` (S1 to S12), the epic AZ-2222.
- Discoveries: the batch report's rows 1 to 54 (all read); rows already resolved by an owner decision (Go-1, Go-2, Go-3 copy, Go-4) or marked clear are not repeated. Review: `review24.md` (4 of 6 fixed, 2 skipped as noted there).
- Every GO criterion has a test: GO-1 `golden_test.go`; GO-2 `readme_rounds_test.go`, `collections_readme_test.go`, `ints_test.go`; GO-3 `parity_*_test.go`; GO-4 `hostile_*_test.go` (65 cases); GO-5 `limits_*_test.go`, `FuzzUnpack`; GO-6 `session*_test.go`; GO-7 the 114 Go handoff lines of `language-pair.sh` (108 run by the worker; the full ring runs at step 11); GO-8 `TestAC7SpeedRoundTrips` (second run without `-race`); GO-9 `test.yml` scaffold, `run-suite.sh go`; GO-10 and GO-16 `publish-go.test.sh`; GO-11 `module_test.go`, `run-suite.sh` `go_deps`; GO-12 `novalue_test.go`, `u11_test.go`; GO-13 `example_test.go`; GO-14 `concurrency_test.go`; GO-15 `invalid_test.go`.
- Probes: none beyond the workers' (node probes of about 55 TypeScript rows, Python 3.14 for U6); the cross-package questions below need new probes in the other five packages, which is loop 25 work.

### Coverage matrix

| id | scenario | status | evidence (AC + test + code) | source |
|----|----------|--------|-----------------------------|--------|
| S1 | A Go service packs a row and a ring member unpacks it, same bytes | covered | GO-1, GO-7; `golden_test.go`, 108 ring handoffs by the worker; `go/pack.go`, `.github/workflows/drivers/handoff-go/` | intake |
| S2 | A Go service unpacks a hostile or truncated packet | covered | GO-2, GO-4; `errors_test.go`, `hostile_loader_test.go` (65 cases, 1 s guard); `go/unpack.go` | intake |
| S3 | Many goroutines pack and unpack with one scheme | covered | GO-14; `concurrency_test.go` (8 x 10 000 under `-race`) | intake |
| S4 | Pack fails halfway | covered | GO-15; `invalid_test.go` (nil bytes, field id named); `go/pack.go` | intake |
| S5 | Nil row, nil map or wrong Go type | covered | GO-15; `invalid_test.go`, `TestPackNilSchemeIsRefused`; `go/rows.go` | intake |
| S6 | Rows at the limits and one past | covered | GO-5; `limits_test.go`, `limits_pack_test.go`, `limits_raised_test.go`; `go/limits.go`, `rounds_unpack.go` | intake |
| S7 | Packets of v0.2.2 reach Go | covered | GO-1, GO-7; golden and ring payload hex round trips (`collections_readme_test.go` AC-4) | intake |
| S8 | Typed struct and `map[string]any`, same values | covered | GO-12; `novalue_test.go`, `group_typed_test.go`, `round_typed_test.go`, `nested_test.go` | intake |
| S9 | A bad Go version was tagged | covered | GO-16; ADR-004 (tags never move; retract in the next `go.mod`); `publish-go.sh` | intake |
| S10 | The publish re-runs for the same tag | covered | GO-16; `publish-go.test.sh` AC-3 (same commit passes without a push, another commit fails naming both) | intake |
| S11 | `go get` from the tag | covered | GO-10, GO-11; `publish-go.test.sh` (hermetic), `run-suite.sh` `go_deps`; the live proxy answers only after the first tag (see D9) | intake |
| S12 | Two clients from one seed | covered | GO-6; `session_test.go` AC5 and the C# ciphertext vector | intake |
| D8 | GO-5 says "0 allocations above the slot budget's ceiling": Go's peak memory for the F10 packet and a wide raised-limit unpack is not measured (the tests pass under `-race` in the 7.6 GiB Docker VM; no RSS figure; README says there is none yet) | gap-clear | quote: GO-5 "Unpack fuzzing ... runs ≥ 60 seconds in CI with 0 panics and 0 allocations above the slot budget's ceiling" (`acceptance_criteria.md`) and `_docs/LESSONS.md` 2026-10-12 "A slot budget is a memory ceiling of maxSlots times the per-slot cost ... Change any charge only with a measured worst-case memory A/B": Given the F10 packet (4,259,778 bytes, `maxSlots` 4,194,304) and the default-limit wide round, When unpacked in Go, Then peak RSS is measured and stays at or below `maxSlots x` the measured per-slot cost, and the figure goes into the loop 22 memory table and the README memory bullet | batch discoveries 34, 49 |
| D9 | The first real tag, the live `proxy.golang.org` check and the first Ubuntu CI run (setup-go, `ring-go.sh` with host `go`, the `go` compose service in the scaffold job) | out-of-scope | `problem.md`: "Out of scope ... a release or tag in this loop"; a tag needs the owner's explicit go with the exact commit. Proven hermetically only (`publish-go.test.sh` with real git and a fake `go`) | batch discoveries 45, 52 |
| D10 | The short wave decided on 2026-10-13 (U24 B, U25 A, U26 A, Low-1 A) | out-of-scope | `problem.md`: "Out of scope ... the short-wave rows (U24, U25, U26, Low-1 in the six packages)"; handoff24 | intake |
| D1 | Empty anchored group: its anchor must be the next id but it takes none (`Flags(0, Group(0,"mark")), U8(0,"n")` builds; no `eq` can name the mark); Go copies TypeScript | gap-unclear | see D1 below | batch discovery 12 |
| D2 | `u2` or a `Slot` as a list or dict element: TypeScript builds it (the slot name becomes the element name; with two slots the second reads from the outer row), Go refuses every one | gap-unclear | see D2 below | batch discovery 24 |
| D3 | Slot width of a `Nested` row inside a round: Go charges the width of the row's own members; Java charges a nested-row group 1 slot | gap-unclear | see D3 below | batch discovery 30 |
| D4 | Unpack of a zero-width repeat round (`01ff00` with `repeat { bytes(1,v,0) }`): TypeScript gives the short-packet shape (needed 0, left 1), Go gives `TrailingBytes` left 1 | gap-unclear | see D4 below | batch discovery 33 |
| D5 | A value unpack cannot use: Go (like TypeScript's interim shape) returns a short-packet error with needed 0; `BadValue` exists but only the session returns it | gap-unclear | see D5 below | batch discovery 40 |
| D6 | `run-suite.sh go` fails without `go/go.mod`; the six other branches skip and write a PASS row | gap-unclear | see D6 below | batch discovery 7 |
| D7 | A split flag bit inside a false `when` with the member given: TypeScript packs the bit with no body (`01000306`, repacks `01000206`); Go copies it (Go-3, pinned) | gap-unclear | see D7 below | batch discovery 3 |

### Gaps that need a decision (gap-unclear)

#### D1: Empty anchored group id

**What is not decided**
An empty anchored group (a presence mark under `flags` or a bit) must have its anchor equal the next id, yet takes no id of its own, so the next field reuses that number and no `eq` can name the mark. TypeScript and Go build it; whether the other four packages do, and whether it is intended, was never probed.

**Options**
- **A — keep and document**: it builds in Go as in TypeScript; probe the other four and put the result in the README. Trade-off: a quirk stays.
- **B — refuse at construction in all seven**: one rule, a breaking change for any scheme that uses it. Trade-off: a loop of changes in six packages for a rare shape.

**Recommendation**: A — probe first; it is a Low.

#### D2: `u2` as a list or dict element

**What is not decided**
TypeScript lets a `u2` be the element of a list or dict (the slot name becomes the element name; a two-slot `u2` reads its second slot from the outer row, which is odd). Go refuses every `u2` element. A single-slot `u2` element would be well defined.

**Options**
- **A — keep Go's refusal and document it** (the README row says so); probe the other five.
- **B — allow a single-slot `u2` element in Go**, refuse two or more slots.
- **C — refuse in TypeScript too** (a breaking change).

**Recommendation**: A — nobody asked for it; revisit with a real use.

#### D3: Slot width of a `Nested` row in a round

**What is not decided**
Go charges the width of the nested row's own members against `maxSlots` (a 1000-member row counts 1000, so the memory bound holds). Java charges a nested-row group 1 slot (a documented exception); the other packages charge the names inside.

**Options**
- **A — keep Go's rule** (same as C#, TypeScript, Python, Rust for groups).
- **B — charge 1 like Java**: cheaper rounds, a weaker memory bound.

**Recommendation**: A.

#### D4: Zero-width repeat round shape

**What is not decided**
For a `repeat` whose body can read nothing, TypeScript returns the short-packet shape (needed 0, left 1); Go returns `TrailingBytes` (left 1). Both refuse; the kind differs. The hostile README allows any non-ok result for a case that names no kind.

**Options**
- **A — leave** (accepted difference: test for the failure, not its kind, as since loop 21).
- **B — Go returns the short-packet shape**.

**Recommendation**: A.

#### D5: `BadValue` from unpack

**What is not decided**
Unpack returns a short-packet-shaped error with needed 0 for a value it cannot use (invalid UTF-8, an unreadable count), the interim shape the hostile README allows. Go has an error kind `BadValue` that only the session returns; a Go caller cannot tell "bad value" from "short" without reading `Needed`.

**Options**
- **A — leave the interim shape** (parity with the six; the C15 error-kind decision is still open for all).
- **B — Go returns `BadValue` for these**: more useful in Go, a difference no other package has until C15 is decided for all.

**Recommendation**: A — decide C15 once for all seven.

#### D6: A missing manifest in `run-suite.sh`

**What is not decided**
`run-suite.sh go` fails without `go/go.mod` (a suite that runs nothing must not pass, AC-3 of AZ-2448). The six others skip silently and write a PASS row, so a tree missing `csharp/*.csproj` still passes the suite step.

**Options**
- **A — align the six to Go**: fail when the manifest is missing. Trade-off: AC-15 (a language missing from the tagged tree publishes 0 packages) relies on the skip in the publish gate, not the suite; check `run-suite.test.sh` and the publish tests first.
- **B — leave** and document the difference.

**Recommendation**: A in loop 25, after reading the publish gate; it is the same no-silent-pass rule.

#### D7: Split bit inside a false `when` (Go-3)

**What is not decided**
`u8 k; m; when(k==1){bit m{u8 a}}; bit m{u8 b}` with k=0, a=5, b=6: TypeScript sets a's bit and writes no `a` (`01000306`); unpack reads the packet and the row repacks as `01000206`. Go copies this. Whether the other five do the same, and whether it is a TypeScript bug, was not probed.

**Options**
- **A — probe all six and decide**: if five agree on `01000206`, fix TypeScript and Go.
- **B — leave** as pinned.

**Recommendation**: A — a cross-package probe, then a small task per package that differs.

### Gaps that are clear (gap-clear)

| id | new AC (Given / When / Then) | quoted basis | proposed owner task |
|----|------------------------------|--------------|---------------------|
| D8 | Given the F10 packet (4,259,778 bytes) at `maxSlots` 4,194,304 and the wide-round packet at the defaults, When unpacked in Go, Then peak RSS is measured and is at or below `maxSlots` x the measured per-slot cost; the figure joins the loop 22 memory table and the README memory bullet | GO-5 "0 allocations above the slot budget's ceiling"; LESSONS 2026-10-12 "Change any charge only with a measured worst-case memory A/B" | new Go task in loop 25 (a measurement, 1 point) |

### Not walked

- Windows and 32-bit Go: `go.mod` and `int` ids; no behavior defined (the project targets Linux/macOS services).
- `PackSession` shared across goroutines: documented one goroutine at a time.
- A Go `retract` directive in `go.mod`: only when a bad version exists (ADR-004).
- `json.Unmarshal` maps (all float64): refused for integer fields by Go-2; documented in the README.

### Harness gaps

- Every batch report of this loop has a discoveries table (parts 1 to 6 of batch 01, parts 1 to 5 of batch 02). No completeness report exists for loop 24 (`implement` Step 15 is not part of this loop's plan rows; the review and this assessment cover it).
- The full `publish-gate.test.sh` aborts on this Mac before `phase_checks` (host pip 21.2.4, Apple clang `cstddef`); it runs at step 11 with the AGENT_GOTCHAS recipes.
