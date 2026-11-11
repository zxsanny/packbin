---
loop: 99
branch: dev
---

# Dart: total review and assessment fixes (loop 99, round 1)

**Task**: AZ-4149_dart_review_fixes
**Name**: Dart: total review and assessment fixes (loop 99, round 1)
**Description**: Fixes from the loop's total review (3 slices), the security audit and the feature assessment, with the owner's decisions.
**Complexity**: 5 points
**Dependencies**: AZ-4134 to AZ-4148
**Component**: dart
**Tracker**: AZ-4149
**Epic**: AZ-4133

## Problem

The total review found two High defects and the audit one Medium; the assessment left product questions that the owner answered on 2026-11-11 ("accept all recommended"). Reports: `_docs/loops/loop99/assessment99.md`, `_docs/05_security/security_report_loop99.md`; review findings are listed below.

## Outcome

- No scheme built from shared Field objects can raise an exception out of pack or unpack.
- A hostile dictionary cannot make unpack quadratic.
- The release run cannot fail late for a token that expired, and does not block the other eight languages before the first Dart publish.
- Every list of languages that must name nine names Dart.

## Scope

### Included

Dart library and tests:
- **R1 (High, review A)** A Field object used in two places of one scheme (for example a member list reused in two `nested` rows, or the same `u8` at top level and inside a `nested`) keeps one identity, so slot numbering is overwritten: `pack` and `unpack` throw `RangeError`, or `scheme()` throws a null-check error. Every occurrence becomes its own node before slots are numbered. Tests: shared member lists in two lists; a shared `sized` in two nested rows; a shared `u8` at top level and in a nested `when`; pack and unpack equal TypeScript's bytes (`0101000109010002 0708` for the review's first scheme).
- **R2 (Medium, security D1)** A `dict` unpacked with 65,536 keys that share one string hash takes about 20 s (2.77 MB packet). The result map must not hash the keys. Add a hostile test with colliding keys (an unpack of such a packet stays under 1 s) and keep key order and map equality for callers.
- **R3 (owner decision 17)** A flat key that names a member of a nested row is refused, naming the member, as for the anchored group (Go-4) and TypeScript. Update `parity_differences.md` row 17 and its tests.
- **R4** Delete dead code: `fieldOf`, `valueFieldOf` (`fields.dart`), `planOf` if unused (`scheme.dart`), `FlagTag.name` if never read, `FrameDirections.contains` (frame_types.dart; no use, no TypeScript counterpart), and the public export of `flagBits` in `packbin.dart` unless a test needs it.
- **R5** `dart/.pubignore` (no `test/`, `tool/`; keep `example/`), and `platforms:` in `dart/pubspec.yaml` (android, ios, linux, macos, windows; no web). The dry run still reports 0 warnings.
- **R6** One sentence in `parity_differences.md` row 13: in a typed row a group whose only members sit under a false `when` is off (the map form with the group map given is on, as TypeScript).

Release and CI:
- **R7 (High, review C)** `.github/workflows/report-row.test.sh`: `dart` in `langs`, the comment says nine.
- **R8 (High, review C; owner decision 20)** The pub.dev token is minted inside `publish-pubdev.sh` right before `dart pub publish` (ID token from `ACTIONS_ID_TOKEN_REQUEST_URL` with audience `https://pub.dev`, then `dart pub token add https://pub.dev --env-var PUB_TOKEN`, as `setup-dart` does; model the request on `pypi_oidc_token`); the early `setup-dart` token is no longer relied on (keep the step only if the SDK still needs it; `PUB_TOKEN` is no longer a plan credential). The expiry guard stays.
- **R9 (owner decision 11)** `pubdev` tier `optional`: with no token or no package on pub.dev the target is skipped with a warning and the other targets are unchanged; a failed upload of a present target still fails the run. ADR-011, `packages.md`, `deployment_procedures.md` and the owner steps follow.
- **R10 (security D3)** `PUB_TOKEN` is not visible to the other upload tools, and the pubdev upload does not see the other registries' secrets (`unset_credentials`, as `publish-swift.sh`).
- **R11 (review C 3)** `scripts/loop-tests.sh` `covers`/`changes_package_files`: a change to `dart/pubspec.yaml`, `dart/LICENSE`, `dart/CHANGELOG.md`, `dart/README.md`, `dart/.pubignore` or `dart/example/*` selects `publish-gate`; update the test row.
- **R12 (review C 6)** Stale text: `publish-jobs-layout.py:221-222` comment and the no-op line, `publish-swift-gate.test.sh:43` "other seven", `docker-compose.publish-dart.yml` in the `scaffold` required-file list of `test.yml`.

