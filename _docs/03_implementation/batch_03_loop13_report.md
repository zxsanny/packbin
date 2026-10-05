# Batch Report

**Batch**: 3 (TypeScript, one worker; the owner added the TypeScript round slicing to the task on 2026-10-05)
**Tasks**: AZ-2091_typescript_nested_flags_names
**Date**: 2026-10-05

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2091_typescript_nested_flags_names | Done | 13 files (5 src, 8 tests) | 224/224 pass, 0 todo | Split-form flag bit wrapping nested flags still drops values on pack (pre-existing, follow-up) |

Files: `src/rounds.ts` (new: round names, count and slice on pack, aligned lists on unpack, mirrors C# `Walker.Rounds.cs`), `src/member-names.ts` (new: construction-time collision check, called from the `Scheme` constructor), `src/fields.ts` (`collectFlagBits` descends into groups and flag bits; `flatten` flattens `flags` members), `src/pack-fields.ts`, `src/walker.ts`, `src/index.ts`; tests `nested-group.test.ts`, `round-values.test.ts`, `round-roundtrip.test.ts` (new), `value-fidelity.test.ts`, `reference-scope.test.ts` (one expectation each). `handoff.ts` unchanged.

## Code Review Verdict: PASS_WITH_WARNINGS (one fix round)

One fresh reviewer (read-only, scratch copies). 0 Critical, 0 High, 1 Medium, 4 Low.

- All spec ACs and the AZ-2134 TypeScript cases pass and are covered; the 62 new tests: 48 fail on HEAD sources, 14 pass and pin HEAD behavior that must not change (lone-scalar broadcast, borrowed `times` count, zero-progress `repeat`, absent keys for zero rounds, alternate `when` branches).
- Regression checks: 30 000 random schemes with name reuse: the new collision check refuses exactly what a spec-derived oracle refuses (5 274), no false refusals or accepts; 120 000 random cases on shapes HEAD supported: identical bytes and errors; a model fuzz of about 250 000 rows: every byte difference from HEAD was a value HEAD dropped or a HEAD throw; 2.4M random packets (313 000 accepted): 0 repack throws, 0 row changes; hostile unpack (440 000 packets over 11 round-heavy schemes): no throw, no hang; each zero-progress guard removed in a scratch copy fails named tests.
- C# cross-check: a scratch console built from `csharp/*.cs` over 20 000 packets and five shapes agreed with TypeScript on accept/reject, aligned rows and repack bytes in every case.
- Public surface: `index.d.ts` and every existing `.d.ts` identical to HEAD; strict tsc clean; AC-10 about 240 ms; handoff driver bytes equal the `language-pair.sh` constants.
- **Medium F1 (Bug, pre-existing, identical on HEAD): flags under a split flag bit are still dropped silently on pack.** `flatten` does not descend into the `field` of a split-form `flagBit`, nor into a `flags` that is a direct member of `flags`: `fb=flagByte("m"); scheme(1, fb, fb.bit(group(g,[u8 a, flags(1,[u8 c])])))` packs `{g:{a:1,c:2}}` to `01010100` (`c` lost); `flags(0,[flags(0,[u8 c])])` packs `{c:2}` to `0100`. A fuzz that allows the shape: 71 of 20 240 accepted packets change their row on repack. Not made worse by this batch and needs a split-form bit wrapping nested flags; recorded as a follow-up (fix `flatten` for `flagBit.field` and a flags member).
- Low F2 (three surviving mutants) fixed in round 2 (+4 tests: a `list` or `dict` named like an unanchored group member is refused; `times` reads a group's own member at the round index; a `when` in a round reads only the round's own value); each mutant now fails a named test. F3, F4 are follow-ups (Discovered 2, 6); F5 (unpack memory) is accepted with a README note.

Reproducing tests changed (reviewed): `value-fidelity.test.ts` "later rounds see their own value" `v: [11]` -> `[undefined, 11]`; `reference-scope.test.ts` "a when in a repeat body names a field of the same round" `v: [7]` -> `[7, undefined]`. Both are exactly what the aligned rule implies; nothing else was weakened.

## Test Suite

- C# 345 passed; TypeScript 224 (0 todo); Python 103; Rust 206; Java 4 runners, 0 failures; C++ all tests passed
- Failed: 0
- `language-pair.sh`: user, nested, boolflag, booltrue, bitwhen, session and position rings pass across all six languages
- CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm {typescript,rust,csharp,python,cpp,java}` (all six exit 0; the TypeScript suite runs on `node:24`), `bash fixtures/hostile/cases.test.sh`, `bash .github/workflows/report-row.test.sh`, `tsc --noEmit --strict` over `typescript/src/index.ts`, `bash .github/workflows/language-pair.sh` (macOS SDK sysroot). The embedded stages and `publish-gate.test.sh` are untouched by this loop's changes and run in Run Tests (step 11).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | A lone non-list value is broadcast to every round in TypeScript (HEAD behavior, kept and pinned by a test); C# packs it into round 0 only; Java broadcasts | AZ-2134, batch 1 item 15 | Owner parity decision (one line in `sliceRound`) | unclear |
| 2 | `times` pack silently drops list entries beyond the count (`{a:2, x:[1,2,3]}` packs `01020102`); C# throws (`RequireNoExtraRounds`) | AZ-2088 twin | Follow-up: refuse like C# | unclear |
| 3 | `when` as a flag member: its bit is never set on pack (HEAD identical) | AZ-2120 (C#) | Add TypeScript to AZ-2120 or a new ticket | unclear |
| 4 | Flags under a split flag bit that wraps a group, and `flags` directly inside `flags`: inner values dropped on pack (review F1, Medium, pre-existing) | AZ-2091 Rule 2 | Follow-up ticket: `flatten` must handle `flagBit.field` and a flags member | clear |
| 5 | A group whose members are only flagBit / u2 / sized: a flat row `{n:5}` leaves the group bit clear, the nested form `{g:{n:5}}` works; such a flat unpacked row does not repack | AZ-2128 | Cover TypeScript in AZ-2128 | unclear |
| 6 | A group written as a nested object inside a round counts present in every round (`{mark:{v:[7,undefined,9]}}` throws `RangeError: missing v`; the flat form packs); unpacked rows are flat so repack works | review F4 | Document, or fold into the flat-row design question (scan C4) | unclear |
| 7 | A `times` inside a `repeat` round: no readable count, nested containers are not sliced; list/dict element contents unchanged | AZ-2091 Excluded | Owner decision (Java and Rust refuse at construction, as C# batch 1 item 14) | unclear |
| 8 | The same member name in a repeat body and at the top level (no group) joins as `[scalar, ...rounds]` | none | Candidate construction error | unclear |
| 9 | Two unanchored groups in mutually exclusive `when` branches that share a member name are refused (spec-literal, conservative) | AZ-2091 AC-5 | Leave, mention in the upgrade note | clear |
| 10 | `sized` / `bits` / `packed` whose count is a field of the same repeat round now unpack (HEAD: error `needed 0`); accept-set widening | AZ-2090 scope rule | Upgrade note | clear |
| 11 | A `when` in a round reads only the round's own value; HEAD fell back to a same-named outer value in a name-collision scheme | AZ-2090 scope rule | Deliberate change, pinned by a test; upgrade note | clear |
| 12 | Unpack memory is about 8 bytes × names × packet bytes: 1 MB zero packet with a 36-name `when` body is 299–313 MB heap (HEAD 11–19 MB); linear, not count-driven; 8 names 78 MB, 100 names 849 MB per MB of packet | AZ-2134 U2 | README untrusted-input note; security audit step | clear |
| 13 | Unpacked TypeScript rows: no `""` flag-byte key; in rounds, every name a round can hold is a list with `undefined` for a skipped round (`[undefined, …]` when no round set it; `JSON.stringify` gives `null`); a bool under flags is `true` / `undefined` | AZ-2091, AZ-2134 | README upgrade note | clear |
| 14 | The driver `unpack-session` could assert there is no `""` key | AZ-2091 | Optional | clear |

## Commit

`[AZ-2091] TS flags in groups, name collisions, aligned rounds`. Body: one line + `Loop: 13`.

## Next: feature assessment (step 10.5), then Run Tests, Update Docs, Security Audit, Retrospective, local deploy and smoke
