---
loop: 101
branch: dev
---

# TypeScript: refuse dictionary keys that collide after U+FFFD

**Task**: AZ-4168_typescript_colliding_dict_keys
**Name**: TypeScript: refuse dictionary keys that collide after U+FFFD (loop 101)
**Description**: TypeScript `pack` refuses a dictionary whose keys become one key once an unpaired surrogate is written as U+FFFD, as Dart does.
**Complexity**: 2 points
**Dependencies**: AZ-4153 (Dart rule, loop 100)
**Component**: typescript
**Tracker**: AZ-4168
**Epic**: AZ-4133

## Problem

TypeScript writes a packet its own unpack refuses when two dictionary keys differ only in unpaired surrogates (or one is a real U+FFFD): both keys are written as U+FFFD, and unpack reads a repeated key. The owner asked for the reference package to refuse this at pack, as Dart does since loop 100. Pack files: `_docs/02_task_plans/typescript-colliding-dict-keys/` (`problem.md`, `acceptance_criteria.md` TC-1 to TC-5, `scenarios.md`, `input_data/expected_results/results_report.md`).

## Outcome

- TypeScript never writes a dictionary packet that its own unpack refuses for these inputs.
- A caller sees a clear error naming the dictionary instead of a packet that fails at the reader.
- Dart and TypeScript agree on the seven cases of the results report.

## Scope

### Included
- Refuse the collision at pack with a `RangeError` naming the dictionary; no bytes returned.
- Tests for the 4 colliding and 3 non-colliding cases, and a seeded random check that every packet pack returns unpacks.
- Docs that say TypeScript writes the unreadable packet: the README Dart notes, `parity_differences.md` row 43, traceability row AL-3, the TypeScript component doc.

### Excluded
- The other six packages, the npm version, any release.
- Any change to the bytes of a dictionary without a collision.

## Acceptance Criteria

**AC-1: Collision refused (TC-1)**
Given a dictionary whose keys are the same once each unpaired surrogate is written as U+FFFD
When packed
Then a `RangeError` naming the dictionary is thrown and no bytes are returned (4 of 4 cases).

**AC-2: Unchanged bytes (TC-2)**
Given the 3 dictionaries without a collision and the existing key rows
When packed
Then the bytes equal today's (0 mismatches) and all existing TypeScript tests and the 957 parity rows pass.

**AC-3: Never unreadable (TC-3)**
Given 20,000 seeded random dictionaries over the lone-half alphabet
When packed and the result unpacked
Then every returned packet unpacks to the swapped keys and every refusal is a real collision (0 unreadable packets).

**AC-4: Same as Dart (TC-4)**
Given the 7 dictionaries of the results report
When packed by Dart and by TypeScript
Then both refuse the same 4 and write the same bytes for the other 3.

**AC-5: Docs (TC-5)**
Given the change is complete
When the documents outside dated history are read
Then none says TypeScript writes an unreadable packet for colliding keys.

## Non-Functional Requirements

**Performance**
- The check is one comparison of neighbouring encoded keys in the sort that already runs; no new allocation beyond the encoded keys the sort already makes.

**Compatibility**
- A dictionary that packed and unpacked before packs to the same bytes; only a dictionary that unpack refused now fails earlier.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the 4 colliding dictionaries; one as a list element | `RangeError` with the dictionary's name; nothing written |
| AC-2 | the 3 other dictionaries | the hex of the results report |
| AC-3 | 20,000 seeded random dictionaries | every returned packet unpacks; every refusal collides |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-4 | the results report cases | Dart and TypeScript agree | 7 of 7 | Compatibility |
| AC-2 | the whole TypeScript suite and `fixtures/text/` | unchanged | all pass | Compatibility |

## Constraints

- TypeScript is the reference: the message follows its existing `name: reason` style and the Dart wording.

## Risks & Mitigation

**Risk 1: A caller relied on the old write**
- *Risk*: a caller packs colliding keys and ships the packet.
- *Mitigation*: no reader could unpack it (every package refuses a repeated key), so the packet carried no data.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| behaviour change of a published npm package | owner asked for it (2026-11-11) | accepted-risk | Low |
| the other six packages may write the same packet | not measured; leftover | open | Low |
