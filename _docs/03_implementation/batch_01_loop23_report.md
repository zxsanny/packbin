# Loop 23 batch 01 report (waves 1a, 1b in one batch; one total review after)

Date: 2026-10-13. Workers per package directory; package suites only (no per-batch review or Docker run, owner rule). Intake `2a76f1e`. Owner decisions U18 B, U19 to U23 A (2026-10-13).

| Wave | Worker | Specs | Package suite |
|------|--------|-------|---------------|
| 1a | typescript | AZ-2434 (U23), AZ-2436 share | 967 of 967; strict `tsc` clean |
| 1a | cpp | AZ-2431 (U19 + G2), AZ-2432 (U20, no source change), AZ-2436 share | host and `gcc:16` green; arm: flash 8152 of 8192 B (margin 40 B), stack 456 of 512 B (margin 56 B), unchanged; s390x 241 of 241 |
| 1a | rust | AZ-2433 (U22), AZ-2435 share, AZ-2436 share | 670 (21 binaries) |
| 1a | python | AZ-2435 share, AZ-2436 share; then AZ-2437 (found in this batch) | 1476 |
| 1b | java | AZ-2436 share | 2540 checks |
| 1b | csharp | AZ-2436 share | 1978 |

CI-parity: PASS — `report-row.test.sh`, `fixtures/hostile/cases.test.sh`, `run-suite.test.sh`, `cpp/embedded/lib.test.sh`, `ring-wiring.test.sh`, golden row, strict `tsc`, and each package suite natively (C++ also `gcc:16`); the Docker `suites` step runs at step 11 before the push.

Worker slips: none. No index writes (`git diff --cached` empty after every join); every change sits in its worker's directory.

## Per task

