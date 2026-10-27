# Handoff to loop 76

From the loop 75 record (`record75.md`). Nothing here is owner-decided unless it says so. The hopper (`_docs/02_tasks/todo/`) and the backlog are empty after close.

## Shipped in loop 75

Frame mode (`FrameSession`, `ReplayWindow`, `MacKey`, the D1 names, `TagMismatch`, `Duplicate`, `TooOld`) in C++, Go, Python and TypeScript, so all eight packages now have the one session (tasks AZ-3292..AZ-3295, 20 points). Each passes 157 of 157 `fixtures/frame/vectors.txt` rows and 27 of 27 crypto rows. The C++ frame image is pinned on the `cpp-m33f` row at 8,416 B of flash and 912 B of stack. README examples of all eight packages equal their tests (`scripts/frame/readme-examples.sh`). Review fixes: Go zero-value `MacKey`, Python negative counter, TypeScript direction mask / `null` window / sparse parts / one `kind` read, C++ tag-compare test.

## First actions of loop 76

0. CI of the loop 75 push (`dev` and `main`): `gh run list --repo zxsanny/packbin --branch dev` and `--branch main`; read any red job's log before calling it a flake.
1. Check `uptime` and `ps -Ao pcpu,command -r | head`; a total run is not a result above load 60 (this loop's pool peaked at 113 from its own suites and still passed).
2. Pick the work: the owner input below, or the candidates. No spec is ready.

## Owner input needed

- **C++ `open` and a receive ring**: copy the body into the call (about 255 B more stack; the frame pin 912 B rises) or keep the documented requirement that the caller's body does not change during the call?
- Unchanged: CS-D5; the first `v*` and `go/v*` tags and F44; close the epic AZ-2750; U24 in the C++ package; whether to drop the M4F row; the release notes of the next 0.x; meshbell renames its Rust `Session`.
- Whether to add a cross-language frame ring (`fixtures/frame/ring-cases.txt`) now that all eight packages have frame mode.
- A public-key pairing step: a candidate from the loop 74 intake, not decided.

## Candidates (not specs yet)

- The pre-existing items of `handoff75.md` still open: the C# and Java `edges` NFC/NFD probe, the `ns20` csproj compile, `cargo test --no-default-features --features frame` all-targets build, the Swift DocC frame types, the vcpkg `supports` line, an AVR runtime check of `chacha20_xor`, test and probe names that still say "Session".
- `publish-timing.selftest.sh` broken pipe under load (L75-2): make its `printf | grep -q` checks `pipefail`-safe (`grep -q` closes the pipe early).
- Review Infos not acted on: C++ `MsgContext` default is a valid all-zero id; C++ `seal` overlap of `ad` with `out` gives a silently wrong tag (documented); a `close` racing an `open` (C++, Python, TypeScript) can accept a frame under the zeroed key (the stated rule; Go takes a lock); the README examples use an all-zero key with the comment "use a random key".
- Go intermittent failure L74-3: did not show in loop 75; keep `smoke` logs on a failure.

## Risks

- **L75-1**: the C++ `open` snapshot (owner decision above).
- **L75-2**: see the timing selftest flake.
- **L74-2, L73-1, L72-1, L71-1, L71-2** (unchanged): see `handoff75.md`.
