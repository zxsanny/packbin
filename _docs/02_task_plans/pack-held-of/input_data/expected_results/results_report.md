# Expected results: pack side `held_of`

No new input. Pairs map onto existing project rows.

| Input | Expected output |
|-------|-----------------|
| Every pack vector of `cpp/tests` (`make -C cpp test`) | byte-equal with the vector, as at HEAD |
| The all-kinds image of `cpp/embedded/common/all_kinds.hpp` on Cortex-M4F | flash at most 8,032 B; stack at most 504 of 512 B |
| A scheme with a `when` chain and a flag-bit chain, packed with a value that refuses | the same `Error`, offset and field id as at HEAD |
