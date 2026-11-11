# Batch 1 report — loop 99 (Dart package)

Tasks: AZ-4134 dart_core (5), AZ-4137 dart_text (3), AZ-4141 dart_crypto (3), AZ-4142 dart_frame (5). 16 points.

| task | result | tests |
|------|--------|-------|
| AZ-4134 | done | 103 (golden, README scalars, short buffers at every cut, null vs 0, invalid values, u64 boundaries, 4 isolates x 10,000, purity); compiled speed 45 ms for 100,000 round trips (bound 1000), 0.37 ms for 1,000 frame unpacks (bound 10) |
| AZ-4137 | done | 19 (418 shared text rows: enc 346, alt 10, bad 32, flip 26, ref 4); `check-emitted.sh` 9 of 9 |
| AZ-4141 | done | 62 (27 of 27 shared crypto rows) |
| AZ-4142 | done | 77 (157 of 157 shared frame rows: keys 20, seal 35, open 57, mac 42, replay 3) |

Whole Dart suite: 261 tests pass; `dart format` 0 changed; `dart analyze --fatal-infos` 0 issues. CI-parity: PASS (the same three commands the Dart suite will run; the container suite arrives with AZ-4145). Review: one total review at the end of the loop (owner rule).

## Discovered during implementation

| spec ref | finding | handling | clear/unclear |
|----------|---------|----------|---------------|
| AZ-4137 AC-3 | TypeScript writes U+FFFD for a lone surrogate; it does not throw (spec was wrong). Go refuses. | Dart refuses (throws `TextEncodeException`); one-line switch to U+FFFD | unclear: owner |
| AZ-4137 | Decode table 4 x 65,536 Uint16 (about 512 KB per isolate, built on first use), TypeScript's shape | kept; Swift's small tables can replace it | unclear: phone memory, revisit at speed task |
| AZ-4137 | `ref` rows are ring packets; walker not there yet | hand-walked in the test; AZ-4138 adds the real scheme rows | clear |
| AZ-4137 | `dart:convert` `utf8.decode` drops a leading U+FEFF | own strict UTF-8 reader | clear |
| AZ-4141 AC-2/AC-3 | no all-ones-key, counter 2^32-1 or empty-HMAC rows in `vectors.txt` | covered by constants cross-checked with OpenSSL and Python; adding rows would change what the other eight assert | unclear: owner |
| AZ-4142 | contract has a short-packet result; 7th refusal kind `shortPacket`, term `short_packet` | added | unclear: term |
| AZ-4142 | direction is an `int` extension type, not an enum | out-of-range gives `bad_value` as TypeScript | unclear: design |
| AZ-4142 | counters and replay window use `BigInt` (unsigned 64-bit) | as TypeScript's bigint rule | clear |
| AZ-4134 | `bool` helper named `flagBool` (a top-level `bool` shadows dart:core) | README spelling line must say it | unclear: name |
| AZ-4134 | two scheme makers: `scheme` (map rows) and `rowScheme` (typed rows); `bind<Row>` needs the row type written | Dart cannot infer it | unclear: naming |
| AZ-4134 | a map scheme ignores bindings | AZ-4135 may adopt Swift's all-or-none rule | unclear |
| AZ-4134 | `eq` on an integer with a whole `5.0` is refused | parity row for AZ-4144 | unclear |
| AZ-4134 | `bytes` accepts only an exact-size `Uint8List` | a `List<int>` could be allowed later | unclear |
| AZ-4137/4134 | the top-level `utf8` helper will clash with `dart:convert`'s `utf8` | decide at AZ-4138 | unclear |

Commit: see git log.
