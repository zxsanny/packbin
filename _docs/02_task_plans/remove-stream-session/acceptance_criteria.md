# Acceptance criteria — loop 74, remove the stream session

Inherited baseline: `_docs/00_problem/acceptance_criteria.md` (clear pack and unpack, message ECC, compact text, frame mode). The project rows about the stream session (lines 42 and 48, `_docs/02_task_plans/pack-session/acceptance_criteria.md`) are retired by this loop (ADR-009). Owner decisions D1 to D6: 2026-10-26, "Accept all recommended".

Figures measured on HEAD 10cc0be + intake ff079b6, 2026-10-26 (`rust/embedded/run.sh host`, exit 0, log `rust-embedded-head.log` in the session scratchpad):

```
rust-m4f   frame   flash=20332 B (limit 20480) stack=1728 B (limit 1991)
rust-m33f  frame   flash=20404 B (limit 20404) stack=1728 B (limit 1728)
rust-m4f   base 15060/456  text 27156/2736  ecc 18692/744   (M33F: 15132/456, 27268/2736, 18764/744)
fixtures/frame/vectors.txt   157 rows  sha256 bc9d36f7e7a3585896adeaebb31b51d23ebd9f2ed08be58476cf8d7e67c8b3e4
fixtures/crypto/vectors.txt   27 rows  sha256 000e1e95b7644a5b48d5e2a23ed8189d35a857fb5b9af62e2bd7d98db6c450b5
fixtures/golden.hex                    sha256 b5faa1b7ccdf1cdf6cebcc82e62224b7e1a1a8109ee4b2b9074405642130d88c
```

## Removal

**AC-1 No stream session.** In each of the 8 packages, the public API offers 0 ways to load a seed, open with a 16-byte nonce, or pack and unpack on an implicit counter; a search for `PackSession` over the package sources, tests, examples, ring drivers, CI scripts and hostile probes finds 0 hits (history records under `_docs/` excepted).

**AC-2 Frame-mode bytes unchanged.** Rust, C#, Java and Swift each pass 157 of 157 rows of `fixtures/frame/vectors.txt`, and the file's SHA-256 equals the value above.

**AC-3 Clear pack, unpack and message ECC unchanged.** Every package's full suite passes with 0 failures; the cross-language ring passes every clear and ECC pair (8 x 8 drivers); `fixtures/golden.hex` keeps the SHA-256 above and `fixtures/ecc/` has 0 changed bytes.

## Names (D1)

**AC-4 One set of frame names.** In Rust, C#, Java and Swift the public frame types are named `FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `ReplayWindow`, `Freshness`, `MacKey` (Java also `FrameSealed`, for its seal result); 0 public types keep an old name (Rust `Session`, `Direction`, `Directions`, `Slot`, `Opened`, `MsgCtx`; Swift `MessageContext`; Java `FrameSession.Slot`, `FrameSession.Opened`, `FrameSession.Sealed`); Java takes a direction as a `FrameDirection`, with 0 public int direction constants.

## Crypto kept for the frame ports (D2)

**AC-5 Verified primitives in the four ports-to-be.** C++, Go, Python and TypeScript each pass 27 of 27 rows of `fixtures/crypto/vectors.txt` (SHA-256 6, HMAC-SHA256 8, HKDF-SHA256 3, ChaCha20 block 6, ChaCha20 XOR 4) through an internal module that is not part of the public API; Rust, C#, Java and Swift still pass 27 of 27.

**AC-6 No new dependency.** Each package's runtime dependency list has 0 additions; the `go` module and the npm package may only lose dependencies.

## Embedded

**AC-7 Rust embedded.** The `session` Cargo feature and the embedded `session` set exist in 0 places; the crate builds with 0 errors with `--no-default-features --features frame` and with `--features frame,text,ecc`; the `frame` set is at most 20,480 B of flash on M4F and equals its M33F pin, re-pinned to the measured figure if it moves (any move is reported); `base`, `text` and `ecc` move by 0 B on both targets.

**AC-8 C++ embedded.** The pinned C++ images keep their pins: `cpp-m4f` 7,712 B of flash and 540 B of stack, `cpp-m33f` 25,720 B and 724 B, and the AVR Uno image builds; the vector runners build and pass with the session tests gone.

## Docs and CI

**AC-9 Contract and ADRs.** `pack-session.md` is version 3.0.0 with 0 stream-mode sections and a Change Log row; ADR-009 is `Accepted` and listed in the ADR index; `fixtures/frame/vectors.txt` keeps its bytes (AC-2).

**AC-10 README and docs.** `README.md` has 0 stream-session sections or examples; every README frame example equals the code of its example test (`scripts/frame/readme-examples.sh`, 0 differences); the component descriptions, `module-layout.md`, `system-flows.md` and the test docs name 0 live stream-session types or files (retired rows are marked retired).

**AC-11 CI green.** Every job of `.github/workflows/test.yml` passes on the `dev` push of the loop close; 0 CI or script steps name a removed file or command.

## Additional tasks (D4)

**AC-12 Frame-port specs.** Four task specs exist (frame mode in C++, Go, Python, TypeScript), one per package, each 5 points, each with a ticket under epic AZ-3199 and ACs of 157 of 157 frame rows, 27 of 27 crypto rows and the D1 names; they are scheduled for loop 75, not implemented in loop 74.

## Out of scope

- Releasing or tagging the packages (owner-run); the next 0.x release notes the removal.
- meshbell's own code (another repository): the rename is documented for it, not made there.
- A public-key pairing step (X25519 against a pinned gateway key): a candidate, not decided.
