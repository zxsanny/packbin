---
kind: queue-item
order: 500
source: loop105 and loop109 records (CI job `embedded-arm`: "Could not resolve 'archive.ubuntu.com'" inside the image build; AZ-4198 `diagnose-dns` workflow)
origin: operator
depends_on: []
status: blocked
blocked_on: the failure has not come back since loop 106 (the image is built on the host network); the cause can only be read from a failing run
created: 2026-11-12
---
# CI: name the cause of the `embedded-arm` name-lookup failure

## Problem
On 2026-11-11 the Docker image build of `embedded-arm` failed three times on the runner with a name lookup error. Loop 106 moved the build to the host network; loop 109 added the `diagnose-dns` workflow and could not reproduce the failure. The cause is unknown.

## Outcome
The cause is named from the `path=` lines of `diagnose-dns`, and the host-network build is kept or dropped on that evidence.

## Code sections
`.github/workflows/diagnose-dns.yml`, `cpp/embedded/run.sh` (the `docker buildx build --allow network.host` call), `_docs/gotchas/buildkit-host-network-allow.md`.

## Acceptance checks
- When `embedded-arm` fails on a name lookup again: `diagnose-dns` is run at once and its `path=` lines are in the findings (`bridge` and `build` failing with `host-network` ok would be the first evidence).
- The decision on the host-network build cites those lines.

## Needs
A failing run (nothing to provide; the item becomes ready when it happens).

## Constraints
No third compose variant (LESSONS 2026-11-11 [tooling]).
