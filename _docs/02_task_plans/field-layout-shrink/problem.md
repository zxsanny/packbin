---
loop: 62
branch: dev
---

# Smaller `Field` table entry in the C++ core (loop 62)

Source: `_docs/loops/loop61/handoff62.md` (candidate "`Field` layout", also in the handoffs of loops 57, 58 and 59). The hopper was empty; on 2026-10-23 the owner picked this candidate from that list in chat and confirmed the scope below in Phase 1.

## Problem

`Field` (`cpp/include/packbin/table.hpp:143`) is the table entry of the C++ package. Its function pointers `item` and `count` are read only for Array entries (`pack.cpp`, `unpack.cpp`, `values.cpp`), yet every entry pays for both: the entry is 36 B on the Cortex-M4F (16 B of small members, 8 B `eq`, then `access`, `item`, `count` at 4 B each), so the 14-entry table of the flash-budget image carries 112 B for fields that only Array entries use. The Cortex-M4F flash budget is 8,192 B with the pin at 8,032 B (160 B margin, `cpp/embedded/lib.sh`); the pack-side `held_of` of loop 61 was dropped because it cost 44 to 72 B over that pin. A saving here would raise the margin and could pay for other work in `cpp/src/core`.

The goal is a smaller `Field` (about 8 B per entry on 32-bit ARM) with the same packets, results, API and stack. Whether the pointers move, merge or are reached another way is a design choice for the task, not part of this problem.

## Code sections / UI locations for this loop

From the owner's pick of 2026-10-23, which named `Field`, the 36 B probe entry and `cpp/src/core`; the owner confirmed the list below in Phase 1. No UI.

| Work | Place |
|------|-------|
| `Field` layout and the Array builders (`array_item`, `array_count`, `bind_array`) | `cpp/include/packbin/table.hpp` |
| Readers of `item` and `count` | `cpp/src/core/pack.cpp`, `cpp/src/core/unpack.cpp`, `cpp/src/core/values.cpp` |
| Flash and stack measurement | `cpp/embedded/run.sh arm` (`arm.sh`, `lib.sh` pins), image `cpp/embedded/common/all_kinds.cpp` |
| Layout guard and notes | `static_assert(offsetof(Field, eq) == 16)` in `table.hpp`, `_docs/AGENT_GOTCHAS.md`, `_docs/02_document/components/05_cpp_package/description.md` |

Out of scope: the wire format, the other seven packages, the `Field` members `late`, `flags` and `eq`, raising the flash pin, any change a user of the package can see in the scheme-building API.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| A different way to reach an Array's item and count may add code that eats the table saving | measure first on the Cortex-M4F image; if flash is not at least 56 B under the pin, keep the source at HEAD and record the figures (AC-6), as loop 61 did | open | Medium |
| Stack margin is 8 B and helpers called from `unpack_one` keep three real arguments | the arm embedded stage runs before the commit; over 504 B is not kept | open | Medium |
| 16-bit targets (AVR, AZ-2068) have other pointer sizes | `cpp-avr-uno` must still build; a larger entry there goes to the owner | open | Low |
| Row U24 (three C++ runner skips) and the first `v*` / `go/v*` tags | owner decides separately | accepted-risk | Low |
