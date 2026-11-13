# Probe: a `flags` that is a direct member of a `flags` (AZ-4251, loop 118)

Date: 2026-11-13. Probe: `scripts/probes/flags-in-flags/` (README there). Scheme `S`, type 1: `flags(flags(u8 x), bool b)`. Reference: TypeScript (`typescript/src/flag-bits.ts` `bitOn`, case `flags`).

## Result

Every package builds `S`, packs the TypeScript bytes for all four shapes and reads them back: 36 lines on stdout plus the second forms (C# dictionary, Rust typed, Java typed, C++ `constexpr`), all `same`. Two runs: 29 s and 26 s, byte-identical, nothing written into the checkout.

| package | both `01030109` | x-only `01010109` | b-only `0102` | none `0100` | second form |
|---------|-----------------|-------------------|---------------|-------------|-------------|
| TypeScript | same | same | same | same | — |
| C# (after the fix) | same | same | same | same | dictionary (`-map`, stderr): same |
| Python | same | same | same | same | — |
| Rust | same | same | same | same | `-nostd`: same; typed `Scheme<T>` (stderr): same |
| Java | same | same | same | same | typed row (stderr): same |
| C++ | same | same | same | same | `constexpr` (stderr): same |
| Go | same | same | same | same | — |
| Swift | same | same | same | same | — |
| Dart | same | same | same | same | — |

Scope: Python, Go, Swift and Dart were probed in their map-row form only (their typed rows build the same nodes; not run). C# also pins the split flag-byte form (`FlagByte().Bit(Flags(...))`) in `csharp/tests/FlagsInFlagsTests.cs`: it went through the same rule and dropped the inner value too.

## C# before the fix

The same probe run against the C# source with the new `Flags` arm of `Walker.BitOn` removed (the code before this loop):

```
csharp	both	built	0102	differs: {"B":true,"X":null}
csharp	x-only	built	0100	differs: {"B":false,"X":null}
csharp	b-only	built	0102	same
csharp	none	built	0100	same
```

The inner value was dropped with no error whenever it was given. `b-only` and `none` were already right: they hold no inner value.

## Decision for the class

None needed: C# was the only package with the defect, and it is fixed in this loop (AZ-4251). No packet of another package changes, so no README upgrade note (spec constraint). A packet C# wrote before the fix never held the inner value; it reads the same as before.

## Raw output (stdout, run 1)

```
typescript	both	built	01030109	same
typescript	x-only	built	01010109	same
typescript	b-only	built	0102	same
typescript	none	built	0100	same
csharp	both	built	01030109	same
csharp	x-only	built	01010109	same
csharp	b-only	built	0102	same
csharp	none	built	0100	same
python	both	built	01030109	same
python	x-only	built	01010109	same
python	b-only	built	0102	same
python	none	built	0100	same
rust	both	built	01030109	same
rust	x-only	built	01010109	same
rust	b-only	built	0102	same
rust	none	built	0100	same
rust	both-nostd	built	01030109	same
rust	x-only-nostd	built	01010109	same
rust	b-only-nostd	built	0102	same
rust	none-nostd	built	0100	same
java	both	built	01030109	same
java	x-only	built	01010109	same
java	b-only	built	0102	same
java	none	built	0100	same
cpp	both	built	01030109	same
cpp	x-only	built	01010109	same
cpp	b-only	built	0102	same
cpp	none	built	0100	same
go	both	built	01030109	same
go	x-only	built	01010109	same
go	b-only	built	0102	same
go	none	built	0100	same
swift	both	built	01030109	same
swift	x-only	built	01010109	same
swift	b-only	built	0102	same
swift	none	built	0100	same
dart	both	built	01030109	same
dart	x-only	built	01010109	same
dart	b-only	built	0102	same
dart	none	built	0100	same
```
