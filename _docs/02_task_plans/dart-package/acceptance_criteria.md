# Loop 99 acceptance criteria — Dart package (AZ-4133)

Inherited project criteria stay in force: AC-1 to AC-16 (`_docs/00_problem/acceptance_criteria.md`) and the contracts `compact-text.md`, `message-ecc.md` (1.1.0) and `pack-session.md` (3.0.0). This feature makes Dart the ninth language for each of them.

## Inherited map

| Project AC or contract | Dart criterion |
|------------------------|----------------|
| AC-1, AC-2, AC-3 | DT-1 |
| AC-4 to AC-9 | DT-2, DT-3 |
| AC-10 | DT-8 |
| AC-11 | DT-9 |
| AC-12, AC-14, AC-15, AC-16 | DT-10 |
| Hostile vectors (`fixtures/hostile/`) | DT-4 |
| Limits and work bounds | DT-5 |
| `compact-text.md` | DT-17 |
| `message-ecc.md` 1.1.0 | DT-18 |
| `pack-session.md` 3.0.0 (frame mode) | DT-6, DT-19 |

## Criteria

- **DT-1 Golden bytes.** Dart packs the AC-1 row to `4001000065cd1d00a3e1110100` and unpacks it to the same five fields with 0 motion fields. Mismatched bytes: 0. Field mismatches: 0.
- **DT-2 Data types.** For every data-type example in `README.md` (integers, floats, fixed bytes, big-endian, `utf8`, list, dictionary, flags, bool, when, repeat, sized, two-bit slots, bits, packed, times), Dart packs the README hex and unpacks it back. Mismatched bytes: 0. A short buffer gives an error value naming the field, the bytes needed and the bytes left, with 0 values; 1 or more trailing bytes give an error value with 0 values. Exceptions thrown by unpack on any input: 0.
- **DT-3 Parity rows.** Every parity row the TypeScript suite pins that applies to Dart gives the same hex in Dart, or a refusal where TypeScript refuses. Hex mismatches: 0. Refusal-vs-bytes disagreements not listed in `parity_differences.md`: 0. Every refusal names the field id (and the count where there is one).
- **DT-4 Hostile vectors.** All cases in `fixtures/hostile/cases.txt` (75 today) give an allowed outcome in Dart. Uncaught exceptions: 0. Each `unpack` case returns in ≤ 1 second. `check-cases.sh` counts nine packages in every pack section's `Run by` / `Not run by` lines and passes.
- **DT-5 Limits and the seeded run.** Default limits equal the other packages' (65,535 rounds, 1,048,576 slots, 16,777,216 bytes), on pack and on unpack. A `limit` case with the lowered limit gives `too_many` or `bad_value` with `needed` 0. A raised limit unpacks the old worst packet. A seeded random unpack run over `fixtures/hostile/fuzz/corpus.txt` plus random mutations runs ≥ 60 seconds in CI with 0 uncaught exceptions, 0 unpack calls over 1 second and 0 results above the slot budget.
- **DT-6 Frame mode.** All 157 rows of `fixtures/frame/vectors.txt` (keys, seal, open, mac, replay) pass in Dart. Mismatched bytes: 0. `FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `ReplayWindow`, `Freshness` and `MacKey` exist under those names. Refusals are result values with the kinds `bad_value`, `too_long`, `buffer_full`, `tag_mismatch`, `duplicate`, `too_old`. After `close()` the key bytes read 0 in 100% of the key buffers, and a seal or open after close is refused. A tag compare takes no early exit (checked by reading every byte: a tag wrong in byte 0 and one wrong in the last byte both read the full tag).
- **DT-7 Rings.** For each kind in `language-pair.sh`, Dart joins that kind's existing ring in both directions with every member; for the `-short` kinds Dart refuses with no row. Dart joins the ECC ring (`ring-ecc.sh`) and the frame ring (`ring-frame.sh`) with all `fixtures/ecc/ring-cases.txt` and `fixtures/frame/ring-cases.txt` rows. Dart's position driver prints the golden hex. Failed handoffs: 0. The ring self-tests catch a lying Dart driver (1 fake liar each for the ECC and the frame ring).
- **DT-8 Speed.** 100,000 pack-then-unpack round trips of the AC-1 fixture take ≤ 1 second on one core in CI, in a compiled build (`dart compile exe`). On the Mac, 1,000 unpacks of a 40-byte target frame take ≤ 10 ms in a compiled build (the phone's several hundred frames a second, with a 100 times margin).
- **DT-9 CI.** `test.yml` runs the Dart suite on 100% of pushes and pull requests: `dart format --set-exit-if-changed`, `dart analyze --fatal-infos` with 0 issues, and `dart test`. A failing test fails the check. `docker-compose.test.yml` has a `dart` service that runs `run-suite.sh dart` on the pinned `dart:3.13.x` image. `test.yml` still makes ≤ 20 jobs. `scripts/loop-tests.sh` has a `dart` stage.
- **DT-10 Release.** Dart is in the golden gate: a tag whose Dart golden check fails publishes 0 packages of any language. The release run has a pub.dev target that takes the version from the tag, and `dart pub publish --dry-run` on the prepared package reports 0 errors and 0 warnings. A tree without `dart/pubspec.yaml` skips the Dart target. The package's license is MIT (`dart/LICENSE` equal to the root `LICENSE`). No real publish and no tag in this loop: real uploads 0.
- **DT-11 Dependencies and purity.** `dart/pubspec.yaml` has 0 runtime dependencies; dev dependencies are `test` and `lints` only. Imports of `dart:mirrors`, `dart:ffi` and `dart:io` under `dart/lib/`: 0. The SDK constraint is `^3.13.0`.
- **DT-12 No value.** `null` is no value (its flags bit is clear; a count behind a clear `when` is refused as in the eight); an empty list is a value with 0 items (count 0 written). The map form reads a nested-row group from the nested map. Each of these rows is pinned by at least 1 Dart test.
- **DT-13 README.** The README has a Dart section (install from pub.dev, one pack and unpack example, the rows and errors paragraphs, the data-type spelling line, the ECC and frame table rows). Every Dart example in the README is compiled and run in CI and prints the README hex. Mismatched bytes: 0. `dart/README.md`, `dart/CHANGELOG.md` and `dart/example/` exist (pub.dev shows them).
- **DT-14 Isolates.** A built scheme is immutable and can be used from many isolates: 4 isolates × 10,000 round trips on one scheme (sent to isolates spawned with `Isolate.run`) give 0 mismatches and 0 errors. A `FrameSession` is used by one isolate at a time (documented).
- **DT-15 Invalid Dart values.** A row whose getter returns an out-of-range value, a map value of the wrong Dart type (a `double` for an integer field, a whole `5.0` too; a `String` for a number), or a missing map key for a required field gives a thrown pack error naming the field id, with no bytes returned. Partial output returned: 0 bytes.
- **DT-16 64-bit integers.** A `u64` field packs and unpacks every value from 0 to 2^64 - 1: values above 2^63 - 1 are the same 64 bits as a negative `int`. `0xFFFFFFFFFFFFFFFF` on the wire unpacks to `-1` and packs back to the same 8 bytes. Mismatched bytes over the 6 boundary values (0, 1, 2^63 - 1, 2^63, 2^64 - 2, 2^64 - 1): 0. A `u64` count above the limits is refused, not wrapped.
- **DT-17 Compact text.** Every row of `fixtures/text/vectors.txt` (`enc`, `alt`, `bad`, `ref`, `flip`) gives the expected bytes, text or refusal in Dart. Mismatches: 0. The Dart code tables are emitted from `fixtures/text/tables.json` by `scripts/text/emit_tables.py`, and `check-emitted.sh` passes with Dart in its list.
- **DT-18 Error correction.** Every row of `fixtures/ecc/vectors.txt` and `fixtures/ecc/percent-vectors.txt` passes in Dart. Mismatches: 0. Parity 0 to 32, repair limit 0 to `n/2`, percentage 0 to 100, at most 254 bytes per message with parity; unpack with repair returns the repaired count; a message past repair gives `uncorrectable`; one above 254 bytes gives `too_long`. A parity, limit or percentage out of range is refused when it is set.
- **DT-19 Crypto primitives.** All 27 rows of `fixtures/crypto/vectors.txt` (sha256, hmac256, hkdf256, chacha-block, chacha-xor) pass in Dart. Mismatched bytes: 0.
- **DT-20 Docs name nine.** The documents that list the packages name Dart: `architecture.md`, `module-layout.md` (a `Component: dart` block), `components/09_dart_package/`, `glossary.md`, the three contracts, `fixtures/*/README.md`, `_docs/04_deploy/packages.md`, and ADR-011 (Dart publishes to pub.dev). Places that still say "eight packages" where nine is meant: 0.
