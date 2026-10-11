# Loop 19 acceptance criteria (loop level; the specs carry the testable Given/When/Then)

- AC-L1: `pack` of a `times` count above `maxRounds` is refused in TypeScript, Python, Java, C# and Rust in under 100 ms and with no allocation proportional to the count (AZ-2329).
- AC-L2: the Python row of review T1 packs to `010201050100` and unpacks to the TypeScript row (AZ-2330).
- AC-L3: three split-form shapes (condition after the byte, skipped count, false condition with a body) are refused by pack in 6 of 6 packages naming the member (AZ-2331).
- AC-L4: a lone byte buffer in a round is refused in 5 of 5 packages that have rounds with buffers (AZ-2332).
- AC-L5: sibling `flags` members pack to the same hex in Rust, TypeScript, Java and C++ (AZ-2333).
- AC-L6: `eq(emptyGroup, true)` builds and packs in C++ with Rust's hex; arm stack stays at or under 512 B (AZ-2334).
- AC-L7: `times` count 0 with values is refused in 6 of 6 (AZ-2335); a short list is a named error in Python (AZ-2336).
- AC-L8: a C# group element with a missing member reports it by name and ignores the outer row (AZ-2337).
- AC-L9: `eq` with an out-of-range, non-integer, NaN or bool-for-integer value is refused at construction in 6 of 6 (AZ-2338).
- AC-L10: a per-package table of the fraction-slot probe exists in the batch report (AZ-2339).
- AC-L11: no listed near-cap file is above 400 lines; every package suite keeps its pass count (AZ-2342).
- AC-L12: the hostile set gains the new `pack`/`construct` cases and all six loaders replay them (wave 2).
- AC-L13: all accepted rows keep their wire bytes: golden, route and ring fixtures pass unchanged except the Python and Rust rows named above.
