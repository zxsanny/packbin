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

## Assessment round 1 (loop 45)

Rows added by `feature-assess` (`_docs/loops/loop45/assessment45.md`). `deferred (pending assessment)` rows are flipped by `new-task --clarify` / `--extend`.

| id | scenario | status | behavior | AC ref | source |
|----|----------|--------|----------|--------|--------|
| CS-D1 | TypeScript keeps module-level state (`outBuf`, scratch) after a pack call | confirmed | TypeScript clears `outBuf` and the used part of the scratch arrays after a pack call (owner 2026-10-20) | AZ-2733 AC-1, AC-2 | assess-round-1 |
| CS-D2 | C++ has no test of a `Text<N>` inside a flags/when group, `times` or `repeat` | confirmed | `times` and `repeat` tested; under flags: bit set with an empty text is 1 byte and a clear bit leaves the text empty. The C++ table writes a bound `Text<N>` under flags always (no absent optional text; `Opt<Text<N>>` is `SchemeInvalid`): excluded by the owner on 2026-10-20 | AZ-2733 AC-3 | assess-round-1 |
| CS-D3 | Test-spec documents still describe the old string format and carry no CS ids | confirmed | test-spec documents show the compact bytes and carry the CS, HD, RL ids | AZ-2733 AC-4 | assess-round-1 |
| CS-D4 | Go fuzz seeds hold old-format string bytes | confirmed | Go seeds hold the compact-format packets of the corpus | AZ-2733 AC-5 | assess-round-1 |
| CS-D5 | Retrain the tables on the owner's real messages before the first tag | frozen | the tables stay as they are for 0.4.0; statistics come from real usage later, and a retrain after a tag is a wire break (owner 2026-10-30; earlier: deferred, owner 2026-10-20, answer B) | — | assess-round-1 |
| CS-D6 | Provisional speed limits for Python (40 s) and TypeScript (4 s) never confirmed | confirmed | Python and TypeScript speed bounds load-aware from one measurement (owner 2026-10-20, answer B) | AZ-2733 AC-8 | assess-round-1 |
| CS-D7 | A big text repeated in many rounds has no speed test in Java, C#, Rust, C++ | confirmed | one 1 s repeated-text test in Java, C#, Rust, C++, fix only if it fails (owner 2026-10-20, answer A) | AZ-2737 AC-1, AC-2 | assess-round-1 · loop 46 |
| CS-D8 | A lone surrogate behaves differently by language | out-of-scope | `feature-description.md`: lone-surrogate behavior per language does not change | — | assess-round-1 |
| CS-D9 | Size report not saved at the path AZ-2657 asked for | confirmed | `size_report.md` saved with the run date and recipe hashes | AZ-2733 AC-6 | assess-round-1 |
| CS-S3 | Eight workers pack and unpack different texts at once in C#, Java, Rust, Go, Swift | confirmed | every result equals the reference bytes or its own input (owner 2026-10-20) | AZ-2735 AC-1, AC-2 | assess-round-1 · loop 46 |
| CS-A5 | CS-5 asks 100,000 random strings; suites run fewer and Python, C#, Swift none | confirmed | criteria say 3,000 per package; Python, C#, Swift gain the test (owner 2026-10-20, answer B) | AZ-2736 AC-1, AC-2 | assess-round-1 · loop 46 |
| CS-A10 | CS-10 asks 100,000 hostile payloads; suites run fewer, Go 20,000, Python, C#, Swift none | confirmed | criteria say 30,000 per package; Python, C#, Swift gain the test, Go rises to 30,000 (owner 2026-10-20, answer B) | AZ-2736 AC-1, AC-3 | assess-round-1 · loop 46 |

## Not walked

- A caller-supplied dictionary of words (v1 has none, owner D4).
- Mixed-direction or right-to-left text; Unicode normalization (NFC/NFD) of input.
