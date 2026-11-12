# Contract: a repeat is the last thing a packet reads

**Component**: library
**Producer task**: AZ-4210 (hostile cases and README text); epic AZ-4209
**Consumer tasks**: AZ-4211 (TypeScript), AZ-4212 (C#), AZ-4213 (Python), AZ-4214 (Java), AZ-4215 (Go), AZ-4216 (Swift), AZ-4217 (Dart), AZ-4218 (Rust), AZ-4219 (C++)
**Version**: 1.0.2
**Status**: frozen (owner decision 2026-11-12, loop 112: "Refuse at build"); implemented in all nine packages in loop 113 (AZ-4210 to AZ-4219)
**Last Updated**: 2026-11-12

## Purpose

A `repeat` has no count on the wire: unpack reads rounds until the buffer ends. Whatever a scheme writes after a repeat is read as more rounds, so the package packs a packet its own unpack refuses, or (two repeats in a row) reads back other values with no error. Measured in all nine packages in loop 112 (`_docs/06_metrics/repeat-followed-by-field_2026-11-12.md`). This contract is the one rule every package checks when a scheme is built, so the nine checks agree.

## Rule

A scheme is refused when it is built if a `repeat` is not the last thing its packet reads. Three cases:

1. **Followed.** A field that can write a byte stands after the repeat. "After" means later in the repeat's own place, or later in any place around it: after the `when`, `flags`, flag bit, group or nested row that holds the repeat, and so on up to the top level of the scheme.
2. **Inside an element.** The repeat sits inside a list or dict element, directly or under a `when`, `flags`, group or nested row of the element. The next element, or the field after the list, follows it.
3. **Inside a round.** The repeat sits inside a `repeat` or `times` round. The next round follows it. TypeScript, C#, Python, Go, Swift and Rust refused this before this contract by their nesting rule and keep that rule and its message. Dart's nesting rule did not look inside a nested row of a round: it keeps its rule and message for the rest and refuses a `repeat` in a nested row of a round by this contract (a `times` there still builds in Dart). Java and C++ allowed it and refuse it by this contract, a group or nested row of the round included.

### A field that can write a byte

| counts | does not count |
|--------|----------------|
| an integer, a float, `bytes` with a size above 0, `utf8`, `sized`, `bits`, `packed`, `u2` | a `bool` (it is a bit of a flag byte that was written earlier) |
| a flag byte, a `flags` | `bytes` with size 0 |
| a `list`, a `dict` | a `when`, group, nested row, `times` or `repeat` that holds nothing that counts |
| a `times` or a `repeat` whose body holds something that counts | |
| a `when`, group, nested row or flag bit that holds something that counts | |

The check is on the scheme, not on a row: a field counts when it can write a byte for some row, whether or not a `when` is taken or a count is zero.

### Refusal

- When: at scheme construction, in every way the package has to build a scheme (typed rows and map rows, the `constexpr` and the run-time form in C++, the map form and the heap-free `validate` in Rust). Never at pack or unpack.
- Kind: the package's scheme error, the same kind its other scheme rules use (the `scheme_error` outcome of `fixtures/hostile/README.md`).
- Text, where the package's scheme errors carry a text: it names the repeat and the first field that follows it, in the words the package's other scheme errors use for a field, and says what to use.
  - Followed: `repeat <anchor>: <field> follows it; a repeat reads to the end of the packet, so nothing can follow it; use times`
  - Inside an element: `repeat <anchor> is inside a list or dict element; a repeat reads to the end of the packet, so another element cannot follow it; use times`
  - Inside a round (Java, and Dart inside a nested row of a round; C++ reports a status; the other six keep their text, which also covers a `times` in a round): `repeat <anchor> is inside a repeat or times round; a repeat reads to the end of the packet, so another round cannot follow it; use times`
- C++ and the Rust heap-free API report a status and a field id, not a text: `SchemeInvalid` with the id of the first field that follows (case 1) or of the repeat (cases 2 and 3). A C++ `constexpr` scheme does not compile.

## Cases

Type number 1. `v`, `w`, `x`, `k`, `mode` are `u8`. Ids follow each package's numbering rule.

### Refused

| id | scheme | case |
|----|--------|------|
| R1 | `repeat(v)`, `x` | 1, top level |
| R2 | `k`, `when(k == 1, repeat(v))`, `x` | 1, after a `when` |
| R3 | `flags(repeat(v))`, `x` | 1, after a `flags` |
| R4 | a nested row or group that holds `repeat(v)`, then `x` | 1, after a nested row |
| R5 | `repeat(v)`, `repeat(w)` | 1, a second repeat |
| R6 | `k`, `when(k == 1, repeat(v))`, `when(k == 2, x)` | 1; the two `when`s cannot both be taken, and it is refused all the same (decision below) |
| R7 | `list` of rows `(mode, repeat(v))` | 2 |
| R8 | `dict` of rows `(mode, repeat(v))` | 2 |
| R9 | `k`, `times(k, repeat(v))` | 3 (new in Java and C++) |

A package whose list or dict element cannot be a row (Rust; C++ for a list or dict bound to a member) has no spelling of R7 and R8 and keeps its own refusal of the row; its tests name the two cases as not writable. C++ refuses R7 and R8 in the unbound form `list(element)`, which builds today.

### Still builds, same bytes

| id | scheme | values | packet |
|----|--------|--------|--------|
| K1 | `x`, `repeat(v)` | `x = 9`, `v = [5, 6]` | `01 09 05 06` |
| K2 | `k`, `when(k == 1, repeat(v))` | `k = 1`, `v = [5, 6]` | `01 01 05 06` |
| K3 | `flags(x, repeat(v))` (the repeat is the last member, nothing after the `flags`) | `x = 9`, `v = [5, 6]` | `01 03 09 05 06` |
| K4 | `k`, `times(k, v)`, `x` (a `times` has a count; fields may follow it) | `k = 2`, `v = [5, 6]`, `x = 9` | `01 02 05 06 09` |
| K5 | a flag byte, a bit of it on `x`, `repeat(v)`, a second bit of it on a `bool` (split flag-byte form; only in packages that have it) | `x = 9`, `v = [5, 6]`, the `bool` true | `01 03 09 05 06` |

K1 to K5 were run in TypeScript on `9cfccda` (loop 112, a scratch run): each packs the packet above and reads back the values. On the same code R6 builds and packs `01 02 09` for `k = 2`, `x = 9` (it reads back), and R9 is refused by the nesting rule. The other eight packages were not run for K2 to K5; each package task runs them on its unchanged code first and reports a packet that differs before it changes anything.

## Invariants

- No packet changes: a scheme that builds under the rule packs and unpacks the same bytes as before it.
- The rule never looks at a row. It is one linear pass over the scheme: paid once when the scheme is built in every package except the Rust heap-free API, where it is a pass over the scheme table inside `validate`, which every heap-free pack and unpack runs first.
- All nine packages refuse R1 to R9 (where the package can write them) and build K1 to K5 (where the package can write them).
- The check runs for a scheme built in any public way; none bypasses it.

## Decisions

- Owner, 2026-11-12 (loop 112): refuse at scheme build. The alternatives (allow a field under a `when` that cannot hold together with the repeat's `when`; refuse at pack; keep the README sentence) were not taken. The first can be added later as a relaxation without breaking a scheme; R6 pins today's answer.
- Agent default, loop 112 (the owner can overrule it): Java and C++ refuse a repeat inside a round at build (case 3), as the other seven do. Today Java packs such a scheme in some rows and refuses others at pack (`a repeat has no end marker, so it can be written in one round only`), and the README warns that the packet reads back differently.

- Agent, loop 113 (the owner can overrule it; `_docs/OPERATOR_TODO.md` D7): the Java text of case 3 does not reuse the sentence of the other seven ("a round cannot hold another repeat or times"), because in Java a round can hold a `times`. It gives the reason of this rule instead, in the shape of the other two texts.

## Non-Goals

- The wire format of `repeat` does not change; no count is added.
- `times` is not restricted: it has a count, and fields may follow it and it may sit in an element.
- Unpack does not change. A packet of a scheme that no longer builds cannot be unpacked with that scheme; a reader of such packets writes the scheme with `times` or reads the bytes by hand.

## Test Cases

| id | case | expected |
|----|------|----------|
| T1 | R1 to R9, each form the package has | scheme error at construction; the text (or the status and field id) as above |
| T2 | K1 to K5 | builds; packs the packet; unpacks to the values |
| T3 | the shared hostile cases of the producer task | `scheme_error` for the `construct` cases, the packet for the `pack` cases |
| T4 | every fixture, golden vector and ring handoff | unchanged bytes |

## Change Log

- 1.0.0 (2026-11-12, loop 112): first version, from the probe findings and the owner's decision.
- 1.0.1 (2026-11-12, loop 113, AZ-4210): the Java text of "inside a round" changed from "...; a round cannot hold another repeat or times" to "...; a repeat reads to the end of the packet, so another round cannot follow it; use times". The old sentence is false in Java and C++, where a `times` inside a round builds. No case and no outcome changed.
- 1.0.2 (2026-11-12, loop 113, AZ-4210, from the code review): rule 3 names Dart's nested row of a round (its nesting rule did not look there, so `k, times(k, nested m { repeat(v) })` built and packed `0102050607`; it is refused now with the Java text, and `times` in a nested row of a round still builds in Dart); C++ refuses a repeat in a group of a round too, and the shared cases `construct_repeat_in_group_in_repeat_round` and `construct_repeat_in_group_in_times_round` (AZ-4232, variants of R9 one container deeper) pin it in all nine packages; the status line says the rule is implemented. No case and no outcome of R1 to R9 and K1 to K5 changed.
  The pass over the table is paid per call in the Rust heap-free API (`nostd::validate`, 104 to 112 B of flash on the device pins); the Non-Functional wording of the package specs ("nothing per pack or unpack") holds for the map form and for C++ only.
