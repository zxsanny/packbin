# Findings — a lone surrogate as a dictionary key, in the six other packages

Measured on 2026-11-11 at HEAD ec86364, one probe per package with its own toolchain (sources in `probes/`, re-run with `_docs/loops/loop102/smoke102.md`). Scheme: type 1, one dictionary `d` with `u8` values; cases A (keys U+D800 and U+DC00), B (U+FFFD and U+D800), C (one key U+D800; Java also "?" and U+D800) and a text field with U+D800. Reference: TypeScript before loop 101 wrote `0102000410efbfbd010410efbfbd02` for A, and its own unpack refused it (a short packet with `needed` 0). TypeScript and Dart now refuse at pack.

| package | can a lone half be given as a key | what `pack` does | writes an unreadable packet |
|---------|-----------------------------------|------------------|-----------------------------|
| C# | yes (`string`) | writes U+FFFD (`Encoding.UTF8.GetBytes`): A and B give `0102000410efbfbd010410efbfbd02`; D `0101000410efbfbd01`; a text `010410efbfbd` | **yes**: A and B; own unpack refuses with `ShortPacket(D, needed 0, left 0)` |
| Java | yes (`String`) | writes `?` (0x3F), not U+FFFD (`String.getBytes(UTF_8)`): A `01020002103f0102103f02`, B `01020002103f020410efbfbd01`, D `01010002103f01`, a text `0102103f` | **yes**: A, and C ("?" with U+D800); B reads back with the key U+D800 silently turned into "?" |
| Python | yes (`str`) | refuses: `UnicodeEncodeError` ... surrogates not allowed (strict UTF-8, no field named) in A, B, C and a text | no |
| Go | no (bytes; the nearest input is ED A0 80, ED B0 80, FF) | refuses: `pack refused at d: d: the string is not valid UTF-8`; a text the same | no |
| Rust | no (`String` cannot hold it; the heap-free form takes key bytes) | std: `from_utf16_lossy` of a lone half is U+FFFD, equal to the real U+FFFD, so a map has one key; heap-free: key bytes ED A0 80 or FF refused (`BadValue`); equal keys refused | no |
| Swift | no (`String` makes a lone half U+FFFD at construction) | the FFFD and lone-half keys are one key (count 1); the NFC/NFD pair in a Foundation dictionary is refused at pack | no |

Cases D and E of C# and Java are readable but the lone half does not survive: it reads back as U+FFFD in C# and as "?" in Java.

Behaviour of a lone surrogate in a key or text across the packages (the project has no written rule): TypeScript, Dart and C# write U+FFFD; Java writes "?"; Python and Go refuse the string. After loop 100 and 101, TypeScript and Dart also refuse two keys that become one. Open: C# and Java write the unreadable packet; Java's "?" also merges a lone half with a real "?".

Find in the sources: C# `csharp/Walker.Collections.cs:102` (`PackDict`), `Walker.Counted.cs:297` (`PackUtf8`); Java `java/src/main/java/packbin/Containers.java:60-84` (`packDict`), `VarFields.java:268` (text); Python `python/src/packbin/_pack.py:49`, `:317`; Go `go/collections_pack.go:22`, `:78`.
