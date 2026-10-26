---
loop: 74
branch: dev
---

# Docs: frame mode is the only session

**Task**: AZ-3291_docs_stream_removal
**Name**: Contract 3.0.0, README, architecture, components, flows and test docs without the stream session
**Description**: A reader finds frame mode as packbin's one session, under the D1 names, and the removal recorded.
**Complexity**: 5 points
**Dependencies**: AZ-3280_ring_ci_stream_removal, AZ-3281_csharp_stream_removal, AZ-3282_java_stream_removal, AZ-3283_python_stream_removal_crypto, AZ-3284_rust_stream_removal, AZ-3285_swift_stream_removal_and_names, AZ-3286_cpp_stream_removal_crypto, AZ-3287_go_stream_removal_crypto, AZ-3288_typescript_stream_removal_crypto, AZ-3289_rust_frame_names, AZ-3290_java_frame_names
**Component**: documentation (`README.md`, `_docs/`, fixture READMEs)
**Tracker**: AZ-3291
**Epic**: AZ-3199

## Problem

The contract, the README (the "Encrypted session" section, 8 languages, the WebSocket client and server examples), the architecture, the module layout, the eight component descriptions, the flows, the interaction risks and the test docs all describe the stream session; `rust/tests/nostd_docs_tests.rs` requires the word "`session`" in three of them.

## Outcome

- `pack-session.md` 3.0.0: frame mode only, a Change Log row ("stream mode removed, ADR-009; frame text unchanged since 2.0.0"), consumers updated.
- README: 0 stream-session sections; the Frame session intro stands alone; the change history notes the removal and the D1 renames (for meshbell and Android, iOS callers).
- `architecture.md`, `module-layout.md`, `components/0{1..8}_*/description.md`, `tests.md`, `system-flows.md` (Flow F4 retired), `interaction-risks.md`, `risk_mitigations.md`, the test docs (`blackbox-tests-05-sessions.md` and the traceability rows marked retired), `_docs/00_problem/` (`problem.md`, `restrictions.md`, `acceptance_criteria.md` session rows retired), `fixtures/crypto/README.md`, `fixtures/hostile/fuzz/README.md`, `rust/embedded/README.md` if AZ-3284 left it, `message-ecc.md` (its session row).
- `rust/tests/nostd_docs_tests.rs` checks the frame feature text instead of "`session`".

## Scope

### Excluded
- History records (`ripple_log_*`, `epics.md`, loop records and smoke scripts, ADR-007 and ADR-008 bodies: ADRs are immutable; the index note of ADR-009 covers them).

## Acceptance Criteria

**AC-1: No live stream docs**
Given the docs above
When `git grep -nE 'PackSession|stream session|Encrypted session'` runs over them
Then every hit is in a row or line marked retired or in the change history

**AC-2: Contract**
Given `pack-session.md`
When read
Then its version is 3.0.0, it has 0 stream-mode sections, and its frame section is byte-identical to 2.0.0's apart from the D1 type names in examples

**AC-3: Examples run**
Given the README frame examples and `rust/tests/nostd_docs_tests.rs`
When `scripts/frame/readme-examples.sh`, the Swift `ReadmeExampleTests` and the Rust docs test run
Then 0 differences and 0 failures

**AC-4: Components and layout complete**
Given the component descriptions and `module-layout.md`
When each public frame type (D1 names) and each source file deleted or added in AZ-3281 to AZ-3290 is looked up
Then 0 are missing and 0 deleted files are listed

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-1 | the grep, every hit read | only retired or history hits |
| AC-3 | `readme-examples.sh`, Swift README test, Rust docs test | 0 differences, 0 failures |
| AC-4 | name and file lookup | 0 missing |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| meshbell (another repository) must rename `Session` | documented in the README change history, not changed there (workspace boundary) | accepted-risk | Low |
