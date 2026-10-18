# Compact text decoders: focused review (loop 36, AZ-2666)

**This is not the `/security` audit.** The project skill `security` is reserved for the owner and cannot be run by the agent, and the built-in `security-review` cannot run here (no `origin/HEAD`). This note is a focused read of the eight decoders for the risks listed in AC HD-5, with the evidence each package already carries. The formal audit stays with the owner (`/security`).

Scope: `python/src/packbin/_text_decode.py`, `typescript/src/text.ts`, `csharp/TextDecoder.cs`, `java/src/main/java/packbin/TextDecoder.java`, `rust/src/walk/text/decode.rs`, `go/text_decode.go`, `swift/Sources/Packbin/TextDecode.swift`, `cpp/src/core/text_decode.hpp`, `text_count.hpp`, and the C++ `Packed` path in `unpack.cpp` and `pack.cpp`.

| Risk | Finding | Evidence |
|------|---------|----------|
| Read past the payload | None found. Every bit read is checked against `8N - pad`; an ESC reads its bytes only after `pos + 8n <= total`; the C++ `byte_at` reads `p[i+1]` only when the 8 bits end inside the payload | the 32 `bad` rows and the 26 `flip` rows in every package; C++ ASan/UBSan run of the whole suite and 100,000 random payloads with guard bytes (AZ-2655 report); Swift, Rust, Go, Java, TypeScript, C#, Python: 20,000 to 200,000 random or damaged payloads, no throw, panic or trap (worker reports) |
| Allocation or time sized by an untrusted number | None found. The count header is at most 2,097,151 and is checked against the bytes left before anything is sized from it; output buffers are `min(65535, 6N + 8)` (C#, Swift), grow by append under the 65,535 limit (Python, TypeScript, Java, Go, Rust), or are the caller's `Text<N>` (C++). Decoding is one pass over the payload bits, linear in N | code reading; the 65,535-character lone-string cases of every package pack and unpack in under 0.1 s |
| UTF-8 validation of the escape and raw paths | Present in all eight: ESC bytes are validated as one scalar (bad lead, bad continuation, overlong, surrogate, above U+10FFFF) and a raw payload is validated whole | `bad` rows `esc_utf8_*`, `raw_*`; C++ no longer borrows unchecked text |
| The 65,535-byte text limit | Enforced as the text grows (compact) and before the copy (raw) in all eight | `bad.length_65536` (a 24 KB payload of spaces); boundary rows at 65,535 |
| Expansion (6N + 8) | Holds: the worst symbol in the frozen tables is the Russian `о` (3 bits for 2 UTF-8 bytes, 5.33 bytes per payload byte) | measured from `tables.json`; random-payload runs assert the bound |
| Dictionary keys | A repeated decoded key is refused in all eight; Swift also refuses more than 30 combining marks in a row in a key (F47, unchanged); C++ needs keys from the caller in ascending order and refuses others | `ac7_*` tests in each package |
| C++ `Packed` pass-through | By design it neither decodes nor validates; pack writes the count and the bytes as given. A relay can forward bytes it never checked; the count is bounded by the input on unpack and by 2,097,151 on pack | AZ-2656 tests `packed_skips_and_forwards`, `damaged_count` |

## Residual risks (not fixed, for the owner)

1. A `PACKBIN_NO_TEXT` build skips a string by its count and does not look inside it: a damaged payload is forwarded as it is. This is the documented behavior of option D.
2. Non-canonical streams are accepted (a wasteful switch, an escape for a letter that has a code, a compact payload where raw would be smaller): one text has several byte forms. A caller that hashes or signs raw bytes must sign the bytes it received, not a repack. The contract states this (decoder rules).
3. There is no checksum: a flipped bit can turn one valid text into another valid text. CRC for the whole message is a separate planned task.
4. TypeScript keeps fixed-size numeric scratch buffers at module level for speed (single-threaded; no text or field is kept there since AZ-2664).

No High or Critical finding.
