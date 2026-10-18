# Compact strings — research report (loop 35, 2026-10-18)

Method, scripts and raw output: `research/` (README, `bench_run.log`). Corpus: Tatoeba Ukrainian (188,876), Russian (1,231,016) and English (2,039,120) sentences, 3 to 100 characters; 12,000 per language to train, 2,000 held out; seed 35. Test sets of 1,500 messages: `lower-*` (lowercased, limited punctuation only), `mixed` (Ukrainian text plus coordinates, `ok?`, English words, ids), `raw-*` (the sentence as written: capitals, quotes, dashes). **The numbers come from sentences, not from your real messages.** Estimates are marked "est.".

All sizes below are **all-in**: the 1-byte header, a 5-bit prefix (3 pad bits, 2 initial-mode bits) and padding to a byte are counted. Bits per character:

| Scheme | lower-ua | lower-ru | lower-en | mixed | raw-ua | raw-ru | raw-en | ≤20 chars |
|--------|---------:|---------:|---------:|------:|-------:|-------:|-------:|----------:|
| Today: UTF-8 + 2-byte count | 15.09 | 15.01 | 8.43 | 12.88 | 15.09 | 15.01 | 8.43 | 15.48 |
| Unishox2 (JS port) | 9.06 | 8.82 | 5.41 | 8.06 | 9.08 | 8.87 | 5.56 | 10.16 |
| **A** Huffman, lowercase, escape to raw UTF-8 | 5.37 | 5.14 | 4.77 | 5.49 | 6.15 | 5.80 | 5.13 | 5.86 |
| **B** A + capital shift + caps-lock + 15 punctuation marks | 5.35 | 5.12 | 4.78 | 5.51 | 5.69 | 5.42 | 5.01 | 5.84 |
| **C** every capital and all printable ASCII in the table | 5.37 | 5.13 | 4.76 | 5.49 | 5.62 | 5.37 | 4.99 | 5.85 |
| **B overlay** (one tree for all languages) | 5.35 | 5.17 | 4.85 | 5.68 | 5.64 | 5.43 | 5.09 | 5.83 |
| Fixed 6-bit, 9 bigram slots | 5.99 | 5.89 | 5.64 | 5.99 | 6.76 | 6.55 | 6.01 | 6.44 |
| Predictive bigram (order 1) | 4.29 | 4.25 | 3.99 | 4.17 | 4.99 | 4.83 | 4.25 | 4.85 |

A 27-character Ukrainian message: 52 bytes today, 18.4 bytes with B (-65 %); English 37.5 characters: 39.5 bytes today, 22.4 with B (-43 %).

## What the numbers say

1. **Capitals and extra symbols cost almost nothing.** B equals A on lowercase text (the shift symbol is rare, so it takes a 6-bit code and does not lengthen the others) and saves 0.4 to 0.5 bits per character (7 %) on text written with capitals. C gains at most 0.07 bit over B and needs 326 table symbols against 205.
2. **One tree for all languages (overlay) costs 0 to 3 %** (mixed text 3 %, English 1.5 %) and cuts the table from 205 symbols to 72. Per-mode trees win only where the C++ flash is not a concern.
3. **The pasted static Huffman scheme measures 5.07 bits per character on Ukrainian, not 4.1** (5.38 with a header byte; round trip is exact). It matches A. It raises `ValueError` on `Привіт`, `м'яч` and `a:b`: no capitals, no apostrophe, no `-` or `:`.
4. **Unishox2 is 1.7 times larger than B on Ukrainian** (9.06 against 5.35) and 13 % larger on English. Its JavaScript port also failed to decode 8 to 12 % of the Cyrillic sentences it had encoded (133 of 1,500 Ukrainian, 184 of 1,500 Russian). The C reference was not tested.
5. **The predictive bigram matrix saves 20 % over B** but needs 134 contexts and 6,136 table entries (est. 3 KB or more) and every error ruins the rest of the string. The owner leaned against it; it is out.
6. **Fixed 6-bit is 12 % larger than B** even with 9 bigram slots (the 55 plain symbols leave 9 of 64 states), but a flip damages at most 2 characters.

## Flipped bit (single random bit in a payload, 600 messages per cell)

| Scheme | decoded wrongly or refused | mean share of characters wrong when it decodes |
|--------|---------------------------:|-----------------------------------------------:|
| UTF-8 | 0 % | 3 to 5 % |
| Huffman A / B / overlay | 5 to 13 % refused | 7 to 9 % |
| Unishox2 | 0.3 to 1.5 % refused | 10 to 39 % |

Huffman codes resynchronise, so a flip costs a handful of characters, and the decoder refuses a stream that ends inside a code. With a count prefix that is intact, none of this reaches the next field (CS-8). The 6-bit design is better still (analytic: at most 2 characters).

