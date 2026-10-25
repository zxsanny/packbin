**Spec 4 of 4: PB-04 (self-contained, 2026-10-25).** Copy into packbin's `_docs/02_tasks/todo/` on intake. The bytes are PB-01's "Normative specification" (Spec 1); the vectors are PB-03's fixture (Spec 3).

# Rust: frame mode with the embedded profile

**Task**: PB-04_rust_frame_mode
**Name**: Rust frame mode, heap-free, with the MAC-only call, a replay window and a `frame` feature
**Description**: The Rust package seals and opens frames per PB-01 on caller buffers, with no heap, a constant-time tag check, a previous-key slot, a 64-message replay window and the MAC-only call; a Cargo feature `frame` adds it without the stream code.
**Complexity**: 8 points
**Dependencies**: PB-01, PB-03; AZ-2749 (Rust `no_std` core, done)
**Component**: rust (`nostd` frame module, `session_core`, features, embedded stage)
**Tracker**: umbrella AZ-3192; packbin gives this task its own AZ id on intake
**Epic**: new packbin epic "Frame mode" (created on intake)

## Problem

Meshbell's field stack is Rust. Its relays and packs (one firmware on an nRF52840: Cortex-M4F, 64 MHz, 256 KB RAM) seal their own status and open one record, their network-key delivery; its smart devices open commands and group frames and seal replies; every node and the station radio (ESP32) compute and check a 4-byte network MIC at every hop with the MAC-only call; the mesh service, simulator and tools (Linux, `std`) do the same on servers. About fifty meshbell tasks are blocked until this lands. Packbin's Rust package has the `no_std` core (`packbin::nostd`, AZ-2749 to AZ-2757) and a heap-free stream session, but no frame mode.

## Outcome

* Cargo feature `frame` (needs no `alloc`; always on with `std`, as `session` is). With `default-features = false, features = ["frame"]` the package builds `#![no_std]` with frame mode, the MAC-only call and the replay window, and none of the stream session.
* The frame-mode session, the MAC-only key and the replay window below, with the bytes and results of PB-01.
* The embedded stage gains a `frame` feature set with recorded flash and stack figures.
* Rustdoc, README example and the Rust component description updated.

## Shape (proposal: names may change in the contract; the capabilities may not)

```rust
// packbin::nostd (feature "frame"; also with "std")
pub const MAX_BODY: usize = 255;
#[derive(Clone, Copy)] pub enum Direction { Up = 1, Down = 2, Group = 3 }
#[derive(Clone, Copy)] pub struct Directions(u8);                  // a set of Up, Down, Group
pub struct FrameConfig { pub tag_len: u8 /* 4, 8 or 16 */, pub directions: Directions }
pub struct MsgCtx { pub msg_id: [u8; 8], pub kind: u8 /* 0..=15 */ }
pub enum Slot { Current, Previous }
pub struct Opened { pub slot: Slot, pub clear_len: usize, pub plain_len: usize }

impl Session {   // owner decision 2026-10-19: one session type, mode by configuration
    pub fn load_frame(key: &[u8; 32], epoch: u32, config: FrameConfig) -> Result<Session, Fault>;
    pub fn set_previous(&mut self, key: &[u8; 32], epoch: u32) -> Result<(), Fault>;   // used by open only
    pub fn clear_previous(&mut self);
    pub fn seal_frame(&self, dir: Direction, ctx: &MsgCtx, ad: &[u8], clear: &[u8], plain: &[u8],
                      out: &mut [u8]) -> Result<usize, Fault>;
    pub fn open_frame(&self, dir: Direction, ctx: &MsgCtx, ad: &[u8], body: &[u8], clear_len: usize,
                      replay: Option<(&mut ReplayWindow, u64)>, out: &mut [u8]) -> Result<Opened, Fault>;
}

pub struct MacKey { /* HMAC inner and outer pad states and the epoch; Debug prints no key bytes */ }
impl MacKey {
    pub fn derive(key: &[u8; 32], epoch: u32, label: &[u8] /* 1..=32 B */) -> Result<MacKey, Fault>;
    pub fn epoch(&self) -> u32;
    pub fn tag(&self, parts: &[&[u8]], out: &mut [u8] /* len 4, 8, 16 or 32 */) -> Result<(), Fault>;
    pub fn verify(&self, parts: &[&[u8]], tag: &[u8]) -> bool;     // constant time
}

#[derive(Clone, Copy, Default)] pub struct ReplayWindow { /* top: u64, bits: u64 */ }
pub enum Freshness { Fresh, Duplicate, TooOld }
impl ReplayWindow {
    pub const fn new() -> Self;
    pub fn check(&self, counter: u64) -> Freshness;                 // never changes the state
    pub fn commit(&mut self, counter: u64);                         // open_frame calls it only after Ok
}
```

