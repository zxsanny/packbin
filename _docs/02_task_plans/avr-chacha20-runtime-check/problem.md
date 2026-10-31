---
loop: 92
branch: dev
---

# AVR runtime check of chacha20_xor (loop 92)

Source: `_docs/loops/loop91/handoff92.md` (candidates), probed on HEAD e64e3eb on 2026-10-31. The owner chose the AVR `chacha20_xor` check. No UI.

Stub written at intake; Phases 2-4 fill it in.

## Change location

No UI. Owner confirmed (2026-10-31): the AVR target in `cpp/embedded/arm.sh` (`target_avr_uno`), running `packbin::detail::crypto::chacha20_xor` from `cpp/src/core/crypto.cpp`.
