# Feature description — compact strings

**Slug**: compact-strings · **Loop**: 35 · **Points**: 13 (new codec in 8 packages, new fixtures and CI wiring) → mandatory `/decompose --feature`.

## Description

Every string packbin writes (a string field, a list element, a dictionary key or value, a string under `repeat`, `times` or `flags`) is encoded by one compact text format instead of a 2-byte count plus UTF-8. The goal: Ukrainian, Russian and English text, digits, coordinates and `, . - : ! ?` in as few bytes as possible, with a flipped bit costing only the string it hits. Owner decisions (2026-10-18): scheme B with a separate table per language plus a number mode; raw-UTF-8 fallback; no built-in word dictionary in v1; tables trained on sentences plus synthetic numbers and then frozen as part of the format; wire break accepted (no tag has ever been published); CRC is a separate later task; the real encode/decode devices are Raspberry Pi, Android and servers, LoRa/ESP32/Cortex-M4F only carry bytes.

Inputs: `problem.md`, `acceptance_criteria.md` (CS-1 to CS-19), `research_report.md` and `research/` (benchmark, greedy comparison, number mode), `scenarios.md`.

## Format decisions made (task 1 turns them into the spec and the frozen tables)

- A string is `[count header][payload]`. The count is a varint of the payload bytes (1 byte to 127, 2 to 16,383, 3 to 2,097,151); count 0 is the empty string. The text itself is at most 65,535 UTF-8 bytes.
- The payload starts with 6 bits: 3 pad bits and 3 start-mode bits (Ukrainian, Russian, English, number, raw UTF-8). Raw means the rest of the payload is the UTF-8 bytes unchanged; the encoder uses it whenever it is not larger.
- Four modes, each with its own canonical Huffman table (code length at most 16): lowercase letters of the language, space, digits and `, . - : ! ?`, 15 extra marks (`; ( ) " % / @ + = * # & _ $` and newline) in the three text modes; the number mode holds digits, `. , - :` and space. Control symbols: switch to another mode, `CAP` (next letter is a capital), `LOCK` (caps lock on or off), `ESC` (the next code point follows as raw UTF-8 bytes).
- The encoder is an optimal parse over mode and caps-lock state with integer code lengths and a fixed tie-break, so all 8 languages write the same bytes (CS-19). The decoder accepts any valid stream whose pad bits are zero.
- The encoder works on the UTF-8 bytes each language already produces today, so lone-surrogate and invalid-input behavior per language does not change.

## Fit (Part A, today → after)

| Area | Today | After | Who depends on today | Collision |
|------|-------|-------|----------------------|-----------|
| 8 packages, string pack/unpack | 2-byte count + UTF-8, written inline in each walker | one codec per package behind the same field functions; list elements and dictionary keys use it too | all callers, README examples, the ring, every inline test hex | wire break (card 1, accepted) |
| Count header | fixed u16 | varint | tests that assert `0107...` style bytes | card 2 |
| C++ strings | `View` borrows bytes from the input; `Text<N>` copies; no heap, no exceptions, no UTF-8 check | `Text<N>` only; scratch buffer from the caller; UTF-8 validated | C++ callers, `all_kinds`, size probe | cards 3, 4, 8 |
| Cortex-M4F size probe (8,192 B flash, 512 B stack) and ARM runner | probe table holds a `utf8` field | `PACKBIN_NO_TEXT` build for embedded CI; string-free probe table | AC-5 of the C++ microcontroller work | card 5 |
| Encoder | one UTF-8 conversion per language | optimal parse, identical in 8 languages | AC-3 golden parity | card 6 |
| Fixtures and CI | `fixtures/golden.hex` (no string), 2 string rows in `cases.txt`, `user_hex` and `nested_hex` in `language-pair.sh`, inline hex in 8 test suites | new vectors file `fixtures/text/vectors.txt`, new hostile rows, new ring vectors | scaffold job, ring, `run-suite.sh`, `loop-tests.sh` | none |
| Docs | README string sections (lines 1140, 1231-1288, 362, 447, 577-583, 649, 784-794, 1571-1580), `schema.md`, `fixtures/hostile/README.md` | rewritten for the new format; ADR 006; contract `compact-text.md` | readers | none |

