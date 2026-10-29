# Batch Report

**Batch**: 2
**Tasks**: AZ-3383_publish_workflow_python, AZ-3384_ring_wiring_python, AZ-3385_publish_jobs_python (three workers, disjoint files) and, by the parent, the host-only part of AZ-3386 (the `publish-pins` port, the two guards, the docs)
**Date**: 2026-10-29

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-3383_publish_workflow_python | Done | `publish-workflow.test.sh` (241 to 150 lines), new `publish-workflow-structure.py` (361) | scratch harness (the real `--groups workflow` calls two scripts other workers were editing): 43 rejects (31 old + 12 new), real workflows 0 errors; parent re-ran: 0 errors, no `eval`/`exec`/`compile` | None |
| AZ-3384_ring_wiring_python | Done | `ring-wiring.test.sh` (278 to 161), `ring-wiring-swift.test.sh` (425 to 358), new `ring-wiring-check.py` (249), `ring-wiring-swift-check.py` (200) | ring-wiring 1 accepts + 38 rejects; swift 1 accepts + 53 rejects; rows script unchanged and passing; parent re-ran all three: rc 0 | duplicated helpers (about 50 lines) in the two checkers |
| AZ-3385_publish_jobs_python | Done | `publish-jobs.test.sh` (384 to 75), new `publish-jobs-layout.py` (406), `publish-jobs-mutate.py` (67), `publish-jobs-mutants.test.sh` (126) | 115 `layout check rejects` = 110 `mutant` + 5 `gate_mutant`, the HEAD count; 15 s; parent re-ran | the specs said 111; HEAD has 110 `mutant` calls (the grep counted the function definition); specs corrected |
| AZ-3386 (part, parent) | Partial | `publish-pins.test.sh`, new `publish-pins-actions.py`, `publish-pins-install.py`; `_docs/04_deploy/ci_cd_pipeline.md`, `_docs/02_document/module-layout.md`, `_docs/02_document/deployment/ci_cd_pipeline.md` | host-only pins checks in a scratch harness: 13 actions rejects, 5 pins-file rejects, ruby scan clean and its mutation found, install check ok (2 jobs) and its mutation rejected; `harness failures: 0` | the container build part of the pins test (`pins_real_checks`) and `publish-gate.test.sh --groups workflow,pins` are not run yet (CI-parity below) |

## Code Review Verdict: not run

No per-batch code review (owner preference, as in loop 81). The parent read the evaluator of AZ-3383 and re-ran every worker's tests.

## Test Suite

- CI-parity: PASS. `bash scripts/loop-tests.sh --only scaffold --all` (160 s, host without Ruby): PASS. `bash .github/workflows/publish-gate.test.sh --groups workflow,pins,static` (52 s): `publish gate tests passed`; it runs `publish-jobs.test.sh` (115 rejects), `publish-precheck.test.sh`, the structure check, and the pins test with its container build.

- No Ruby on the host: `grep -rniE 'r[u]by' .github scripts` finds nothing (`.sh`, `.yml`, `.py`, `tool-pins.txt`).
- Non-vacuity (workers, on copies): AZ-3383 three flipped or removed rules; AZ-3384 timeouts, `RING_PYTHON`, compose tag, `RING_RUST`, `RING_JDK`, `RING_SWIFT`, cache path, an action pinned to a tag, an `if` on a step; AZ-3385 `if`, no timeout, renamed gate job, a no-op edit (refused as "unchanged"); reader failures exit 2 with the cause in every checker.
- Behaviour differences from the Ruby that the workers reported: see the table below.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The Python `if:` parser is stricter than the Ruby `eval`: a lone `&`, `|`, `=`, `===`, `()`, a chained `==` and adjacent strings are refused (the Ruby accepted `&` and `|` on booleans, and `()`) | AZ-3383 AC-3 | kept stricter; no real workflow uses them | clear (spec: 0 cases that HEAD refuses are accepted; nothing HEAD refused is now accepted) |
| 2 | `needs.x.result` inside a quoted string was substituted by the Ruby; now it stays literal | AZ-3383 AC-2 | kept literal | clear |
| 3 | A non-mapping step or file crashed the Ruby with a trace; now a violation line or exit 1/2 with a message | AZ-3384, AZ-3385 AC-3 | kept | clear |
| 4 | `expect_rejected` / `expect_structure_failure` accept only exit 1 as a refusal; exit 2 (reader failure) fails the script | AZ-3381 AC-3 | kept; a missing PyYAML cannot pass a check vacuously | clear |
| 5 | Messages quote values as Ruby 3.4 `inspect` (`{"k" => v}`) | AZ-3384, AZ-3385 | kept for byte-for-byte messages; only the wording in messages | clear |
| 6 | `publish-jobs.test.sh` mutants run with `exec` on repo-owned Python text (never workflow text) | AZ-3385 | accepted: the snippets are tracked source; the script exits 1 on a no-op, a raised edit or a dump that does not load back equal | clear |
| 7 | The two ring-wiring checkers share about 50 lines of small helpers (`to_s`, `inspect`, `dig`, ...) because a hyphenated file name cannot be imported and the task forbade a new shared file | AZ-3384 | a later loop may move them next to `yaml_get.py`; not now | unclear (a refactor, not a defect) |
| 8 | `PINS_NAMES` check: "the pins test also scans docs"; `_docs/04_deploy/ci_cd_pipeline.md` is the pins section, which now names `pyyaml` | AZ-3386 AC-5 | done in this batch | clear |

## Commit

`[AZ-3383] [AZ-3384] [AZ-3385] Port the workflow, ring and job checks to Python`. Body: one line + `Loop: 82`.

## Next Batch: AZ-3386 (guards verified in CI-parity, then the push and CI result)
