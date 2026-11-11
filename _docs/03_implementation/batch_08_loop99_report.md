# Batch 8 report — loop 99 (Dart package): review, audit and assessment fixes

Task: AZ-4149 dart_review_fixes (5). Sources: the total review (slices A, B, C), the full security audit (`security_report_loop99.md`), the feature assessment round 1 (`assessment99.md`, CLARIFY answered by the owner: accept all recommended).

| item | result |
|------|--------|
| R1 High (review A) | a Field object used in two places of one scheme corrupted slot numbering (RangeError out of pack/unpack): every occurrence is its own node; 17 tests, fail before the fix, TypeScript hex equal |
| R2 Medium (audit D1) | dict with keys sharing one string hash: 20.2 s to 130 ms for 65,535 keys; result is a `SplayTreeMap` ordered by UTF-8 bytes; pack reads values from the entries (parent fix, test added) |
| R3 | a flat key naming a member of a nested row is refused (owner decision 17) |
| R4 | dead code deleted (`fieldOf`, `valueFieldOf`, `planOf`, `FlagTag.name`, `FrameDirections.contains`, `flagBits` export) |
| R5 | `dart/.pubignore`, `platforms:` (no web); dry run 0 errors 0 warnings, 62 KB |
| R7 High (review C) | `report-row.test.sh` lists dart |
| R8 High (review C) | the pub.dev token is minted inside `publish-pubdev.sh` right before the upload, 30 s expiry guard; `setup-dart` step stays for the SDK |
| R9 | `pubdev` is optional: no OIDC permission or no package on pub.dev skips it with a warning naming the owner steps |
| R10 | the other upload tools do not see `PUB_TOKEN`; the pubdev upload sees only its own token (tests check the stub environments; 7 mutants killed) |
| R11 | the local publish-gate stage covers the Dart package files |
| R12 | stale text; compose file in the scaffold list; `PACKBIN_DART_STRICT` unchanged (default 0) |
| R13 | ECC contract and README say "usually", with the small-parity numbers (n = 2: 1 in 13; n = 4: 1 in 400; n = 8 and 32: none) |
| R14 | DT-3 amended for list and dict element errors |
| R15 | audit merged into `security_report.md` as F70 to F77 |

Whole Dart suite: 1,919 tests pass; `dart format` 0 changed; `dart analyze --fatal-infos` 0 issues; `report-row.test.sh` and `loop-tests.test.sh` pass. Step 11 follows.

## Discovered during implementation

| finding | handling | clear/unclear |
|---------|----------|---------------|
| the release worker's gate groups `phases`, `phases-rerun`, `readonly` and the standalone dart package checks failed on network or container DNS here (pypi.org, nuget, compote, pub.dev for `lints`) | the step 11 run repeats them | unclear until step 11 |
| `dart pub token add` after `setup-dart`'s early token: does it replace a same-URL entry? | assumed; unproven until the first tag | unclear |
| ADR-011 carries an amendment line (token minted at upload; tier optional) | | clear |
