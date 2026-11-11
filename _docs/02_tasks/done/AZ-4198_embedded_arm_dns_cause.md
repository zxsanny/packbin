---
loop: 109
branch: dev
---

# CI: find why the embedded-arm image build could not resolve names on the runner

**Task**: AZ-4198_embedded_arm_dns_cause
**Name**: CI: find why the embedded-arm image build could not resolve names on the runner (loop 109)
**Description**: A manual diagnostic workflow records how the runner's Docker bridge network resolves names and repeats lookups; a findings document names the cause or says "not reproduced"; the host-network workaround of AZ-4191 is kept or replaced from that finding.
**Complexity**: 3 points
**Dependencies**: AZ-4191 (the workaround this task judges)
**Component**: ci (`.github/workflows/`, `cpp/embedded/`)
**Tracker**: AZ-4198
**Epic**: AZ-4133

## Problem

On 2026-11-11 the `embedded-arm` job failed on `Could not resolve 'archive.ubuntu.com'` in `apt-get update` of the image build (runs 43051226349 and 43051232665, commit `61505c9`, jobs started 16:07 to 16:17 UTC) on runner image `ubuntu-26.04` `20261101.186.1`; at 13:10 UTC the same job passed on the same image, and `ubuntu-latest` was `ubuntu-24.04` on 2026-11-01. AZ-4191 built the image on the host network instead and never found why the bridge network could not resolve names. A workaround for an unknown fault cannot be judged, kept or removed.

## Outcome

- The cause is named with a log line, or the findings say "not reproduced" with the evidence read; no guessed cause.
- The workaround stays only for a reason the findings give, or is replaced by a fix at the cause.

## Scope

### Included
- One workflow file `.github/workflows/diagnose-dns.yml`, `workflow_dispatch` only, `permissions: contents: read`, no secrets: prints the host resolver (`/etc/resolv.conf`, `resolvectl status`), the daemon settings (`docker info`, `/etc/docker/daemon.json`, the `bridge` network) and a bridge container's `/etc/resolv.conf`; then for a stated number of minutes (input, default 12) looks up `archive.ubuntu.com` and `security.ubuntu.com` every 5 seconds from the host, from a bridge container, from a host-network container, and once a minute by a `docker build` whose `RUN` does the lookup (the mechanism that failed). One log line per lookup: time stamp, path, name, `ok` or `fail` and the error text. A failed lookup never stops the run.
- Run it by hand on `dev` (and again at a different hour if the first run shows nothing); read the logs with `gh api`.
- `_docs/06_metrics/embedded-arm-dns_2026-11-11.md`: the cause with its log line, or `not reproduced` with every run id read (CI runs 43051226349, 43051232665, 43026701119 and the diagnostic runs) and the minutes covered.
- The decision on the workaround and the comments in `cpp/embedded/run.sh` and `cpp/embedded/Dockerfile` that quote the findings.

### Excluded
- Other Docker builds in CI (read for comparison only); a retry wrapper around the job; a change of runner label; any application source.
- Keeping the diagnostic workflow after the findings is the findings' decision, not a goal.

## Acceptance Criteria

**AC-1: Resolver blocks (project AC-1 of the loop pack)**
Given a manual run of the diagnostic workflow on `dev`
When the job ends
Then its log holds the three blocks `host resolver`, `docker daemon` and `bridge container resolv.conf`.

**AC-2: Lookups over time**
Given the same run with the default window
When the lookup phase ends
Then the log holds at least 60 lookups per path (host, bridge, host-network) over at least 10 minutes, each with `ok` or the error text, and at least 10 `docker build` probes.

**AC-3: Findings are evidence**
Given the findings document
When it names a cause
Then the line that shows it is quoted from a run log with its run id; when it names none it says `not reproduced`, lists every run id read and the minutes covered.

**AC-4: Workaround follows the findings**
Given the findings
When the workaround is kept, the comments in `run.sh` and the `Dockerfile` give the finding as the reason; when it is replaced, the `embedded-arm` job passes on the new path
Then no comment states a cause the findings do not show (0 such comments).

**AC-5: Job green**
Given the final push of the loop
When CI ends on `dev`
Then `embedded-arm` is success and 20 of 20 jobs of `test.yml` are success.

**AC-6: Nothing else touched**
Given the loop's diff
When listed with `git diff --stat`
Then only `.github/`, `cpp/embedded/` and `_docs/` appear; no secret is read or printed by the workflow.

## Unit/Blackbox Tests

| AC | Test |
|----|------|
| AC-1, AC-2 | the dispatched run itself (log read with `gh api`); the structure checks that scan `.github/workflows/*.yml` stay green (pinned `uses:`, permissions) |
| AC-3, AC-4 | smoke script: the findings file exists; every quoted line is found in a saved log; `run.sh` and `Dockerfile` comments contain no cause the findings do not name |
| AC-5 | the `dev` run of the final push |
| AC-6 | smoke script: `git diff --stat` paths |

Project criteria exercised: none changed (no library behaviour). Interaction risks: single component, no new seams.

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| The fault was intermittent (about one hour on one day); the run may not reproduce it | findings say `not reproduced`; never a likely cause | open | Medium |
| The workflow costs about 14 runner minutes per run and sits in the repository | manual trigger only; kept or deleted by the findings | open | Low |