A frame call on a stream session, or a stream call on a frame session, is `BadValue`. Error kinds as PB-01 decides (`BadValue`, `TooLong`, `BufferFull`, `ShortPacket`, `TagMismatch`, `Duplicate`, `TooOld`), carried in `Fault` like the rest of `nostd`.

## Behaviour (from PB-01, restated for the implementation)

* `load_frame` derives `K_enc(d)` and the HMAC pad states of `K_mac(d)` for each named direction once; no HKDF and no key-block hashing per message. `set_previous` does the same for the previous slot.
* `seal_frame` is deterministic and stateless; on any refusal nothing is written, and on an error after writing started the written bytes are zeroed.
* `open_frame` follows PB-01's order: argument checks, then the replay check (no MAC for `Duplicate` or `TooOld`), then the tag with the current slot, then once with the previous slot, then decryption, then the window commit. `out` is not written unless the result is `Ok`; a failed open never changes the window.
* The tag compare and `MacKey::verify` fold every byte into an accumulator (no early exit); the accumulator passes through `core::hint::black_box` before the final test.
* Derived keys and pad states are overwritten on drop (best effort, as the stream session does).

## Scope

### Included

* The `frame` feature, frame mode in the `nostd` session, `MacKey`, `ReplayWindow`, the PB-03 fixture tests, property and hostile tests, the embedded feature set, docs

### Excluded

