# Reference cases: `when`, `times`, `repeat` as a `flags` member (AZ-2120, AZ-2128 flagged concern)

Every hex below comes from a real run of the C# package at wave 3a (dictionary rows through `BinaryPacker.Pack` / `Read`; the
same bytes come from a typed row wherever a typed row can hold the row). Type number is `1`, so every packet starts with `01`.
Field names are lowercase here (C# uses PascalCase properties). Integers are little-endian: `heading=90` is `5a 00`.

## Rule (what C# implements; the other five packages must give the same bytes and rows)

1. Members of one `flags` container are decided **in order**, and each is decided against the values written so far in its
   scope (the same set a `when` is decided on at unpack). So a `when` may name an earlier member of the same `flags`.
   Implementation hint: write a placeholder flags byte, decide each bit just before writing that member, patch the byte at the end.
2. `when` member: bit on iff the condition holds on the values written so far AND its body holds a value (any body child
   present, at any depth). Condition false: bit clear, and a body value given in the row is not written and is not an error
   (the same as a `when` outside `flags`). Condition true and no body value: bit clear.
3. `times` member: bit on iff its count (the value of the count field, read from what was written in this scope) is above 0.
   Count missing (the count field was skipped): bit clear. Count 0 and a non-empty list given for a body value: pack error
   naming the value (the same as a `times` outside `flags`, hostile case `pack_times_list_too_long`).
4. `repeat` member: bit on iff at least one round has a value (a body value is present: a list with an entry, or a lone value).
   A `repeat` reads to the end of the packet, so it is the last thing in the packet.
5. In a `group` (anchored, under `flags`) the same three kinds count for the group's bit exactly as above (so the group's
   bit is on when only its `when` body, or only its `times` rounds, hold values).
6. A set bit whose member cannot be written in full (a body value of the `when`/round missing, a list shorter than the count)
   makes pack fail, naming the missing value. No bytes are returned.
