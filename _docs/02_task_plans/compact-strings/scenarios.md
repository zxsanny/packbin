# Scenarios — compact-strings

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred. AC refs are feature ACs in `acceptance_criteria.md`; `/decompose` remaps each to its task AC.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | A caller packs the empty string (first use, nothing to say) | confirmed | The field is 1 byte (count 0); unpack returns the empty string. | CS-15, CS-5 | intake · AZ-2648..2654 AC-3; AZ-2655 AC-1; AZ-2647 AC-4 |
| S2 | The same string is packed twice, or in two languages | confirmed | Same bytes every time and in all 8 languages. | CS-7, CS-19 | intake · AZ-2648..2654 AC-1; AZ-2655 AC-1; AZ-2657 AC-2 |
| S3 | Two threads pack and unpack at once | confirmed | The tables are constants; no shared mutable state. C++ takes the encoder scratch from the caller. | CS-18 | intake · AZ-2655 AC-3 |
| S4 | A packet ends inside a string, or a bit in the payload is flipped | confirmed | Unpack returns an error naming the field and 0 values, or a string with some characters wrong; the next fields are unaffected while the count header is intact; nothing is read past the payload. | CS-8, CS-9, CS-10 | intake · AZ-2648..2654 AC-4; AZ-2655 AC-5; AZ-2657 AC-1 |
| S5 | A string holds invalid UTF-8 (escape bytes, raw fallback, a C++ borrowed view) | confirmed | Refused naming the field, in all 8 languages. | CS-16 | intake · AZ-2648..2654 AC-6; AZ-2656 AC-4 |
| S6 | A packet written with today's format is unpacked | out-of-scope | No version byte; it fails or reads wrong text. The owner accepted the break (no tag was ever published). | — | intake |
| S7 | A caller wants today's plain `utf8` back for some field | out-of-scope | Every string uses the compact format; no switch. | — | intake |
| S8 | A text of 65,535 and 65,536 UTF-8 bytes; payloads of 127 and 128 bytes | confirmed | 65,535 is accepted and 65,536 refused on pack, as today; the count header is 1 byte to 127, 2 bytes from 128. | CS-17 | intake · AZ-2648..2654 AC-5; AZ-2646 AC-4 |
| S9 | Emoji, a ZWJ sequence, a combining mark, U+0000, Polish letters | confirmed | Each code point not in the tables takes the escape and round-trips; the field is never larger than today's. | CS-5, CS-13 | intake · AZ-2648..2654 AC-1,2; AZ-2646 AC-4 |
| S10 | A dictionary with string keys | confirmed | Pairs are sorted by the key's UTF-8 bytes before the keys are encoded (unchanged); a repeated decoded key is refused; Swift still refuses more than 30 combining marks in a key; C++ still needs ascending keys from the caller. | CS-6 | intake · AZ-2648..2654 AC-7; AZ-2655 AC-6 |
| S11 | Ukrainian text with a typographic apostrophe (U+2019, U+02BC), quotes or a dash | confirmed | They are escaped and round-trip; no normalization of the input. | CS-5 | intake · AZ-2647 AC-4 (rows); AZ-2648..2654 AC-1,2 |
| S12 | A string inside a list, a dictionary value, a `repeat` or `times` round, or an optional field under `flags` | confirmed | Every string position uses the same codec; an absent optional field adds 0 bytes, an empty string adds 1. | CS-6, CS-15, CS-4 | intake · AZ-2648..2654 AC-3; AZ-2655 AC-6 |

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

## Not walked

- A caller-supplied dictionary of words (v1 has none, owner D4).
- Mixed-direction or right-to-left text; Unicode normalization (NFC/NFD) of input.
