# Acceptance criteria — loop 71 (frame mode in C#, Java, Swift)

Frame mode is the Rust one of loop 69 (contract `pack-session.md` 2.0.0, ADR 008, vectors `fixtures/frame/vectors.txt`), ported to three more packages. Every AC below is checked per package: P = C#, Java, Swift. Project ACs exercised: AC-3 (shared golden fixtures, 0 mismatched bytes), AC-10 (speed, unchanged), AC-11 (CI on every push).

## G1: Vectors (per package P)

- **AC-G1.1 Frame rows.** Given `fixtures/frame/vectors.txt` (157 data rows), when the P suite loads every `keys`, `seal`, `open`, `mac` and `replay` row, then every output field of every row matches (0 mismatches), E1 to E5 included, and the rows with epoch 0x1000000, direction 0 and 4, `kind` 16, `tag_len` 0, 5 and 32 give `BadValue`.
- **AC-G1.2 Primitive rows.** Given `fixtures/crypto/vectors.txt` (27 data rows), when the P suite runs the SHA-256, HMAC-SHA256, HKDF-SHA256 and ChaCha20 rows through the primitives the package uses, then 0 rows mismatch (PB-02 for P).
- **AC-G1.3 Not vacuous.** Given a copy of each fixture with 1 expected byte changed, when the P suite loads it, then it fails and names the row (2 fixtures x 3 packages).

## G2: Behavior (per package P)

- **AC-G2.1 Tampering gives no plaintext.** Flipping each single bit of `ad`, `clear`, ciphertext and tag of E1 to E3 in turn, and changing `msg_id`, `kind`, direction, epoch and key, gives `TagMismatch` every time, the output buffer keeps its sentinel bytes, and the window is unchanged.
- **AC-G2.2 Replay before crypto.** A duplicate or too-old counter gives `Duplicate` or `TooOld` with 0 MAC computations (an internal counter, test only); a fresh valid body commits its counter; a fresh tampered body does not.
- **AC-G2.3 Previous slot.** At (B, 7) with previous (A, 6): a body sealed under (A, 6) opens `Ok` with slot `Previous`; under (B, 7) opens `Ok` with `Current`; with no previous slot the first is `TagMismatch`.
- **AC-G2.4 MAC-only.** E4 and E5 give the same tags for 1, 2 and 3 parts; a flipped tag bit verifies `false`; label of 0 or 33 bytes and `n` of 0, 2, 5 are `BadValue`.
- **AC-G2.5 Refusals.** Each contract refusal returns its kind (`BadValue`, `TooLong`, `BufferFull`, `ShortPacket`, `TagMismatch`, `Duplicate`, `TooOld`); seal leaves 0 partial output bytes; random hostile bodies, lengths and `clear_len` values (1,000 per package, fixed seed) cause 0 unhandled exceptions or crashes.
- **AC-G2.6 Tag compare.** The tag compare folds every byte with no early exit (a test with a tag differing only in the last byte and only in the first byte takes the same code path: no branch on the compare result until all bytes are folded; checked by reading the code in review and by a unit test of the helper on equal, first-byte-different and last-byte-different inputs).
- **AC-G2.7 Wipe.** After `Dispose` / `close` / `deinit` (per language) the derived keys and MAC pad states of the session are overwritten (a test reads the internal arrays through the existing test access to private fields: all zero). Best effort is stated in the docs where the runtime may copy (GC, ARC).

## G3: Compatibility and cross-checks

- **AC-G3.1 Stream unchanged.** The existing session vectors and tests of each package pass with 0 changed stream bytes; `PackSession` / `PackbinError.Kind` keep every existing member (Swift's pinned case list test gets the 4 new raw values (the 3 kinds and `buffer_full`), nothing else).
- **AC-G3.2 Same bytes across languages.** The seal of E1 to E3 in C#, Java and Swift gives the same body as the Rust one (checked through the shared vectors, 0 differing bytes).
- **AC-G3.3 Targets.** C# builds and passes on `net10.0` and `netstandard2.0` (`-p:PackbinTarget=netstandard2.0`); Java passes `api-check.sh` (Android API level 26 signature) and `javac --release 17`; Swift builds with `-warnings-as-errors -strict-concurrency=complete` and passes the thread-sanitizer run.
- **AC-G3.4 Docs.** README has a `### C#`, `### Java` and `### Swift` subsection under "Frame session" with an example that is compiled or run by a test in that package (the Rust example is a doc test; here a test file holds the same code), the uniqueness rule stays in bold, and each component description lists the frame API.

## Out of scope

- Python, TypeScript, C++, Go frame mode and primitive tests; the cross-language frame ring (`fixtures/frame/ring-cases.txt`).
- The std `PackSession` taking a mode; any change to stream bytes, operations or results.
- A frame-mode security audit; per-key-slot replay windows (F69-2); hardening of the `hkdf.rs` temporaries; hardware cycle counts.
- Scenario S10 (a caller reusing a `msg_id`): the library cannot check it; the docs state the rule.
