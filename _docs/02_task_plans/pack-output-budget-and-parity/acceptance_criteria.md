# Loop 20 acceptance criteria (loop level; the specs carry the testable Given/When/Then)

- AC-L1: a lone 65 535-character `utf8` under a `times` of 65 535 is refused by pack in TypeScript, Python, Java, C# and Rust in under 1 s with peak resident memory under 256 MB, naming the member (AZ-2354).
- AC-L2: a list element holding a `times` (40 items of `{n: 65535}` over a `u64` body, about 21 MB) is refused at the default and packs after the limit is raised to 32 MiB (AZ-2354).
- AC-L3: a packet of exactly `maxBytes` bytes packs; one byte more is refused, in 5 of 5 (AZ-2354).
- AC-L4: a 65-name round at count 65 535 (over `maxSlots`) is refused by pack in 5 of 5; a `repeat` of `maxRounds + 1` entries is refused, `maxRounds` packs (AZ-2354, AZ-2355).
- AC-L5: count 0 written after the byte with a list is refused in 6 of 6, with a lone scalar it packs (AZ-2356); a combined `flags` skipped count with values is refused in 6 of 6 (AZ-2360).
- AC-L6: C++ refuses the U4 and G4 shapes; arm stack at or under 512 B and flash at or under 8 192 B (AZ-2357, AZ-2364).
- AC-L7: C# refuses `5.0` for integer `eq` values and slots (AZ-2358); enum rule pinned by tests in each package and written in the README (AZ-2359).
- AC-L8: Java refuses `BigDecimal` 1.5 in `u2`/`bits`/`packed`, refuses a u64 count above int range in `sized`/`bits`, and `ByteSink` never overflows its size (AZ-2361); Python G2 and TypeScript G3 give named errors (AZ-2362, AZ-2363).
- AC-L9: no file named in AZ-2365 is above 500 lines; suites keep their counts.
- AC-L10: a typed C# `Unpack` of `03 01 02` for `Repeat(0, U8 V)` returns an error result, no exception; a `List<int>` of `u32` inside a round fails at construction (AZ-2366).
- AC-L11: the hostile set gains the new `pack` cases and all six loaders replay them (AZ-2367).
- AC-L12: all accepted rows keep their wire bytes: golden, route and ring fixtures pass unchanged.
