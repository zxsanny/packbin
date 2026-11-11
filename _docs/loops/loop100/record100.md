# Autodev loop record - loop 100

loop: 100
branch: dev
plan_artifact: _docs/loops/loop100/plan100.md
tasks_shipped: [AZ-4153_dart_typescript_alignment]
decisions:
  - owner (2026-11-11): the Dart package takes TypeScript's behaviour on five rows left as built in loop 99, before the first pub.dev publish; accept all recommended twice (the row list, then three questions the probes raised)
  - five rows: D1 a lone surrogate is written as U+FFFD (keys ordered after the swap; keys that collide after it refused at pack, Dart's own rule); D7 a clear message above its parity is a `packError` with TypeScript's text; D8 a refused text and a repeated or out-of-order dictionary key are a short packet with `needed` 0; D6 a map row has no key for 0 rounds (a group keeps `{}`, typed rows keep `[]`); D10 an empty `nested` is a presence mark under `flags` or a flag bit and refused elsewhere with TypeScript's words
  - kept as built: D9 `Uint8List` for `bits` and `packed`, the helper names, Go-1, Go-2, Go-4, `eq(u64, -1)`, no `BigInt`, the frame direction type, the member-less `groupOf`, an empty `nestedRow` refused
measurements:
  - Dart: 2,004 tests (1,919 before) in about 7 s; `dart/lib` 12 files changed, about 205 lines; no file above 500 lines; 5 new test files; 25 tests rewritten because they pinned the old behaviour
  - read by running TypeScript and Dart on HEAD: 16 text and key packets of TypeScript equal in Dart byte for byte; 29 fixture text refusals as a field and a key; 15 zero-round places; 3 counts and 4 percentages at and over the parity limit
  - hostile-bytes run over 14 touched scheme shapes: 3,446,774 inputs, 48,254,836 unpack calls, 0 throws; the reviewer's runs: 6,000 differential cases against TypeScript, 798 parity limits, 66,430 strings, about 1.4 million mutated unpacks, 0 mismatches and 0 exceptions
  - step 11: typescript, csharp, python, java, rust, go, cpp, dart, swift passed in the first run (swift 428 s); scaffold (406 s), ring (101 s) and publish-gate (311 s, 8 shares) passed after a rerun with the right host environment (818 s); cpp-embedded-arm, rust-embedded and ac10 unchanged
review: "independent total review (no High or Medium; 3 Low fixed) + diff-scoped full security pass (F78 Low, fixed) + feature assessment round 1 COMPLETE (`assessment100.md`)"
retro: _docs/06_metrics/retro_2026-11-11_loop100.md (next retro due by loop 104)
leftovers:
  - TypeScript (not this loop): `pack` writes an unreadable packet for two dictionary keys that become one after U+FFFD (`{"\ud800": 1, "\udc00": 2}` gives `0102000410efbfbd010410efbfbd02`, and its own unpack refuses it with `needed` 0); Dart refuses these at pack. A fix is a TypeScript change (refuse at pack, as Dart) and a note in `parity_differences.md`.
  - owner (before the first tag that contains `dart/`; unchanged from loop 99): publish a first version by hand with `dart pub publish`, then enable automated publishing for `zxsanny/packbin` with tag pattern `v{{version}}`; afterwards edit the two README lines that say Dart is installed from the repository
  - harness (Low): the empty-nested mark inside a `repeat` round is checked by a scratchpad probe and the shared code path, not by a committed test row (`assessment100.md`); the hostile-bytes run of this loop is a scratchpad program and is not committed
  - not run here: the vcpkg supports and consumer checks (no vcpkg tool; the gate prints NOT RUN); a physical board; OIDC token lifetime and pub.dev's answer to a re-publish (unproven until the first tag)
  - host (recorded in `AGENT_GOTCHAS.md`): a total `loop-tests.sh` run needs Python 3.13, `RUSTUP_TOOLCHAIN=1.98` and `PACKBIN_CXX_SYSROOT`; Python 3.14 and the system Python have no PyYAML, rustup's default is 1.79.0
  - open owner questions of loop 99 kept as built (unchanged): `short_packet` as a seventh frame refusal; names `flagBool`, `groupOf`, `utf8Field`, `nested`, `rowScheme`, `bind`; `eq(u64,-1)` builds; `bits`/`packed` as `Uint8List`; frame direction as an `int` wrapper; `PACKBIN_DART_STRICT` default 0
  - from loop 98 (unchanged): U24; vcpkg `supports`; a public-key pairing step; the s390x stage does not compare its percentage packets with the M3 file; root-owned folders under `cpp/build/embedded/rust-m33f` and `rust-mutants`
  - Jira: AZ-4153 In Testing (epic AZ-4133 still open until the first publish); AZ-4134 to AZ-4149 In Testing from loop 99
smoke: PASS (agent run, owner rule 2026-10-12: 10/10 steps passed at 3d8394b; checks in smoke100.md)
smoke_artifact: _docs/loops/loop100/smoke100.md
assessment_artifact: _docs/loops/loop100/assessment100.md
loop_end_merge: main
