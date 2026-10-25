---
loop: 69
branch: dev
---

# Loop 69: packbin frame mode, Rust first (AZ-3192)

The folder keeps the intake slug `rust-m33f-and-frame-mode`; the Rust Cortex-M33F row left this loop (owner, 2026-10-25) and goes to loop 70.

## What

meshbell (a LoRa field mesh, every field component Rust) needs packbin **frame mode** for the 4-byte network MIC on every radio frame, node seals, opening the network-key delivery record, and key-check bytes (the MAC-only call). The owner decided on 2026-10-19 (route A) that the radio seal is a `frame` mode of the session next to today's `stream` mode. The Rust `no_std` core it builds on has landed (AZ-2749, epic AZ-2750).

Jira AZ-3192 (umbrella, Task, To Do, labels frame-mode, meshbell, packbin, rust) carries four self-contained hand-off specs as comments (2026-10-25 11:06 to 11:07), saved verbatim in `input/`:

| Spec | Points | In this loop |
| --- | --- | --- |
| PB-01 frame mode contract and ADR | 4 | all: `pack-session.md` 2.0.0, ADR 008, problem and restriction files, README |
| PB-02 primitive reference vectors | 3 | the fixture, the Python check and the Rust test; the other seven packages are a follow-up (owner, 2026-10-25) |
| PB-03 frame golden vectors | 4 | all: reference generator, fixture, checks |
| PB-04 Rust frame mode | 8 | all: `frame` feature, session, `MacKey`, `ReplayWindow`, embedded `frame` set on the Cortex-M4F |

19 points in all (the Jira table says 17: PB-01 and PB-03 are 4 in the specs, 3 in Jira). No version byte (rule R-08 keeps its rule; frame mode adds one exception: the body ends with its tag).

Done when the Rust `nostd` frame-mode seal, open and MAC-only call match the PB-03 golden vectors on the host and in the Cortex-M4F embedded stage, and meshbell can pin the packbin commit.

## Code sections / UI locations for this loop

Owner words (2026-10-25, loop 69 choice, accepted as recommended): "Rust on Cortex-M33F ... Code: rust/src/nostd and the Rust embedded stage"; then "also add task AZ-3192" and the scope answer "Frame mode only, Rust-first".

- Rust: `rust/src/nostd` (session), `rust/src/session_core` (SHA-256, HKDF, ChaCha20 pad), `rust/Cargo.toml` features, `rust/embedded/` (`feature-sets.txt`, `limits.txt`, probe).
- Docs and fixtures named by the specs: `_docs/02_document/contracts/library/pack-session.md`, `_docs/02_document/adr/`, `_docs/00_problem/`, README, `fixtures/crypto/`, `fixtures/frame/`, `scripts/crypto/`, `scripts/frame/`.

## Flagged concerns

| concern | policy / owner | status | severity |
| --- | --- | --- | --- |
| The meshbell hand-off specs are not on this machine | they are Jira comments on AZ-3192, saved under `input/` | resolved | Critical |
| Spec points differ from the Jira table (19, not 17) | owner | accepted-risk (sizes follow the specs) | Low |
| PB-02 asks for vector tests in all eight packages | owner narrowed it to Rust and the Python reference this loop; the seven others follow | accepted-risk | Medium |
| The project AC list says "Authentication ... inside the library" is out of scope | PB-01 changes it for frame mode only (owner route A, 2026-10-19); ADR 008 | open until PB-01 lands | High |
| The Rust M33F embedded row moved to loop 70 | owner | resolved | Low |
