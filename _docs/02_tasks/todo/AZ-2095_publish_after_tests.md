# Publish runs only after the tests pass on the tagged commit

**Task**: AZ-2095_publish_after_tests
**Name**: Publish gated on test.yml
**Description**: A version tag publishes nothing unless every test job (suites, publish-gate tests, embedded) passed on that exact commit in the same run.
**Complexity**: 2 points
**Dependencies**: None (coordinate edits of `test.yml` with AZ-2070_hostile_vectors, whose format check goes into the `scaffold` job)
**Component**: ci-publish
**Tracker**: AZ-2095
**Epic**: AZ-2069

## Problem

`publish.yml` and `test.yml` are independent workflows:

- `.github/workflows/publish.yml:3-6` triggers on `push: tags: v*`. Its only job, `publish` (`:13-49`), runs the position gate (`:17-18`), then credentials (`:19-30`), then `publish-registries.sh` (`:31-44`). It has no `needs:`, no `workflow_call`, and no check of the test result.
- `.github/workflows/test.yml:3-5` triggers on `push` with no filter, so it also runs on the same tag push, in parallel. A red test run does not stop a green publish run.
- The only content check before a registry write is the golden position row (`publish-gate.sh:34-51`). Unit suites, the publish-gate tests (`publish-gate.test.sh`) and the embedded targets (`test.yml:46-57`) are not required.
- The docs say otherwise:
  - `_docs/02_document/deployment/deployment_procedures.md:5` ("Tests are green on the commit");
  - `_docs/04_deploy/deployment_procedures.md:3`;
  - `_docs/02_document/system-flows.md:18,138` ("F3 depends on F1 and F2 passing on that commit");
  - `_docs/02_document/tests/environment.md:73` ("test, before a tag is allowed to publish").
- `publish.yml:8-10` grants `contents: write` and `id-token: write` at workflow level, so every job in that file gets them.

Source: `discovery/scan_ci_docs.md` LF4, change D4; `list-of-changes.md` C11.

## Outcome

- On a `v*` tag, the publish workflow first runs the full test workflow on the tagged commit and starts the publish job only when every test job succeeded.
- The test jobs run with read-only permissions and no registry secrets, even when called from the publish workflow (ADR-002: "The test job … does not hold those secrets").
- A tag push runs the tests once: as part of publish, not twice in parallel.
- Branch pushes and pull requests run `test.yml` exactly as today (AC-11).

## Scope

### Included
- `test.yml`: callable from another workflow (`workflow_call`), keeping its `push` and `pull_request` triggers for branches. The `push` trigger stops firing on tags, so a tag runs the tests only through `publish.yml`.
- `publish.yml`:
  - a job that calls `test.yml` for the tagged commit, with permissions limited to `contents: read` and no secrets passed;
  - the `publish` job `needs:` it;
  - workflow-level permissions reduced to `contents: read`;
  - `contents: write` and `id-token: write` granted only on the `publish` job.
- `publish-gate.test.sh` `static_checks` (`:20-49`) and `workflow_checks` (`:373-379`): check the new structure by parsing the workflow YAML, not by grepping text. Structure to check: test job calls `test.yml`; `publish` needs it; permissions as above; no `secrets: inherit` on the test call.
- Docs: `deployment_procedures.md` (both copies), `system-flows.md` F3 and `tests/environment.md:73` describe the enforced order.

### Excluded
- Making the embedded job faster or cached (D12). The publish run gets longer by the test time (~40 min cold) — see Flagged concerns.
- Build-before-upload (task 27) and re-run/registry policy (task 28).
- Changing what the tests do.

## Acceptance Criteria

**AC-1: Failing tests publish nothing**
Given a `v*` tag on a commit where any test job fails (suites, publish-gate tests or embedded)
When the publish workflow runs
Then the `publish` job is skipped. No gate, credential or registry step runs and no registry receives anything. The workflow concludes `failure`.

**AC-2: Passing tests then publish**
Given a `v*` tag on a commit where every test job passes
When the publish workflow runs
Then the `publish` job starts after the tests and runs the gate, credentials and registries as before.

