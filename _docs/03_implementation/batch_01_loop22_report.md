# Loop 22 batch 01 report (waves 1a, 1b, 2 in one batch; one total review after)

Date: 2026-10-12. Commit 04a8cd9. Workers per package directory; package suites only (no per-batch review or Docker run, owner rule). Contract: `reference_loop22.md` (TypeScript). Running notes: `_docs/loops/loop22/notes22.md`.

| Wave | Worker | Specs | Package suite |
|------|--------|-------|---------------|
| 1a | typescript | AZ-2410, AZ-2415, probe rows for AZ-2413/AZ-2414/AZ-2412 | 905 (917 after loaders); strict `tsc` clean |
| 1a | cpp | AZ-2416 (`has_member` in `cpp/include/packbin/order.hpp`) | host and `gcc:16` green; arm: flash 8152 of 8192 B (margin 40 B), stack 456 of 512 B (margin 56 B) |
| 1a | csharp | AZ-2411 (also integer dicts with float values) | 1800 on net10.0 and netstandard2.0 |
| 1a | rust | AZ-2412 (map scheme; flags / split-bit path) | 484 lib + integration |
| 1b | python | AZ-2410, AZ-2413 (equal-length check removed), AZ-2415 | 1082 (1003 at HEAD) |
| 1b | java | AZ-2410, AZ-2415, AZ-2413 probe | 2204 checks (2153) |
| 1b | csharp (pass 2) | AZ-2410, AZ-2415, AZ-2413 probe | 1827 on both targets |
| 1b | rust (pass 2) | AZ-2414 (shape A), AZ-2410, AZ-2415, AZ-2413 probe | 485 lib + integration |
| 1b | cpp (pass 2) | AZ-2410 probe: no source change (a typed row has no "no value") | host and `gcc:16` green |
| 2 | fixtures | AZ-2417: 10 new cases | `check-cases.sh` ok: 65 |
| 2 | six loaders | AZ-2417 replay, AZ-2418 AC-1 standing wrong-rule tests (TS 2, Python 4, Rust 4, Java 7, C# 3 groups, C++ 1) | TS 917, Python 1099, Java 2252, C# 1840, Rust 489 lib + integration, C++ green |

AZ-2418 AC-2 (`row4_packed_*`): nothing to correct; the case exists only in the TypeScript SPEC table, and the README "width 1" lines belong to the `pack_*_count_clear_when` cases, which TypeScript already builds with width 1.

Worker slips, all contained: none touched the index; the Python worker removed a stray `hostile_refusals.py-E` its sed left.

## AZ-2415 memory A/B (F10 shape, peak RSS, default limit before and after)

| Package | Before (4 194 304) | After (1 048 576) | Share of old peak | Note |
|---------|--------------------|-------------------|-------------------|------|
| TypeScript | 1 070 MB | 353 MB | 33 % | Node 22 |
| Java | 960 MB | 317 MB | 33 % | `-Xmx4g`; 824 -> 273 MB at `-Xmx1g` |
| C# | 733 MB | 235 MB | 32 % | typed unpack; dictionary read 731 -> 232 MB |
| Python | 550 MB | 162 MB | 29 % | |
| Rust | 628 MB | 120 MB | 19 % | stand-in shape (64-wide `times`, 65 535 rounds): a list element cannot hold a `times` |

All under 400 MB. The slot count is exactly a quarter; the runtime floor and the packet do not shrink, so peak RSS is 29 to 33 % (parent reading of AC-2, decision in the spec).

## Probe outcomes (AZ-2413, rows R1 to R3 of `reference_loop22.md` section 3b)

TypeScript, Java, C# and Python agree after the change: a lone value and a `when` list outside `flags` pack to the same bytes; a short required list is refused (Python `KeyError 'missing field b'`, Java `expected int, got null`, C# `'B' has no value`, TypeScript `missing b`). Rust takes `repeat` rounds as groups only, so its per-name rows are refused with the AZ-2412 text; through `times` it matches TypeScript except lists for a member under a `when` (refused, TypeScript packs them).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear or unclear |
|---|---------------------|----------|-------------------|------------------|
| 1 | Rust refuses a list for a member under a `when` inside a `times`; TypeScript, Python, Java, C# pack it. Rust unpack gives per-name lists with only the rounds that read the name, so repacking from them shifts values | AZ-2414 | owner row for loop 23 (align Rust or document) | unclear |
| 2 | C++ builds `when(id, eq(-1, v), ...)`: never holds, member dropped silently on pack, unpack fails | AZ-2416 | refuse a negative `eq` field id (flash check) | unclear |
| 3 | C++ `packed` with bias -1 refused in every cell (not traced) | AZ-2410 | trace | unclear |
| 4 | The three `construct_empty_*when*` cases are refused by the scope rule first in five packages; C++ shows the empty-body rule only with `eq(-1, ...)` | AZ-2417 | per-package pins exist; consider a case shape that reaches the rule | unclear |
| 5 | C++ `check_shape` lives in `cpp/include/packbin/order.hpp` (spec said `cpp/src/core`) | AZ-2416 | spec text fixed | clear |
| 6 | C#: `List<decimal>` for an `f32`/`f64` field is refused at build (existing) | AZ-2411 | decide later | unclear |
