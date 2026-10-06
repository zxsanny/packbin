# TypeScript refuses a member name declared twice in one scope

**Task**: AZ-2188_typescript_duplicate_member_names
**Name**: TypeScript duplicate member names refused at construction
**Description**: A scheme that declares the same member name twice in one scope, with both declarations outside every `when`, fails at construction naming the member; alternate `when` branches may still share a name.
**Complexity**: 1 point
**Dependencies**: AZ-2091_typescript_nested_flags_names (the member-name check and its place rule)
**Component**: typescript
**Tracker**: AZ-2188
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (T29, Q1); batch 3 discovered 8. Written for the recommended option B of the decision below.

- TypeScript rows are flat: one value per member name. AZ-2091 refuses a name used inside an unanchored group and outside it, but its AC-5 allows duplicates in the same scope, so a scheme that declares one name twice in the same scope builds and loses one of the values.
- Probe 1 (verified): `u8(0, a)`, `u8(1, a)`. `{a:7}` packs `01 07 07`. Unpacking `01 01 02` returns `{a:2}`: the second value wins and the first is gone.
- Probe 2: two `times` bodies sharing `v` (`u8 n`, `times(1, 0, u8 v)`, `u8 m`, `times(3, 2, u8 v)`). Unpacking `01 02 0a 0b 01 0c` gives `{n:2, v:[12], m:1}` (the last list only), and repacking that row throws `missing v`.
- Probe 3: a `repeat` member named like a top-level field (`u8(0, k)`, `repeat(1, u8(1, k))`). Unpacking `01 05 06 07` gives `{k:[5,6,7]}` (the scalar joined to the rounds), and repacking throws `k: expected a number for u8, got object`.
- A duplicate under `flags` builds too: `u8(0, a)`, `flags(1, u8(1, a))` with `{a:3}` packs `01 03 01 03`.

## Outcome

- A name declared twice in one scope fails at construction with a `RangeError` naming the member, from both `scheme(...)` and `new Scheme(...)`, when both declarations are outside every `when`.
- Two or more `when` branches may keep sharing a name (AZ-2091 AC-5), and every valid scheme keeps its bytes.

## Scope

### Included
- A construction check on member names that share one scope (the top level or one unanchored group; anchored groups, `flags`, `repeat` and `times` bodies share the scope around them, as in the AZ-2091 check).
- Tests for the probes below.

### Excluded
- Names in different scopes: a list or dict element has its own scope; a group and the outside is AZ-2091's existing check.
- Renaming rows or changing the flat-row design (scan C4).
- A name declared once outside any `when` and once inside one (see the flagged concern).

## Acceptance Criteria

**AC-1: The same name twice at one level**
Given `u8(0, a)`, `u8(1, a)`
When `scheme(...)` or `new Scheme(...)` is called
Then it throws `RangeError` naming `a`.

**AC-2: Two `times` bodies sharing a name**
Given `u8(0, n)`, `times(1, 0, u8(1, v))`, `u8(2, m)`, `times(3, 2, u8(3, v))`
When the scheme is built
Then it throws `RangeError` naming `v`.

**AC-3: A `repeat` member named like a top-level field**
Given `u8(0, k)`, `repeat(1, u8(1, k))`
When the scheme is built
Then it throws `RangeError` naming `k`.

**AC-4: A name under `flags` and outside**
Given `u8(0, a)`, `flags(1, u8(1, a))`
When the scheme is built
Then it throws `RangeError` naming `a`.

**AC-5: Alternate `when` branches keep sharing**
Given `u8(0, kind)`, `when(1, eq(0, 0), u8(1, shape))`, `when(2, eq(0, 1), u16(2, shape))`, and two `when` branches that write one member inside a `repeat` round
When they are built, and `{kind:1, shape:300}` is packed
Then both build, and the bytes are `01 01 2c 01`.

**AC-6: Other scopes are not touched**
Given `u8(0, a)`, `list(xs, u8(0, a))` (the element is named like the top-level field)
When it is built and `{a:7, xs:[1,2]}` is packed
Then it builds and the bytes are `01 07 02 00 01 02`; the existing group-versus-outside refusal keeps its message.

**AC-7: Existing schemes build**
Given every scheme in the tests, the README examples and the language-pair drivers
When they are built
Then they build (a scheme that no longer builds is listed in the task notes), and the golden, route and ring bytes are unchanged.

## Non-Functional Requirements

**Compatibility**
- Packet bytes of schemes that still build do not change.

**Reliability**
- The refusal happens at construction, before any pack or unpack.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | `u8 a, u8 a`, via `scheme()` and `new Scheme()` | `RangeError` names `a` (builds today) |
| AC-2 | two `times` bodies with `v` | `RangeError` names `v` |
| AC-3 | `repeat` member named like a top-level field | `RangeError` names `k` |
| AC-4 | `flags` child named like a top-level field | `RangeError` names `a` |
| AC-5 | `when` siblings at the top level and in a round | build; `01 01 2c 01` |
| AC-6 | element named like a top-level field | builds; `01 07 02 00 01 02` |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-7 | `fixtures/golden.hex`, route fixture, handoff drivers | build, pack, unpack | all build; unchanged hex | project AC-3 |

## Constraints

- ADR-001: TypeScript only; no public API change; browser-safe `src`.
- The check lives in the `Scheme` constructor so `new Scheme` and `scheme()` agree (AZ-2129, AZ-2091 flagged concern).
- `RangeError` is the scheme error type.
- Wire bytes and probe results come from the current code; the worker re-derives them from a real run.

## Risks & Mitigation

**Risk 1: A scheme that happened to build stops building**
- *Risk*: a caller scheme with a duplicate name (for example one whose two fields always hold the same value) is refused.
- *Mitigation*: such a scheme packs one value into two fields and unpacks only the last; the message names the member; README upgrade note.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| DECISION (ticket): A) leave, B) refuse a name declared twice when both declarations are outside every `when`, C) refuse every duplicate except across `when` siblings. These ACs are written for B (recommended). The owner confirms the option before implementation | owner | open | Medium |
| Under B, a name declared once outside any `when` and once inside one still builds (`u8 shape` plus `when(...)` with `u16 shape`); only C refuses it. Confirm with the decision | owner | open | Low |
| Two unanchored groups in mutually exclusive `when` branches that share a member are already refused (batch 3 discovered 9); unchanged | owner | accepted-risk | Low |

## Owner decision (2026-10-06)

DECIDED, the proposed default: option B: refuse duplicate member names outside every `when`. The open DECISION rows above are resolved by this section.

## Loop 16 result (2026-10-06)

Done in loop 16 (batch 2), option B. A list or dict element is its own scope (batch 1 review TS-F2): duplicates inside it are refused and it may reuse names of the row around it. Two existing tests pinned duplicates that AC-3 and AC-4 refuse and were rewritten (`nested-group.test.ts` "an anchored group shares the scope around it" now uses `when` branches, `01012c01`; `round-values.test.ts` "a repeat member named like an earlier scalar joins it" is now a refusal test). An anchored group named like its own child (`group(0, g, [u8(0, g)])`, which packed `0107` at HEAD) is also refused. Open: two declarations inside the same `when` body still build and write the value twice.