## Scenarios

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | A caller packs the empty string (first use, nothing to say) | confirmed | The field is 1 byte (count 0); unpack returns the empty string. | CS-15, CS-5 | intake |
| S2 | The same string is packed twice, or in two languages | confirmed | Same bytes every time and in all 8 languages. | CS-7, CS-19 | intake |
| S3 | Two threads pack and unpack at once | confirmed | The tables are constants; no shared mutable state. C++ takes the encoder scratch from the caller. | CS-18 | intake |
| S4 | A packet ends inside a string, or a bit in the payload is flipped | confirmed | Unpack returns an error naming the field and 0 values, or a string with some characters wrong; the next fields are unaffected while the count header is intact; nothing is read past the payload. | CS-8, CS-9, CS-10 | intake |
| S5 | A string holds invalid UTF-8 (escape bytes, raw fallback, a C++ borrowed view) | confirmed | Refused naming the field, in all 8 languages. | CS-16 | intake |
| S6 | A packet written with today's format is unpacked | out-of-scope | No version byte; it fails or reads wrong text. The owner accepted the break (no tag was ever published). | — | intake |
| S7 | A caller wants today's plain `utf8` back for some field | out-of-scope | Every string uses the compact format; no switch. | — | intake |
| S8 | A text of 65,535 and 65,536 UTF-8 bytes; payloads of 127 and 128 bytes | confirmed | 65,535 is accepted and 65,536 refused on pack, as today; the count header is 1 byte to 127, 2 bytes from 128. | CS-17 | intake |
| S9 | Emoji, a ZWJ sequence, a combining mark, U+0000, Polish letters | confirmed | Each code point not in the tables takes the escape and round-trips; the field is never larger than today's. | CS-5, CS-13 | intake |
| S10 | A dictionary with string keys | confirmed | Pairs are sorted by the key's UTF-8 bytes before the keys are encoded (unchanged); a repeated decoded key is refused; Swift still refuses more than 30 combining marks in a key; C++ still needs ascending keys from the caller. | CS-6 | intake |
| S11 | Ukrainian text with a typographic apostrophe (U+2019, U+02BC), quotes or a dash | confirmed | They are escaped and round-trip; no normalization of the input. | CS-5 | intake |
| S12 | A string inside a list, a dictionary value, a `repeat` or `times` round, or an optional field under `flags` | confirmed | Every string position uses the same codec; an absent optional field adds 0 bytes, an empty string adds 1. | CS-6, CS-15, CS-4 | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | Packets with strings change bytes in all 8 languages | owner accepted (2026-10-18) | Update schema, fixtures, README and tests in this loop |
| 2 | Count header: fixed 2 bytes today | A — varint count of payload bytes | CS-3, CS-17 |
| 3 | C++ `View` borrows text from the input; compact text cannot be borrowed | A — C++ strings bind to `Text<N>` only | CS-18 |
| 4 | C++ allocates nothing, but the optimal parse needs working memory | A — caller-sized scratch buffer, error when too small | CS-18 |
| 5 | The M4F size probe and the ARM runner use string fields under a 8,192 B flash budget | A — `PACKBIN_NO_TEXT` build switch; probe table has no string | CS-12 |
| 9 | A board without the codec cannot read the fields after a string | Owner option D (2026-10-18) — a `Packed` view skipped by the count header; board can forward the bytes | CS-20 |
| 6 | Encoder rule must give identical bytes in 8 languages | A — optimal parse with fixed tie-break | CS-19 |
| 7 | Many byte strings decode to the same text (non-canonical) | A — decoder accepts any valid stream with zero pad bits | CS-9 |
| 8 | C++ does not validate UTF-8 today | A — validate escape and raw bytes in all 8 | CS-16 |

Cards in plain words:

1. **Old packets with strings stop being readable.** Today a string is a 2-byte count then the text; after, it is a bit stream. Nothing marks the version. Accepted by the owner because no tag was ever published.
2. **The count header.** Today it is always 2 bytes. A one-byte varint (up to 127 payload bytes) saves a byte per string; the cost is a field that is no longer fixed-width.
3. **C++ cannot borrow text any more.** `View` points into the input buffer, but compact text has to be decoded. C++ strings bind to `Text<N>` (a copy, `TooMany` when N is too small), as the existing copy type does.
4. **C++ allocates nothing, yet the optimal parse needs a table of choices per character.** The caller passes a scratch buffer sized to the longest text it packs; too small is an error, never a different encoding.
5. **The Cortex-M4F size probe uses a string field.** It measures core plus a 14-entry table against 8,192 B of flash. With `PACKBIN_NO_TEXT` the embedded builds link no codec and the probe table swaps its string for another field kind, so the budget and its 32 B margin are unchanged.
6. **All 8 languages must write the same bytes.** An optimal parse with integer costs and a fixed tie-break is up to 6 % smaller than a simple greedy rule (Russian most) and costs about 100 more lines per language.
7. **Many streams decode to the same text** (a wasteful switch, an escape for a letter that has a code). The decoder accepts any valid stream with zero pad bits; the encoder is canonical.
9. **A board without the codec could not read the fields after a string.** Owner option D: such a build binds the string to `Packed`, a borrowed view of the compact payload that is skipped by its count header, so integer fields after the string still read and the bytes can be forwarded unchanged.
8. **C++ checks no UTF-8 today.** The escape and raw paths carry arbitrary bytes, so all 8 packages validate them; C++ gains a validator and its two "accepted" hostile cases become refusals.
