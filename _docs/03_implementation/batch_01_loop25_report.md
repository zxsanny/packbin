# Loop 25 batch 01 report (wave 1: cpp range check, csharp nested dict names, python ValueError, go peak memory)

Date: 2026-10-14. Intake `3897c85`. Four workers on disjoint package trees; package suites only (no per-batch review, owner rule).

| Worker | Spec | Owns | Result |
|--------|------|------|--------|
| cpp | AZ-2452 | `cpp/include/**`, `cpp/src/**`, `cpp/tests/**` | host suite and `gcc:16` suite pass; arm embedded stage PASS, vectors 241 of 241, **flash 8152 of 8192 B (margin 40 B), stack 456 of 512 B (margin 56 B): both unchanged**. Source diff is `table.hpp` +5 and `fields_counted.hpp` +4; new `builder_id_range_host_tests.cpp` (9 test functions) |
| csharp | AZ-2453 | `csharp/**` | `env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo`: 1985 passed, 0 failed (baseline 1978) |
| python | AZ-2454 | `python/src/**`, `python/tests/**` | pytest 1486 passed, 0 failed (baseline 1476) |
| go | AZ-2455 | `go/mem_test.go` | `-tags packbin_memtest` run PASS; default `go test -race` ok, `gofmt -l` and `go vet` clean |

Parent checks: `git diff --cached` empty after each join; every worker edit is inside its owned tree.

CI-parity: PASS — `report-row.test.sh`, `fixtures/hostile/cases.test.sh`, `run-suite.test.sh`, `cpp/embedded/lib.test.sh`, `ring-wiring.test.sh` (all rc 0); each changed package's own suite as listed above (cpp also through `gcc:16` and the arm stage). The seven-suite compose run and `publish-gate.test.sh` run once at step 11.

Worker slips: none.

## Parent rework on the cpp tests (not a slip)

The first AZ-2452 tests passed without the range check: `packed(.., 32768)` wraps negative, `times(.., 70000)` and `sized(.., 65537)` wrap to ids another rule refuses, and `when(65536, ..)` is refused first by the anchor-equals-first-child rule (loop 22 lesson: a hostile case refused by another rule passes for the wrong reason). The worker replaced them with ids that wrap to a valid field and gave each a control that builds, then proved it by mutation in a scratch copy: both hunks reverted gives 21 failures, only `leaf` reverted gives 8 (AC-2, AC-3), only `counted_leaf` reverted gives 13 (AC-1). Boundary pair 32767 builds and 32768 is refused is pinned on the node through `check_shape`, because a full scheme with id 32767 needs 32 768 fields.

## Figures for the docs (step 13)

| Shape | Go peak (`HeapAlloc`, one run, ±10 %) |
|-------|----------------------------------------|
| F10 at `MaxSlots` 4 194 304 (packet 4 259 778 B) | **625 MB** (TotalAlloc 1 063 MB) |
| Wide round at the default limits, 1 048 320 slots (packet 1 048 325 B) | **94 MB** (TotalAlloc 92 MB) |

Both agree with the F41 audit figures (about 624 MB; about 105 MB per MiB). The Go row goes into the loop 22 memory table and the README memory bullet at step 13. The test is behind the build tag `packbin_memtest` so the CI run time does not change; run it with `go test -tags packbin_memtest -v -run TestMem -count=1 ./...` in `golang:1.27`.

## Discovered during implementation

| # | Spec ref | Finding | Proposed handling | Status |
|---|----------|---------|-------------------|--------|
| 1 | AZ-2454 | The real TypeScript text is `<label>: count <id> was not written` (`typescript/src/written.ts`), not a `pack.ts` text. The spec's AC-1 scheme shorthand (`times(1, "n"), u8(0, "n"), u8(2, "x")`) is rejected by Python's validator (a count must be declared earlier); the tests use the `when`-holds-the-count pattern of AZ-2386 and AZ-2410 | spec wording corrected here; `_borrowed` now splits "None means not written" from "non-int" | clear |
| 2 | AZ-2454 | Four existing Python test files asserted `RuntimeError` / `is missing` and were updated to `ValueError` / `was not written` | follows from the change | clear |
| 3 | AZ-2452 | `Result::field` is the wrapped int16 id, so the error for `when(65537, ..)` names field 1, not 65537 (the original 32-bit input cannot ride the error path) | document; naming the original needs a `cpp/include` change and arm margin (40 B) | unclear, owner? |
| 4 | AZ-2452 | `bits(1, 32768)`, `bits(1, 65535)` and `bits(1, -2)` were silent "no count" builds before; they are now refused. Only `-1` is the sentinel | covered by tests; README note at step 13 | clear |
| 5 | AZ-2453 | U26 A applies to **unpack too**: a dictionary row comes back with the nested-row group nested (`Row: [{V:7},{V:8}]`, was flat `V: [7,8]`), as Go-4 ("nested maps both ways"). Breaking for callers that read the flat shape | README C# note and the C# row of the Go-4 text at step 13; ask the owner at the assessment if the handoff meant pack only | unclear, owner? |
| 6 | AZ-2453 | `Ac1_Repack_TypedListObjectOfNestedGroupElements` asserted a throw (no wrong bytes) and now round-trips: `PackGroup` accepts any `IReadOnlyDictionary` as the inner shape | improvement; test renamed | clear |
| 7 | AZ-2453 | Existing parity tests kept their expected hex and only wrapped the dictionary inputs, so the TypeScript-derived constants still hold; the new AC-1 hex `010701` is the worker's manual computation, not a TypeScript run | the step 11 parity run covers it; probe it in TypeScript at step 11 if a gap shows | clear |
| 8 | AZ-2455 | `wideRound(t)` in `go/limits_pack_test.go` needs raised limits; a sibling `wideRoundNearOneMiB` (n = 16 128) keeps the AC-2 run at the defaults | none | clear |
| 9 | wave 2 | AZ-2456 and AZ-2458 both name the parity doc as owned; workers write probe tests only and report hex rows, the parent writes the doc rows | spec ownership amended in plan25 | clear |
