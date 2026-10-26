---
loop: 74
branch: dev
---

# Loop 74: remove the stream session; frame mode is the one session

Phase 1 grasp: owner, 2026-10-26. The first answer ("Session wipe at destroy", AskQuestion at loop start) was replaced in the same intake: the owner asked what the stream `PackSession` is for, the agent found no application where it is the right tool, and the owner chose "Remove it" (AskQuestion "Stream mode", recommended option). Then, in chat: "let it be FrameSession, and match everywhere; add frame mode to C++, Go, Python and TypeScript, maybe put that as an additional task".

## What

Packbin has two session modes (ADR-008). The **stream** session shares a 32-byte seed; the opener sends 16 bytes once; every packet is XORed with a ChaCha20 stream picked by an implicit counter; there is no tag. The **frame** session seals each message on its own with per-device keys, a caller nonce and a truncated HMAC tag (encrypt-then-MAC), and refuses a changed, replayed or misdirected frame.

Why the stream session goes (owner, 2026-10-26):
- The websocket runs over wss: TLS already encrypts and authenticates, so stream mode adds nothing there.
- Radio links lose frames: the counter is never sent, so one lost packet garbles every later one. Frame mode exists for that.
- No other application was found. Secrecy through a relay that ends TLS is served better by frame mode, which authenticates; stream mode is malleable (flip ciphertext bit k, plaintext bit k flips).
- A shared seed is the weaker key model; per-device keys, or a public-key exchange, are better.

The stream session shipped in v0.1.x to v0.3.0 and `go/v0.3.0`; the packages are 0.x, so the removal is a minor version step. meshbell uses frame mode only.

This loop:
1. Removes the stream session from all eight packages: Rust std `PackSession`, the stream half of the Rust heap-free `Session`, the Rust `session` Cargo feature and its embedded set; the C#, Java, Swift, C++, Go, Python and TypeScript `PackSession`; their tests, README sections, fixtures, hostile drivers and docs.
2. Renames the Rust heap-free frame type `Session` to `FrameSession`, and makes the frame API names match in the four frame-mode packages (Rust, C#, Java, Swift).
3. Keeps the HKDF-SHA256 and ChaCha20 code of C++, Go, Python and TypeScript, because frame mode is added to those four packages next.

Additional tasks (owner: "put that as an additional task"): frame mode in C++, Go, Python and TypeScript, one task per package, equal to Rust on `fixtures/frame/vectors.txt` and `fixtures/crypto/vectors.txt`. Specs are written in this loop; they run after the removal.

Frame-mode bytes do not change: the 157 rows of `fixtures/frame/vectors.txt` and the 27 rows of `fixtures/crypto/vectors.txt` stay byte for byte.

## Code sections / UI locations for this loop

Owner words: "Remove it" on the option "delete stream mode from all 8 packages, fixtures, ring and docs; contract 3.0.0 (frame mode only); next 0.x minor"; "let it be FrameSession, and match everywhere".

Sites: each package's stream `PackSession` and its tests (inventory in `feature-description.md`), `rust/src/nostd/session.rs`, `rust/src/session/`, `rust/Cargo.toml` features, `rust/embedded/`, `fixtures/hostile/fuzz/`, `_docs/02_document/contracts/library/pack-session.md`, `_docs/02_document/adr/`, `README.md`.

## Flagged concerns

| concern | policy / owner | status | severity |
| --- | --- | --- | --- |
| Removing `PackSession` breaks any v0.1.x to v0.3.0 user of it | owner, 2026-10-26: remove; 0.x minor step, release notes say so; no user known | accepted-risk | Medium |
| ADR-008 says one session type serves the websocket (stream) and the radio (frame) | ADR-009 (this loop) records the removal; ADR-008's frame decision stands | open | Low |
| Renaming the Rust heap-free `Session` to `FrameSession` is a source change for meshbell's Rust code (another repository) | owner, 2026-10-26: "let it be FrameSession"; the change is documented for meshbell, not made there (workspace boundary) | accepted-risk | Low |
| C++, Go, Python and TypeScript have no session at all until their frame-mode ports land | owner, 2026-10-26: frame mode in those four as additional tasks | open | Low |
| The four kept crypto primitives have no caller in those packages until the frame port | kept on purpose for the port (owner); each keeps its own tests | open | Low |
