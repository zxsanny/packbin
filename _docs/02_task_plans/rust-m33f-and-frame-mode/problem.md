---
loop: 69
branch: dev
---

# Loop 69: Rust on Cortex-M33F, and Rust frame mode for meshbell (AZ-3192)

Status: Phase 1 intake stub (grasped from the owner's chat, 2026-10-25); Phase 1 not yet confirmed.

## What

Two items in one loop, both in the Rust package:

1. **Rust embedded stage on Cortex-M33F** (owner accepted the recommended option, 2026-10-25): build the Rust `nostd` core for the nRF54L15 core (M33F), with its own flash and stack pins, next to the C++ `cpp-m33f` row of loop 68. The Rust stage still builds for Cortex-M4F.
2. **AZ-3192, packbin Rust frame mode for meshbell** (owner added, 2026-10-25; Jira To Do, 17 points, labels frame-mode, meshbell, packbin, rust): the 4-byte network MIC on every radio frame, node seals, opening the network-key delivery record, and the MAC-only key-check call. Jira scope names four hand-off specs in meshbell `_docs/cross_repo/packbin/`: PB-01 contract and ADR (3), PB-02 primitive reference vectors for HMAC-SHA256, HKDF and ChaCha20 (3), PB-03 frame golden vectors (3), PB-04 Rust frame mode (8). Done when the seal, open and MAC-only call match the PB-03 vectors on the host and in the Cortex-M4F embedded stage, and meshbell pins the packbin commit. No version byte (rule R-08).

## Code sections / UI locations for this loop

- `rust/src/nostd` and the Rust embedded stage `rust/embedded/` (item 1 and the frame mode of item 2), named by the owner in the loop 69 choice.
- Arm stage link scripts and pins for M33F: `cpp/embedded/arm/`, `cpp/embedded/lib.sh` (read as the model for the Rust row; the C++ rows stay).

## Flagged concerns

| concern | policy / owner | status | severity |
| --- | --- | --- | --- |
| The meshbell hand-off specs PB-01 to PB-04 are not on this machine (`../meshbell` does not exist; workspace boundary forbids writing there) and the Jira text holds only the scope; the frame mode contract (tag input, key derivation, nonce, epoch keys, replay window) is unknown | owner supplies the specs or says PB-01 is written here from the Jira text | open | Critical |
| AZ-3192 is 17 points (13 or more forces `/decompose`), plus item 1: one loop may be too large | owner chooses the split | open | High |
| Item 1 needs QEMU `mps2-an505` for a Rust row; the Rust stage runs no QEMU today (to be read in Phase 2) | agent reads `rust/embedded/` | open | Medium |