7. Unpack of a set bit reads the body; unpack of a clear bit reads nothing and the row has no entry for the body values.
   Unpack is unchanged (it already did this in every package; C# is the reference reading).
8. Nothing else changes: golden `4001000065cd1d00a3e1110100`, route fixture, every packet not using this shape.

## Schemes

Notation as `fixtures/hostile/README.md`: ids follow the field order; a group/`flags`/`when`/`repeat`/`times` anchor equals the
next value id and is not written; ids continue through `flags`, `when`, `repeat`, `times` bodies; `eq(id, v)` tests the earlier field `id`;
`times` takes its count from an earlier integer field.

| Scheme | Definition |
|--------|-----------|
| WA | `id0 u8 mode; id1 flags anchor 1 { id1 when anchor 1 eq(0,1) { id1 u8 speed }, id2 u16 heading }` |
| WS | split form of WA: `id0 u8 mode; flagbyte m; bit m { id1 when anchor 1 eq(0,1) { id1 u8 speed } }; bit m { id2 u16 heading }` |
| WG | `id0 u8 mode; id1 flags anchor 1 { group g anchor 1 { id1 when anchor 1 eq(0,1) { id1 u8 speed } }, id2 u16 heading }` (g: the group's own presence member, null in every row) |
| W2 | `id0 u8 mode; id1 flags anchor 1 { id1 when anchor 1 eq(0,1) { id1 u8 speed, id2 u8 extra }, id3 u16 heading }` |
| GS | `id0 u8 mode; id1 flags anchor 1 { group g anchor 1 { id1 u8 extra, id2 when anchor 2 eq(0,1) { id2 u8 speed } }, id3 u16 heading }` |
| WE | `id0 flags anchor 0 { id0 u8 mode, id1 when anchor 1 eq(0,1) { id1 u8 speed } }` (the `when` names an earlier member of the same `flags`) |
| TA | `id0 u8 n; id1 flags anchor 1 { id1 times anchor 1 count=id0 { id1 u8 pt }, id2 u16 heading }` |
| TS | split form of TA: `id0 u8 n; flagbyte m; bit m { id1 times anchor 1 count=id0 { id1 u8 pt } }; bit m { id2 u16 heading }` |
| TG | `id0 u8 n; id1 flags anchor 1 { group g anchor 1 { id1 times anchor 1 count=id0 { id1 u8 pt } }, id2 u16 heading }` |
| T2 | `id0 u8 n; id1 flags anchor 1 { id1 times anchor 1 count=id0 { id1 u8 pt, id2 u8 pu }, id3 u16 heading }` |
| RA | `id0 u8 mode; id1 flags anchor 1 { id1 u16 heading, id2 repeat anchor 2 { id2 u8 pt } }` |
| R2 | `id0 u8 mode; id1 flags anchor 1 { id1 u16 heading, id2 repeat anchor 2 { id2 u8 pt, id3 u8 pu } }` |

A list value (`pt=[5,6]`) holds one entry per round. In a row, a name not listed is absent (null).

## `when`

| Case | Scheme | Row | Packs to | Unpack row |
|------|--------|-----|----------|------------|
| W-true (AC-3) | WA | mode=1 speed=7 heading=90 | `010103075a00` | mode=1 speed=7 heading=90 |
| W-false | WA | mode=0 heading=90 | `0100025a00` | mode=0 heading=90 |
| W-true-no-body | WA | mode=1 heading=90 | `0101025a00` | mode=1 heading=90 |
| W-false-body-given | WA | mode=0 speed=7 heading=90 | `0100025a00` (speed not written, no error) | mode=0 heading=90 |
| W-only-when | WA | mode=1 speed=7 | `01010107` | mode=1 speed=7 |
| W-only-mode | WA | mode=0 | `010000` | mode=0 |
| W-old-packet (unpack only) | WA | - | `0101025a00` unpacks without error | mode=1 heading=90 |
| W-new-packet (unpack only) | WA | - | `010103075a00` | mode=1 speed=7 heading=90 |
| W-split-true | WS | mode=1 speed=7 heading=90 | `010103075a00` | mode=1 speed=7 heading=90 |
| W-split-false | WS | mode=0 heading=90 | `0100025a00` | mode=0 heading=90 |
| W-split-no-body | WS | mode=1 heading=90 | `0101025a00` | mode=1 heading=90 |
| W-split-false-body-given | WS | mode=0 speed=7 heading=90 | `0100025a00` | mode=0 heading=90 |
| W-group-true | WG | mode=1 speed=7 heading=90 | `010103075a00` | mode=1 speed=7 heading=90 |
| W-group-false | WG | mode=0 heading=90 | `0100025a00` | mode=0 heading=90 |
| W-group-no-body | WG | mode=1 heading=90 | `0101025a00` | mode=1 heading=90 |
| W-group-false-body-given | WG | mode=0 speed=7 heading=90 | `0100025a00` | mode=0 heading=90 |
| W-group-only-when | WG | mode=1 speed=7 | `01010107` | mode=1 speed=7 |
| W-group-old-packet (unpack only) | WG | - | `0101025a00` | mode=1 heading=90 |
| W-missing-body-value (pack error) | W2 | mode=1 speed=7 heading=90 (extra missing) | pack error naming `extra` | - |
| W-two-values | W2 | mode=1 speed=7 extra=8 heading=90 | `01010307085a00` | mode=1 speed=7 extra=8 heading=90 |
| W-group-sibling-true | GS | mode=1 extra=4 speed=7 heading=90 | `01010304075a00` | mode=1 extra=4 speed=7 heading=90 |
| W-group-sibling-false | GS | mode=0 extra=4 heading=90 | `010003045a00` | mode=0 extra=4 heading=90 |
| W-group-sibling-missing-when-body (pack error) | GS | mode=1 extra=4 heading=90 (speed missing) | pack error naming `speed` | - |
| W-group-sibling-missing-sibling (pack error) | GS | mode=1 speed=7 heading=90 (extra missing) | pack error naming `extra` (group bit is on through the `when` body) | - |
| W-group-nothing | GS | mode=1 heading=90 | `0101025a00` (group bit clear) | mode=1 heading=90 |
| W-same-flags-true | WE | mode=1 speed=7 | `01030107` | mode=1 speed=7 |
| W-same-flags-false | WE | mode=0 speed=7 | `010100` (speed not written) | mode=0 |
| W-same-flags-no-body | WE | mode=1 | `010101` | mode=1 |
| W-same-flags-no-mode | WE | speed=7 | `0100` (mode missing: its bit clear, the `when` cannot hold) | (empty row) |
| W-same-flags-unpack | WE | - | `01030107` | mode=1 speed=7 |

## `times`

| Case | Scheme | Row | Packs to | Unpack row |
|------|--------|-----|----------|------------|
| T-0-rounds (AC-4) | TA | n=0 heading=90 | `0100025a00` | n=0 heading=90 |
| T-1-round | TA | n=1 pt=[5] heading=90 | `010103055a00` | n=1 pt=[5] heading=90 |
| T-2-rounds | TA | n=2 pt=[5,6] heading=90 | `01020305065a00` | n=2 pt=[5,6] heading=90 |
| T-only-times | TA | n=2 pt=[5,6] | `0102010506` | n=2 pt=[5,6] |
| T-only-n | TA | n=0 | `010000` | n=0 |
| T-old-packet (unpack only) | TA | - | `0100025a00` | n=0 heading=90 |
| T-new-packet (unpack only) | TA | - | `01020305065a00` | n=2 pt=[5,6] heading=90 |
| T-list-too-short (pack error) | TA | n=2 pt=[5] heading=90 | pack error naming `pt` | - |
| T-values-missing (pack error) | TA | n=1 heading=90 (pt missing) | pack error naming `pt` | - |
| T-count-0-values-given (pack error) | TA | n=0 pt=[5] heading=90 | pack error naming `pt` ("holds 1 items, but the times count is 0") | - |
| T-list-too-long (pack error) | TA | n=1 pt=[5,6] heading=90 | pack error naming `pt` ("holds 2 items, but the times count is 1") | - |
| T-split-0 / 1 / 2 | TS | as TA | the same bytes as the TA rows | as TA |
| T-split-errors | TS | as the four TA error rows | pack error naming `pt` | - |
| T-group-0 / 1 / 2 | TG | as TA | the same bytes as the TA rows | as TA |
| T-group-errors | TG | as the four TA error rows | pack error naming `pt` | - |
| T-two-values-missing (pack error) | T2 | n=1 pt=[5] heading=90 (pu missing) | pack error naming `pu` | - |
| T-two-values-1 | T2 | n=1 pt=[5] pu=[6] heading=90 | `01010305065a00` | n=1 pt=[5] pu=[6] heading=90 |
| T-two-values-2 | T2 | n=2 pt=[5,6] pu=[7,8] heading=90 | `010203050706085a00` | n=2 pt=[5,6] pu=[7,8] heading=90 |

(Round layout: round 0 is `pt[0] pu[0]`, round 1 is `pt[1] pu[1]`: `05 07 | 06 08`.)

## `repeat`

| Case | Scheme | Row | Packs to | Unpack row |
|------|--------|-----|----------|------------|
| R-0-rounds | RA | mode=1 heading=90 | `0101015a00` | mode=1 heading=90 |
| R-1-round | RA | mode=1 pt=[5] heading=90 | `0101035a0005` | mode=1 pt=[5] heading=90 |
| R-2-rounds | RA | mode=1 pt=[5,6] heading=90 | `0101035a000506` | mode=1 pt=[5,6] heading=90 |
| R-only-repeat | RA | mode=1 pt=[5,6] | `0101020506` | mode=1 pt=[5,6] |
| R-only-mode | RA | mode=1 | `010100` | mode=1 |
| R-old-packet (unpack only) | RA | - | `0101015a00` | mode=1 heading=90 |
| R-new-packet (unpack only) | RA | - | `0101035a000506` | mode=1 pt=[5,6] heading=90 |
| R-missing-body-value (pack error) | R2 | mode=1 pt=[5] heading=90 (pu missing) | pack error naming `pu` | - |
| R-two-values-1 | R2 | mode=1 pt=[5] pu=[6] heading=90 | `0101035a000506` | mode=1 pt=[5] pu=[6] heading=90 |
| R-two-values-2 | R2 | mode=1 pt=[5,6] pu=[7,8] heading=90 | `0101035a0005070608` | mode=1 pt=[5,6] pu=[7,8] heading=90 |
| R-two-values-unpack | R2 | - | `0101035a0005060708` unpacks as two rounds: (5,6) and (7,8) | mode=1 pt=[5,7] pu=[6,8] heading=90 |

## C# notes for the other workers

- Same-bytes checks across `typed` and `dict` rows: where the package has both, both must give the table's bytes.
- C# message for a missing value is `'<name>' ... has no value ...` (or `'<name>' holds N items, but the times count is M`); error kind and label are out of scope (C15). Each package checks that its error names the value.
- Bit order inside the flags byte is member order (bit 0 = first member). In WA the `when` is bit 0 and `heading` is bit 1; in RA `heading` is bit 0 and the `repeat` is bit 1.
- Hostile probe C# also checks: a body value outside its field range (speed=300, a round entry 300) fails pack naming the field, with no bytes.

## Loop 19 supersessions (AZ-2331, AZ-2335; owner decisions of 2026-10-11)

The rows above stay the reference for every case they pin, except the ones below. Nothing in the unpack column changes.

| Row or rule | Loop 18 text | Loop 19 |
|-------------|--------------|---------|
| Rule 3, "Count missing (the count field was skipped): bit clear" | silent, all six | superseded for values that are given. **Split form (WS, TS and the group shapes): all six packages refuse** a `times` whose count was never written (or is written after the byte) while a value is given, naming the value (AZ-2331 AC-1, AC-2; C++ does not see a count that is set in the row but behind a clear `when`). **Combined `flags` (TA, TG): Python and C++ refuse too** (C++ only when the count has no value in the row; a count set in the row but behind a clear `when` still packs, `010003055a00`); C#, TypeScript, Java and Rust keep the silent drop (not decided, loop 20) |
| W-split-false-body-given (WS, mode=0 speed=7 heading=90) | `0100025a00`, no error | **unchanged**: AC-3 was decided as option A, so a false condition packs silently with the body left out, whether the `when` source is written before or after the flag byte, in all six packages. C# and Rust applied AC-3 literally first and were corrected in the follow-up. The error is loud only when the body would be written and the byte left the bit clear |
| T-split-0 / 1 / 2 (TS) | the same bytes as TA | unchanged when the count is written before the byte; a count written after the byte with a count above 0, or 0 with a list of values, is an error |
| T-split-errors (TS) | pack error naming `pt` | unchanged; a lone scalar with a count of 0 packs `0100025a00` in C# (review A1) and Rust |
| Rule 3, count 0 and a non-empty list | pack error naming the value | unchanged, and the same error everywhere outside `flags` (AZ-2335: all six); a **lone scalar** with count 0 is not an error in any package (`01 00` for `u8 n; times(n, u8 x)`) |
| New: W-split-source-after-byte, T-split-count-after-byte, T-split-count-skipped | not in the table | hostile `pack` cases of the same names; error naming the member in all six packages |
| New: sibling `flags` scope | Rust shared one flag-byte scope for the members of one `flags` (batch 1 discovery 3) | each member has its own scope in C++, TypeScript, Java and now Rust (AZ-2333; C# and Python not re-checked); `flagbyte fb; flags(group g1 {v; fb byte; bit fb x}, group g2 {bit fb y}); bit fb b` with v=3 x=5 y=6 b=7 packs `0103030301050607` in TypeScript and Rust |