**AC-3: Test jobs hold no secrets and no write permissions**
Given the test workflow called from `publish.yml`
When its jobs run
Then their token has `contents: read` only, there is no `id-token: write`, and no registry secret is passed (`publish-gate.test.sh:24-29` token-name check still passes).

**AC-4: Tests run once per tag**
Given a `v*` tag push
When GitHub Actions starts workflows
Then `test.yml` does not start on its own for the tag. Only the call from `publish.yml` runs it.

**AC-5: Branches and pull requests unchanged**
Given a push to any branch or a pull request
When workflows start
Then `test.yml` runs with the same jobs as today, and `publish.yml` does not run.

**AC-6: The structure is checked in CI**
Given `publish-gate.test.sh`
When it runs in the `scaffold` job
Then it parses both workflow files and fails if the test call, the `needs:` edge, the permission split or the branch-only push trigger is missing.

## Non-Functional Requirements

**Reliability**
- The publish job cannot start without a successful test run in the same workflow run (graph dependency, not a timestamp or API lookup).

**Performance**
- Tag-to-registry time grows by the test time. No polling loops are added.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-6 | parse `publish.yml`: test job uses `./.github/workflows/test.yml`; `publish.needs` includes it | pass; removing `needs` in a temp copy fails |
| AC-3 | parse permissions: workflow level `contents: read`; test job `contents: read`; only `publish` has `id-token: write` | pass; a temp copy granting `id-token` at workflow level fails |
| AC-4/5 | parse `test.yml`: `workflow_call` present; `push` limited to branches; `pull_request` kept | pass |

The parser must be one already on the runner and locally: Python `json`/`tomllib` cannot read YAML. Pick one of Ruby `yaml` (stdlib Psych), the runner's `python3 -c "import yaml"`, or a pinned `actionlint` + `yq`, after a Complexity Budget Check. Do not add another `grep` structure check (F24 in `components/07_ci_publish.md`).

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-2, AC-4 | first real `v*` tag after merge (`v0.2.0`) | Actions run graph | one workflow run: `test` jobs → `publish`; no separate `test` run for the tag; run URL recorded in the release report | Reliability |
| AC-1 | optional, before `v0.2.0`: if task 27's build-only dry run exists, a `workflow_dispatch` dry run on a branch with a deliberately failing suite | run graph | publish job skipped; no credential step ran | Reliability |

No laptop publish and no throw-away real tag to prove AC-1. If no dry-run path exists yet, AC-1 is proven by the structure checks (AC-6) plus GitHub's documented `needs` semantics, and re-checked on the first real tag.

## Constraints

- Canonical CI path only: a tag push → `publish.yml` on GitHub Actions. No manual or laptop publish, no API-triggered runs to work around a failing test (meta-rule "Re-queue means the canonical trigger").
- Tokens only as CI secrets. Called test jobs get none (`secrets: inherit` is forbidden here).
- ADR-002 stays: one tag = the release; the golden gate stays before any registry write.
- `.github/workflows/*.sh` changes follow `bash.md`.

## Risks & Mitigation

**Risk 1: Called workflow inherits write permissions**
- *Risk*: In a reusable call, the caller's permissions apply. Leaving `id-token: write` at workflow level would give it to test code that runs repository scripts.
- *Mitigation*: Permissions split (AC-3), checked by AC-6.

**Risk 2: Publish duration**
- *Risk*: Cold embedded run (~40 min) plus Maven polling (up to 22.5 min, `publish-registries.sh:264-273`).
- *Mitigation*: Accepted for now; D12 (caching) is the follow-up. Set `timeout-minutes` on jobs so a stuck run ends.

**Risk 3: Tag on a commit never tested on a branch**
- *Mitigation*: That is exactly the case this task covers: tests run on the tagged commit itself.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Publish duration grows by the full test time, including the ~40 min embedded cold run, because D12 (embedded caching / path filter) is not in the bug-fix plan | plan owner | open | Medium |
| A "dry run" path for proving AC-1 without a real tag depends on task 27; until then AC-1 is proven structurally and on the first real tag | task 27 owner | open | Low |
| A YAML parser for the structure check is a tooling choice (Ruby stdlib vs Python yaml vs actionlint). It needs a Complexity Budget Check | implementer / user | open | Low |
