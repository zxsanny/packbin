# Loop 25 batch 02 report (wave 2: D1 and D7 probes in five packages, run-suite alignment, README)

Date: 2026-10-14. Wave 1 is `b5c804e`. Five probe workers (one per package: python, rust, csharp, java, cpp) on disjoint trees; AZ-2477 and AZ-2479 were done by the parent in `58d912c`. Package suites only (no per-batch review, owner rule).

## Ticket keys: correction

Specs and the first three commits (`3897c85`, `b5c804e`, `58d912c`) name the tickets **AZ-2452 to AZ-2459**. Those keys were counted on from AZ-2451 without running New Task step 7, and they are existing Jira issues for unrelated work (geofence deletes, emergency frames, the Seq epic). Nothing in Jira was changed under them. The real tickets were created on 2026-10-14 and every file was renumbered in the fix-forward commit that adds this report (the three commit subjects keep the old keys; nothing was pushed):

| Wrong key in commits | Real key | Work |
|----------------------|----------|------|
| AZ-2452 | AZ-2472 | cpp builder id range check (U25 A) |
| AZ-2453 | AZ-2473 | C# nested dictionary names (U26 A) |
| AZ-2454 | AZ-2474 | Python ValueError text (Low-1 A) |
| AZ-2455 | AZ-2475 | Go peak memory (D8) |
| AZ-2456 | AZ-2476 | D1 probe, empty anchored group |
| AZ-2457 | AZ-2477 | run-suite.sh missing manifest (D6 A) |
| AZ-2458 | AZ-2478 | D7 probe, split flag bit in a false `when` |
| AZ-2459 | AZ-2479 | README, C++ unbound member (U24 B) |

Lesson: a ticket key comes from the tracker, never from counting; the project's Jira project is shared with other repositories.

## Workers

| Worker | Result |
|--------|--------|
| python | `python/tests/test_loop25_probe_d1_d7.py`, 8 tests; pytest 1494 passed, 0 failed; no `src` change |
| rust | `rust/tests/loop25_probe_d1_d7_tests.rs`, 13 tests, `rustfmt --check` clean on the new file; `cargo test` 686 passed, 0 failed, 0 warnings; no source change |
| csharp | `csharp/tests/Loop25ProbeD1D7Tests.cs`, 18 tests; `dotnet test` 2003 passed, 0 failed; no `src` change |
| java | `Loop25ProbeD1D7Test.java` (9 methods) and one line in `PackbinTest.java`; the Java suite passes (2586 checks, 46 new); no source change |
| cpp | `loop25_probe_d1_d7_host_tests.cpp` (6 functions), registered in `cpp/Makefile` and `main.cpp`; host and `gcc:16` suites pass; mutation check (4 wrong hex values gave 12 failures); `cpp/src` and `cpp/include` untouched, so the arm stage was not needed (margins stay flash 40 B, stack 56 B) |

Parent checks: `git diff --cached` empty after each join; every edit is inside the worker's package.

CI-parity: PASS — `report-row.test.sh`, `run-suite.test.sh` (new cases mutation-checked against the old script: every bare tree passed before, fails now), `ring-wiring.test.sh`, `fixtures/hostile/cases.test.sh` all rc 0; each package's own suite as listed. The seven-suite compose run and `publish-gate.test.sh` run once at step 11.

Worker slips: none.

## D7: split flag bit inside a false `when`, member given (`k=0, a=5, b=6`)

TypeScript: pack `01000306`; unpack gives `{k:0, b:6}`; repack gives `01000206`; with `k=1` pack `0101030506`.

| Package | Pack k=1 / k=0 | Unpack | Repack | Result |
|---------|----------------|--------|--------|--------|
| Python | same | same | same | matches |
| Rust | same | same (no `a`) | same | matches (the `when` anchor is 2, not 1: Rust counts the flag byte, an id model that was already in place) |
| C# | same | same (dictionary and typed) | same | matches |
| Java | same | same | same | matches |
| C++ | same | same | same | matches |

No walker fix was needed in any package; the rows are pinned in each suite. D7 is closed: the Go copy of TypeScript (Go-3) is the behavior of all seven.

## D1: empty anchored group (`Flags(0, Group(0,"mark")), U8(0,"n")`)

TypeScript: `{mark:true}` `0101`, `{mark:false}` `0100`, split form `010303`, handoff row `{mark:true, n:3}` `010103`, `{n:1}` `010001`, `{}` RangeError "missing n", and a `when` that names the empty group is refused at construction.

| Package | Bytes | Where it differs from TypeScript (pinned in a `..._differs_from_typescript` test, no code change) |
|---------|-------|------------------------------------------------------------------------------------------------|
| Python | none: construction refuses `group 0 has no fields, so it can never carry a value` for all four schemes | the API has no accessor for an anchored group; documented (README line on empty groups) |
| Rust | equal on every row | the empty group takes an id slot like a flag byte: `U8` after it must be id 1 (id 0 panics `field id 0 is not the next order 1`, TypeScript takes 0 and refuses 1); a `when` that names the mark builds and packs `010107` / `0100` where TypeScript refuses; the map form has no bool, the mark is `U8(1)` / `U8(0)` / absent |
| C# | equal on every row, dictionary and typed | none (error wording differs, as everywhere) |
| Java | equal on the set rows (through `group(Access.get, Access.set)`; the anchored `group(0)` with no accessor is refused, AZ-2131) | `Boolean.FALSE` packs `0101` (TypeScript `0100`) and the handoff row with mark false `010103` (`010003`); unpack gives `{mark:{}}`; `flags(0, group(0))` is refused; error wording differs |
| C++ | equal on every row (`group<&Row::mark>(id)` on a `bool`) | a `when` that names the empty group builds (`010107` / `0100`); documented in the README (the empty group takes the id of the field after it) |

D1 is closed as decision A (keep, document). Step 13 puts the Rust, Java and Python differences into the README beside the existing C++ line. No Bug ticket: none of these is a hex difference on a row TypeScript packs.

## Discovered during implementation

| # | Spec ref | Finding | Proposed handling | Status |
|---|----------|---------|-------------------|--------|
| 1 | AZ-2477 | `run-suite.sh` is one script with six `if` branches, not six wrappers; the spec's ownership list and its AC-15 wording task were wrong. `publish-gate.sh` decides `absent <lang>` itself and no publish script calls `run-suite.sh` | spec amended; one sentence in `ci_cd_pipeline.md` | clear |
| 2 | AZ-2477 | TypeScript's branch runs `bash -lc` and cannot take a fake `npm`, so only csharp, rust, cpp and java have a positive fake-tool test | the compose run at step 11 runs TypeScript for real | clear |
| 3 | AZ-2479 | The README bullet "Open rows (loop 24)" held exactly the four decided rows; it now records the U24, U25, U26 and Low-1 outcomes and the Go memory figures | done in `58d912c` | clear |
| 4 | AZ-2476 | Java: `Boolean.FALSE` for an empty-group mark packs the set bit (`0101`) | README line at step 13; ask the owner at the assessment whether to align | unclear, owner? |
