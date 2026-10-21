# Acceptance criteria — C# repeated-text cache and C++ `when` of a skipped source (loop 54)

Outcomes only. Numbers are the pass line.

## C# repeated text (AZ-2737 CS-D7, CS-5/CS-D inherited)

- **AC-C1: speed with headroom.** One 65,535-character text in 200 rounds of `times`, packed and unpacked, takes at most 1 s nominal times the load factor (the existing test, unchanged), and at most 250 ms measured on an idle host in 10 of 10 consecutive runs, on the default target and on `PackbinTarget=netstandard2.0` (four times the room the CI runs had), typed and dictionary.
- **AC-C2: same bytes.** Every packet any existing C# test or fixture packs is byte-identical before and after (the 4,228 tests of the suite pass on both targets; every `enc` row of `fixtures/text/vectors.txt` unchanged).
- **AC-C3: a changed text is encoded again.** Over 200 rounds with the text changed at round 100, with alternating texts A, B, A, B, and with two texts of the same length that differ only in the last character, the packet equals the packet built by encoding every round's text one by one (0 differing bytes). A compacting text and a raw text are both covered.
- **AC-C4: nothing outlives a pack call.** Two pack calls in a row (same text, then a different text), and two threads packing at once (the existing concurrency test), share no text between calls: 0 differing bytes against the one-by-one encoding; the cache is released when the call ends.
- **AC-C5: limits unchanged.** A text of 65,536 UTF-8 bytes is refused with the same message as today.

## C++ `when` of a skipped source

- **AC-W1: skipped source, value not equal.** For `u8 mode; when(mode==1){u16 a; u8 k}; when(k==2){u8 b}` with mode 0, k 2, b 5, `pack` writes the mode byte only (the packet equals the Python and Rust packet for the row, 0 differing bytes) and `unpack` returns mode 0 with no error and no trailing bytes.
- **AC-W2: skipped source, value equal to zero.** For the same scheme with `when(k==0)`, mode 0, k 0, b 5: `pack` writes the mode byte only and `unpack` returns mode 0, no error, `b` unset (a skipped source is absent on both sides).
- **AC-W3: held source.** With mode 1 the packet carries `a`, `k` and `b` (equal to the Python and Rust packet, 0 differing bytes) and unpacks to the same row; the same for the `k==0` variant.
- **AC-W4: nested skip.** A source inside a `when` inside another `when`, with the outer condition false, makes the consuming `when` false; with the outer true and the inner false, also false; both true, the body is written.
- **AC-W5: same `when` holds both.** A `when` that holds both the source and its consumer writes the consumer body whenever the source is written (the chain stops there, as `mark_held` does for counts).
- **AC-W6: shared case in all eight packages.** `fixtures/hostile/cases.txt` gets a case for the scheme of AC-W1 and AC-W2 (rows with mode 0 and mode 1); the runners of all eight packages execute it, with 0 failing packages and 0 skipped runners for it.
- **AC-W7: embedded budget.** The Cortex-M4F image built by the arm embedded stage stays at or under 8,192 B flash and 512 B stack, `cpp-avr-uno` and `PACKBIN_NO_TEXT` still build with sizes inside their recorded margins, and the new margins are written in `_docs/AGENT_GOTCHAS.md`.
- **AC-W8: same bytes elsewhere.** Every packet any existing C++ test, the hostile corpus and the cross-language ring pack or read is byte-identical before and after for the cases that do not use a skipped source (the C++ suite on `gcc:16` and the language-pair run pass with 0 failures).

## Inherited project acceptance criteria exercised

| Project AC | Why |
|------------|-----|
| `acceptance_criteria.md` Bytes (identical bytes across the eight packages) | AC-C2, AC-W1 to AC-W3, AC-W6, AC-W8 |
| AZ-2737 AC-1 / CS-D7 (65,535 characters, 200 rounds, 1 s) | AC-C1 |
| Embedded budget (8,192 B flash, 512 B stack, `AGENT_GOTCHAS.md`) | AC-W7 |
| CS-S3 (two threads, no shared mutable state) | AC-C4 |

## Added by the feature assessment, round 1

- **AC-W9 (AZ-2823): link limit.** A `when` source 255 entries behind its holding `when` builds; 256 and 301 entries are refused when the scheme is checked (the limit counts already have).
