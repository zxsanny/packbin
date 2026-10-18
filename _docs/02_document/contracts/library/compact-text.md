# Contract: compact-text

**Component**: library (all 8 packages)
**Producer task**: AZ-2646 — AZ-2646_compact_text_format_spec.md
**Consumer tasks**: AZ-2647, AZ-2648, AZ-2649, AZ-2650, AZ-2651, AZ-2652, AZ-2653, AZ-2654, AZ-2655, AZ-2656, AZ-2657, AZ-2658
**Version**: 1.0.0
**Status**: frozen
**Last Updated**: 2026-10-18
**Tables**: `fixtures/text/tables.json`, sha256 `764ad13ee701af908b7c802abe67d0ac8639bc9bce5a3af666695c5f6df1d9c4`

## Purpose

The wire form of every string packbin writes: a string field, a list element, a dictionary key or value, a string under `repeat`, `times` or `flags`. It replaces the 2-byte count plus UTF-8. All eight packages write the same bytes for the same string. The reference implementation is `scripts/text/textfmt.py`; where this text and the reference disagree, fix the one that is wrong and re-run `fixtures/text/check-vectors.sh`.

## Shape

### Field

```
string  = count payload
count   = varint            ; payload length in bytes
payload = N bytes, N = count; absent when count = 0
```

- `varint` is LEB128: 7 bits per byte, least significant group first, bit 7 set on every byte except the last. 1 to 3 bytes (0 to 2,097,151). A longer or non-minimal varint (a last byte of 0x00 after the first byte) is refused (`varint`). A buffer that ends inside it is `short`.
- Count 0 is the empty string, with no payload (1 byte on the wire).
- The text is at most 65,535 UTF-8 bytes (`length` when a decoded text is longer, and pack refuses a longer text naming the field). Pack counts the UTF-8 bytes the language already produces for the string.
- A buffer that holds fewer than `count` bytes after the varint is `short`.

### Payload

Bits are numbered from the most significant bit of the first byte.

| Bits | Meaning |
|------|---------|
| 0 to 2 | `pad`: number of unused bits at the end of the last byte (0 to 7) |
| 3 to 5 | start mode: 0 Ukrainian, 1 Russian, 2 English, 3 number, 4 raw UTF-8; 5 to 7 are refused (`mode`) |
| 6 to 8N-pad-1 | symbols, then the pad bits (all zero; `pad`) |

Raw UTF-8 (start mode 4): the payload is the byte `0x10` (pad 0, mode 4, two zero bits) followed by the UTF-8 bytes of the text, unchanged. Any other first byte with mode 4 is refused (`raw`). The bytes must be valid UTF-8 (`utf8`) and at most 65,535 (`length`). `N` is therefore 1 plus the UTF-8 length.

### Modes, symbols and tables

Four modes: 0 Ukrainian (`ua`), 1 Russian (`ru`), 2 English (`en`), 3 number (`num`). Each has its own prefix code, listed in `fixtures/text/tables.json` (`modes.<name>.lengths`, in symbol-index order; `modes.<name>.symbols` names each index). The alphabets, capitals and shared characters are in the same file and are normative:

- Letters: `ua` = `абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'` (34), `ru` = `абвгдеёжзийклмнопрстуфхцчшщъыьэюя` (33), `en` = `abcdefghijklmnopqrstuvwxyz'` (27). The apostrophe is U+0027 and has no capital. Every other letter has a capital, given in `upper` (explicit code points; no runtime case conversion).
- Shared (32, in this order): space, `0123456789`, `, . - : ! ?`, then `; ( ) " % / @ + = * # & _ $` and newline (U+000A).
- Number characters (15, in this order): `0123456789`, `.`, `,`, `-`, `:`, space.

Symbol order in a text mode (index = position): the letters of the language in alphabet order; the 32 shared characters; `SW` to each other mode in ascending mode number (three symbols, the last being `SW num`); `CAP`; `LOCK`; `ESC`. Symbol order in the number mode: the 15 number characters; `SW ua`, `SW ru`, `SW en`; `ESC`. Table sizes: ua 72, ru 71, en 65, num 19.

