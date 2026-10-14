# Autodev Loop Plan — Loop 26

loop: 26
kind: product
confirmed: true
branch: dev
ship: false

Loop works on `dev` in this session (no worktree). Intake: `_docs/loops/loop25/handoff26.md`; feature `_docs/02_task_plans/swift-package/` (problem, SW-1 to SW-16, S1 to S12, `task_map.md`); epic AZ-2223, children AZ-2513 to AZ-2524 (47 points). Owner decisions 2026-10-14: G1 A, D1b A, P1 A (F44 stays with the owner); S-1 to S-5; five rulings (group map nested both ways, NFC/NFD dict keys refused, Foundation `NSNumber` Bool/integer refused, `swift:5.9` compile step, Go added to the pack-session Consumers line). Owner preferences unchanged (memory `one-total-review-and-test`, `noninteractive-subagent-commands`, `long-runs-visible-status`, `decision-batches-accept-recommended`): workers run only their own suite; no per-batch review or Docker run; one total review and one step-11 run through `scripts/loop-tests.sh` at the end (check `uptime` and swap first); no chained feature-assess rounds; shell-hygiene paragraph (`< /dev/null`), index-write ban and "no formatter or linter on files you do not own" in every worker prompt; the parent checks `git diff --cached` and `ps` after each join.

## Scope

Specs claimed (`loop: 26`): AZ-2513 to AZ-2524. AZ-2068 stays out. F44 (owner-only) and the first tag are not in this loop.

| id | points | writes | source |
|----|--------|--------|--------|
| AZ-2513 | 5 | `swift/**`, `Package.swift`, `.gitignore` | core: manifest, scalars, flags, when, errors, typed and map rows |
| AZ-2514 | 5 | `swift/**` | scheme construction checks, anchored group |
| AZ-2515 | 5 | `swift/**` | rounds and counted kinds |
| AZ-2516 | 5 | `swift/**` | strings, lists, dicts, nested rows |
| AZ-2517 | 3 | `swift/**`, `fixtures/hostile/fuzz/**` | limits, pack budgets, fuzz corpus |
| AZ-2518 | 5 | `swift/**`, `Package.swift`, `Package.resolved` | PackSession, in-package ChaCha20 |
| AZ-2519 | 3 | `swift/**`, `fixtures/hostile/check-cases.sh` (+ test), `README.md` pack sections | hostile vectors, eight-package checker |
| AZ-2520 | 3 | `swift/**` | parity rows |
| AZ-2521 | 3 | `run-suite.sh` (+ tests), `test.yml` scaffold job, both compose files, `report-row.test.sh` | CI suite, `swift:5.9` compile step |
| AZ-2522 | 3 | ring files, `drivers/handoff-swift/`, `ring-swift.sh`, `language-pair.sh`, `ring-toolchains.sh`, new Swift wiring test, `test.yml` ring job | ring |
| AZ-2523 | 5 | publish scripts and tests, ADR-005, `module-layout.md` Swift lines | release, golden gate, consumer resolve |
| AZ-2524 | 2 | `README.md`, `architecture.md`, `pack-session.md`, `swift/Tests` example test | README |

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | P0 `/problem` + `/new-task` ran at intake |
| decompose-feature | 9.5 | Decompose Feature | no | done at intake (commit `5b906c7`): 12 specs, layout, risks |
| implement | 10 | Implement | yes | two streams, see `## Implementation` |
| code-review | — | Total review | yes | one total review at high effort over `b81102f..HEAD`, **before** step 11 so its fixes are in the one test run |
| feature-assess | 10.5 | Feature Assessment | yes | once, read-only; open rows go to the loop 27 handoff |
| run-tests | 11 | Run Tests | yes | one total run: `scripts/loop-tests.sh --plan`, then the run (Swift suite, other seven, hostile, ring, publish-gate tests) |
| test-spec-sync | 12 | Test-Spec Sync | yes | traceability rows for SW-1 to SW-16 |
| update-docs | 13 | Update Docs | yes | `architecture.md`, component docs, README Swift section (AZ-2524 owns the README text) |
| security | 14 | Security Audit | yes | hostile input in a language that traps, ChaCha20 written in-package, the release resolve check |
| performance | 15 | Performance Test | no | AC-10 is asserted inside AZ-2513/AZ-2521 |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | no tag; the first Go and Swift tags need the owner's go and the F44 ruleset |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | 47 points, new language |
| local-deploy | — | Local deploy + open site | yes | no site: suites, ring and gate tests are the local run |
| smoke | — | Smoke acceptance | yes | one-paste script `smoke26.md`, run by the agent at the commit before the close commit |

