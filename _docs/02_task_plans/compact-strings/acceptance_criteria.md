# Compact strings — acceptance criteria

Outcomes only. Numbers marked (P) are provisional. CS-1 to CS-3, CS-10 and CS-13 were set from the research report (`research_report.md`, 2026-10-18); CS-11 and CS-12 stay provisional until a codec is built. Owner decisions 2026-10-18: scheme B baseline, wire break accepted, one flipped bit may ruin only its own string, CRC is a separate later task.

## Size

Measured on Tatoeba sentences (`research_report.md`); the bounds leave 5 to 10 % over the best measured scheme. "Today" is the 2-byte count plus UTF-8. Size means the whole string field, header included.

- **CS-1.** On the reference corpus, lowercase with `, . - : ! ?` only, a string field is at most 40 % of today's size in Ukrainian and in Russian, and at most 62 % in English (measured 35.5 %, 34.4 %, 57.5 %). Mixed messages (Ukrainian text, numbers, an English word) are at most 48 % (measured 44 %).
- **CS-2.** On the same sentences written with capitals, quotes and dashes, a string field is at most 40 % of today's size in Ukrainian and Russian and at most 62 % in English (measured 37.4 %, 36.2 %, 60.4 %).
- **CS-3.** A string of ≤ 127 payload bytes carries a count header of 1 byte (CS-17), plus a prefix of 6 bits in the payload.
- **CS-4.** A packet with no string, list or dictionary field keeps its bytes: the AC-1 position record stays 13 bytes.
- **CS-14.** Numbers: coordinates with 4 decimals, ids of up to 8 digits, times `hh:mm` and counters are at most 56 % of today's size (measured 51 % with a number mode; 64 % with digits in the ordinary tables, 99 % when the tables are trained on sentences only). Ukrainian text followed by coordinates or a counter is at most 45 % (measured 39 %).
- **CS-13.** No string field is ever larger than today's: for every string under 128 bytes of UTF-8, field size ≤ 2 + UTF-8 bytes (measured: Polish text and a 300-letter rare-letter run were larger than today without a raw fallback).

## Round trip

- **CS-5.** For every corpus string and 100,000 random Unicode strings (capitals, emoji, other scripts, combining marks, the empty string, 65,535-byte strings), unpack of pack returns the same string. Mismatches: 0. No string is refused for its content.
- **CS-6.** A list of strings and a dictionary of string to list of string round-trip with the same counts and the same pair order (sorted by the key's UTF-8 bytes). Mismatches: 0.

## Cross-language

- **CS-7.** On every shared string golden fixture, the bytes from C#, TypeScript, Python, Rust, C++, Java, Go and Swift are identical. Mismatched bytes: 0 (inherits AC-3).

## Damage and errors

- **CS-8.** Flip any one bit inside a string's payload bytes: every other field of the packet unpacks unchanged (mismatched fields: 0) and the string field returns either a string or an error naming the field. Reads past the payload: 0.
- **CS-9.** A payload that ends inside a code, or holds a code that is not defined, returns an error naming the field and 0 values (inherits AC-8, AC-9).
- **CS-10.** 100,000 hostile payloads (random bytes, longest runs, repeated shift and escape) never crash, never hang and never produce more than 6 output bytes per payload byte plus 8 (worst case in the frozen tables 5.33). Unpack time per payload ≤ 1 ms for 64 KiB.

## Speed and size on devices

- **CS-11.** 100,000 pack-then-unpack round trips of a 20-character Ukrainian string finish in ≤ 1 second on one core in C#, TypeScript, Rust, Java, C++, Go and Swift, and ≤ 2 seconds in Python (P; same limits as AC-10).
- **CS-12.** Devices that only carry the packet (LoRa, ESP32, Cortex-M4F, Pico) neither pack nor unpack strings (owner, 2026-10-18). A C++ build with `PACKBIN_NO_TEXT` defined links no string codec and refuses a string field bound to `Text<N>` when the field list is built (a field bound to `Packed` is accepted, CS-20); the embedded CI builds define it, so the Cortex-M4F size probe keeps its 8,192 B flash and 512 B stack budgets with a string-free 14-entry table (flash and stack unchanged within 0 B for a string-free table). The codec itself targets Raspberry Pi, Android and servers: no flash budget.
- **CS-20.** A C++ build with `PACKBIN_NO_TEXT` reads the fields after a string by skipping it with its count header, hands the string to the caller as a borrowed `Packed` view of the compact payload (no decoding), and packs it back unchanged; no codec symbol is linked (owner option D, 2026-10-18).
- **CS-15.** The empty string is 1 byte on the wire (count 0). Measured today: 2 bytes.
- **CS-16.** Invalid UTF-8 on the escape or raw path is refused on unpack, and on pack in C++ and Go, in all 8 languages, naming the field (C++ borrowed bytes unchecked until now).
- **CS-17.** The longest text is 65,535 UTF-8 bytes, as today; 65,536 is refused on pack naming the field. The count header is 1 byte up to 127 payload bytes, 2 up to 16,383, 3 up to 2,097,151.
- **CS-18.** C++ binds a string field to `Text<N>` only (a `View` cannot borrow compact text); a text longer than N is `TooMany`, never cut. C++ pack takes a caller-sized scratch buffer for the encoder, and a text that needs more scratch than given is an error, never a different encoding. 0 heap allocations, 0 exceptions.
- **CS-19.** Encoder rule: the same string gives the same bytes in all 8 languages (CS-7); the rule is an optimal parse over language and caps-lock state with integer costs and a fixed tie-break, not a language-local choice.

## Mapped inherited project ACs

| Project AC | Why this feature exercises it |
|------------|-------------------------------|
| AC-1, AC-2 | position record bytes and values stay the same (CS-4) |
| AC-3 | golden fixtures identical across languages (CS-7) |
| AC-8, AC-9 | short and trailing bytes (CS-9) |
| AC-10 | speed loop gets a string variant (CS-11) |

## Out of scope

- A CRC or checksum for the message (separate later task)
- Uppercase-folding or any lossy mapping; emoji or other scripts in the table (they take the escape to raw UTF-8)
- Languages other than Ukrainian, Russian and English in the table
- Unicode normalization of the input
- Map state, adaptive models or a dictionary the caller supplies (the built-in language and token set is part of the format)