- **AZ-2431 (U19, G2)**: the C++ `when()` builder (`cpp/include/packbin/fields.hpp`) marks a source id below 0 or above 32 767 Invalid, so `check_shape` refuses the scheme with `SchemeInvalid` at the `when`'s id (also closes `eq(32768)` and `eq(65535)`, which the int16 table field wrapped to a negative id). Folded at compile time: 0 B. G2: the body rule is pinned by direct `has_member`/`check_shape` calls and `eq(0, ...)` spellings (`empty_body_rule_host_tests.cpp`); an id assertion alone cannot separate the rules, because a round's id is its first child's id. The AZ-2416 tests moved there; the `eq(-1)` loader helper was removed from `hostile_host_tests.cpp`. C++ runs `check_shape` before `resolve`, so the three `construct_empty_*when*` vectors reach the body rule first in C++.
- **AZ-2432 (U20)**: typed row. A member bound to an `Array` is always present (`cpp/src/core/values.cpp:89-90`), its bit is set, and `pack_small` refuses with `BadValue` at the member when `ref_value` finds the count's `when` clear (`cpp/src/core/pack.cpp:141-142`), before the bias is added (`:145`); bias 0 refuses the same cells. Spelled unbound (`packed(1, 2, 1, -1)`, no member pointer), C++ packs `010000` for count 1 with bias -1, as the five. README exception (step 13). Tests: `packed_bias_novalue_host_tests.cpp`.
- **AZ-2433 (U22)**: Rust `repeat` reuses the `times` list check (`lists_agree`): a value kept beside `__repeat__` groups must be what the rounds hold (`repeat at id N: list for 'x' disagrees with its rounds`); without groups, names of a `times` nested in the body are refused with the U13 text. Rows that now refuse (packed at HEAD): `n:[2]` beside one round (`010105`), `x:[5]` beside two rounds, lone `x:6`, `x:[]` beside one round, nested `w:[7]` beside groups, nested `w:[1]` / `w:1` without groups (`01`). Unchanged (hex checked against a HEAD copy): groups only, agreeing lists, nested-`times` groups, nothing given. Spec AC-1 example amended (the review's `n:[1]` agrees and packs, as through a `times`).
- **AZ-2434 (U23)**: TypeScript refuses a bigint count above `MAX_SAFE` in the U11 shape with the U11 text (`flag-bits.ts`; `MAX_SAFE` exported from `kinds.ts`; `validCount` unchanged, so its other callers are unchanged). 128-row grid: outcome and number equal to Python on every row. 2^53 exactly is refused too (Python as well). The `times` split (U6) is unchanged and pinned.
- **AZ-2435 (G1)**: Python (F10 packet, `max_slots=4_194_304`) and Rust (`u32 n; times(n){64 u8}`, `with_limits(65_535, 4_194_304)`) unpack the old worst packet; the defaults refuse it (`ShortPacket left=3_194_814`, `Short left=3_145_664`). About 4 to 6 s each; neither package has a slow marker.
- **AZ-2436 (G3)**: the U11 refusal pinned in six positions (group, bit holding a group, outer holding `when`, bit holding a holding `when`, `times` round, `repeat` round) x `bits`/`packed`/`sized` x split bit/combined `flags` in TypeScript, Python, Java, C#, Rust; count 0, a left-out count and a holding inner `when` keep the HEAD hex in all six packages. Java and C# cannot spell a named anchored group around the member (their nested-row group has its own id scope; the build refusal is pinned). C++ packs the clear bit for an unbound member (discovery 1). AC-2 amended after the TypeScript probe (the literal shape is the existing silent skip, pinned in all six).
- **AZ-2437 (found here)**: Python refused `times {n:2, mode:[1,0], c:[3]}` and `repeat {mode:[1,0], c:[3]}` through the U11 check (`_at_round` raised past the list end). TypeScript, Java and C# pack `01020103000000` / `010103000000` (parent and worker probes). The `times` row packed at 88c063f (a loop 22 regression from AZ-2410); the `repeat` row was refused at 88c063f by the old equal-length rule. Fix: `_RoundValues.unwritten_count` (`python/src/packbin/_pack_rounds.py`) read by `_refuse_unwritten_count` (`_pack.py`); a holding round with no entry is still refused as at HEAD. Rust refuses those per-name lists by its own rules (U18 for `times`, U13 for `repeat`) and packs the same hex from groups.

## Discovered during implementation

| # | Spec ref | Finding | Proposed handling | Status |
|---|----------|---------|-------------------|--------|
| 1 | AZ-2436, AZ-2410/U11, AZ-2432 | C++ does not apply U11 to an unbound `bits`/`packed`/`sized` member: count 3, clear `when`, packs the clear bit at the top level (row 56) and in all six nested positions, where the five refuse | owner row for loop 24: refuse in `pack_flag_byte`/`pack_flags` (flash cost unmeasured, margin 40 B) or README exception | unclear |
| 2 | AZ-2436 | `cpp/tests/core/hostile_pack_loop21.hpp:129-134` skip text for `pack_novalue_count_clear_when_*` says "a typed row has no 'no value'"; the unbound spelling exists | reword after row 1 is decided | clear |
| 3 | AZ-2431 | `fixtures/hostile/README.md:36`: C++ refuses the `construct_empty_*when*` cases by the body rule first, and `eq(-1, ...)` is now refused | fix text in step 13 | clear |
| 4 | AZ-2431, F36 | C++ ids above the int16 range wrap: `eq(65536, 1)` binds field 0 and packs `010105`; count ids (`times`, `bits`, `packed`, `sized`) truncate the same way, and a count id of -1 is not checked | Low note on F36; loop 24 row (builder check, 0 B expected) | unclear |
| 5 | AZ-2431 AC-3 | A C++ round of only a `when` holding a member cannot build (its source must sit before it in the round); the body rule passes it (direct check), the scope rule refuses it | none | clear |
| 6 | AZ-2433 | An empty list beside `__repeat__` groups now refuses in Rust (it disagrees with rounds that hold the name), as for `times`; without groups an empty list still packs | README sentence (step 13) | clear |
| 7 | AZ-2433 AC-2 | A `repeat` nested in a `repeat` or `times` cannot be built in Rust (construction panic) | clause dropped from the spec | clear |
| 8 | AZ-2433 | Rust: a top-level `__times_N` key for a `times` nested in a repeat body is still dropped without a word; a repeat-body `flags` name given without groups is not refused | loop 24 rows | unclear |
| 9 | AZ-2436 | C#: a dictionary row reads a nested-row group's names from the outer row; a nested dictionary under the group's name is not read (`'Mode' (field id 0) has no value`) | reference/README line if undocumented | unclear |
| 10 | AZ-2435 | Python and Rust have no slow marker; the raised-limit tests take 4 to 6 s and several hundred MB each in the default suite | none, or a marker later (`pyproject.toml` owner) | clear |
| 11 | handoff | `mypy --strict` from PyPI today reports 16 errors in 4 files (the same set at HEAD and after AZ-2437), not one at `_pack.py:410`; CI runs no mypy | record the version in the handoff | clear |
| 12 | AZ-2434 | The new TypeScript test files are not strict-typechecked (`@types/node` not installed); the documented check covers `src/index.ts` only | none | clear |
