# Feature: Swift package (AZ-2223, loop 26)

An eighth language package, `swift/` (library target `Packbin`, manifest `Package.swift` at the repository root), hand-written in Swift (ADR-001: no shared walker, no generator, no wrapper of the C++ core). It packs and unpacks the same bytes as the seven packages for every feature they share (wire format, schemes and dispatch, strings/lists/dicts, rounds and limits, hostile vectors, `PackSession`), takes rows as typed structs bound by getter/setter closures or as `[String: Any]`, throws a typed error and never traps on hostile input. Swift joins the CI suite (`swift:6`), the language-pair ring (every kind, both ways), the golden gate of the publish, and installs through Swift Package Manager from the existing `vX.Y.Z` tag. Problem, decisions S-1 to S-5, ACs SW-1 to SW-16: `problem.md`, `acceptance_criteria.md` in this folder.

## Scenarios

See `scenarios.md` (S1 to S12, all `confirmed`; AC refs SW-1 to SW-16).

## Complexity (New Task Step 2)

13 points or more (Scope high: shared CI, ring, publish gate, README, hostile checker plus a new package; Novelty medium: Swift traps on overflow, `Package.swift` at the root, swift-crypto on Linux; Risk high). Routing: mandatory `/decompose --feature` (`protocols.md` § New Task complexity gate). The Go epic is the size reference (12 tasks, 45 points).

## Codebase analysis (Step 4, reads only)

- Insertion points: new `swift/` and root `Package.swift`; `.github/workflows/` (`run-suite.sh swift`, `test.yml`, `language-pair.sh` + a `ring-swift.sh` and `drivers/handoff-swift/`, `ring-toolchains.sh`, `publish-gate.sh` golden check, `publish.yml` Swift resolve step, `tool-pins.txt`); `docker-compose.test.yml` (+ `docker-compose.publish.yml`); `fixtures/hostile/check-cases.sh` and the README pack sections (eight names); `README.md`.
- Contracts and layout: `contracts/library/` gets a Swift consumer line; `module-layout.md` gets a `Component: swift` block and the packages table row; `components/08_swift_package` (decompose 1.5); ADR-005 (Swift installs from the root `Package.swift` at the `vX.Y.Z` tag) aligned with ADR-001 (own walker) and ADR-002/ADR-004 (gate, tag layout). No ADR conflict.
- Reference: the TypeScript tests (`typescript/tests/` parity tables) and the Go package (`go/`, 15 k lines incl. tests) for structure and the task split.
- Seams (Step 4.6): Swift ↔ ring (15 kinds × 7 languages, both ways), Swift ↔ golden gate (all-or-nothing), Swift ↔ hostile checker (eight names, whole-word match), Swift ↔ session (C# ciphertext, RFC 8439). `interaction-risks.md` is updated by the owning tasks.

## Fit decisions

| card | collision | chosen option |
|------|-----------|---------------|
| 1 | ADR-002 and ADR-004 name six registry packages plus a Go tag | A — new ADR-005 "Swift installs from the root `Package.swift` at the `vX.Y.Z` tag", no extra tag |
| 2 | The golden gate is all-or-nothing | A — Swift joins the gate: a Swift mismatch publishes 0 packages |
| 3 | Ring kinds run in different language subsets | A — Swift joins each kind's ring both ways with every member |
| 4 | Where the seven packages differ, which does Swift copy | A — TypeScript at HEAD, except documented TypeScript-only exceptions (U6), where Swift follows the others |
| 5 | `check-cases.sh` counts seven names | A — checker, the README pack sections and the Swift hostile loader in one task; whole-word match |

## Assumptions confirmed (new-task Step 5, auto-applied 2026-10-14)

1. TypeScript is Swift's row-for-row reference (card 4); D1b rows stay as documented.
2. `components/08_swift_package` and a `module-layout.md` Swift block are added by decompose 1.5.
3. One worker writes in `swift/` at a time; shared CI, ring and publish files go to separate workers once the Swift API exists (disjoint file sets, parent owns tracker, commit and the single total review and test run).
4. No tag is pushed in loop 26; SW-10 is proven by the publish tests and a dry run against a local bare repository.
5. Rows are typed structs bound by getter/setter closures plus a `[String: Any]` map form; `nil` is no value, an empty array is a value with 0 items.
6. Jira: epic AZ-2223 exists; decompose creates the child tickets (one per task) before any spec names a key.
