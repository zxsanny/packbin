# Test Data Management

## Seed Data Sets

| Data Set | Description | Used by Tests | How Loaded | Cleanup |
|----------|-------------|---------------|-----------|---------|
| position | type 64, sid 1, lat 500000000, lon 300000000, profile 1, motion flags clear | FT-P-01, FT-P-02, FT-P-03, NFT-PERF-01 | inline values from `results_report.md` | none; the call does not store the packet |
| flags | flags 0x00 and 0x20 around a uint16, and a stored 0 | FT-P-04, FT-P-05, FT-N-01 | inline | none |
| groups | conditional group and a repeated pair | FT-P-06, FT-P-07, FT-N-02 | inline | none |
| strings | `zxsanny`, empty, and 65536 bytes of `a` | FT-U-01, FT-U-02, FT-U-03, FT-U-04 | inline | none |
| compact text vectors (loop 35) | `fixtures/text/vectors.txt`: 346 `enc`, 10 `alt`, 32 `bad`, 4 `ref` and 26 `flip` rows (text, expected field bytes, refusal kind, ring packet, bit-flip target); tables `fixtures/text/tables.json` (sha256 in the contract `compact-text.md`); sentence-set sizes `fixtures/text/tables.report.md` (the Tatoeba corpus is not in the repository); size of the `enc` rows `_docs/02_task_plans/compact-strings/size_report.md` | CS-1 to CS-20, FT-U-01, FT-U-02 | each package reads the file by path; `fixtures/text/check-vectors.sh` re-derives every row with `scripts/text/textfmt.py` | none; the files are read only |
| lists | `[1, 2]`, one big-endian 1, list then a following byte, empty, 65536 elements | FT-L-01, FT-L-02, FT-L-03, FT-L-04 | inline | none |
| dictionaries | the 79-byte user value, empty triple, a repeated key | FT-D-01, FT-D-02, FT-D-03, FT-D-04, FT-D-05 | inline | none |
| handoffs | producer hex consumed by the next language | FT-H-01, FT-H-02, FT-H-03 | inline | none |
| borrowed count | width-2 kinds `0,1,2,3`, width-1 bias −1, two pairs then `7`, and the route fixture | FT-C-01, FT-C-02, FT-C-03, FT-C-04, FT-C-05 | inline | none |
| hostile packets | `fixtures/hostile/cases.txt`: 33 cases (loop 19 added `eq_out_of_range` and seven `pack` cases, see FT-X-24 to FT-X-33; the 25 of loop 18 follow): packets and invalid schemes with the outcome kinds each may return (zero-progress repeat, hostile counts, invalid UTF-8, nine flag bits, later and outer references, bool outside flags, `eq(bool, false)` (AZ-2126), two `limit` cases: a `repeat` and a `times` past a low round limit, AZ-2220), and five `pack` cases (AZ-2194: out-of-range integer, missing value, `times` list too long and too short, aligned round row `01030102020303`; each README section has `Scheme`, `Row`, `Run by` and `Not run by`) | AZ-2069 package tasks (AZ-2071 to AZ-2075, AZ-2078 and later), format check in the `scaffold` job | each package reads the file by path and writes the scheme by hand from `fixtures/hostile/README.md` | none; the file is read only |
| flags members | `_docs/03_implementation/flags_member_reference_cases_loop18.md`: about 60 hex-pinned rows over twelve schemes (WA to R2) for a `when`, `times` or `repeat` as a `flags` member; e.g. `010103075a00`, `0100025a00`, `01020305065a00`, `0101035a000506`, `01030107` | FT-X-13, FT-X-14 | each package pins the hex of the table in its own member tests (`MemberCases` or `member-cases` helpers) | none; the table is read only |
| lone round values | `u8 n; times(count n){ dict d { utf8 e } }` with a lone and a per-round dictionary; `u8 n; times(count n){ u8 x, u8 y }` with a lone scalar | FT-X-11, FT-X-12 | inline | none |
| flag-byte scope | C++ schemes with a flag byte inside a `flags` member or flag-bit child, rows `v=3 x=5 b=7` | FT-X-15, FT-X-16 | inline | none |
| C# typed rows | typed row classes with narrow, wide and unsupported collection members, a nested row with null members, `u2`, `bits` and `packed` slots with fractions and range edges, the F25 packet `01 01 00 ff ff ff ff`, ring hex `010300010100020200` | FT-X-17 to FT-X-21, NFT-SEC-03 | inline in the C# tests; ring hex in `.github/workflows/language-pair.sh` | none |
| round and split-form rows | loop 19: `u32 n; times(count n){ u8 x }` with n 65536 / 70000 / 4e9; `u64 n` 4294967299; the split-form schemes of `pack_split_*` (rows `mode=1 speed=7`, `n=2 pt=[5,6]`, `sel=0 pt=[5]`, `mode=0 speed=7 heading=90`); S1 `flagbyte fb; flags{ group g1{v; fb byte; bit fb x}, group g2{bit fb y} }; bit fb b`; `eq` constants 300, -1, 70000, `"x"`, NaN, 1.5, `true` | FT-X-24 to FT-X-33 | inline in each package's tests; the hostile rows by id from `fixtures/hostile/README.md` | none |
| hostile packets, seven loaders (loop 24) | `fixtures/hostile/cases.txt`: 65 cases = 10 unpack + 2 limit + 15 construct + 38 pack (the 33 above grew in loops 20 to 22; unchanged in loops 23 and 24). Go is the seventh reader: every one of the 38 pack sections names Go in `Run by` and none in `Not run by`; `check-cases.sh` counts seven names with a whole-word match | GO-4, FT-X-87, NFT-SEC-04 | `go/hostile_loader_test.go` and `go/hostile_pack_test.go` write each scheme by hand from `fixtures/hostile/README.md` and read the file by path; the case tables are checked equal to `cases.txt` (`TestHostileTablesHoldNoCaseTwiceAndNoOther`) | none; read only |
| Go fuzz seed corpus | `go/testdata/fuzz/FuzzUnpack/` (56 files at loop 24, 54 since loop 74: the `ring_session_body` and `ring_session_packet` seeds were deleted with the stream session, ADR 009): the golden packet and body, the ring payloads, and every unpack and limit packet of `cases.txt`, each with and without its type byte | GO-5, FT-X-88 | read by `FuzzUnpack` and `TestFuzzSeedsReadWithTheSchemeOfTheirKind` | new inputs go to the Go build cache; a failing input would be written under `go/testdata/fuzz` (none exists) |
| ring kinds and Go handoffs | the 15 kinds of `language-pair.sh` (GO-7): `user`, `nested`, `boolflag`, `booltrue`, `bitwhen`, `session` (all six other languages; retired in loop 74, ADR 009, AZ-3280), `roundflags`, `roundwhen` (TypeScript, Rust, Java, C++; C# only packs), `listgroup`, `dictgroup`, `listflags` (TypeScript, Python, Java, C#), the three `-short` refusals; 114 explicit Go handoff lines, guarded by `ring-wiring.test.sh` | GO-7, FT-X-90 | hex inline in `language-pair.sh`; Go driver `.github/workflows/drivers/handoff-go/` | none |
| Go session vectors (retired in loop 74, ADR 009) | seed bytes 1..32, value `01` + 15 zero bytes, the AC-1 row: C# ciphertext `b55d0a29c56c203712b241232e`; TypeScript's keyed first-packet vectors | GO-6, FT-X-89 (retired) | was inline in `go/session_test.go` (deleted) | none |
| hostile packets, eight loaders (loop 26) | the same 65 cases (unchanged in loops 23 to 26). Swift is the eighth reader: the pack and limit sections name Swift in `Run by`; `check-cases.sh` counts eight names with a whole-word match | SW-4, FT-X-128, NFT-SEC-05 | `HostileLoader.swift`, `HostilePacks.swift`, `HostileSchemes.swift`, `HostileRules.swift` write each scheme by hand and read the file by path; `HostileTests.tables_holdEveryCaseOnceAndNoOther` | none; read only |
| unpack fuzz corpus | `fixtures/hostile/fuzz/corpus.txt` (new in loop 26, AZ-2517): 28 inputs, `name kind hex`: the 12 unpack and limit packets of `cases.txt` and 16 packets of Go's seed corpus (ring payloads, their `-short` forms, the golden packet) | SW-5, FT-X-129 | read by Swift `FuzzTests` (`corpus_holdsEveryHostileUnpackAndLimitPacket` checks every unpack and limit case is there); any package may read it | none; read only |
| ring kinds and Swift hand-offs | the same 15 kinds; 136 `handoff` lines with Swift (22 of them Go-Swift), guarded by `ring-wiring-swift.test.sh` | SW-7, FT-X-131 | hex inline in `language-pair.sh`; Swift driver `.github/workflows/drivers/handoff-swift/` | none |
| Swift session (retired in loop 74, ADR 009) and RFC 8439 vectors | the Go session vectors above (retired); RFC 8439 §2.3.2 (block) and §2.4.2 (ciphertext); 300 zero bytes at packet 5 against OpenSSL's key stream | SW-6, FT-X-130 | inline in `ChaCha20Tests.swift` (`SessionTests.swift` deleted in loop 74) | none |
| crypto primitive vectors (loop 69; all eight packages since loop 74) | `fixtures/crypto/vectors.txt`: 27 published rows of SHA-256, HMAC-SHA256, HKDF-SHA256 and the ChaCha20 block and cipher (`fixtures/crypto/README.md`) | FT-X-156, FT-X-163; the loop 74 internal modules | read by path: Rust `src/crypto_vectors_tests.rs`, C# `CryptoVectorTests`, Java `CryptoVectorsTest`, Swift `CryptoVectorTests`, and the internal crypto modules of C++ (`crypto_vectors_host_tests.cpp`), Go (`crypto_vectors_test.go`), Python (`test_crypto_vectors.py`) and TypeScript (`crypto-vectors.test.ts`) | none; read only |
| frame vectors (loop 69) | `fixtures/frame/vectors.txt`: 157 rows (20 `keys`, 35 `seal`, 57 `open`, 42 `mac`, 3 `replay`; E1 to E5 included) of `pack-session.md` frame mode | FT-X-157, FT-X-163 | read by path by the Rust, C#, Java and Swift frame tests | none; read only |

## Data Isolation Strategy

Each call gets its own input buffer. The packages do not keep the last packet.

## Input Data Mapping

| Input Data File | Source Location | Description | Covers Scenarios |
|-----------------|----------------|-------------|-----------------|
| results_report.md | `_docs/00_problem/input_data/expected_results/results_report.md` | Position hex, flag widths, group widths, speed bound, publish counts | FT-P-01 through FT-P-09, FT-N-01 through FT-N-04, NFT-PERF-01 |

## Expected Results Mapping

| Test Scenario ID | Input Data | Expected Result | Comparison Method | Tolerance | Expected Result Source |
|-----------------|------------|-----------------|-------------------|-----------|----------------------|
| FT-P-01 | position values | hex `4001000065cd1d00a3e1110100`, length 13 | exact | N/A | results_report.md position row 1 |
| FT-P-02 | that hex | five fields as named, motion field count 0 | exact | N/A | results_report.md position row 2 |
| FT-P-03 | position packed twice | byte mismatch count 0 | exact | N/A | results_report.md position row 3 |
| FT-P-04 | flags 0x00 and 0x20 | 0 extra bytes, then 2 extra bytes | exact | N/A | results_report.md flags rows 1–2 |
| FT-P-05 | optional value 0 | bit set, stored integer 0 | exact | N/A | results_report.md flags row 3 |
| FT-P-06 | conditional group | 0 extra bytes, or extra bytes equal to the group width | exact | N/A | results_report.md groups rows 1–2 |
| FT-P-07 | repeated group on a boundary | one value per complete group | exact | N/A | results_report.md groups row 3 |
| FT-N-01 | buffer ending inside the uint16 | error names field, needed, left; value count 0 | exact | N/A | results_report.md flags row 4 |
| FT-N-02 | 1 leftover byte, or 1 byte after the list | error; value count 0 | exact | N/A | results_report.md groups rows 4–5 |
| FT-P-08 | version tag, both languages, golden match | 2 packages, MIT, manual uploads 0 | exact | N/A | results_report.md publish row 2 |
| FT-P-09 | push or pull request | tests run; a failure fails the check | exact | N/A | results_report.md publish row 1 |
| FT-N-03 | version tag, golden mismatch > 0 | packages published 0 | exact | N/A | results_report.md publish row 3 |
| FT-N-04 | tag whose tree lacks a language | packages published 0 for that registry | exact | N/A | results_report.md publish row 4 |
| NFT-PERF-01 | position, 100000 round trips, one core | elapsed time | threshold_max | ≤ 1 second | results_report.md speed row 1 |
| FT-U-01 | string `zxsanny` | hex `062bfcfee119b2` (compact text, 7 bytes), text `zxsanny` | exact | N/A | AZ-1938 AC-1, CS-7 |
| FT-U-02 | empty string | hex `00` (compact text, 1 byte), text length 0 | exact | N/A | AZ-1938 AC-2, CS-15 |
| FT-U-03 | 65536 bytes of `a` | bytes written 0 | exact | N/A | AZ-1938 AC-3 |
| FT-U-04 | count 7, 2 bytes left | needed 7, left 2, value count 0 | exact | N/A | AZ-1938 AC-4 |
| FT-L-01 | list `[1, 2]` little-endian | hex `020001000200`, list `[1, 2]` | exact | N/A | AZ-1939 AC-1 |
| FT-L-02 | list `[1]` big-endian | hex `01000001` | exact | N/A | AZ-1939 AC-2 |
| FT-L-03 | list `[1]` then byte 2 | hex `01000102`, list `[1]`, next field 2, bytes left 0 | exact | N/A | AZ-1939 AC-3 |
| FT-L-04 | empty list, and 65536 elements | empty hex `0000`; long list writes 0 bytes | exact | N/A | AZ-1939 AC-4 |
| FT-D-01 | user value | 79-byte hex, bytes left 0, six-language mismatch 0 | exact | N/A | AZ-1940 AC-1 |
| FT-D-02 | access keys inserted store, channel, map | mismatch against FT-D-01 is 0 | exact | N/A | AZ-1940 AC-2 |
| FT-D-03 | the 79-byte user hex | username, two roles, three access lists, wrong fields 0, bytes left 0 | exact | N/A | AZ-1940 AC-3 |
| FT-D-04 | empty string, list, and dictionary | hex `010000000000` | exact | N/A | AZ-1940 AC-4 |
| FT-D-05 | one dictionary key twice | value count 0 | exact | N/A | AZ-1940 AC-5 |
| FT-H-01 | six user-value handoffs | wrong fields 0, bytes left 0 | exact | N/A | AZ-1941 AC-1 |
| FT-H-02 | nested map and store | 49-byte hex, wrong fields 0, bytes left 0 | exact | N/A | AZ-1941 AC-2 |
| FT-H-03 | position record in each language | hex `4001000065cd1d00a3e1110100`, mismatch 0 | exact | N/A | AZ-1941 AC-3 |
| FT-C-01 | count 4, values 0, 1, 2, 3, width 2, bias 0 | byte `e4`, four values, count not repeated, six-language mismatch 0 | exact | N/A | 04_borrowed_count AC-1 |
| FT-C-02 | count 9 and eight bits of 1, bias −1; count 1, bias −1 | byte `ff`; 0 bitset bytes | exact | N/A | 04_borrowed_count AC-2 |
| FT-C-03 | count 2, two lat/lon pairs, trailing `u8` 7 | pairs match, trailing byte 7, bytes left 0 | exact | N/A | 04_borrowed_count AC-3 |
| FT-C-04 | route fixture | hex `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101` twice, bytes left 0, schemes 1, mismatch 0 | exact | N/A | 04_borrowed_count AC-4 |
| FT-C-05 | kinds length ≠ count; count 2 and one coordinate byte | pack names the field; unpack names field, needed, and left; value count 0 | exact | N/A | 04_borrowed_count AC-5 |
| FT-X-08 | `flags(bool on)`, `when eq(0, v)`; `v` false, then true with `{on: true, v: 5}` | build fails naming the `when` and field 0; hex `010105`; `{on: false}` packs `0100` | exact | N/A | AZ-2126 AC-1 to AC-3 |
| FT-X-09 | a `when` on float, utf8, bytes, sized, bits, packed; a count on bool, float, counted field | construction fails naming the `when` or the count; the controls build and round-trip | exact | N/A | AZ-2126 AC-1 (owner decision 2026-10-06) |
| FT-X-10 | the five `pack` cases of `cases.txt` | `pack_error` x4 (no bytes), `bytes` `01030102020303`; C++ skips `pack_out_of_range_integer` | exact | N/A | AZ-2194 AC-4 to AC-8; hostile README |
| FT-X-11 | lone dictionary and list of two dictionaries in a `times` and a `repeat` round | error naming `d`; hex `010201000100610100780100010062010079` and `0101000100610100780100010062010079` | exact | N/A | AZ-2308 AC-1 to AC-3 |
| FT-X-12 | Rust map `times`, rows with a lone scalar, one round, lists, a short list | `010201040105`, `0103010401050106`, `010201040104`, `01010104`, `010201040205`; short list names `x` | exact | N/A | AZ-2311 AC-1 to AC-3 |
| FT-X-13 | WA, WE, TA, RA, R2 rows | `010103075a00`, `0100025a00`, `01030107`, `0100025a00`, `01020305065a00`, `0101015a00`, `0101035a000506`; R2 unpack `pt=[5,7] pu=[6,8]` | exact | N/A | AZ-2120 AC-1 to AC-5, flags_member_reference_cases_loop18.md |
| FT-X-14 | four incomplete rows, three old packets, the golden | pack errors naming `extra`, `pt`, `pt`, `pu`; old packets unpack; golden `4001000065cd1d00a3e1110100` | exact | N/A | AZ-2120 AC-6, AZ-2128 AC-2, AC-3 |
| FT-X-15 | C++ flag-byte scope schemes (a), (b), (c) | `SchemeInvalid` naming `b`; `01010007`, `010101030007`, `01010103010507` | exact | N/A | AZ-2304 AC-1 to AC-4 |
| FT-X-16 | three split-bit probes; C++ `{k: 0, b: 6}`, `{k: 1, a: 5, b: 6}` | `010105`, `010209`, `01000109`; `01000106`, `010101010506` | exact | N/A | AZ-2135 AC-1 to AC-3 |
| FT-X-17 | typed members `List<int>` for `u32`, `Stack<int>`, `List<long>` for `u32` | `ArgumentException` naming the member; `List<long>` builds | exact | N/A | AZ-2305 AC-1, AC-2, AC-4 |
| FT-X-18 | nested row with null members, null nested row, filled depth-2 row | `ArgumentException` naming `A`, `M`, `A`; `0100`; `01010406` | exact | N/A | AZ-2306 AC-1 to AC-3 |
| FT-X-19 | `flags{u8 a, u16 b}` list and dict elements; the three ring hex | `010300010100020200`, `0102000100780101010079020200`; rings pass | exact | N/A | AZ-2307 AC-1 to AC-4 |
| FT-X-20 | fractions, out-of-range and wrong-typed slot values; valid values | `ArgumentException` naming the member; `0103`, `010202`, `01020c` | exact | N/A | AZ-2309 AC-1 to AC-4 |
| FT-X-21 | packet `01020001020304` read and packed; random packets; an int for `Bytes` | original bytes; `ArgumentException` naming the member | exact | N/A | AZ-2310 AC-1 to AC-4 |
| FT-X-22 | C# rows with a missing value, short lists, a foreign row type, numbers that do not fit, fractions, bool and string for integers | `ArgumentException` naming the member; golden `4001000065cd1d00a3e1110100`, route `3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101` unchanged; infinities `0000807f`, `000080ff` | exact | N/A | AZ-2088 AC-1 to AC-9, AZ-2191 AC-1 to AC-5 |
| FT-X-23 | `repeat` with 65 535 and 65 536 rounds; `maxRounds` 3 packets `01aabbcc`, `01aabbccdd`, `0103090909`, `010409090909`, `0104090909`, `01ff09`, `01030909`; `maxSlots` 6 packets; 1 MiB packet; hostile `0111223344`, `010411223344` | accepted at the limit; refused when round 4 would start (`needed` 0, `left` 1 or 0); the 1 MiB packet refused at round 65 536 with `left` 983041; invalid limits refused | exact | N/A | AZ-2216 to AZ-2219 AC-1 to AC-11, AZ-2220 AC-1 to AC-7 |
| FT-X-24 | `u32 n; times{u8 x}` with n 65536, 70000, 2e9, 4e9, `u64 n` 4294967299 and 4294967296, lone `x`; n 65535; `maxRounds` 70000 | error naming the first body member and no bytes; 5 + 65535 bytes at the limit; 70000 packs with the raised limit | exact | N/A | AZ-2329 AC-1 to AC-3 |
| FT-X-25 | `u8 a; times(count a){ u8 k, when(k==1){u8 v}, when(v==5){u8 w} }`, a = 2 | `010201050700` in Python and TypeScript | exact | N/A | AZ-2330 AC-1 to AC-3 (spec text: `010201050100`) |
| FT-X-26 | the four `pack_split_*` rows | `pack_error` x3; `0100025a00` for `pack_split_false_condition_silent`; C# probes `0100025a00`, `0102005a00`, `0102c85a00` | exact | N/A | AZ-2331 AC-1 to AC-4 |
| FT-X-27 | `times` with `bytes(2) d`, n = 2, `d` = `0102` alone, then `[0102, 0304]` | error naming `d`; `010201020304` | exact | N/A | AZ-2332 AC-1, AC-2 |
| FT-X-28 | S1 rows `v3 x5 y6 b7`, `v3 x5`, `y6`, `b7`, `v3 y6` | `0103030301050607`, `010001030105`, `01010206`, `01020007`, `010103030006` | exact | N/A | AZ-2333 AC-1, AC-2 (TypeScript run) |
| FT-X-29 | C++ empty group as `when` source, on and off | `010107`, `0100` | exact | N/A | AZ-2334 AC-1 (Rust row, read) |
| FT-X-30 | `times` a = 0 with `x = [5]`, `x = []`, lone `x = 5` | error naming `x`; `0100`; `0100` | exact | N/A | AZ-2335 AC-1, AC-2 |
| FT-X-31 | Python `times` count 3 with a list of 2 | an error naming `x`, no `IndexError` | exact | N/A | AZ-2336 AC-1 |
| FT-X-32 | C# list and dict group elements missing member `A` while the outer row holds `A` | `ArgumentException` naming `'A'`; complete elements unchanged | exact | N/A | AZ-2337 AC-1, AC-2 |
| FT-X-33 | `eq` constants 300, -1, 70000, 200 for i8, 4 and 7 for a u2 slot, `"x"`, NaN, 1.5, `true`; valid 5 and the range edges | construction error naming the `when` and the member; valid values build and keep their bytes | exact | N/A | AZ-2338 AC-1 to AC-4 |
| FT-X-34 | fractions 0.5, 1.5, 2.5, 2.999 and whole floats in `u2`, `bits`, `packed` slots | the per-package table in `batch_01_loop19_report.md` | report | N/A | AZ-2339 AC-1 |
| FT-X-35 | C++ `flags(group(flag_byte(0), flag_bit(0,x)))`, `x = 5` and no value | `01010105`; `0100` | exact | N/A | AZ-2340 AC-1 |
| FT-X-36 | fake venvs: no pytest, usable, failing pytest, not a venv, missing | non-zero with the venv path; pytest called; non-zero; directory kept; venv built | exact | N/A | AZ-2341 AC-1 |
| FT-X-37 | line counts and suite counts before and after the split | each file under 400 lines; C# 844, Rust 479, Java identical | exact | N/A | AZ-2342 AC-1, AC-2 |
| NFT-SEC-03 | packet `01 01 00 ff ff ff ff` and a `List<long>` member for a `u32` list | no exception; value `[4294967295]`; the narrow member cannot be built | exact | N/A | AZ-2305 AC-3 |
| FT-X-83 | the position row, Go typed and map | hex `4001000065cd1d00a3e1110100`, 5 fields, motion fields 0 | exact | N/A | GO-1; `fixtures/golden.hex` |
| FT-X-87 | the 65 hostile cases in Go | allowed outcome each; unpack within 1 s; 0 panics | exact | 1 s per unpack | GO-4; `fixtures/hostile/README.md` |
| FT-X-89 (retired in loop 74, ADR 009) | seed 1..32, value `01` + 15 zero bytes, the AC-1 row | `b55d0a29c56c203712b241232e`, mismatched bytes 0 | exact | N/A | GO-6; C# ciphertext, session AC-1 |
| FT-X-91 | the position row, 100 000 round trips, one core, no `-race` | elapsed time | threshold_max | <= 1 second (160 ms typed, 128 ms map in the compose run) | GO-8; AC-10 |
| FT-X-124 | the position row, Swift typed and map | hex `4001000065cd1d00a3e1110100`, 5 fields, motion fields 0 | exact | N/A | SW-1; `fixtures/golden.hex` |
| FT-X-128 | the 65 hostile cases in Swift | allowed outcome each; unpack within 1 s; 0 traps | exact | 1 s per unpack | SW-4; `fixtures/hostile/README.md` |
| FT-X-130 (session part retired in loop 74, ADR 009) | seed 1..32, value `01` + 15 zero bytes, the AC-1 row | `b55d0a29c56c203712b241232e`, mismatched bytes 0 | exact | N/A | SW-6; C# ciphertext, session AC-1 |
| FT-X-132 | the position row, 100 000 round trips, release build | elapsed time | threshold_max | <= 1 second (0.37 s typed, 0.19 s map in a worker run on the Mac) | SW-8; AC-10 |

## External Dependency Mocks

| External Service | Mock/Stub | How Provided | Behavior |
|-----------------|-----------|-------------|----------|
| npm registry | not called by the byte tests | the publish checks read the workflow result | a mismatch publishes 0 packages |
| NuGet registry | not called by the byte tests | same | same |

## Data Validation Rules

| Data Type | Validation | Invalid Examples | Expected System Behavior |
|-----------|-----------|-----------------|------------------------|
| integer field | value fits the width | a uint16 of 65536 | error, 0 bytes written |
| buffer | length matches the fields that are present | one byte short of a field | error, value count 0 |
