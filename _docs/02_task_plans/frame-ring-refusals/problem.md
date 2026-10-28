---
loop: 78
branch: dev
---

# Frame ring: refusal rows and driver cleanups

## What

The cross-language frame ring (loop 77, AZ-3338, AZ-3341) runs seal, open, MAC and verify through 8 drivers and checks every result against the reference codec `scripts/frame/framefmt.py`. Its refusal rows today are tampered `open` and `verify` rows only (16 per language). The refusals that name an error (`TooLong`, `BadValue`, `BufferFull`, direction not loaded) are not in the ring: the owner deferred them on 2026-10-27 because the row syntax has no `dirs` and `out_len` columns and the drivers abort on a direction outside 1 to 3 and use a fixed 300-byte buffer. Four driver defects (L-1, L-2, L-3 and a Python skip answer) were left open at the same time.

This loop adds the by-name refusal rows and fixes those defects.

## Why

`fixtures/frame/vectors.txt` already checks the refusals inside each package. The ring adds what vectors.txt cannot: the exact line each driver prints for a refusal (the TypeScript short-packet name was wrong there until loop 77) and the proof that no driver aborts on bad input. A driver that crashes on `dir=0` or turns a bad hex digit into a zero byte makes a ring result mean less than it says.

## Who

The maintainers of the 8 packages (C#, TypeScript, Python, Rust, C++, Java, Go, Swift) through CI (`ring` job) and `scripts/loop-tests.sh`.

## Behavior

1. **Refusal rows by name.** `fixtures/frame/ring-cases.txt` gains rows that every language must refuse with the reference error name: seal and open (`TooLong`, `BadValue`, `BufferFull`, direction 0, 4 and not loaded) and MAC (`BadValue` for label of 0 and 33 bytes and `n` of 0, 2, 5). The rows are the 22 refusal cases of `vectors.txt` (`refuse.seal.*` 11, `refuse.open.*` 6, `mac.label*`/`mac.nbad*` 5), written as explicit hex rows. Each expected name is checked against `framefmt.py` on every load, as for the existing rows. The existing tampered `open` rows keep their form.
2. **Row columns.** A seal or open refusal row carries `dirs` (directions the session loaded, decimal digits as in vectors.txt) and `out_len` (the caller's output buffer). The driver lines carry both as trailing fields; a line without them means `123` and 300 bytes, so the existing lines stay valid.
3. **Drivers do not abort.** A direction of 0 or 4, or one not in `dirs`, makes each driver print `BadValue` and go on to the next line (today Java and C# throw, Go, Rust and Swift abort, Python raises for 0, C++ maps it to Up). Each driver takes the buffer size from `out_len`.
4. **L-1 strict hex.** In all 8 drivers a token that is not hex (bad digit, odd length) ends the process with a non-zero exit and a message naming the line. Today TypeScript, Swift, C++ and Java accept it quietly.
5. **L-2 blame the writer.** `ring_frame.py open-in` and `verify-in` check that every line a writer printed is hex (or `-`). A writer that printed a non-hex word (for example `TooLong` for a good row) is reported by `check` as `<writer>: <case> seal gave ...`, its lines go to the readers as `open-skip` / `verify-skip`, and no reader is reported as failed.
6. **L-3 Go.** The Go driver checks every number it parses and the scanner error; a malformed number or an over-long line ends the process with a non-zero exit.
7. **Python skip.** The Python driver answers `open-skip` and `verify-skip` with `skip`, like the other seven.

## Out of scope

Key and msg_id length refusals (U1: Rust takes `&[u8; 32]` and an 8-byte id), multi-part MAC messages, the refusal display that shows five lines a reader, the other loop 77 leftovers (public-key pairing step, AVR check, dead-code warnings).

## Code sections / UI locations for this loop

- `fixtures/frame/ring-cases.txt`, `fixtures/frame/README.md` (row syntax note), `scripts/frame/ring_frame.py`
- the 8 frame drivers under `.github/workflows/drivers/`: `handoff_frame.py`, `handoff-frame.ts`, `HandoffFrame.java`, `csharp/HandoffFrame.cs`, `handoff-go/frame.go`, `handoff-rust/src/frame.rs`, `handoff-swift/Sources/handoff-swift/Frame.swift`, and the frame section of `handoff.cpp` (lines 419-504)
- `.github/workflows/ring-frame.sh`, `.github/workflows/ring-frame.test.sh`, and one new script that runs the real drivers on malformed lines (`ring-frame-drivers.test.sh`), wired into the `ring` job of `.github/workflows/test.yml` and `scripts/loop-tests.sh`

## Flagged concerns

| concern | policy / owner | status | severity |
|---|---|---|---|
| The refusals are also checked per package by vectors.txt, so the new rows duplicate coverage in part | owner told on 2026-10-28 and chose "accept all recommended" | accepted-risk | Low |
| Eight drivers change at once; a driver edit that is not run on its toolchain breaks CI (loop 77: six defects in the first push) | run the real ring and every `test.yml` ring step before the first push (LESSONS, loop 77) | open | Medium |
| `dirs` / `out_len` change the driver line format that the Python harness and the self-test stand-in `fake.py` both read | `fake.py` and `ring_frame.py` change in the same batch; old lines stay valid | open | Low |
