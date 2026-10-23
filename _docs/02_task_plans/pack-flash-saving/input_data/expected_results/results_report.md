# Expected results: pack.cpp flash saving, then pack-side `held_of`

No new input. Pairs map onto existing project rows.

| Input | Expected output |
|-------|-----------------|
| Every pack vector of `cpp/tests` (`make -C cpp test`, host and `gcc:16`) | byte-equal with the vector, as at HEAD |
| The all-kinds image of `cpp/embedded/common/all_kinds.hpp` and the 14-entry probe on Cortex-M4F, after a kept saving | flash at most 7,736 B (a saving of 72 B or more) or at most 7,807 B (a smaller saving); stack at most 496 of 512 B |
| The same probe after a kept `held_of` | flash at most the part 1 figure; stack at most the part 1 figures |
| A scheme with a `when` chain and a flag-bit chain, packed with a value that refuses | the same `Error`, offset and field id as at HEAD |