* Stream-mode bytes and behaviour (unchanged)
* Other packages (C#, Java, Swift: later tasks); hardware cycle counts on a real nRF52840 (later task)
* Any new dependency: the primitives are `session_core`'s

## Acceptance Criteria

**AC-1: Vectors**
Given `fixtures/frame/vectors.txt`
When the Rust suite runs with default features and with `--no-default-features --features frame`
Then every row matches, including E1 to E5, every refusal, every tamper, previous-slot, replay and MAC-only row

**AC-2: Tampering never yields plaintext**
Given E1, E2 and E3  
When every single bit of `ad`, `clear`, ciphertext and tag is flipped in turn, and `msg_id`, `kind`, direction, epoch and key are each changed  
Then each open is `TagMismatch`, the output buffer still holds its sentinel bytes, and the window is unchanged

**AC-3: Replay before crypto**
Given a window and a counter that is a duplicate or too old  
When `open_frame` runs  
Then the result is `Duplicate` or `TooOld` and no SHA-256 compression ran (test-only counter); a fresh valid body commits its counter, a fresh tampered body does not

**AC-4: Previous slot**
Given a session at (B, 7) with previous (A, 6)  
When bodies sealed under (A, 6) and under (B, 7) are opened  
Then the results are `Ok` with `Previous` and `Ok` with `Current`; with no previous slot the first is `TagMismatch`

**AC-5: MAC-only**
Given E4 and E5 and their messages split into one, two and three parts  
When `tag` and `verify` run  
Then the tags match and do not depend on the split, a flipped bit gives `false`, and `size_of::<MacKey>()` is at most 72 bytes

**AC-6: Cost per message**
Given a 236-byte plaintext with an 11-byte `ad`, no clear part and `tag_len` 4, and a 255-byte MAC-only message  
When seal, open and `tag` run  
Then seal and open each use at most 4 ChaCha20 blocks and 6 SHA-256 compressions, and `tag` at most 6 compressions (test-only counters)

**AC-7: Heap-free, panic-free on the device**
Given the embedded stage (Cortex-M4F, `mps2-an386`) with the `frame` feature set, whose probe seals and opens E1 with a window and computes and verifies E4  
When `checks.sh` runs  
Then no heap or panic symbol is linked, the round trip matches on the device, and flash and stack are recorded in `limits.txt`; stack is at most 2,048 B and flash at most 20,480 B

**AC-8: The feature switch**
Given `frame` off  
When the existing feature sets are built  
Then their flash and stack figures are unchanged; and with `frame` on and `session` off no stream-session symbol is linked

**AC-9: Stream unchanged**
Given the existing session vectors, the std/core cross-open tests and the ring  
When the suite runs  
Then all pass with no change to stream bytes

**AC-10: Refusals and hostile input**
Given PB-01's refusals and the hostile corpus style of `nostd` (random bodies, lengths and `clear_len` values)  
When seal and open run  
Then each refusal has its error kind, seal leaves no partial output, and no input panics

## Non-Functional Requirements

* `size_of::<ReplayWindow>()` = 16; frame-mode `Session` with two slots and three directions is recorded in the component description (target at most 640 B).
* No heap, no panic path, no `unsafe` in the frame module (`#![forbid(unsafe_code)]` there); no `unwrap`, `expect`, panicking index or unchecked arithmetic on a path reachable from untrusted bytes (the existing clippy rules).
* Builds for `thumbv7em-none-eabihf` and the host; no target-specific code (meshbell's ESP32 station radio uses only `MacKey`).

## Unit Tests

| AC Ref | What to Test | Required Outcome |
| --- | --- | --- |
| AC-1 | fixture rows, both feature configurations | all match |
| AC-2 | exhaustive single-bit flips of E1 to E3 and field changes | `TagMismatch`, sentinel intact, window unchanged |
| AC-3 | duplicate and too-old counters; fresh valid and fresh tampered bodies | refused with 0 compressions; commit only on `Ok` |
| AC-4 | two-slot session, both bodies; one-slot session | `Previous`, `Current`; `TagMismatch` |
| AC-5 | E4, E5, part splits, flipped tag, `size_of` | match; `false`; at most 72 B |
| AC-6 | block and compression counters | within the stated counts |
| AC-7 | embedded `frame` set | no heap or panic symbol; round trip on the device; within the budget |
| AC-8 | sizes with `frame` off; symbols with `session` off | unchanged; no stream symbol |
| AC-9 | stream vectors, cross-open tests, ring | green |
| AC-10 | refusal rows, random hostile inputs | error kinds, no partial output, no panic |

Property test besides the fixture: random keys, epochs, contexts, `ad`, `clear` and `plain` within the limits round-trip through seal and open, and a random sequence of window steps matches a model of PB-01's rules.

## Constraints

* Bytes and results exactly as PB-01; any difference is a contract change first.
* Packbin conventions: source files at most 500 lines (soft cap), tests in Arrange-Act-Assert form, no verbose logs, the embedded limits set by the owner at the measured figure plus 5%.
* The uniqueness rule (PB-01) is in the rustdoc of `seal_frame` and `MsgCtx`.

## Risks & Mitigation

**Risk 1: The compiler shortens the constant-time compare**

* _Mitigation_: a fold over all bytes with `black_box` on the accumulator; reviewed in the frame-mode security audit (later task)

**Risk 2: Stream users pay for frame state**

* _Mitigation_: the frame variant of `Session` exists only with the `frame` feature; AC-8 checks the existing sets are unchanged

**Risk 3: Stack of the MAC over parts on the device**

* _Mitigation_: no joined copy of the message; AC-7 bounds the stack at 2,048 B


