# Task map — dart-package (AZ-4133, loop 99)

Specs in `_docs/02_tasks/todo/` named by their Jira keys (AZ-4134 to AZ-4148, created 2026-11-10 under epic AZ-4133). Shape mirrors the Swift epic (AZ-2513 to AZ-2524) plus compact text, error correction, crypto and frame mode. Total 61 points.

| task file | points | deps | DT criteria owned | scenarios owned |
|---|---|---|---|---|
| AZ-4134_dart_core.md | 5 | none | DT-1, DT-8, DT-11, DT-14, DT-15, DT-16 | S2 (short), S3, S4, S5, S7 |
| AZ-4135_dart_scheme_checks.md | 5 | AZ-4134 | — (DT-2, DT-3 construction rows) | — |
| AZ-4136_dart_rounds.md | 5 | AZ-4135 | DT-2 | — |
| AZ-4137_dart_text.md | 3 | AZ-4134 | DT-17 | — |
| AZ-4138_dart_collections.md | 5 | AZ-4136, AZ-4137 | DT-12 | S8 |
| AZ-4139_dart_limits.md | 3 | AZ-4138 | DT-5 | S6 |
| AZ-4140_dart_ecc.md | 5 | AZ-4136 | DT-18 | S9 |
| AZ-4141_dart_crypto.md | 3 | AZ-4134 | DT-19 | — |
| AZ-4142_dart_frame.md | 5 | AZ-4141 | DT-6 | S10 |
| AZ-4143_dart_hostile_vectors.md | 3 | AZ-4139, AZ-4140 | DT-4 | S2 (hostile) |
| AZ-4144_dart_parity_rows.md | 3 | AZ-4143 | DT-3 | — |
| AZ-4145_dart_ci_suite.md | 3 | AZ-4134 | DT-9 | — |
| AZ-4146_dart_ring.md | 5 | AZ-4138, AZ-4140, AZ-4142, AZ-4145 | DT-7 | S1 |
| AZ-4147_dart_release.md | 5 | AZ-4145, AZ-4146 | DT-10 | S11, S12 |
| AZ-4148_dart_docs.md | 3 | AZ-4144, AZ-4147 | DT-13, DT-20 | — |

Result: DT-1 to DT-20 each have exactly 1 primary owner (20 of 20); S1 to S12 each have exactly 1 primary owner (S2 is split by part: short buffers AZ-4134, hostile cases AZ-4143); S13 is out of scope (AZ-4134 Excluded). Unowned 0.

## Waves

1. AZ-4134 (alone: it creates the package).
2. AZ-4135, AZ-4137, AZ-4141, AZ-4145 (disjoint files).
3. AZ-4136, AZ-4142.
4. AZ-4138, AZ-4140 (the codec files; scheme wiring after AZ-4138 lands if both touch the walker).
5. AZ-4139, AZ-4146.
6. AZ-4143, AZ-4147.
7. AZ-4144, then AZ-4148.

## Write sets

- Walker files of `dart/lib/` and their tests: AZ-4134 → AZ-4135 → AZ-4136 → AZ-4138 → AZ-4139, one worker at a time. `.gitignore` (Dart lines): AZ-4134.
- Standalone modules, each with its own files: text codec `dart/lib/src/text*` + `scripts/text/**` (AZ-4137); crypto `dart/lib/src/crypto*` (AZ-4141); frame `dart/lib/src/frame*`, `mac_key*`, `replay*` (AZ-4142); error correction `dart/lib/src/ecc*` (AZ-4140, which also adds the scheme's parity setting).
- Hostile: `dart/test/hostile*`, `fixtures/hostile/check-cases.sh`, `cases.test.sh`, `fixtures/hostile/README.md` (AZ-4143). Parity tests `dart/test/parity*` and `parity_differences.md` (AZ-4144).
- Shared CI files, disjoint: AZ-4145 (`run-suite.sh`, its tests, `test.yml` suites and scaffold jobs, `docker-compose.test.yml`, `scripts/loop-tests.sh` and its test, `tool-pins.txt`); AZ-4146 (`drivers/handoff-dart/**`, `ring-dart.sh`, `language-pair.sh`, `ring-*.sh` and their tests, `publish-position.sh`, `test.yml` ring job, `scripts/frame/readme-examples.sh`); AZ-4147 (`publish-*` scripts and tests except `publish-position.sh`, `docker-compose.publish.yml`, `test.yml` publish-gate jobs, `publish.yml`, ADR-011 and the ADR index, `_docs/04_deploy/packages.md`); AZ-4148 (`README.md`, `dart/README.md`, `dart/CHANGELOG.md`, `dart/example/**`, `dart/test/readme*`, `_docs/02_document/**` except ADRs, `fixtures/{crypto,ecc,text,frame}/README.md`, `fixtures/hostile/fuzz/README.md`).
- `test.yml` is edited by AZ-4145, then AZ-4146, then AZ-4147, never at the same time.