## Edge cases and costs (HUF-B and overlay, trained on 6,000 sentences per language)

- 3,000 random Unicode strings (ASCII, Cyrillic, em dash, euro, emoji, CJK, combining marks, length 0 to 60) and 18 hand cases (empty, `Привіт`, `ПРИВІТ, СВІТЕ!`, `привіт 😀`, ё, Polish, `ǅ`, `ß`, `İ`, 300 × `x`): 0 round-trip failures.
- **The escape path can lose to plain UTF-8**: Polish `zażółć gęślą jaźń` 42 bytes against 28 today; 300 × `x` 378 against 302 (rare Latin letters in a Ukrainian-trained table). Fix: use the unused value 3 of the 2-bit initial-mode field to mean "the payload is raw UTF-8". The field is then no larger than today's up to 126 UTF-8 bytes and at most 2 bytes larger above (the count header grows to 2 and 3 bytes).
- Code lengths run from 3 to 18 bits. Limit them to 16 (a length-limited Huffman costs a few hundredths of a bit). A payload of N bytes decodes to at most about 4 UTF-8 bytes per payload byte (a 4-bit Cyrillic letter is 2 UTF-8 bytes): bound 5 N + 8.
- Table size on a small target (est., not built; no longer a constraint, see Recommendation): canonical decoding needs the symbols sorted by code, plus a count per length, plus the letter table: per-mode trees about 480 B of data, overlay about 310 B, plus 400 to 700 B of Thumb code. **Added flash about 0.7 to 1.1 KB, so the 8,192 B Cortex-M4F budget (32 B margin) must be raised.** A 15-symbol punctuation block costs about 20 B.
- Switching costs 14 to 18 bits; Ukrainian text with English words stays at 5.5 bits per character.

## Numbers (added after the first run)

The first run trained its tables on sentences, which hold almost no digits, so digits got 12 to 16-bit codes: a message of coordinates, ids, times and counters cost 10.78 bits per character, 20.9 bytes against 21.1 today (no gain). Three variants on 1,000 such messages (`research/numbers.py`, `numbers2.py`):

| Tables | numbers | Ukrainian text | text + coordinates |
|--------|--------:|---------------:|-------------------:|
| Trained on sentences only | 10.78 bits/char (99 % of today) | 5.32 | not measured |
| Trained with 15 % number messages | 6.91 (64 %) | 5.44 | 5.61 |
| **Plus a number mode** (digits . , - : space; a fourth mode, initial-mode field 3 bits) | **5.57 (51 %)** | 5.36 | **5.13** |

The number mode costs 1 more prefix bit and 22 table symbols and is never worse on text. Round trips of 7 hand cases: 0 failures.

## Encoder rule: optimal parse or simple greedy (added before decompose)

Every language must write the same bytes for the same string (AC-3), so the encoder's choices (when to switch language, when to use CAP or LOCK, where to enter the number mode) are part of the format.  compares an optimal parse (dynamic programming over language and caps-lock state, integer costs) with a simple rule set (stay in the current language; switch to the first language that holds the letter; number mode for a run of 3 or more digits; LOCK when two capitals follow):

| Test set | optimal | greedy | greedy loss |
|----------|--------:|-------:|------------:|
| Ukrainian | 5.36 | 5.37 | 0.3 % |
| Russian | 5.18 | 5.50 | 6.3 % |
| English | 4.81 | 4.81 | 0.0 % |
| numbers | 5.57 | 5.78 | 3.9 % |
| text + coordinates | 5.14 | 5.26 | 2.3 % |
| Ukrainian with capitals | 5.64 | 5.66 | 0.2 % |

0 round-trip failures with greedy. Russian loses most because the greedy rule starts in Ukrainian for letters both languages share and then switches back and forth.

## Recommendation

**B with a separate table per language, plus a number mode, code lengths limited to 16, raw-UTF-8 fallback, tables frozen into the format.** On lowercase text it matches the best measured scheme, on text with capitals it is 7 % smaller than A, numbers drop to 51 % of today's size, it round-trips every string and it cannot grow past today's size. Owner scope 2026-10-18: the real encode/decode devices are Raspberry Pi, Android and servers, so the table size no longer decides between per-language tables and the shared overlay tree (1 to 3 % fewer bytes for per-language tables). The Cortex-M4F flash budget concern is dropped: carry-over devices do not decode strings.

## Not measured

- Real messages from your system (the weights come from Tatoeba sentences: complete, literary, one capital each). Digits, call signs and abbreviations would move them.
- Unishox2's C reference, and Meshtastic's own Unishox2 preset.
- Flash and stack of the real decoder on Cortex-M4F; speed in any language.
- A built-in word dictionary (nothing was measured; none exists yet).