Code assignment (canonical Huffman): sort the symbols by (code length, symbol index); the first symbol gets the all-zero code of its length; the next code is the previous code plus 1, shifted left by the growth in length. Every table is a complete code (the Kraft sum is exactly 1) with lengths at most 16, so every bit pattern decodes; the only code error is a stream that ends inside a code (`code`).

### Decoding

State: mode (from the start mode), capital lock off, no pending `CAP`. Read codes from the current mode's table until the bits (up to `8N - pad`) are used up.

| Symbol | Effect |
|--------|--------|
| letter `L` | the letter, or its capital when the lock is on; with a pending `CAP` the capital (clears `CAP`). A letter without a capital (the apostrophe) is unaffected by the lock; after `CAP` it is refused (`cap`) |
| shared / number character | that character (the lock does not change it); a pending `CAP` is refused (`cap`) |
| `SW m` | the mode becomes `m`; the capital lock stays as it is; a pending `CAP` is refused (`cap`) |
| `CAP` | sets a pending `CAP`; refused when the lock is on or `CAP` is already pending (`cap`) |
| `LOCK` | toggles the capital lock; a pending `CAP` is refused (`cap`) |
| `ESC` | the next code point follows as 1 to 4 UTF-8 bytes, 8 bits each, with no alignment; a pending `CAP` is refused (`cap`); bytes cut short are `esc`; invalid UTF-8 (bad lead byte, bad continuation, overlong, surrogate, above U+10FFFF) is `utf8` |

A `CAP` still pending at the end is `cap`. A decoded text longer than 65,535 UTF-8 bytes is `length` (checked as it grows). The decoder accepts any stream that follows these rules, including streams the encoder would not write.

Refusal names (`kind`), used by `fixtures/text/vectors.txt`: `short`, `varint`, `mode`, `pad`, `code`, `cap`, `esc`, `utf8`, `raw`, `length`. Every package returns its own error that names the field; the kind decides only whether a row is refused.

### Encoding (canonical: all packages write the same bytes)

1. Empty text: the byte `00`. Text over 65,535 UTF-8 bytes: refused naming the field.
2. Parse the code points. A parse is a sequence of symbols with the capital lock and the mode tracked as in the decoder. The cost of a parse is its bits: the code length of every symbol, in the table of the mode in which it is written, plus 8 bits for every UTF-8 byte after an `ESC`.
3. The edges of a character `c` in mode `m` with lock `k` (state `(m, k)`; `(3, 1)` exists, because the lock survives the number mode):
   - Letter edge. If `c` is a letter of `m` (mode not 3): when it has a capital, the symbol is allowed only if `k = 0`; the apostrophe is allowed for any `k`. If `c` is the capital of a letter of `m`: with `k = 1` the letter symbol alone; with `k = 0` the symbols `CAP`, then the letter.
   - Shared edge. If `c` is in the shared list (modes 0 to 2) or the number list (mode 3): that symbol, in any `k`.
   - Escape edge. For any `c`: `ESC`, then the UTF-8 bytes of `c`.
   - Control edges (no character consumed): `SW m'` for each `m' != m` to state `(m', k)`; `LOCK` (modes 0 to 2) to state `(m, 1-k)`.
4. The parse with the fewest bits wins. Among parses with the same bits, the winner is the one whose symbol indexes (in the table of the mode of each symbol) are lexicographically smallest. Dynamic programming from the end gives it: let `f(i, s)` be the cheapest cost to finish from character `i` in state `s` (`f(n, s) = 0`; solve control edges within a position by repeating until nothing improves); from the start state take, at every step, the edge with the smallest first-symbol index among those whose cost plus the cost of what follows equals `f(i, s)`. The edges of one state have distinct first symbols, so the choice is unique.
5. The start mode is the mode `m` with the smallest `f(0, (m, 0))`; a tie goes to the smaller mode number.
6. The compact payload has `N = ceil((6 + bits) / 8)` bytes. The raw payload has `1 + len(UTF-8)` bytes. Write the compact payload only if `N` is strictly smaller than the raw one, otherwise the raw payload. The field is the varint of the payload length, then the payload.

