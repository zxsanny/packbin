**Spec 1 of 4: PB-01 (self-contained, 2026-10-25).** Copy into packbin's `_docs/02_tasks/todo/` on intake. Packbin has no access to meshbell, so everything needed is here.

# Frame mode: contract and ADR

**Task**: PB-01_frame_mode_contract_and_adr
**Name**: Frame mode: contract and ADR
**Description**: The session contract gains a `mode` setting; `frame` mode and the MAC-only call are specified byte for byte, and an ADR records that authentication enters packbin's scope for frame mode only.
**Complexity**: 4 points
**Dependencies**: None
**Component**: library contracts and docs (`_docs/02_document/contracts/library/pack-session.md`, ADRs, README, problem and restriction files)
**Tracker**: umbrella AZ-3192; packbin gives this task its own AZ id on intake
**Epic**: new packbin epic "Frame mode" (created on intake)

## Context

Meshbell is a LoRa field mesh (433 MHz, SF11, 250 kHz, about 1 kbit/s). Every field component is Rust: one firmware for relays and packs and the smart-device profile (nRF52840: Cortex-M4F, 64 MHz, 1 MB flash, 256 KB RAM, `no_std`), the station radio (ESP32, `no_std`), and on servers the mesh service, the simulator and the tools (`std`). Later the same frames are sealed and opened by the server of a partner system (C#), the Android app (Kotlin through packbin's Java package) and the iOS app (Swift): those are packbin tasks after this one.

The packbin owner decided on 2026-10-19 (route A): the radio seal goes into packbin as a `frame` mode of the session, chosen by configuration next to today's `stream` mode, so one session type serves the websocket (stream) and the radio (frame). The Rust `no_std` core it builds on has landed (AZ-2749 and its slices, epic AZ-2750).

Why today's stream session cannot run on the radio:

| Stream session today | Radio fact | Effect |
| --- | --- | --- |
| The ChaCha20 counter is implicit; packets must arrive in order and none may drop | LoRa frames are lost (collisions, half-duplex), reordered (retries, backup paths) and duplicated (two stations hear one frame); many senders reach one server | The first lost frame breaks every later one |
| Nothing detects a changed byte | Anyone with a 433 MHz radio can flip ciphertext bits; with a stream cipher, flipping bit k flips plaintext bit k | A target position can be shifted without the key |
| A 16-byte opener once per connection | The radio has no connection; a handshake costs airtime and fails under loss | Keys must be derivable on both ends with nothing on the air |
| One shared seed | Field devices get captured | Each device needs its own key; a capture reveals only that key |

## Problem

The session contract (`pack-session.md` 1.0.0) defines a stream only: a per-direction counter that is never sent, keys from a seed and a 16-byte opener, no tag. Packbin's problem statement lists authentication as a non-goal, and restriction R-08 says the wire carries only the fields (no tag, length prefix, version byte or schema id). Frame mode needs an explicit nonce per message, associated data, a 4-byte tag, a replay window and keys per (key, epoch, direction), plus a MAC-only call for meshbell's per-hop network check.

## Outcome

* `pack-session.md` 2.0.0 with a **Configuration** section and a **Frame mode** section that state, normatively and language-neutrally, everything in "Normative specification" below. Stream mode text and bytes are unchanged.
* A **MAC-only** section in the same contract (or a sibling contract `frame-mac.md`, owner's choice) for the call in "MAC-only call" below.
* ADR 008 "Authentication in frame mode": frame mode authenticates, stream mode does not (it runs inside TLS); why truncated HMAC-SHA256 and not Poly1305; why encrypt-then-MAC; why a caller nonce and no randomness.
* Packbin's `_docs/00_problem/` files: authentication is in scope for frame mode only; R-08 gains one exception: a frame-mode body ends with its tag (the length bytes of the MAC input are never sent).
* README: a "Frame session" section with one Rust example (seal, open with a replay window, MAC-only), and the uniqueness rule in bold.

## Normative specification

All integers are little-endian unless the row says otherwise. `‖` is concatenation. `HKDF` is HKDF-SHA256 (RFC 5869) with output length 32. `HMAC` is HMAC-SHA256 (RFC 2104 / RFC 4231). `ChaCha20` is the RFC 8439 block function and cipher.

### Configuration (fixed when the session is loaded, never sent)

| Setting | `stream` (default, today) | `frame` |
| --- | --- | --- |
| `mode` | `stream` | `frame` |
| Key input | 32-byte seed and a 16-byte opener nonce | the caller's 32-byte key and a 32-bit `epoch`, `epoch` at most 0xFFFFFF; no opener |
| Directions | send and receive | the directions the caller names at load, any of `1` up, `2` down, `3` group; a call in a direction not loaded is refused |
| `tag_len` | none | 4, 8 or 16; fixed for the lifetime of the loaded key (meshbell uses 4) |
| Nonce | internal counter per direction | built per message from the caller's 8-byte `msg_id` and 4-bit `kind` (below) |
| Associated data | none | caller bytes, 0 to 255, authenticated and not sent by packbin |
| Previous key | none | optional second (key, epoch) slot, used by open only |
| Replay window | none | caller-owned, 64 messages per sender; optional per call |

A frame-mode call on a stream session, or a stream call on a frame session, is refused (`BadValue`).

### Per-message inputs

| Input | Size | Meaning |
| --- | --- | --- |
| `d` | 1..=3 | direction; must be one the session loaded |
| `msg_id` | 8 B | caller bytes that are unique per (key, epoch, d) for every message ever sealed |
| `kind` | 0..=15 | caller nibble mixed into the nonce (meshbell: the frame type) |
| `ad` | 0..=255 B | associated data |
| `clear` | 0..=255 B | a clear part: sent as is, authenticated |
| `plain` | 0..=255 B | the part that is encrypted |

Limit: `len(clear) + len(plain) + tag_len <= 255` (the body); otherwise `TooLong`.

### Key schedule

For each loaded direction `d`, at load time (never per message):

```
salt      = "packbin-frame" (13 ASCII bytes) ‖ epoch as u32 LE (4 B)
K_enc(d)  = HKDF(IKM = key, salt, info = [d] ‖ "enc", L = 32)
K_mac(d)  = HKDF(IKM = key, salt, info = [d] ‖ "mac", L = 32)
```

### Nonce (12 bytes)

```
N = msg_id (8) ‖ ((kind << 4) | d) (1) ‖ epoch as u24 LE (3)
```

### Encryption

`ciphertext = plain XOR ChaCha20(K_enc(d), N)` with the 32-bit block counter starting at 0 (the RFC 8439 cipher with initial counter 0). At most 4 blocks for a 255-byte body.

### Tag (encrypt-then-MAC)

```
M   = N (12) ‖ len(ad) as u8 ‖ ad ‖ len(clear) as u8 ‖ clear ‖ ciphertext
tag = first tag_len bytes of HMAC(K_mac(d), M)
```

### Body

```
body = clear ‖ ciphertext ‖ tag
```

`N` and the length bytes in `M` are never sent. Because `M` starts with `N`, the tag binds `msg_id`, `kind`, the direction and the epoch: a body replayed under another `msg_id` fails the tag. The receiver knows `len(clear)` from its own message layout and passes it to open.

### Seal

1. Check the arguments (direction loaded, `kind` <= 15, lengths); on refusal nothing is written.
2. Write `clear`, then the ciphertext, then the tag into the caller's buffer; return the body length.
3. On any error after writing started, the written bytes are zeroed.

Seal is deterministic: the same inputs give the same bytes. It never uses the previous key and never changes state.

### Open (the order is normative)

1. Argument checks: direction loaded, `kind` <= 15, `len(ad)` <= 255. `len(body) < clear_len + tag_len` is `ShortPacket`. An output buffer shorter than `len(body) - clear_len - tag_len` is `BufferFull`.
2. Replay check (only when the caller passes a window and the message's counter): `Duplicate` or `TooOld` ends the call here, with no MAC computed.
3. Tag check with the current key: build `N` from the caller's `msg_id`, `kind`, `d` and the current epoch, recompute the tag over `M` from the received bytes and compare all `tag_len` bytes in constant time.
4. On mismatch, if a previous (key, epoch) is loaded, repeat step 3 once with it (keys and nonce from the previous epoch). Still no match: `TagMismatch`.
5. Decrypt the ciphertext into the caller's buffer with the keys of the slot that matched.
6. Commit the counter into the window (only now; a failed open never changes the window).
7. Return `Ok` with which slot opened (`Current` or `Previous`), the clear part's length and the plaintext's length.

The output buffer is not written unless the result is `Ok`.

### Replay window (one per sender, caller-owned)

* State: `top` (u64, highest committed counter) and `bits` (u64; bit i set means counter `top - i` was committed). `bits == 0` means empty. 16 bytes.
* `check(n)`: empty, or `n > top`: `Fresh`. `top - n >= 64`: `TooOld`. Bit `top - n` set: `Duplicate`. Otherwise `Fresh`. `check` never changes the state.
* `commit(n)`: empty: `top = n`, `bits = 1`. `n > top`: shift `bits` left by `n - top` (0 when the shift is 64 or more), set bit 0, `top = n`. Otherwise set bit `top - n`.
* The counter is the caller's: a value that increases with every message of one sender (meshbell: `creation_wave * 4096 + sequence`, see "How meshbell uses it").

### MAC-only call

A tag without encryption, for meshbell's per-hop network check and for key fingerprints.

```
K_label  = HKDF(IKM = key (32 B), salt = "packbin-frame" ‖ epoch as u32 LE, info = 0x00 ‖ label, L = 32)
tag      = first n bytes of HMAC(K_label, message)
```

* `label` is 1 to 32 bytes; the leading 0x00 keeps these keys apart from the frame keys (directions are 1 to 3).
* `n` is 4, 8, 16 or 32.
* The message is passed in parts (for example a 4-byte wave and the frame bytes) and hashed with no joined copy.
* The key object holds the HMAC state precomputed from `K_label` (the inner and outer pad states, 64 B), so a call costs only the message's SHA-256 compressions plus one. The object is at most 72 bytes (meshbell keeps three of them in RAM).
* Verify compares all `n` bytes in constant time and returns a boolean.

### Uniqueness rule (the caller's duty, bold in the README)

**For one (key, epoch, direction), a** `msg_id` is never sealed twice with different contents. Reuse breaks confidentiality of both messages. Packbin cannot check it. Moving to a new epoch derives new keys and nonces.

### Results and error kinds

Reuse packbin's kinds where they fit: `BadValue` (configuration or argument out of range), `TooLong`, `BufferFull`, `ShortPacket`. New kinds: `TagMismatch`, `Duplicate`, `TooOld`. The ADR decides whether they join the existing `Error` enum or a frame-mode enum; the names must be the same in every package.

### Security notes for the ADR

* Truncated HMAC down to 32 bits is allowed (NIST SP 800-107 Rev. 1, carried into SP 800-224); LoRaWAN uses a 4-byte MIC on every frame. Polynomial MACs (GHASH, Poly1305) are not truncated to 32 bits.
* Forgery odds with a 4-byte tag: 2^-32 per try (about 68 years on average at one try per second). Callers count tag failures per sender as an attack indicator.
* The compare has no early exit and no secret-dependent branch; SHA-256 and ChaCha20 use no secret-indexed tables.
* A captured device reveals only its own key; callers rotate shared keys after a loss.
* Derived keys and HMAC states are overwritten when the session or key object is dropped (best effort, as the stream session does).

## How meshbell uses it (informative)

The meshbell radio frame (at most 255 B):

| Bytes | Field | Notes |
| --- | --- | --- |
| 0-1 | destination | on-air byte order |
| 2-3 | source |  |
| 4-5 | id field | class (2 bits), creation wave mod 4 (2 bits), sequence (12 bits; restarts every wave) |
| 6 | type (high nibble), TTL (low nibble) |  |
| 7-8 | next hop | changes at every hop |
| 9-10 | relay | changes at every hop |
| 11.. | body | `clear` (a routing trailer, optional) ‖ ciphertext ‖ 4-byte tag; at most 240 B |
| last 4 | network MIC | MAC-only call, recomputed at every hop |

* `msg_id` = source (2) ‖ id field (2) ‖ creation wave as u32 LE (4). The creation wave is never sent: the receiver rebuilds it from the 2 bits and its clock. Sequences restart every wave, waves never repeat and source ids are never reissued, so `msg_id` is unique.
* `kind` = the frame type nibble.
* `ad` (11 B) = destination (2) ‖ source (2) ‖ id field (2) ‖ creation wave as u32 LE (4) ‖ type nibble (1). TTL, next hop and relay are left out because they change at every hop.
* Replay counter = `creation_wave * 4096 + sequence`.
* Network MIC = MAC-only call with the network key, the network-key epoch, label `net`, message = creation wave as u32 LE ‖ every frame byte before the MIC, `n` = 4. One frame type uses the same call without the wave.
* Meshbell also takes a 2-byte key fingerprint from a 4-byte MAC-only tag over the ASCII text `check`.
* Uses: relays and packs seal their own status (up) and open one record, their network-key delivery (42 B, down, from the server); smart devices open commands (down) and group frames (group) and seal replies (up); the mesh service seals key records and opens status. Epochs are at most 16 bits in practice.

## Worked examples

Computed by meshbell from this text alone with an independent implementation: Python 3 `hmac` and `hashlib`, HKDF cross-checked against the `cryptography` package 46.0.1, ChaCha20 from `cryptography` 46.0.1 (OpenSSL 3.6.1), whose use was checked against RFC 8439 §2.4.2. PB-03 must reproduce them byte for byte. Hex, no separators.

**E1: up, no clear part, tag 4.** key = 32 × `11`, epoch 1, d 1, kind 4, plain = `0102030405060708090a0b0c`.

| Item | Value |
| --- | --- |
| msg_id | `00301005e8030000` |
| ad | `000100301005e803000004` |
| K_enc(1) | `2a26f46689797b89a46c24bb1d7d31876ffd6fe68f86b04bb32a1c62061437ce` |
| K_mac(1) | `8147b3e3c2a5feed9cd4a5167169c48a1fc898e03b9cfa48e4144efd6a5601e3` |
| N | `00301005e803000041010000` |
| M | `00301005e8030000410100000b000100301005e8030000040053e9dc75fb459d775e620566` |
| body | `53e9dc75fb459d775e6205661cdf37ff` (ciphertext 12 B, tag `1cdf37ff`) |

**E2: down, a 42-byte record, tag 4.** key = 32 × `11`, epoch 1, d 2, kind 5, plain = bytes `40` to `69`.

| Item | Value |
| --- | --- |
| msg_id | `00022001e9030000` |
| ad | `003000022001e903000005` |
| K_enc(2) | `f421aaa83c48b853e9977379c0958c58f83e2fc72d590a57b1a8910b6802a93e` |
| K_mac(2) | `7f16afe6559313e8a883f384de44370e1b223a6de2a2252427f8da5833236063` |
| N | `00022001e903000052010000` |
| body | `7f711291e9a9ebb93760ac8b851f2a29c46a3b70f6a447b62ddbc159ddfba687109cc6d02d5e509bb9bd00b7da70` |

**E3: group, 3-byte clear part.** key = 32 × `33`, epoch 7, d 3, kind 6, clear = `a1b2c3`, plain = bytes `80` to `93`.

| Item | Value |
| --- | --- |
| msg_id | `00013002ea030000` |
| ad | `ffff00013002ea03000006` |
| K_enc(3) | `0a26995c011a4e87d1a327986b6b086202045544d3ab0a8fbcd681be1286bb05` |
| K_mac(3) | `190bb28d43cdff7805ef628706256badfec84c30fd15f4e426b048768a8431aa` |
| N | `00013002ea03000063070000` |
| M | `00013002ea030000630700000bffff00013002ea0300000603a1b2c34f51e601a79e78a25a9bf5bb74206019f1d76978` |
| body, tag 4 | `a1b2c34f51e601a79e78a25a9bf5bb74206019f1d769783cbc82b7` |
| body, tag 16 | `a1b2c34f51e601a79e78a25a9bf5bb74206019f1d769783cbc82b7c519c38115025b8cd5b5f82b` |

**E4: MAC-only, network check.** key = 32 × `22`, epoch 7, label `net`, message = `e8030000` ‖ bytes `c0` to `d3`, n 4: K_label = `dc5966ac393a983cec3f48ee16233b4b06b468d720732abdd8e91ae116bd4a93`, tag = `56db9bec`.

**E5: MAC-only, short text.** key = 32 × `22`, epoch 8, label `net`, message = `636865636b` (`check`), n 4: K_label = `8faf8eec4c65f8c69dcfb879368d4b6e47580569fb93d175a60fdc351752af80`, tag = `3cf8e8c5`.

## Changes from meshbell's earlier drafts

* The 14-byte-header layout of 2026-10-03 is withdrawn; only the layout above exists.
* The nonce is generic (`msg_id` 8 B, `kind` 4 bits) instead of naming meshbell's header fields; meshbell's mapping gives the same bytes as its 2026-10-20 request.
* `M` starts with the nonce, so the tag binds `msg_id`, `kind`, direction and epoch even when a caller's AD does not; then `len(ad)`, so AD of any length cannot be confused with the clear part.
* The MAC-only info starts with 0x00 (domain separation from the frame keys).
* `tag_len` 0 is not allowed in frame mode; frame mode always authenticates.

## Scope

### Included

* `pack-session.md` 2.0.0 (Configuration, Frame mode, MAC-only), ADR 008, README section, packbin problem and restriction files (authentication in scope for frame mode; the R-08 exception)

### Excluded

* Code (PB-04 and later), vectors (PB-02, PB-03)
* Any change to stream-mode bytes, operations or results
* C#, Java, Swift and other package work (later tasks)

## Acceptance Criteria

**AC-1: Every byte is determined**
Given the contract alone  
When a reader implements seal, open, the replay window and the MAC-only call  
Then every byte of keys, nonce, ciphertext, `M`, tag and body, and every result, is determined, with no choice left open

**AC-2: The worked examples follow from the contract**
Given the contract and an independent script written only from it  
When E1 to E5 are recomputed  
Then every value matches this spec

**AC-3: Stream unchanged**
Given `mode = stream`
When the contract is compared with 1.0.0  
Then no stream byte, operation or result changed

**AC-4: Scope recorded**
Given ADR 008 and the problem and restriction files  
When they are read  
Then frame mode authenticates, stream mode does not, R-08 has exactly the tag exception, and the reasons are stated

**AC-5: Open order and refusals**
Given the open procedure  
When a reader checks it  
Then no MAC runs for a duplicate or too-old counter, no plaintext is written before the tag matched, and a failed open never changes the window

**AC-6: Uniqueness rule**
Given the README and the contract  
When they are read  
Then the uniqueness rule is stated in bold, with meshbell's `msg_id` as the example

## Unit Tests

None (documentation task). AC-2 is checked by an independent script; PB-03 turns the contract into the fixture.

## Constraints

* Language-neutral text: no Rust-only types in the normative part.
* Packbin conventions: ADR numbering in `_docs/02_document/adr/`, contract versioning (a new mode is a major version of the contract because the configuration is new; stream bytes unchanged).

## Risks & Mitigation

**Risk 1: A caller reuses a** `msg_id`

* _Mitigation_: the uniqueness rule in bold in the README and rustdoc; meshbell's ids are unique by construction (source, wave, sequence)

**Risk 2: The 4-byte tag is judged too short later**

* _Mitigation_: `tag_len` 8 and 16 exist; it is fixed per loaded key, so a change is a new key or epoch, not a silent switch