Docs:
- **R13** `message-ecc.md`: the sentence that says an error is returned "and never a wrong row" says "usually" and states the small-parity risk (n = 2 with 2 errors accepts a wrong message in about 1 of 13 runs; n = 4 with 3 errors 1 of 400; n = 8 and above none seen). No version bump.
- **R14 (owner decision 16)** `acceptance_criteria.md` DT-3: list and dict element and key errors name the list and the index or key (a list has no field id).
- **R15** Merge the audit's findings D1 to D8 into `_docs/05_security/security_report.md` with F-numbers (next free) after the fixes.

### Excluded

Owner decisions kept as built (assessment D1 to D10, D12, D13, D15, D18, D19, D21 to D23): lone surrogate refused, `short_packet` kind, helper names, `eq(u64,-1)`, `eq` BigInt and 5.0, zero rounds, `tooLong`, `bad_value` for dictionary keys and text, `Uint8List` for bits and packed, empty `nested`, strict default 0, ring cache, memory, decode table, crypto constants, int wrapper, binding choices, checker. The OIDC token lifetime and pub.dev's answer to a re-publish stay unproven until the first tag.

## Acceptance Criteria

**AC-1: Shared fields**
Given a scheme whose member list or Field object is used in two lists, two nested rows, or at top level and in a nested row
When it is built, packed and unpacked
Then no exception is thrown by pack or unpack, and the bytes equal TypeScript's for the same scheme.

**AC-2: Colliding dictionary keys**
Given a packet with 65,536 dictionary keys that share one string hash
When unpacked
Then the call returns within 1 second and the keys are in order.

**AC-3: Flat key of a nested row**
Given a map row with a flat key that names a member of a nested row whose map is not given
When packed
Then pack throws a refusal naming the member.

**AC-4: Release token**
Given a tag run with Dart present
When the pub.dev target uploads
Then the token is minted inside the upload step, an expired token is refused with "run the tag again", and a run without a token or without the package on pub.dev skips pubdev with a warning and publishes the other targets.

**AC-5: Nine names**
Given the report-row test and the loop-tests publish-gate stage
When a Dart package file changes or the suites matrix lists dart
Then the test passes and the publish-gate stage is selected.

**AC-6: Pub package**
Given the prepared Dart package
When `dart pub publish --dry-run` runs
Then 0 errors and 0 warnings, the archive holds no `test/` or `tool/`, and `platforms` lists no web.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the three shared-field schemes of the review | no exception; TypeScript's bytes |
| AC-2 | colliding keys packet | under 1 s; ordered keys |
| AC-3 | flat key given for a nested member | refusal naming it |
| AC-4 | publish-pubdev stubs: expired token, no token, no package | refused, skipped, skipped |
| AC-5 | report-row test, loop-tests test rows | pass |
| AC-6 | dry run on a prepared copy | 0 warnings, no test/ or tool/ |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1 to AC-6 | the repository at HEAD | the Dart suite, `scripts/loop-tests.sh --only dart,scaffold,publish-gate` | pass | Reliability |

## Constraints

- No file over 500 lines; a built scheme stays immutable and isolate-safe.
- No real upload and no tag.

## Risks & Mitigation

**Risk 1: fixing R1 changes node identity used by references**
- *Risk*: references resolve through identity-keyed maps at build time.
- *Mitigation*: copy nodes before numbering; the whole Dart suite (1,887) and the parity tables (957) must stay green.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| OIDC token lifetime and pub.dev's answer to a re-publish unproven | first tag | accepted-risk | Medium |
