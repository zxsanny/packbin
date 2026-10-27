# ADR-009: Frame mode is the only session; the stream session is removed

- **Status**: Accepted
- **Date**: 2026-10-26
- **Deciders**: project owner (loop 74 intake, 2026-10-26: "Remove it"; "let it be FrameSession, and match everywhere"; decisions D1 to D6 "Accept all recommended")
- **Supersedes**: —
- **Superseded by**: —

## Context

ADR-008 kept two session modes: `stream` (a shared 32-byte seed, a 16-byte opener nonce, a ChaCha20 pad per packet, an implicit counter, no tag) for the websocket, and `frame` (sealed, authenticated frames) for the radio. At the loop 74 intake the owner asked what the stream session is for. The websocket runs over wss, which already encrypts and authenticates, so stream mode adds nothing there. A lossy link cannot use it: the counter is never sent, so the first lost packet garbles every later one (ADR-008 rejected it for the radio on that ground). The one niche found, secrecy from end to end through a relay that ends TLS in the middle, is served better by frame mode, which also works on ordered links and refuses a changed byte; stream mode has no integrity check (flipping ciphertext bit k flips plaintext bit k). Its only edge is zero bytes of overhead against frame mode's 4-byte minimum tag. The owner also noted that a shared seed is the weaker key model; per-device keys (frame mode) or a public-key exchange (TLS, or a later pairing step) are better.

The stream session shipped in v0.1.x to v0.3.0 and `go/v0.3.0`. The packages are 0.x, so a removal is a minor version step. meshbell, the only named consumer, uses frame mode.

- Acceptance criteria addressed: `_docs/02_task_plans/remove-stream-session/acceptance_criteria.md`
- Contract: `_docs/02_document/contracts/library/pack-session.md` 2.0.0 (becomes 3.0.0)

## Decision

We will remove the stream session from all eight packages and keep frame mode as the one session of packbin.

The removal covers each package's stream `PackSession` (Rust std, C#, Java, Swift, C++, Go, Python, TypeScript), the stream half of the Rust heap-free `Session`, the Rust `session` Cargo feature and its embedded set, the stream rows of the contract and the stream parts of the shared fixtures, drivers and docs. The frame API has one set of type names in every package that has frame mode, the C# set: `FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `ReplayWindow`, `Freshness`, `MacKey` (Rust renames `Session`, `Direction`, `Directions`, `Slot`, `Opened`, `MsgCtx`; Swift renames `MessageContext`; Java moves `Slot`, `Opened` and `Sealed` out of `FrameSession` as `FrameSlot`, `FrameOpened`, `FrameSealed` and takes a `FrameDirection` enum for its int directions). The packages that gain frame mode later use the same names. The crypto primitives that C++, Go, Python and TypeScript have for the stream session (SHA-256, HMAC-SHA256, HKDF-SHA256, ChaCha20) move to an internal module of each package, tested on the 27 rows of `fixtures/crypto/vectors.txt`, because frame mode is added to those four packages next (loop 75). Frame mode bytes, the 157 rows of `fixtures/frame/vectors.txt` and the 27 rows of `fixtures/crypto/vectors.txt` do not change. `pack-session.md` keeps its file name, becomes 3.0.0 and describes frame mode only; its frame text is unchanged since 2.0.0, so citations of "2.0.0" in the frame fixtures and sources stay valid.

## Alternatives Considered

| Alternative | Rejected because |
|-------------|------------------|
| Keep stream mode as it is | No application was found where it is the right tool; it is unauthenticated, needs lossless ordered delivery, and runs inside TLS where it adds nothing |
| Deprecate now, remove in a later release | Carries untested-in-use code and its CI time through more releases for no known user; at 0.x the removal is a minor step now |
| Harden it (wipe the seed and keys at destroy, loop 74's first scope) | Work on a type with no use |
| Add a tag to stream mode | That is frame mode; it would change every stream packet's bytes and keep the implicit counter that breaks on loss |

## Consequences

### Positive

- One session model in every package; a user cannot pick an unauthenticated mode by mistake
- Less code, tests and CI time in eight packages; the Rust `session` embedded set and its flash and stack pins go away
- The four packages without frame mode kept their HKDF and ChaCha20 for the frame-mode port, which landed in loop 75 (AZ-3292..AZ-3295)

### Negative

- A breaking change for any user of `PackSession` from v0.1.x to v0.3.0 (none known); the next release notes say so
- C++, Go, Python and TypeScript had no session at all between loop 74 and loop 75; their frame-mode ports landed in loop 75 (AZ-3292..AZ-3295)
- Encryption with zero bytes of overhead is gone: frame mode costs at least a 4-byte tag per message
- The frame types are renamed in Rust, Java and Swift (Rust `Session` becomes `FrameSession`), a source change for meshbell's Rust code and any frame-mode user

### Neutral / Open

- ADR-008's frame-mode decision stands; its "one session type serves the websocket (stream) and the radio (frame)" and the stream rows of its Alternatives no longer apply
- A public-key pairing step that derives each device's frame key (X25519 against a pinned gateway key) is a candidate, not decided

## Evidence

- `_docs/02_document/contracts/library/pack-session.md` § Configuration, § Frame mode
- `_docs/02_document/adr/008_authentication-in-frame-mode.md` § Decision, § Consequences
- `_docs/02_task_plans/remove-stream-session/problem.md`
