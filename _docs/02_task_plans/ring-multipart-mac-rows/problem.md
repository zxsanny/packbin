---
loop: 96
branch: dev
---

# Frame ring: MAC rows over a message in several parts

Owner decision (2026-10-31, loop 96 intake, hopper empty): picked "multi-part MAC rows in the ring" from the loop 95 leftovers; this is the opt-in that G8m of loop 77 asked for. Ticket AZ-3495.

## What and why

The ring (`.github/workflows/ring-frame.sh`, rows in `fixtures/frame/ring-cases.txt`) sends each driver a `mac` line with one hex message. Every package's MAC-only call takes a message in parts, so the in-parts path is not compared across the eight languages. Detail follows in Phase 2.

## Code sections / UI locations for this loop

No UI. The frame ring harness only (details in Phase 2).
