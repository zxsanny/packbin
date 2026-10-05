# CI runs the cross-language ring on every push

**Task**: AZ-2193_ci_cross_language_ring
**Name**: `language-pair.sh` in CI
**Description**: The test workflow gains one job that installs the six toolchains and runs the cross-language ring (`language-pair.sh`) on every push and pull request, so a package that drifts from the others fails the build instead of waiting for a manual run.
**Complexity**: 3 points
**Dependencies**: AZ-2179_rounds_ring (the rings the job runs)
**Component**: shared harness (`.github/workflows/test.yml`, `.github/workflows/language-pair.sh`)
**Tracker**: AZ-2193
**Epic**: AZ-2069

## Problem

Loop 13 feature assessment (X2), owner scope A on 2026-10-05: not fixed in loop 13, filed as a follow-up.

- `language-pair.sh` packs a row in one language and unpacks it in the next, around all six languages (C#, TypeScript, Python, Rust, Java, C++), for the `user`, `nested`, `boolflag`, `booltrue`, `bitwhen` (no Python) and `session` rings. It then checks that each language packs the golden position bytes. It stops at the first mismatch and prints `<language> pack-<ring> mismatch`.
- Checked in the repository: `test.yml`, `publish.yml` and `docker-compose.test.yml` never call it; outside task specs the only mention is a sentence in the module layout doc. The script is a manual gate.
- What CI does run on every push: the six per-package suites in containers, the hostile case file check, the report column check, the `embedded` job, and the publish gate step, which packs the golden position row in each language and compares it to `fixtures/golden.hex`. So the golden-fixture half of project AC-3 is enforced; the other shared rings are not.
- Project AC-3: "the bytes from all six first-release languages are identical. Mismatched bytes: 0." AC-11: "CI runs the tests on 100% of pushes and pull requests." Drift in `user`, `nested`, the bool rings, `session` and (after AZ-2179) the round rings goes unseen until someone runs the script by hand.
- The script uses the toolchains installed on the host (`dotnet`, `node`, `python3`, `cargo`, `c++`, `javac`/`java`), not the images in `docker-compose.test.yml`. The `embedded` job shows the workflow already runs multi-toolchain jobs.

## Outcome

- Every push and pull request runs the ring; a mismatch fails the check and names the producer language and the ring.
- The toolchains in the job match the versions the per-package suites use.
- Docs say the ring is enforced on every push.

## Scope

### Included
- One job in the test workflow that provisions the six toolchains and runs `language-pair.sh`.
- A static check, in the scaffold job, that the workflow calls the script.
- The one-line doc change that states the ring runs on every push.

### Excluded
- New rings or driver changes (AZ-2179 owns the rounds ring).
- Branch protection settings (the required-check list lives in the repository host's settings, outside the repo).
- Running the ring on tags in `publish.yml` (the publish gate stays as it is).

## Acceptance Criteria

**AC-1: The ring runs on every push and pull request**
Given the test workflow
When a commit is pushed or a pull request is opened or updated
Then a job runs `language-pair.sh`, with no branch or path filter, as its own check.

**AC-2: Green when all languages agree**
Given the current drivers and every ring (`user`, `nested`, `boolflag`, `booltrue`, `bitwhen`, `session`, the golden position `4001000065cd1d00a3e1110100`, plus `roundflags` and `roundwhen` once AZ-2179 lands)
When the job runs
Then it passes and the log ends with `language pairs passed`.

**AC-3: Drift fails and is named**
Given a change that makes one language pack different bytes for a ring (for example the `user` ring, expected `0107007a7873616e6e79...`)
When the job runs
Then it fails with a non-zero exit and the log names the language and ring (for example `csharp pack-user mismatch`); a consumer that cannot read the bytes also fails the job.

**AC-4: Toolchains match the suites**
Given the toolchain versions of the per-package suites (C# SDK 10, Node 24, Python 3.14, Rust 1.98, GCC 16, JDK 26 today)
When the job provisions its toolchains
Then it uses the same versions and logs each version before the ring runs; if a version is not available on the runner, the job fails at provisioning and says which.

**AC-5: Existing jobs are unchanged**
Given the `scaffold` and `embedded` jobs
When the new job is added
Then they run and report as before, and the new job runs in parallel with them.

**AC-6: The static check guards the wiring**
Given the scaffold job
When `test.yml` stops calling `language-pair.sh`, or the job gains a path or branch filter
Then the scaffold job fails.

**AC-7: Docs state it**
Given the module layout doc's CI description
When this task is done
Then it says the cross-language ring runs on every push and pull request.

## Non-Functional Requirements

**Performance**
- Target: under 15 minutes on a hosted runner (a proposal; the first run measures it). Build caches are allowed; they must not change what is compared.

**Reliability**
- The ring is deterministic. A mismatch is never retried away; a failure to provision a toolchain is reported as that, not as a mismatch.

## Unit Tests

| AC Ref | What to Test | Required Outcome |
|--------|-------------|-----------------|
| AC-6 | static check against `test.yml` and corrupted copies (call removed, path filter added) | passes on the real file, fails on both copies |

## Blackbox Tests

| AC Ref | Initial Data/Conditions | What to Test | Expected Behavior | NFR References |
|--------|------------------------|-------------|-------------------|----------------|
| AC-1, AC-2 | branch off `dev`, current drivers | push and open a pull request | the ring job appears and passes | Performance |
| AC-3 | throwaway branch with one expected hex changed, never merged | push | the job fails and names the ring and language | Reliability |
| AC-4 | same run | read the job log | six toolchain versions printed, equal to the suites' | Reliability |
| AC-5 | same run | read the other checks | `scaffold` and `embedded` results unchanged | Performance |

## Constraints

- Land after AZ-2179 so the job runs the full ring set. The script and drivers do not change here.
- ADR-001: no shared walker; the drivers use each package's public API only.
- No secrets in the job; test results do not feed the report columns.

## Risks & Mitigation

**Risk 1: The first CI run shows drift that local runs hid**
- *Risk*: a different compiler (C++ builds with `-Werror`) or runtime version changes a result.
- *Mitigation*: run it on a branch first; pin versions as in AC-4; fix the driver or the package before merging.

**Risk 2: The job is slow**
- *Risk*: the script rebuilds the C#, Rust, C++ and Java drivers on each call.
- *Mitigation*: toolchain and build caches; if the target is missed the owner chooses between a slower check and option B.

**Risk 3: Toolchain downloads fail**
- *Risk*: six installs on one runner raise the chance of an infrastructure failure.
- *Mitigation*: pinned versions and caches; the log separates provisioning from mismatch (AC-4).

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| DECISION: A) a CI job on every push (written above; recommended: catches drift, slower, multi-toolchain jobs already exist) or B) keep the ring a manual release gate and say so in project AC-3 and the docs (AC-1 to AC-6 replaced by one doc change). The owner confirms the option before implementation | owner | open | Medium |
| The assessment says CI runs only "the publish-gate position bytes"; that step is in the scaffold job on every push, so the golden half of AC-3 is already enforced and this task closes the rest | spec corrected | resolved | Low |
| Making the check required (branch protection) is a repository setting outside this change | owner | open | Low |
