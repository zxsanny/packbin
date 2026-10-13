---
loop: 24
branch: dev
---

# Go strings, lists, dicts and nested rows

**Task**: AZ-2443_go_collections
**Name**: Go strings, lists, dicts and nested rows
**Description**: Go packs and unpacks `utf8`, counted lists, dictionaries, group and flags elements and nested-row groups as TypeScript.
**Complexity**: 5 points
**Dependencies**: AZ-2442
**Component**: go
**Tracker**: AZ-2443
**Epic**: AZ-2222

## Problem

Strings, lists and dicts are the user-shaped rows (`user`, `listgroup`, `dictgroup` ring kinds). Go needs them for full parity, with the map form reading nested maps (U26 A).

Feature ACs and scenarios: `_docs/02_task_plans/go-package/` (GO-2 (collections), GO-3, GO-12 (U26 A); scenario S8).

## Outcome

- README UTF-8, list and dictionary examples pack and unpack with 0 mismatched bytes.
- The map form reads a nested-row group from the nested map; a typed row reads a nested struct.

## Scope

### Included

- `utf8` (u16 length, invalid UTF-8 refused as TypeScript), `list` (u16 count), `dict` (u16 count), group and flags elements, nested-row groups, dict keys not flattened, lone bytes/utf8/dict in a round.
- Owns (exclusive write): `go/**`

### Excluded

- Limits (AZ-2444)

## Acceptance Criteria

**AC-1: README collection examples**
Given README UTF-8, list and dictionary examples
When packed and unpacked
Then the README hex both ways; mismatched bytes 0

**AC-2: Collection rows**
Given the TypeScript tests `list-element-kinds`, `list-group-elements`, `dict-keys-not-flattened`, `dict-non-plain-object`, `nested-group`, `lone-bytes-in-round`, `lone-dict-in-round`, `binding`, `value-fidelity`, `borrowed-count`
When ported to Go
Then same hex or same refusal; disagreements 0

**AC-3: Nested map (U26 A)**
Given a nested-row group whose names repeat outer names, given as a nested `map[string]any` and as a nested struct
When packed
Then the inner values come from the nested map/struct, never the outer row; the two forms give the same bytes

**AC-4: Ring payloads**
Given the `user`, `nested`, `listgroup`, `dictgroup`, `listflags` hex of `language-pair.sh` and the three `-short` hex
When unpacked and repacked in Go
Then the same hex; the short ones refused with no row

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|---|---|---|
| AC-1 | README table | README hex |
| AC-2 | ported rows | TypeScript outcome |
| AC-3 | nested map vs struct | same bytes, inner values |
| AC-4 | ring hex | round trip / refusal |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|---|---|---|---|---|
| AC-4 | ring (AZ-2449) | Go in the ring | handoffs pass | — |

## Constraints

- Go copies TypeScript at HEAD row for row (loop 24 fit decision 4); where TypeScript is a documented exception (U6 bigint `times` split) Go follows the five. A disagreement found while porting is reported to the parent, not decided inside the task (probe-first).
- ADR-001: hand-written walker, no generator, no import of another package. Standard library plus `golang.org/x/crypto` only (G-3). No cgo.
- AZ-2442 left `reached` keyed per round node: scope it per list or dict element. Rounds start in `packer.rounds` and `reader.rounds`; the map form of a round is aligned per-name lists (`[]any`, nil for a skipped round); a group inside a round is one map per round (Go-4). `[]byte` is a byte run, never a list.
- Go runs only in Docker on the owner's Mac: `docker run --rm -v "$PWD":/src -w /src/go golang:1.27 go test -race ./...` (G-2).
- Errors are values; no panic escapes `Pack`, `Unpack` or scheme construction on any input.

## Risks & Mitigation

**Risk 1: Map value types**
- *Risk*: JSON-like maps can hold float64 for integers.
- *Mitigation*: Accept Go integer kinds and refuse non-integral floats as TypeScript `int-range`; documented in package docs.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| none beyond the feature's (size, `problem.md`) | parent | resolved | Low |
