# Autodev loop record - loop 99

loop: 99
branch: dev
plan_artifact: _docs/loops/loop99/plan99.md
tasks_shipped: [AZ-4134_dart_core, AZ-4135_dart_scheme_checks, AZ-4136_dart_rounds, AZ-4137_dart_text, AZ-4138_dart_collections, AZ-4139_dart_limits, AZ-4140_dart_ecc, AZ-4141_dart_crypto, AZ-4142_dart_frame, AZ-4143_dart_hostile_vectors, AZ-4144_dart_parity_rows, AZ-4145_dart_ci_suite, AZ-4146_dart_ring, AZ-4147_dart_release, AZ-4148_dart_docs, AZ-4149_dart_review_fixes]
decisions:
  - owner (2026-11-10): a ninth package, Dart, in `dart/`; full parity in one loop; pub.dev as `packbin`; Dart 3.13 and newer; native targets only (no web); the autodev state file tracked again
  - agent defaults A-1 to A-7 (`problem.md`): TypeScript is the reference; unpack returns error values and never throws; `u64` is a Dart `int`; no dependency; typed rows by closures plus maps; the suite shares the Go CI job (20 jobs); the version comes from the tag
  - owner (2026-11-11): the mix of a count and a percentage is refused when declared (`withParitySettings`); no character limit in packbin (the mesh app keeps its own 200-character rule); accept all recommended answers to the 23 assessment questions (pubdev optional until the first publish, a flat key of a nested row refused, the token minted at upload, `.pubignore` and `platforms`, DT-3 amended); restart Docker Desktop (done by the agent; the 18 containers started again)
  - parent (2026-11-11): a count with no value or a negative count is `bad_value` in Dart (an item or round that reads no byte stays `short`); a wall-time assertion in a test replaced by a count of keyed reads
measurements:
  - Dart: 1,919 tests in about 6 s (1.2 GB peak); `dart/lib` 7,040 lines, 40 files, largest 419; compiled speed 100,000 round trips in 48 ms (bound 1,000), 1,000 frame unpacks in 0.36 ms (bound 10)
  - shared fixtures, 0 changed, all pass: text 418 rows, crypto 27, frame 157, ECC 1,328 + 1,044, hostile 75 (15 unpack, 2 limit, 15 construct, 43 pack, 0 not run); 957 TypeScript parity rows; 11 + about 60 recorded differences with tests
  - rings, nine languages on the Mac: ECC 81 pairs 66,825 rows, frame 81 pairs, 0 mismatches; frame driver malformed lines 382 checks
  - seeded unpack run 10 s: 1.5 million unpack calls, 0 failures, slowest 8.3 ms
  - step 11: 15 stages passed (typescript, csharp, python, java, go, cpp, rust, swift, dart, scaffold, cpp-embedded-arm, rust-embedded, ring, ac10, publish-gate in 8 shares); `test.yml` 20 jobs
review: "total review 3 slices (A walker: 1 High fixed; B codecs: PASS; C CI/ring/publish: 2 High fixed) + full security audit (Medium 1, Low 7: F70 to F77 in `security_report.md`) + feature assessment round 1 CLARIFY answered by the owner, COMPLETE after AZ-4149 (`assessment99.md`)"
retro: _docs/06_metrics/retro_2026-11-11_loop99.md (next retro due by loop 104)
leftovers:
  - owner (before the first tag that contains `dart/`; until then pubdev is skipped with a warning and the other 8 languages publish): publish a first version by hand with `dart pub publish` from your pub.dev account (the final README, CHANGELOG and example exist), then enable automated publishing for `zxsanny/packbin` on the package's Admin tab with tag pattern `v{{version}}`; do not require a GitHub environment there. After it, edit the two README lines that say Dart is installed from the repository until the first publish (`README.md` and `dart/README.md`).
  - not run here: the vcpkg supports and consumer checks (no vcpkg tool); a physical board; the first CI run of everything Dart (the 20-job `test.yml`, the 60 s seeded run, the ring and gate on Linux, the container memory of `max_slots_test.dart` about 815 MB, the Dart driver cache value); OIDC token lifetime and pub.dev's answer to a re-publish and to `dart pub token add` after `setup-dart` (unproven until the first tag)
  - open owner questions kept as built: a lone surrogate in text is refused (TypeScript writes U+FFFD); `short_packet` as a seventh frame refusal; names `flagBool`, `groupOf`, `utf8Field`, `nested`, `rowScheme`, `bind`; `eq(u64,-1)` builds; zero rounds as empty lists; `tooLong` for an oversized message; `bad_value` for repeated dictionary keys and text refusals; `bits`/`packed` as `Uint8List`; frame direction as an `int` wrapper; `PACKBIN_DART_STRICT` default 0 (a real tag warns when `dart/CHANGELOG.md` lacks the version)
  - Jira: AZ-4133 (epic, open until the first publish) and AZ-4134 to AZ-4149 In Testing
  - from loop 98 (unchanged): U24; vcpkg `supports`; a public-key pairing step; the s390x stage does not compare its percentage packets with the M3 file; root-owned folders under `cpp/build/embedded/rust-m33f` and `rust-mutants`
smoke: PASS (agent run, owner rule 2026-10-12: 11/11 steps passed at ab9774c; checks in smoke99.md)
smoke_artifact: _docs/loops/loop99/smoke99.md
assessment_artifact: _docs/loops/loop99/assessment99.md
loop_end_merge: main
