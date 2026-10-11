# Loop 18 total review

Date: 2026-10-10 to 2026-10-11. Scope: `git diff aea6344..b3418b8` source of all six packages (about 1 400 changed source lines; about 7 500 lines of tests were read only where a test was replaced or removed) and the harness (`fixtures/hostile/`, `.github/workflows` ring files, the C# ring driver). One review for the whole loop (owner preference, memory `one-total-review-and-test`), four read-only reviewers by package (C#; TypeScript and Python; Rust and Java; C++ and harness), run by the parent after the last wave. Verdict before fixes: **FAIL** (C#: 1 High, 2 Medium); after the fixes approved by the owner on 2026-10-11 ("fix 3 now"): **PASS_WITH_WARNINGS**, 0 Critical, 0 High, 5 Medium open (owner decisions, below), Low rest.

Owner answer 2026-10-11: fix the C# High, the C# Medium and the TypeScript `Map` bug plus all Low findings now; the Python round scope, the pack round cap and the split-form silent drop go to the loop 19 handoff.

## C# (reviewer 1)

| # | Where | Finding | Severity | Outcome |
|---|-------|---------|----------|---------|
| C1 | `Walker.Counted.cs` `ElementValues` + `RowBinding.Element` | typed row with `List<object?>` / `Dictionary<string,object?>` holding `Flags` elements repacked to flag byte `00` with no error (new in AZ-2307) | High, Bug | **fixed**: flags branch first, `RowBinding.IsRow`; unpack `0102000101020200` repacks to the same bytes; 4 failing-first tests |
| C2 | `FieldBinding.cs` `CollectionShape.Holds` | AZ-2305 accepted any element type for Group/Flags/List/Dict/U2 elements with a non-row member; `List<int>` for flags elements threw `InvalidCastException` out of `Unpack` | Medium, Bug | **fixed**: element must be `object` or assignable from what unpack hands over; 28 tests. Bits, Packed, When, Times elements still accepted (unlikely shapes) |
| C3 | `Walker.cs` `PackFlagByte`, `FlagGroup.cs`, `Walker.Presence.cs` | split `flagByte`: a `when`/`times` bit is decided where the flag byte is read; a condition or count written between the byte and the bit leaves the bit clear and drops the body silently (pack cannot produce a packet its own unpack accepts) | Medium, Spec-Gap | **open, owner** (handoff 19, U7/U8): the reference tables put the source before the byte; cheap loud fix proposed in C# only |
| C4 | `FieldBinding.cs` `IsSupported` | `ICollection<int>`, `IReadOnlyList<int>`, `Collection<int>` and element types `IConvertible`/`IComparable` built and worked before and are now refused; the comment was false | Low, Spec-Gap | **fixed (comment)**: refusal kept on purpose (owner principle: refusing can be relaxed later, accepting cannot be withdrawn); accepted set listed; upgrade note; the accepted set stays an open owner question (U11) |
| C5 | `Packbin.cs` `WhenSource` | AZ-2126 closes the never-matching `when` only for a bool; `Eq(u8, 300)`, a string or NaN on an integer source still builds | Low, Spec-Gap | **open** (handoff 19) |
| C6 | `Field.cs` `ElementRowType`, `Walker.Presence.cs` | per-element LINQ and closure allocation on the pack path | Low, Perf | **fixed** (computed once; `AnyChildPresent` loop) |
| C7 | `FieldBinding.cs` | duplicate kind-to-range table | Low, Maint | **fixed** (`Walker.Range`, `Walker.KindName` internal) |
| C8 | `Walker.Counted.cs` 480 lines | cap | Low, Maint | **fixed**: 322 lines; `Walker.Collections.cs` 167 |
| C9 | tests | no test for C1, C2, `ICollection` | Low, Test | **fixed** (34 new tests) |
| C10 | `language-pair.sh` | ring is a chain, not all pairs | Low, Spec-Gap | **open** (handoff 19) |

Five deleted C# tests verified: the zero-width round guards cannot be rebuilt with a legal `when` source (integer, bool or u2 sources always read a byte); the plain zero-width tests stay.

## TypeScript and Python (reviewer 2)

| # | Where | Finding | Severity | Outcome |
|---|-------|---------|----------|---------|
| T1 | `python/src/packbin/_pack.py`, `_unpack.py` | `repeat`/`times` rounds reuse the outer `seen` instead of a fresh scope; a value a round skipped stays visible to a later `when` (TypeScript and C# use a fresh scope per round: `01020105010002` vs `010201050100`); not introduced by this diff | Medium, Bug (parity) | **open, owner** (handoff 19): changes Python bytes |
| T2 | `typescript/src/fields.ts` `isPlainObject` | a `Map` given for a `dict` name outside a round packed as an empty dictionary (`010000`) | Medium, Bug | **fixed**: strict `isPlainObject`; `Map`, `Set`, `Date`, class instances refused with "expected dictionary"; 7 tests |
| T3 | `flag-bits.ts`, `_pack.py` | `times` member with count 0 skipped the lone-dict refusal | Low | **fixed** (both) |
| T4 | same | `times` whose count field was skipped drops the body values silently | Low, Spec-Gap | **open** (owner kept it; U7) |
| T5 | `_pack.py` | short `times` list outside `flags` is a bare `IndexError` | Low, Test | **open** (U9) |
| T6 | `ref-scope.ts` | misplaced comment, "a object" | Low, Style | **fixed** |
| T7 | `_validate.py` | error text formats the caller's value with `!r` | Low, Security | **fixed** (`_shown`, also `_scheme.py`) |
| T8 | Python `==` | `eq(intField, True)` matches 1 in Python only | Low, Spec-Gap | **open** (handoff 19) |
| T9 | `flag-bits.ts` | `roundNames()` Set rebuilt per `bitOn` | Low, Perf | **fixed** (cached `shape` on bound repeat/times) |
| T10 | `_pack.py` | `_child_on` / `pack_nodes` size | Low, Maint | no change |
| T11 | `_validate.py` | `kind[0] in "ui"` | Low, Style | **fixed** (frozenset) |

## Rust and Java (reviewer 3)

| # | Where | Finding | Severity | Outcome |
|---|-------|---------|----------|---------|
| R1 | `rust/src/walk/times.rs:44-46`, `pack.rs:307-311` | the lone scalar goes to every round and nothing bounds the count on pack: `n=u32::MAX` with a lone `pt` writes about 4 GiB (Java, Python, TypeScript and C# broadcast the same way) | Medium, Security/Perf | **open, owner** (handoff 19): cap the rounds on pack like unpack does (`DEFAULT_MAX_ROUNDS` 65 535) in all six, or accept the risk |
| R2 | `times.rs:68` | `times` member of `flags`, count 0, empty `Groups`, non-empty kept list dropped `pt` without an error | Low | **fixed** (`check_lists`) |
| R3 | `integrity.rs:57-59` | the `flags` name was recorded before its members, so a member naming its own `flags` byte built but could not pack | Low | **fixed** (refused at construction; a `when` naming an earlier member still builds) |
| R4 to R7 | `lib.rs` order, doc wraps, `MapScheme::new` doc, `has_split_flags` | style and simplification | Low | **fixed** |
| R8 | `unpack.rs` 471, `field/mod.rs` 479, `Walker.java` 464 lines | close to the 500 cap | Low, Maint | **open** (split before the next addition) |

## C++ and harness (reviewer 4)

| # | Where | Finding | Severity | Outcome |
|---|-------|---------|----------|---------|
| H1 | `cases.test.sh:33` | `corrupt()` accepted any error | Low, Test | **fixed** (message fragment per corruption; proven by breaking a copy) |
| H2 | `cases.test.sh:20` | hard-coded count and id list | Low | **fixed** (derived count) |
| H3 | `check-cases.sh:43-48` | substring package count is brittle | Low | **fixed** (documented in the README format section) |
| H4 | `check-cases.sh:96-105` | README packet hex not compared with `cases.txt` | Low, Test | **fixed** (+2 corruptions) |
| H5 | `ring-wiring.test.sh:248` | driver command check always passed | Low, Test | **fixed** (command templates; 5 negative cases) |
| H6 | `unpack.cpp` | duplicated save/restore wrapper, magic `8` | Low, Maint | **fixed** (`kFlagBytes`, one NOINLINE template helper; host `__text` 3 904 B before and after) |
| H7 | `values.cpp` | two consecutive anonymous namespaces | Low | **fixed** |
| H8 | `unpack_scoped` flash cost | embedded size not measured | Low, Perf | **step 11** (embedded stages) |

## Checked and found correct (all four reviewers)

Placeholder flags byte and patching in all six; split flag byte decided where it is read; `when` on values written so far; `times` and `repeat` bits; AZ-2126 construction checks with no false refusal of valid schemes (integer sources including `u2` slots, `be()` fields, `i64`; bool source with `true`; counts naming `flags` and flag-byte names); golden `4001000065cd1d00a3e1110100` and the route fixture unchanged; no new swallowed exception, no `unwrap` on hostile data in Rust; unpack untouched; C# ring driver packs the three pinned hex strings exactly and refuses the short packets; `check-cases.sh` is bash 3.2 clean.
