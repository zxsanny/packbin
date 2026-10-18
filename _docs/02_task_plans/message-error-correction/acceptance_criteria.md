# Message error correction — acceptance criteria

Loop 38. "Parity bytes" is the number `n` a scheme declares (0 to 32). "Correction limit" `t` is what the receiver is willing to repair, 0 to `n/2` (integer division). A wrong byte counts once however many of its bits differ. Clear message = the packed fields without parity. All numbers are checked in each of C#, TypeScript, Python, Rust, C++, Java, Go and Swift unless the line says otherwise.

## Off means unchanged

- **EC-1.** A scheme with 0 parity bytes packs and unpacks exactly as before. On every shared golden fixture, including the 13-byte position fixture `4001000065cd1d00a3e1110100`, the bytes are identical to those before this loop. Mismatched bytes: 0. The existing suites pass with 0 failures and 0 tests removed.

## Protected message

- **EC-2.** A scheme with `n` parity bytes (n = 1, 2, 4, 8, 16, 32) packs to exactly the clear length + `n` bytes. The first bytes are the clear message. For the position fixture the output equals the vectors in `input_data/expected_results/results_report.md` (rows 2 to 6). Mismatched bytes across the eight packages: 0.
- **EC-3.** A scheme that declares `n` above 32 fails when the scheme is built, with an error naming `n` and the limit 32. Messages built from it: 0.
- **EC-4.** Pack of a clear message longer than 254 − `n` bytes returns a typed error naming the clear length and the limit, and writes 0 bytes. With `n` = 32 a 222-byte clear message packs and a 223-byte one is refused. Unpack of a buffer longer than 255 bytes under a protected scheme returns the same kind of error and 0 values.

## Detection and correction

- **EC-5.** With `n` ≥ 2 and correction limit `t` = `n/2`, corrupting up to `t` bytes at any positions (including parity bytes and including the case where all 8 bits of a byte flip) makes unpack return the original row and report the number of bytes it repaired. Checked on the position fixture with n = 2: all 15 positions × 255 byte values (3,825 cases) recover 100 %; and with n = 4, 8 and 16: 1,000 seeded random cases each, with the number of wrong bytes drawn from 1 to `t`, recover 100 %. Wrong rows returned: 0.
- **EC-6.** With correction limit `t`, corrupting from `t + 1` up to `n − t` bytes makes unpack return an error naming the kind (uncorrectable) and 0 values. With n = 4 and `t` = 1: 10,000 seeded cases of 2 or 3 wrong bytes are all refused, wrong rows returned: 0. With n = 4 and `t` = 0 (detect only): 10,000 seeded cases of 1 to 4 wrong bytes are all refused, wrong rows returned: 0.
- **EC-7.** Random garbage in place of a protected message of the position fixture's length with n = 2 and `t` = 0: of 200,000 seeded buffers at most 12 are accepted (expected about 3, the chance of passing is 1 in 65,536).
- **EC-8.** A buffer whose bytes all match the protected message returns the row and reports 0 bytes repaired. A buffer shorter than `n` bytes under a protected scheme returns an error naming the parity, the byte count needed (`n`) and the byte count present (inherits AC-8) and 0 values. A caller that asks for a correction limit above `n/2` gets an error before any byte is read.

- **EC-14.** With n = 4 and `t` = 0, a protected message of the position fixture with 1 to 3 bytes removed from the tail, or 1 to 3 arbitrary bytes added, returns an error and 0 values: 10,000 seeded cases, wrong rows returned: 0. Shifting by exactly one byte (a trailing zero byte added, or the last byte removed) is refused in all 8 packages; a message with a last parity byte of `00` is one of the cases checked. The same fixture packed with 0 parity bytes (13 bytes) read by the n = 4 scheme with `t` = 0 returns an error and 0 values. A scheme with 0 parity bytes given a protected message returns the trailing-bytes error (inherits AC-9).
- **EC-15.** The contract lists, for n = 1, 2, 4, 8, 16 and every `t` from 0 to `n/2`, the chance that a random buffer of the fixture's length is accepted. Table rows: 5 values of `n` with their `t` values, each number computed, not estimated.
- **EC-16.** One dispatch that reads the type byte to choose among schemes accepts handlers only when all of them declare the same parity count; a mix is refused when the dispatch is built, naming both counts. With a shared count, a message whose type byte is among the wrong bytes (1 to `t` wrong bytes, the type byte always one of them) is repaired first and then reaches the right handler: 1,000 seeded cases per package, wrong handlers run: 0. (C++, TypeScript, Rust and any other package that has a dispatch form.)
- **EC-17.** In C++ unpack of a protected scheme repairs the caller's buffer in place and takes a writable buffer; a scheme with 0 parity bytes keeps the read-only unpack. The repaired buffer equals the original protected message after a successful unpack, bytes that differ: 0.

## Cross-language

- **EC-9.** Every package reads the protected bytes written by every other package, including after the corruption of EC-5: 8 writers × 8 readers = 64 pairs over the vectors in the results report, mismatched rows: 0.

## Sessions and text

- **EC-10.** Under an open session, a protected message is the padded clear message + `n` bytes. The receiver repairs up to `t` wrong bytes before the pad is removed and returns the original row. With n = 4 and 2 wrong bytes the row is recovered in all 8 packages. With n = 4, `t` = 2 and 3 wrong bytes the unpack returns an error and the next payload from the same sender is still read correctly. A session with a scheme of 0 parity bytes keeps the same-length payload (inherits `pack-session.md`).
- **EC-11.** A protected message holding a compact-text field with n = 4: any 2 wrong bytes anywhere (inside the string payload, the count, or a neighbouring field) return the original row, including the original string. Strings that differ from the original: 0 (inherits CS-8).

## Targets and speed

- **EC-12.** The Cortex-M4F build with the feature switched off has the same flash size as before this loop (8,132 B, limit 8,192 B) and the same stack size (492 B). The ESP32 and Pico builds with encode switched on build with 0 errors and 0 warnings, and a message packed there equals the vector bytes.
- **EC-13.** Unpack with correction of a 254-byte message with 16 parity bytes and 8 wrong bytes finishes 1,000 times in ≤ 1 second on one core in C#, TypeScript, Rust, C++, Java, Go and Swift. In Python the same loop takes ≤ 5 seconds. Pack of 1,000 such blocks takes ≤ 1 second in every package, Python included.

## Inherited project criteria

| Project AC | Why this feature exercises it |
|------------|-------------------------------|
| AC-1, AC-2, AC-3 | unprotected golden bytes stay identical in all languages (EC-1) |
| AC-8, AC-9 | short and trailing bytes on a protected scheme return the same errors (EC-4, EC-8) |
| AC-10 | the 100,000-round-trip speed bound stays true for unprotected schemes (EC-1) |
| CS-8 | a flipped bit in a string payload never yields a different string once protection is on (EC-11) |

## Out of scope

- Splitting a long message into blocks, interleaving, correction across several messages.
- Retraining the text tables on real messages (D5).
- Correction on the Cortex-M4F build.
- Encryption of the parity beyond what the session already does; authentication (no tag is added).
