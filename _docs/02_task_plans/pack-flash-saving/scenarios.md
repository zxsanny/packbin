# Scenarios: pack.cpp flash saving, then pack-side `held_of`

| # | Scenario | Row | Status |
|---|----------|-----|--------|
| 1 | A saving of at least 72 B is found: kept, pin lowered, part 2 (`held_of`) runs | AC-2, AC-5, AC-6 | confirmed |
| 2 | A saving of 1 to 71 B is found: kept as a pure reduction, pin lowered, part 2 skipped | AC-2, AC-5 | confirmed |
| 3 | No saving in any shape tried: source stays at HEAD, shapes and figures recorded, no pin change | AC-2 | confirmed |
| 4 | `held_of` on top of the saving ends above the part 1 figure: dropped, source at the part 1 state | AC-7 | confirmed |
| 5 | A saving grows a stack figure (a deeper or wider pack frame): that shape is dropped or reshaped | AC-3 | confirmed |
| 6 | A refused value inside a flag bit's child, a held `when`, a counted item or a dict key: same `Error`, offset and field id | AC-4 | confirmed |
| 7 | GCC 16 `-Werror` or avr-gcc 7.3 rejects a construct the Mac clang accepted | AC-9 | confirmed |
| 8 | The other seven packages read bytes the C++ pack wrote (shared corpus, ring) | AC-4 | confirmed |
