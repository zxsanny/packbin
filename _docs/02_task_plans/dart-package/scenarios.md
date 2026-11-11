# Scenarios — dart-package

Source of rows: `intake` (new-task Step 4.7, epic handoff). Status: confirmed / out-of-scope / deferred. AC refs are the feature ACs in `acceptance_criteria.md` with the owning task AC.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | A Flutter app packs a row and a server (any ring language) unpacks it | confirmed | the bytes equal the other languages'; the consumer gets the same row | DT-1, DT-7 (AZ-4146 AC-1) | intake |
| S2 | The phone unpacks a hostile or truncated frame from the socket | confirmed | an error value naming the field, needed and left; no row; no exception; ≤ 1 s | DT-2, DT-4 (AZ-4134 AC-3, AZ-4143 AC-1) | intake |
| S3 | A first byte that names no scheme arrives | confirmed | the result carries `unknown_type` with the byte; no exception | DT-2 (AZ-4134 AC-3) | intake |
| S4 | The same scheme is used from the UI isolate and the duty service's background isolate | confirmed | safe: the scheme is immutable; 0 mismatches; a frame session is one isolate at a time | DT-14 (AZ-4134 AC-6) | intake |
| S5 | Pack fails halfway (third field out of range), or a getter returns a wrong type | confirmed | a thrown error naming the field; no bytes, no partial output | DT-15 (AZ-4134 AC-5) | intake |
| S6 | Rows at the limits (65,535 rounds, 1,048,576 slots, 16 MiB) and one past | confirmed | at the limit packs and unpacks; one past is refused as in TypeScript; no silent wrap of a 64-bit count | DT-5, DT-16 (AZ-4139 AC-1) | intake |
| S7 | A `u64` field holds a value above 2^63 - 1 | confirmed | read as a negative `int` with the same 64 bits; packs back to the same bytes | DT-16 (AZ-4134 AC-7) | intake |
| S8 | The same values given as a typed row and as a map | confirmed | the same bytes; `null` = no value, empty list = 0 items; nested-row group read from the nested map | DT-12 (AZ-4138 AC-3) | intake |
| S9 | A message with parity arrives with flipped bytes | confirmed | up to the repair limit it is repaired and the count returned; past it `uncorrectable`; with limit 0 any damage is `uncorrectable` | DT-18 (AZ-4140 AC-2) | intake |
| S10 | A sealed frame is replayed, or arrives after `close()` | confirmed | `duplicate` or `too_old` from the caller's replay window; after close a refusal and zeroed keys | DT-6 (AZ-4142 AC-3) | intake |
| S11 | A new app adds `packbin: ^X.Y.Z` to `pubspec.yaml` | confirmed | resolves from pub.dev with 0 runtime dependencies on Dart 3.13 and newer; proven in this loop by the dry run and a path-dependency consumer | DT-10, DT-11 (AZ-4147 AC-2) | intake |
| S12 | The release run starts for a tag whose Dart golden check fails, or re-runs for a version pub.dev already has | confirmed | a failed golden check publishes 0 packages; a version already on pub.dev is reported as already published and the run does not fail on it | DT-10 (AZ-4147 AC-1, AC-3) | intake |
| S13 | Someone compiles an app that uses the package for the web | out-of-scope | — | — | intake |
| D1 | Text with a lone surrogate: TypeScript writes U+FFFD, Dart throws | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-17 (AZ-4137 AC-3) | assess-round-1 |
| D2 | Frame refusal term `short_packet` (a seventh kind beyond the six in DT-6) | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-6 (AZ-4142) | assess-round-1 |
| D3 | Dart helper names: `flagBool`, `groupOf`, `utf8Field`, `nested`/`nestedRow`, `scheme` vs `rowScheme`, `bind<Row>` | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-2 (AZ-4134, AZ-4135, AZ-4138) | assess-round-1 |
| D4 | `eq(u64, -1)` builds and equals 2^64 - 1 | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-16 (AZ-4135) | assess-round-1 |
| D5 | `eq` with a `BigInt` or a whole `5.0` is refused | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-3 (AZ-4135) | assess-round-1 |
| D6 | Zero rounds unpack to empty lists; TypeScript leaves the key out | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-12 (AZ-4136) | assess-round-1 |
| D7 | Pack refusal of a message too long for its parity has kind `tooLong` | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-18 (AZ-4140) | assess-round-1 |
| D8 | `bad_value` for repeated or unordered dictionary keys and refused text | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-4 (AZ-4138) | assess-round-1 |
| D9 | `bits` and `packed` unpack as `Uint8List` | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-2 (AZ-4136) | assess-round-1 |
| D10 | An empty `nested` row is refused | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-3 (AZ-4138) | assess-round-1 |
| D11 | Required `pubdev` target blocks the other eight languages until the owner's first publish; README lines say "once the first version is published" | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-10 (AZ-4147) | assess-round-1 |
| D12 | `PACKBIN_DART_STRICT` defaults to 0, so dry-run warnings do not stop a tag | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-10 (AZ-4147) | assess-round-1 |
| D13 | Dart driver build cache in the ring may save nothing | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-7 (AZ-4146) | assess-round-1 |
| D14 | pub.dev archive ships `test/` and `tool/`; no `.pubignore`; `public_member_api_docs` off | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-10 (AZ-4147, AZ-4148) | assess-round-1 |
| D15 | CI container memory for `max_slots_test.dart` (about 815 MB peak) | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-5 (AZ-4144) | assess-round-1 |
| D16 | List and dictionary element errors carry no field id | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-3, DT-15 (AZ-4138) | assess-round-1 |
| D17 | A flat key naming a member of a nested row is ignored; TypeScript refuses | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-3 (AZ-4144) | assess-round-1 |
| D18 | Text decode table of about 512 KB per isolate on a phone | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-17 (AZ-4137) | assess-round-1 |
| D19 | No all-ones key, counter 2^32 - 1 or empty-HMAC rows in the shared crypto file | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-19 (AZ-4141) | assess-round-1 |
| D20 | pub.dev OIDC token lifetime and re-publish answer unproven until the first tag | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-10 (AZ-4147) | assess-round-1 |
| D21 | Frame direction is an `int` extension type, not an enum | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-6 (AZ-4142) | assess-round-1 |
| D22 | Typed-row choices: map scheme ignores bindings; typed anchored group binds to the row around it; `bytes` takes an exact-size `Uint8List` only | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-2, DT-12 (AZ-4134) | assess-round-1 |
| D23 | `check-cases.sh` checks `Run by` lines for stage `pack` only | decided (owner 2026-11-11, accept all recommended) | see `_docs/loops/loop99/assessment99.md` | DT-4 (AZ-4143) | assess-round-1 |
| D24 | Stale "eight packages" wording in four Python docstrings and `module-layout.md:349` | resolved (loop 99 round 1) | see `_docs/loops/loop99/assessment99.md` | DT-20 (AZ-4148) | assess-round-1 |
| D25 | `parity_differences.md` row 12 says a member-less group mark unpacks as `{}`; code and README say `true` | resolved (loop 99 round 1) | see `_docs/loops/loop99/assessment99.md` | DT-12 (AZ-4135) | assess-round-1 |
| N1 | Dart `int` wraps silently: a size or count from input overflowing | covered (assess-round-1) | see `_docs/loops/loop99/assessment99.md` | DT-5, DT-16 (AZ-4139) | assess-round-1 |
| N2 | Keys are wiped on `close()` only, not at garbage collection | covered (assess-round-1) | see `_docs/loops/loop99/assessment99.md` | DT-6 (AZ-4142) | assess-round-1 |
| N3 | The committed pubspec version is a placeholder; the release writes the tag's version | covered (assess-round-1) | see `_docs/loops/loop99/assessment99.md` | DT-10 (AZ-4147) | assess-round-1 |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | ADR-002 names six registries, ADR-004 and ADR-005 add a Go tag and a Swift check; pub.dev is a seventh registry that only takes a CI upload through GitHub OIDC from a tag-triggered run | A — new ADR-011 "Dart publishes to pub.dev from the version tag"; a `pubdev` target in the required tier; the first version is published by the owner by hand | yes (AZ-4147) |
| 2 | The golden gate is all-or-nothing | A — Dart joins the gate: a Dart mismatch publishes 0 packages | yes (AZ-4147) |
| 3 | Ring kinds run in different language subsets | A — Dart joins each kind's ring both ways with every member | yes (AZ-4146) |
| 4 | Where the eight packages differ, which does Dart copy | A — TypeScript at HEAD with Go-1 to Go-4 as Swift took them; differences go to `parity_differences.md` | yes (AZ-4144) |
| 5 | `check-cases.sh` counts eight names | A — checker, the `Run by` lines and the Dart hostile loader change in one task; whole-word match | yes (AZ-4143) |
| 6 | `test.yml` makes 20 jobs, the free plan's limit | A — the Dart suite shares the Go suites job, and the publish-gate takes Dart into an existing group | yes (AZ-4145, AZ-4147) |
| 7 | The other packages throw or return on unpack by their language's habit; the phone needs a bad frame dropped without an exception | A — unpack returns a result with an error value (as TypeScript, Python and C#); pack and construction throw | yes (AZ-4134) |

## Not walked

- A consumer on a Dart SDK older than 3.13 (the SDK constraint refuses the resolve).
- Two versions of the package in one app (pub resolves one).
