# Code Review Report

**Batch**: 2 (loop 16): AZ-2188, AZ-2128 (TS part), AZ-2183, AZ-2184, AZ-2197 (TypeScript); AZ-2128, AZ-2114, AZ-2121 AC-4 (Rust); AZ-2101, AZ-2128, AZ-2114, AZ-2121 (Java); AZ-2100, AZ-2134, AZ-2128 (Python) | **Date**: 2026-10-06 | **Mode**: Full, one read-only reviewer per package with mutation checks and differential runs against HEAD, then a fix pass and a delta review of the Python fix | **Verdict**: PASS_WITH_WARNINGS (after fixes)

Verdicts as first reported: TypeScript PASS_WITH_WARNINGS, Rust PASS_WITH_WARNINGS, Java PASS_WITH_WARNINGS, Python FAIL (High, security). Delta review of the Python fix: FAIL (a second High in the same control), fixed in a second fix pass (see below).

## Owner decisions taken after the first review (2026-10-06)

1. Python round and slot limits: option A, add them like the other five packages (defaults 65,535 rounds and 4,194,304 slots per unpack call, `Scheme.with_limits`).
2. Python nested rounds: option A, refuse a `repeat` or `times` inside a round at construction, like TypeScript and C#.
3. TypeScript `eq(id, undefined)`: option A, pack mirrors unpack.
4. `when` / `times` / `repeat` as a `flags` member: option C, hold for the loop that lands the C# work, so the five packages are decided together.

## Findings and disposition

| # | Pkg | Severity | Category | Title | Disposition |
|---|-----|----------|----------|-------|-------------|
| PY-F1 | Python | High | Security / Performance | Rounds cost names x rounds of memory, no limit (391 MiB for 1 MiB, 1.5 GiB with 300 names) | FIXED (owner A): `with_limits`, `max_rounds` 65,535, `max_slots` 4,194,304, per-call budget, hostile `limit` vectors replayed; the 1 MiB attack packets are now refused in 0.1 to 0.4 s and under 130 MiB |
| PY-D1 | Python | High | Security / Performance | Slot budget does not price the per-element lists of rounds inside list/dict elements (about 480 MiB and 7 s for 1 MiB `list(list(...))`) | FIXED inside decision A (accounting corrected: eight extra slots per name per run, `_round_leaves` cached); see the batch report for the measured numbers |
| PY-F2 | Python | Medium | Bug | `times(repeat)` and nested rounds only guarded for an outer `repeat`, at pack time | FIXED (owner A): refused at construction, pack-time guard removed |
| PY-D2 | Python | Medium | Test gap | A budget fresh per list/dict element passed all tests | FIXED (test added) |
| PY-F3 | Python | Medium | Bug (pre-existing, open concern) | `when` / `times` / `repeat` as a `flags` member never sets its bit | HELD (owner C) |
| PY-F4 | Python | Low | Spec-Gap | Bit numbering follows `.bit()` call order (AZ-2100 Included line) | Open for the owner; Python is not in AZ-2135's component list |
| PY-F5, PY-D5 | Python | Low | Bug / Maintainability | An accessor bound to the row itself made `repeat` unpack raise; `with_limits` dropped subclass state | FIXED (local lists dict; `copy.copy`) |
| PY-F6 | Python | Low | Spec-Gap | Pack stricter than TypeScript on short lists, bare `IndexError` for `times` | Accepted (loud, unchanged from HEAD; recorded) |
| PY-F7, PY-D4 | Python | Low | Docs | README, AGENT_GOTCHAS, security report still say Python is unbounded and unchecked | Step 13 docs pass |
| TS-F1 | TypeScript | Medium | Bug | `eq(id, undefined)`: pack returned bytes its own unpack rejects (HEAD was readable) | FIXED (owner A): pack mirrors unpack, two tests |
| TS-F2 | TypeScript | Medium | Performance | Null-prototype row 2x to 9x slower per round or item | FIXED: plain `{}` row, only `__proto__` defined as an own property (22 ms against 22 ms at HEAD for 60k items) |
| TS-F3 | TypeScript | Low | Spec-Gap | A member given flat and inside its group object: nested wins | Pinned by a test (both key orders) |
| TS-F4, TS-F5 | TypeScript | Low | Maintainability / test gap | Dead `flatten` flagBit branch; u2 "any slot" not pinned | FIXED (branch removed; test added) |
| TS-F6 | TypeScript | Low | Maintainability | Near-duplicate name walker, duplicated tests | Not done (no test deletion) |
| JA-F1 | Java | Medium | Spec-Gap (docs) | New overload, construction break and wire change missing from README | Step 13 docs pass |
| JA-F2 | Java | Medium | Bug (pre-existing) | A flag byte outside a nested row with its bit inside builds and packs unreadable bytes | Open, same at HEAD; follow-up |
| JA-F3 | Java | Low | Bug (pre-existing) | A null nested member or null list element is dropped silently on pack | Open, same at HEAD; follow-up |
| JA-F4 | Java | Low | Scope | Nested-row presence under `flags` is its member alone | Accepted: the only bytes that change are ones that did not unpack at HEAD |
| JA-F5 | Java | Low | Spec-Gap | Javadoc said every nested group below a factory group needs a factory | FIXED (sentence states what is checked) |
| JA-F6 | Java | Low | Performance | One HashMap per nested-row occurrence | Accepted (4.4 ms against 9.7 ms for 65,000 rounds) |
| RU-F1, RU-F2 | Rust | Low | Maintainability / test gap | Flag-byte exclusion unpinned; typed nested `flags` untested | FIXED (shared `any_member_on` loop, two tests, one doc sentence) |
| RU-F3 | Rust | Low | Docs | Upgrade note lacks the new Rust bytes | Step 13 docs pass |

## Existing tests changed

- TypeScript: `nested-group.test.ts` "an anchored group shares the scope around it" (rebuilt with `when` branches, same intent) and `round-values.test.ts` "a repeat member named like an earlier scalar joins it" (now a refusal test): both pinned duplicates that AZ-2188 AC-3 and AC-4 refuse, spec-sanctioned; `u64-count.test.ts` only gained tests.
- Python: `hostile_support.py` and `test_hostile_vectors.py` gained the replay of the two `limit` vectors, additive; no other existing test file changed.
- Rust: none. Java: `PackbinTest.java` gained four class registrations.

## Mutation and differential evidence

Mutation checks failed the right tests in every package (TypeScript eight, Rust eleven, Java fourteen, Python nine and more in the delta); two survivors (TypeScript flagBit branch, `bitOn` u2 first slot; Rust flag-byte skip) were closed by the fix pass. Differential runs against HEAD: TypeScript about 500k scheme and row pairs (only intended refusals and fixes differ), Rust about 47k schemes per seed (rows HEAD packed without dropping a value are unchanged), Java 40,000 schemes (only the intended id-shadow fix differs), Python about 30,000 cases twice (0 regressions). Hostile unpack: Java 100k, Python about 350k at default and tight limits, TypeScript unchanged read paths: no throw, no hang.

## Not checked

C#, the owner's uncommitted work, the ring beyond what the parent ran, Python 3.10 to 3.13, Linux allocator numbers (all figures are macOS arm64).
