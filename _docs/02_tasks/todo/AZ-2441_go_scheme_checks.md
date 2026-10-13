---
loop: 24
branch: dev
---

# Go scheme construction checks and the anchored group

**Task**: AZ-2441_go_scheme_checks
**Name**: Go scheme construction checks
**Description**: Go refuses every scheme the TypeScript package refuses at construction, with an error naming the field.
**Complexity**: 5 points
**Dependencies**: AZ-2440
**Component**: go
**Tracker**: AZ-2441
**Epic**: AZ-2222

## Problem

A scheme that the other packages refuse at construction (gaps, repeated ids, a flag bit read before its byte, a `when` naming a later field, ...) must not build in Go, or Go would pack bytes no other language reads.

Feature ACs and scenarios: `_docs/02_task_plans/go-package/` (GO-2, GO-3 (construction rows)).

## Outcome

- Every construction refusal of TypeScript (`components/02_typescript_package/description.md` §2, `scheme`) is a construction error in Go naming the id.
- Every README scheme builds.

## Scope

AZ-2440 already has: eq id declared earlier in the same scope, flag bit with no flag byte earlier, ninth bit (combined and split), nil field, constructor refusals, mixed `Bind` — extend these, do not rewrite.

### Included

- The anchored `group` kind (`Group(anchor, name, members...)`, reserved in `go/doc.go`): pack and unpack as a `flags` member, a flag-byte bit and wherever TypeScript allows it, typed and map rows, flag-group presence (TypeScript `flag-group-presence`, `nested-group` rows that need no rounds or collections); added in batch 01 (discovery 6: no task owned it).
- Type number outside 0..255; id gap, repeated id, negative id (U25 for Go); anchor that is not the next value id; flag bit whose byte is not read earlier in the same scope; bool or empty group outside flags/flag-byte bit; `eq`/count id that is not an earlier field of the same scope; `eq` value its source can never hold; member-name collisions; a `repeat`/`times` inside a round; anchored group as list/dict element (the check only; elements come in AZ-2443); nine `flags` members.
- Owns (exclusive write): `go/**`

### Excluded

- Rounds and collection walking (AZ-2442, AZ-2443)

## Acceptance Criteria

**AC-1: Refusals**
Given each refusal row of the TypeScript construct tests (`scheme`, `scheme-constructor`, `reference-scope`, `flag-scope`, `split-bits-field-order`, `duplicate-names`, `eq-source-kinds`, `eq-value-checked`, `int-range` construct rows)
When the Go scheme is built
Then an error value naming the field id; no panic; refused-vs-built disagreements with TypeScript 0

**AC-2: README schemes build**
Given every scheme in README.md
When built in Go
Then built; errors 0

**AC-3: Negative ids**
Given a field id, count id or `eq` id below 0
When built
Then refused naming the id (U25 A, Go `int` ids)

**AC-4: Anchored group**
Given the TypeScript `flag-group-presence` rows and the `nested-group` rows without rounds or collections
When packed and unpacked in Go (typed and map)
Then the same hex or refusal as TypeScript; an empty group is refused at construction

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | ported construct rows | same refused/built outcome as TypeScript |
| AC-2 | README schemes | build |
| AC-3 | negative ids | refused |
| AC-4 | group rows | TypeScript outcome |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-1 | hostile `construct` cases (run fully in AZ-2446) | build | scheme_error | — |

## Constraints

- Go copies TypeScript at HEAD row for row (loop 24 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Go follows the five. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import of another package. Standard library plus `golang.org/x/crypto` only (G-3). No cgo.
- Go runs only in Docker on the owner's Mac: `docker run --rm -v "$PWD":/src -w /src/go golang:1.27 go test -race ./...` (G-2).
- Errors are values; no panic escapes `Pack`, `Unpack` or scheme construction on any input.

## Risks & Mitigation

**Risk 1: TypeScript rule order**
- *Risk*: Two rules can fire on one scheme; the message differs by rule.
- *Mitigation*: Go checks in the TypeScript order; AZ-2446 pins the rule per hostile case.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (size, `problem.md`) | parent | resolved | Low |
