# Loop 21 acceptance criteria (loop level; the specs carry the testable Given/When/Then)

- AC-L1: a round packed at exactly `maxSlots` unpacks in the same package, and the charged slot count follows one rule in 6 of 6, pinned by `_docs/03_implementation/reference_loop21_slots.md` (AZ-2382, AZ-2381).
- AC-L2: a short list in an optional flags position is refused in 5 of 5 growable packages (AZ-2383); count 1 behind a clear `when` with no rounds is refused in 6 of 6 (AZ-2386); `bits`/`packed`/`sized` counts behind a clear `when` are refused in 6 of 6 (AZ-2387).
- AC-L3: a split-bit `times` with count above 0 after the byte and an absent or `[]` body packs a clear bit, same bytes, in 5 of 5 (AZ-2384); C++ packs a direct late `when` in a bit body when another child sets the bit, or the change is dropped with the flash saving recorded (AZ-2385).
- AC-L4: arm stack at or under 512 B and flash at or under 8 192 B after the loop.
- AC-L5: C# unpack returns `byte`/`ushort`/`uint`/`sbyte`/`short`/`int` for narrow integer fields and pack refuses a whole-number float for an integer field (AZ-2373); typed rounds bind to a collection of rows (AZ-2388); a dict member that cannot hold rounds fails at build (AZ-2389); `WithLimits(maxRounds, maxSlots)` still resolves (AZ-2393).
- AC-L6: an empty `times` or `repeat` body fails at build in 6 of 6, and the F33 request shape fails in under 1 s (AZ-2390).
- AC-L7: `times(65535) { u8 }` with 1 000 enclosing fields costs at most 2 times the 100-field run in TypeScript (AZ-2391).
- AC-L8: the four loaders (Python, Java, Rust, C++) check the rule or message of each refused `pack` case (AZ-2392).
- AC-L9: the hostile set gains the new `pack` cases and all six loaders replay them (AZ-2394).
- AC-L10: all accepted rows keep their wire bytes: golden, route and ring fixtures pass unchanged.
- AC-L11: no file touched is above 500 lines (soft cap).
