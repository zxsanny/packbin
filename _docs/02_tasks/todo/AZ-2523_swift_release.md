---
loop: 26
branch: dev
---

# Swift release: ADR-005, golden gate and the consumer resolve check

**Task**: AZ-2523_swift_release
**Name**: Swift release: ADR-005, golden gate and the consumer resolve check
**Description**: A version tag whose eight languages match the golden bytes is resolved by `swift package resolve` and built in a throwaway consumer at exactly that version; a Swift mismatch publishes 0 packages; no tag is created, moved or deleted.
**Complexity**: 5 points
**Dependencies**: AZ-2521, AZ-2522
**Component**: swift
**Tracker**: AZ-2523
**Epic**: AZ-2223

## Problem

Swift has no registry; Swift Package Manager fetches it from the existing `vX.Y.Z` tag through the root `Package.swift` (S-1, S-3). ADR-002 names six registry packages and ADR-004 adds the Go tag (fit decision 1), and the gate is all-or-nothing (fit decision 2), so Swift must join the gate, and the release must prove a consumer can resolve and build the tag.

Feature ACs and scenarios: `_docs/02_task_plans/swift-package/` (owns SW-10, SW-16; scenarios S9, S10, S11 owned).

## Outcome

- ADR-005 (Accepted): Swift installs from the root `Package.swift` at the `vX.Y.Z` tag, after the same golden gate; it amends nothing (ADR-002 and ADR-004 stay as written).
- `publish.yml` runs the Swift golden check in the gate and, after the gate and the uploads, `publish-swift.sh`: `swift package resolve` and a build in a throwaway consumer that depends on `https://github.com/zxsanny/packbin` at exactly `X.Y.Z`.

## Scope

### Included

- `language_present swift` (`Package.swift` and `swift/`); Swift in `PACKBIN_LANGS` and the gate (`publish-position.sh swift` via the AZ-2522 position program in the `swift` compose container); a `swift-check` target with no upload: the consumer resolve and build, retried for up to 30 minutes, which checks that the resolved revision is the `vX.Y.Z` commit; the root `LICENSE` MIT check; the publish tests (new sibling `publish-swift.test.sh`; `publish-phases.test.sh` is over 500 lines and `publish-gate.test.sh` is at 496, so neither grows).
- ADR-005, the ADR index, and the `module-layout.md` Swift lines (the Swift block written at decompose 1.5 stays; this task adds the Swift CI, ring and publish line beside the Go one).
- Owns (exclusive write): `_docs/02_document/adr/005_*.md`, `_docs/02_document/adr/README.md`, `_docs/02_document/module-layout.md` (Swift lines), `.github/workflows/publish.yml`, `publish-lib.sh`, `publish-gate.sh`, `publish-position.sh`, `publish-registries.sh`, `publish-build.sh`, `publish-upload.sh`, `publish-check.py` (each: the swift target's branch only), a new `publish-swift.sh`, a new `publish-swift.test.sh`, the seven-language lists in `publish-gate.test.sh` (replaced, not grown), `publish-readonly.test.sh` (`RO_SERVICES` gains `swift`: the `swift` service in `docker-compose.publish.yml` exists since AZ-2521), `publish-rerun.test.sh`

### Excluded

- Pushing any real tag in loop 26; a Swift Package Index listing (S-3)
- Creating, moving or deleting any tag, in any loop

## Acceptance Criteria

**AC-1: Gate includes Swift (SW-10)**
Given a tree where Swift's position program prints a wrong byte
When `publish-gate.sh` runs
Then it prints the mismatch and publishes 0 packages, 0 Go tags, and runs no Swift check

**AC-2: Consumer resolves the tag (SW-10, S11)**
Given a passing gate for `vX.Y.Z` and a local bare repository holding the tag (dry run in tests)
When the publish runs
Then the throwaway consumer (`.package(url:, exact: "X.Y.Z")`) resolves the `vX.Y.Z` commit and builds `Packbin` on Linux; against GitHub the check retries for up to 30 minutes, then fails the step

**AC-3: Re-run and tags never move (SW-16, S9, S10)**
Given a re-run of the publish for the same `vX.Y.Z`, and a tag that resolves to a commit other than the workflow's
When the Swift check runs
Then the re-run resolves the same commit and passes; the other commit fails naming both commits; in both cases the refs of the bare repository are unchanged (tag pushes, moves and deletes 0); a bad version is fixed by the next patch, as ADR-005 states

**AC-4: Absent Swift (SW-10)**
Given a tree without `Package.swift` or without `swift/`
When the gate runs
Then `absent swift`; the Swift check is skipped; the other packages and the Go tag publish as before

**AC-5: ADR and manifest (SW-10)**
Given ADR-005 and the root `Package.swift` and `LICENSE`
When read
Then ADR-005 Status Accepted; it states the install line, the gate rule, that no Swift tag exists and that tags never move; `swift-tools-version: 5.9`, iOS 15, macOS 12; `LICENSE` MIT; non-MIT identifiers 0

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1..4 | `publish-swift.test.sh` scenarios against a local bare repository | as stated |
| AC-5 | ADR and manifest checks | as stated |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | `publish-gate.test.sh` | the full gate test | passes with eight languages | AC-12, AC-14, AC-15 |

## Constraints

- ADR-001 (own walker), ADR-002 and ADR-004 (gate, tag layout) stay as written; ADR-005 amends nothing.
- The workflow never writes a tag: the Swift check only reads (resolve, build). The dry run uses a local bare repository; no tag is pushed in loop 26 (S-5).
- The consumer build runs in the `swift` container of `docker-compose.publish.yml` (read-only repository mount) or with Swift on the runner; any new `uses:` is pinned to a commit SHA.
- Every shell step ends on its own (stdin closed, bounded time).

- From AZ-2521 (loop 26), files this task also owns: `publish-lib.sh` `PACKBIN_LANGS` and `publish-readonly.test.sh` `RO_SERVICES` (the `swift` and `swift-min` services exist in both compose files, `/src` read-only), the CI line for Swift in `_docs/02_document/module-layout.md`. `publish-pins.test.sh` already lists the `swift` and `swift-min` image pins (parent, 2026-10-14). The 5.9 compile step is a second service `run-suite.sh swift-min`, not a step inside `swift` (a `swift:6` container cannot start `swift:5.9`), so a CI run writes two Swift report rows.

## Risks & Mitigation

**Risk 1: A bad root manifest breaks every consumer**
- *Risk*: `Package.swift` at the root is what `swift package resolve` reads for every Swift consumer; a bad one passes the Swift suite only if CI builds from a different entry.
- *Mitigation*: The consumer check resolves through the URL at the tag, exactly as an app would; CI builds the root manifest on every push (AZ-2521).

**Risk 2: Consumer resolve time**
- *Risk*: The resolve fetches `swift-crypto` and builds it on Linux, adding minutes to the publish.
- *Mitigation*: The 30-minute window bounds it; the check is the last step and gates no upload.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| F44 (tag ruleset on `v*`) is the only guard against a moved tag outside the workflow | owner applies it in repository settings before the first tag | open | Medium |
| The consumer check proves Linux; a macOS consumer build is not in CI (no Apple-platform job, out of scope) | macOS build is proven on the owner's Mac by AZ-2513; parent confirms | accepted-risk | Low |