## Implementation

### Files that change (ownership tiers)

- `swift/**`, `Package.swift`, `Package.resolved`: one writer at a time (stream A). SwiftPM locks `.build`, so no two workers run `swift build` or `swift test` at once in the root tree.
- Shared CI/ring/publish/docs files are stream B (disjoint from `swift/`): AZ-2521 (`run-suite.sh` and its tests, `test.yml` scaffold job, compose files, `report-row.test.sh`), then AZ-2522 (ring; its `test.yml` edit is the ring job only), then AZ-2523 (publish scripts, ADR-005).
- `README.md` is shared by AZ-2519 (hostile pack sections / checker) and AZ-2524: they run in different waves, never together.
- Parent-only: `_docs/**` except the files the specs name, tracker, commits, the reviews.

### Order of work

Workers: one `general-purpose` agent per task; brief carries ticket id, spec path, Owns, Forbidden, "no commit, no tracker, no compose rebuild", test command for its task only. Swift 6.3.3 is installed: `swift test` at the repository root (`swift test --sanitize=thread` where the spec says); Linux and `swift:5.9` runs only in AZ-2521's checks. TypeScript is the reference: each worker probes TypeScript (`node --experimental-strip-types`) before pinning a row, and asks each refusal test for a mutation proof.

- Wave 1: AZ-2513 alone (defines the API every later task builds on).
- Wave 2: AZ-2514 (stream A) ‖ AZ-2521 (stream B).
- Wave 3: AZ-2515, then AZ-2516, then AZ-2517, then AZ-2518 (stream A, one after another); stream B idles until AZ-2518 is joined.
- Wave 4: AZ-2519 → AZ-2520 (stream A) ‖ AZ-2522 (stream B, after AZ-2518).
- Wave 5: AZ-2523 (stream B, after AZ-2521 and AZ-2522; stream A finished).
- Wave 6: AZ-2524.
- Then: total review, feature-assess, step 11, 12, 13, 14, 17, close.

### Proof

Each task's own ACs and test table; the one total run is `scripts/loop-tests.sh`. Swift pins SW-1 to SW-16 as `task_map.md` assigns them.

Decision 2026-10-14 (owner, after the waves): Swift 6 only. `Package.swift` is `swift-tools-version: 6.0` (Swift 6 language mode), swift-crypto 4.3.1; the `swift-min` service, its 5.9 compile step and its loop-tests stage are removed; the CI image is `swift:6.3.3` (`swift:6` is not a Docker Hub tag). The wave-2 notes below are kept as history.

### Carried from wave 2 (parent decisions, 2026-10-14)

- AZ-2521 split the 5.9 compile into its own service `run-suite.sh swift-min` (accepted: a `swift:6` container cannot start `swift:5.9`); two Swift report rows per CI run.
- `scripts/loop-tests.sh` (AZ-2500) has no Swift stage yet: a small parent task before step 11 adds stages and change detection for `swift/**`, `Package.swift`, and the `swift` and `swift-min` services (no ticket needed beyond AZ-2521's scope note; commit under AZ-2521).
- The dependency check allows 0 or 1 direct dependency until AZ-2518 adds `swift-crypto`; AZ-2518 then switches it to exactly one (one line in `run-suite.sh`).
- First-CI unknowns (cannot be run here): thread sanitizer under Docker on `ubuntu-latest` (`vm.mmap_rnd_bits`), the scaffold job's 60-minute limit, the SwiftPM cache path, `Foundation` Bool/integer split on Linux. Recorded for the loop 27 handoff.

### Risks

- Swift traps on hostile input (High): each worker uses checked arithmetic and bounds-checked reads; AZ-2517 and AZ-2519 count traps; the thread-sanitizer and fuzz runs prove it in CI.
- The serial `swift/` chain is the long pole (AZ-2513 to AZ-2520, 32 points); stream B overlaps it.
- `ring-wiring.test.sh` is at the 500-line cap: the Swift guards go in a new sibling file (decided).
- A worker's Swift disagreement with TypeScript is reported to the parent, not decided inside the task.

## Assessment rounds

None yet.
