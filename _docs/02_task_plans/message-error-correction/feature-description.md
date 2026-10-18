# Feature: message error correction (parity bytes per scheme)

**Slug**: message-error-correction  **Loop**: 38  **Estimate**: 13 points (Scope high: 8 packages, contracts, fixtures, embedded budgets; Novelty medium: a byte-oriented error-correcting code in 8 languages; Risk high: wire contract, M4F 60 B flash margin). Mandatory `/decompose --feature`.

Source files in this folder: `problem.md` (intake, decisions 1 to 5, code area), `acceptance_criteria.md` (EC-1 to EC-17), `input_data/expected_results/results_report.md` (golden bytes and corruption cases), `scenarios.md`.

## Description

A scheme may declare a number of parity bytes `n` (0 to 32, default 0). Pack appends `n` parity bytes to the packed message; unpack checks the whole message and repairs up to `t` wrong bytes (`t` from 0 to `n/2`, chosen by the caller at unpack, `t` = 0 means detect only). Beyond the limit unpack returns a typed error (uncorrectable) and never a wrong row. A scheme with `n` = 0 is byte-identical to today. A message sends at most 254 bytes including parity (the clear length is covered but not sent). Decisions 1 to 5 of `problem.md` apply: one mechanism (Reed-Solomon over bytes, no separate CRC); setting per scheme; typed error beyond 255 bytes; session parity covers the padded bytes; correction behind `PACKBIN_NO_ECC`, off on Cortex-M4F.

## Fit (Step 4.7 Part A, summary)

| Component / flow | Today | After | Who depends on today | Collision |
|------------------|-------|-------|----------------------|-----------|
| Pack/unpack entry points, eight packages | the packed bytes are the fields | `n` parity bytes after the fields when the scheme declares them; unpack checks and repairs first | callers, golden fixtures, shared vectors | none for `n` = 0 |
| Multi-scheme dispatch by the type byte (C++ `on(...)`, TypeScript, Rust `unpack_with`, others) | the first byte picks the scheme | the first byte may be among the wrong bytes | callers with several schemes | card 1 (resolved) |
| C++ unpack buffer | read-only | writable for protected schemes (repair in place) | embedded callers | card 2 (resolved) |
| Session (`pack-session.md`, F4) | payload = clear length | protected: clear length + `n` | the cross-language session match | card 4 (resolved) |
| Architecture principle, ADR 001 | the bytes are only the fields | opt-in exception | docs, `architecture.md` | card 3 (resolved, new ADR 007) |
| Cortex-M4F embedded build | flash 8,132 of 8,192 B; stack 492 B | unchanged with the feature off | CI size gate | card 5 (resolved) |
| Compact text (`compact-text.md`, CS-8) | one flipped bit damages one string, never the next field | protected: the original string or an error up to `t` | text decoders | none |
| Unpack hostility bound | error value, time and memory set by the input length | decode cost bounded by 255 × 32 operations | hostile-input suite | none (EC-13) |

ADR cross-check: ADR 001 (the wire size stays the sum of the present fields) drifts for protected schemes only. Not a conflict: deliverable is `### ADR Impact` and a new `_docs/02_document/adr/007_message-error-correction.md`.

## Deliverables the decomposition must cover

1. Contract `_docs/02_document/contracts/library/message-ecc.md`: code parameters (field polynomial, roots), parity position, `n` and `t` rules, error kinds, miscorrection table (EC-15), size limit, session and dispatch rules. ADR 007. Update `architecture.md` principle, `pack-session.md`, `interaction-risks.md`, the eight component descriptions, README.
2. Shared vectors in `fixtures/` (golden protected bytes and the corruption cases of `results_report.md`) and the checker that all eight packages must pass (EC-9: 8 writers × 8 readers).
3. One task per package: scheme setting, pack, unpack with repair and the repaired count, the new error kind, dispatch rule (EC-16), session (EC-10), compact text (EC-11), speed (EC-13). C++: allocation-free core, in-place repair (EC-17), `PACKBIN_NO_ECC`.
4. Embedded: the Cortex-M4F size check with the feature off and the ESP32 and Pico builds with encode on (EC-12).
5. CI: the vector check wired into the existing ring or readonly-gate job without raising the median past the current budget (see CI-speed memory: median about 213 s).

## Scenarios

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | A caller keeps a scheme with 0 parity bytes | confirmed | bytes and errors exactly as before | EC-1 | intake |
| S2 | The same row is packed twice under a protected scheme | confirmed | the same bytes both times (parity is a function of the message) | EC-2 | intake |
| S3 | A receiver reads a message with 1 to `t` wrong bytes, including the type byte or a parity byte | confirmed | the row is returned and the repaired count is reported | EC-5 | intake |
| S4 | A receiver reads a message with more wrong bytes than it may repair but up to `n - t` | confirmed | an error naming the kind, 0 values | EC-6 | intake |
| S5 | A receiver reads random garbage | confirmed | refused except for the stated chance; the contract lists that chance for each `n` and `t` | EC-7, EC-15 | intake |
| S6 | The tail of the message is lost, or bytes are added | confirmed | an error, 0 values (with `t` = 0) | EC-14 | intake |
| S7 | The scheme starts to declare parity after bytes were sent without it, or the reverse | confirmed | a protected scheme refuses unprotected bytes (error, 0 values); an unprotected scheme given protected bytes returns the trailing-bytes error | EC-14, AC-9 | intake |
| S8 | Parity count 0, 1, 32, 33 | confirmed | 0 unchanged; 1 and 32 pack; 33 refused when the scheme is built | EC-2, EC-3 | intake |
| S9 | A clear message of 254 − `n` bytes and one byte more | confirmed | the first packs, the second is refused with a typed error, 0 bytes written | EC-4 | intake |
| S10 | Several schemes dispatched by the type byte, the type byte is among the wrong ones | confirmed | all handlers of one dispatch declare the same parity count; the message is repaired, then dispatched; a mix is refused when the dispatch is built (card 1) | EC-16 | intake |
| S11 | A session carries a protected message; a payload is lost or arrives with wrong bytes | confirmed | up to `t` wrong bytes are repaired before the pad is removed; beyond that an error, and the next payload from the same sender is still read | EC-10 | intake |
| S12 | A compact-text field in a protected message has wrong bytes | confirmed | the original string or an error, never a different string at or below the correction limit | EC-11 | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | scheme chosen by the type byte, which may be among the wrong bytes | A — one shared parity count per dispatch | yes (EC-16) |
| 2 | C++ receive buffer is read-only today | A — repair in place, a writable buffer for protected schemes only | yes (EC-17) |
| 3 | "the bytes are only the fields" (architecture principle, ADR 001) | opt-in per scheme, off by default; a new ADR 007 records the exception | yes (EC-1, ADR deliverable) |
| 4 | session payload is "the same length as clear pack" | protected schemes only: clear length + `n` | yes (EC-10) |
| 5 | Cortex-M4F flash margin is 60 B | feature behind flags, M4F measured unchanged with it off | yes (EC-12) |

## Acceptance criteria (copy)

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

- **EC-14.** With n = 4 and `t` = 0, a protected message of the position fixture with 1 to 3 bytes removed from the tail, or 1 to 3 arbitrary bytes added, returns an error and 0 values: 10,000 seeded cases, wrong rows returned: 0. The same fixture packed with 0 parity bytes (13 bytes) read by the n = 4 scheme with `t` = 0 returns an error and 0 values. A scheme with 0 parity bytes given a protected message returns the trailing-bytes error (inherits AC-9).
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
