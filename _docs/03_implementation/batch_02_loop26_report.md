# Batch 2 report — loop 26

Tasks: AZ-2514 (Swift scheme construction checks and the anchored group, 5 points; stream A, `swift/**`) and AZ-2521 (Swift in the CI suite, 3 points; stream B, CI files), in parallel with disjoint write sets. No per-batch review (owner preference).

| Task | Status | Evidence |
|------|--------|----------|
| AZ-2514 | Done | 4 of 4 ACs; 82 tests in 17 suites (parent re-run: pass), strict release build 0 warnings, thread sanitizer 0 reports (worker), 24 of 24 mutation proofs red, about 110 TypeScript rows probed. |
| AZ-2521 | Done | AC-1 to AC-4 wired; `run-suite.test.sh` and `report-row.test.sh` pass (parent re-run); `docker compose config` for both files exit 0; 31 of 31 mutation proofs red. Commit `c687e75`. Real container runs (`swift:6`, `swift:5.9`, sanitizer, Linux speed) are not run here: the first CI run proves them. |

CI-parity: no change in what CI runs for the other languages; the Swift suite commands were run locally (`swift build -c release -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete`, `swift test`) with the Mac flags of `AGENT_GOTCHAS.md`.

## Decisions taken by the parent

- `publish-pins.test.sh` `PINS_NAMES` now lists `swift` and `swift-min` (the new image pins), committed with AZ-2521.
- The 5.9 compile is the service `run-suite.sh swift-min`, run right after `swift` in the scaffold loop (a `swift:6` container cannot start `swift:5.9`): two Swift report rows per CI run (accepted).
- `scripts/loop-tests.sh` Swift stage: a parent task before step 11 (plan26 § Carried from wave 2).

## Discovered during implementation

| # | Spec ref | Finding | Proposed handling | clear/unclear |
|---|----------|---------|-------------------|---------------|
| 1 | AZ-2514 AC-4 | A group is a nested `[String: Any]` both ways; a flat key naming a member of a group not given is refused (owner ruling, Go-4 A). Hex equals TypeScript for the nested form | keep; AZ-2520 lists it | clear |
| 2 | AZ-2514 Scope | Round-nesting and count-id checks wait for the kinds | AZ-2515 (written into its spec) | clear |
| 3 | AZ-2514 Scope | Element-kind check waits for list/dict | AZ-2516 (written into its spec) | clear |
| 4 | AZ-2514 AC-1 | `Condition.eq` takes only integers and `Bool`: TypeScript float/string/null eq values cannot be written in Swift; `Int128` wider than 64 bits refused with TypeScript's text | keep the typed API | clear |
| 5 | AZ-2514 | A mark given `1` in a map is refused (TypeScript leaves the bit clear): extends Go-1 B to empty-group marks | keep; AZ-2520 lists it | clear |
| 6 | AZ-2514 | A short packet in a flags member inside a group reports the anchor field id (TypeScript reports an empty name), as Go | keep | clear |
| 7 | AZ-2521 | Dependency check allows 0 or 1 direct dependency until AZ-2518 adds `swift-crypto` | AZ-2518 switches it to exactly one | clear |
| 8 | AZ-2521 | CI fuzz step needs a `FuzzTests` suite reading `PACKBIN_FUZZ_SECONDS` | written into AZ-2517 | clear |
| 9 | AZ-2521 | Thread sanitizer under Docker on `ubuntu-latest` may need `vm.mmap_rnd_bits=28`; scaffold job 60 min limit may be tight; SwiftPM cache path and `--force-resolved-versions` on 5.9 unproven | first CI run; loop 27 handoff | unclear |