Costs are integers, so the result does not depend on floating point.

### C++ (the allocation-free core)

- A string member binds to `Text<N>` (a decoded copy; `TooMany` when the text does not fit) or to `Packed` (a borrowed view of the payload after the count, no decoding; a no-text build skips a string by its count and can forward the bytes). It never binds to `View`.
- Pack takes a caller-sized scratch buffer for the parse (about 32 bytes per character); a text that needs more scratch than given is an error naming the field, never a different encoding.
- A build with `PACKBIN_NO_TEXT` links no codec and refuses a field bound to `Text<N>` when the field list is built; a field bound to `Packed` is accepted. Pack of a `Packed` member writes its count and bytes as given and does not decode or validate them.
- 0 heap allocations, 0 exceptions, tables in read-only memory.

## Invariants

- Same string, same bytes in all 8 packages (`fixtures/text/vectors.txt`).
- A string under 128 UTF-8 bytes is never larger than 2 + its UTF-8 bytes.
- A payload of N bytes decodes to at most 6N + 8 UTF-8 bytes (the worst symbol in the frozen tables is the Russian о: a 3-bit code for 2 UTF-8 bytes, 5.33 bytes per payload byte).
- Dictionary pairs are sorted by the key's UTF-8 bytes before the keys are encoded (unchanged). A repeated decoded key is refused (unchanged).

## Versioning Rules

- The format has no version byte. Any change to a table, a symbol order, the alphabets, a tie-break rule or the header is a wire break and needs a new ADR.
- Retraining the tables is a wire break. `fixtures/text/tables.json` is part of the format; its sha256 is recorded above.

## Worked examples (real bytes; reproduce with `scripts/text/textfmt.py`)

Codes below are the canonical codes of the frozen tables; `bits` counts the symbol bits.

| Text | Parse (mode in brackets after a switch) | Field bytes |
|------|------------------------------------------|-------------|
| `привіт` | start `ua`; `п`=110111 `р`=10101 `и`=0100 `в`=10000 `і`=10010 `т`=0111 (29 bits, pad 5) | `05 a3 7a a4 24 e0` (count 5) |
| `Привіт, Світе!` | start `ua`; `CAP`=1111100 `п` `р` `и` `в` `і` `т` `,`=1111011 space=000 `CAP` `с`=10110 `в` `і` `т` `е`=0011 `!`=1111111110 (86 bits) | `0c 83 e6 f5 48 49 fd 8f 96 84 9c ff e0` |
| `ПРИВІТ` | start `ua`; `LOCK`=111111111110101 `п` `р` `и` `в` `і` `т` (44 bits) | `07 c3 ff ae f5 48 49 c0` |
| `привіт ok 48.46` | start `ua`; six letters, space=000, `SW en`=111111101, `o`=0111 `k`=1111011 space=001, `SW num`=11111101, `4`=1000 `8`=1100 `.`=000 `4`=1000 `6`=1010 (82 bits) | `0b 03 7a a4 24 e3 fa fe cf ec 60 8a` |
| `привіт 😀` | start `ua`; six letters, space=000, `ESC`=111111111100, bytes `f0 9f 98 80` (76 bits) | `0b c3 7a a4 24 e3 ff 3c 27 e6 20 00` |

## Change Log

| Version | Date | Change | Author |
|---------|------|--------|--------|
| 1.0.0 | 2026-10-18 | Frozen with tables.json (AZ-2646); owner decisions D1 to D5 and option D | loop 35 |
| 0.1.0 | 2026-10-18 | Draft | loop 35 |
