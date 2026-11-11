---
loop: 109
branch: dev
---
# Loop 109 — why the embedded image build could not resolve names on the runner

Loop: 109 (on `dev`, no worktree). Owner choice 2026-11-11 for the empty hopper: "Embedded-arm DNS cause" (retro 108 action 3, open since loop 106). Source: `_docs/loops/loop106/record106.md`, `_docs/loops/loop108/record108.md`, `_docs/06_metrics/retro_2026-11-11_loop108.md`.

## What

On 2026-11-11 the `embedded-arm` job failed on `Could not resolve 'archive.ubuntu.com'` inside `apt-get update` of the image build (`cpp/embedded/Dockerfile`, step `#7`): every attempt of run 43051226349 and run 43051232665 (commit `61505c9`, jobs started 16:07 to 16:17 UTC). The Dockerfile had not changed; the same job passed at 13:10 UTC (run 43026701119, commit `4e9110a`) on the **same** runner image (`ubuntu-26.04`, version `20261101.186.1`), and passed on 2026-11-01 on `ubuntu-24.04` (`20261025.353.1`). Loop 106 went around it (`docker buildx build --allow network.host --network host`, apt retries) and never found why the build's bridge network could not resolve names. So the cause is unknown, and the host-network build is a workaround of an unknown fault.

Evidence read in this loop (CI logs through `gh api`): the failing and passing jobs show the same runner image; `ubuntu-latest` moved from 24.04 to 26.04 between 2026-11-01 and 2026-11-11; the bridge build resolved names fine at 13:10 UTC and failed at 16:07 to 16:17 UTC; the two ESP jobs of the same run passed.

## Who

The package owner (reads CI) and the next agent session that sees a name-lookup failure on a runner.

## In scope

- A diagnostic workflow `workflow_dispatch` (own file, no secrets) that records, on `ubuntu-latest`, what the Docker bridge network uses for names: the host resolver (`/etc/resolv.conf`, `resolvectl status`), the daemon's settings (`docker info`, `/etc/docker/daemon.json`), and a container's `/etc/resolv.conf`; and repeats name lookups of `archive.ubuntu.com` and `security.ubuntu.com` from a bridge container, from a host-network container and from the host, over a stated time window.
- A findings document `_docs/06_metrics/embedded-arm-dns_2026-11-11.md` that names the cause with the log line that shows it, or says it was not reproduced, with the runs read and the window covered.
- The decision on the workaround, taken from the findings: keep `--network host` (reason named) or fix at the cause; the comment in `cpp/embedded/run.sh` and `Dockerfile` states the finding, not a guess.

## Out of scope

- Other Docker builds in CI (ESP, swift, rust compose services): they are only read for comparison.
- A retry wrapper around the whole job.
- Changing the runner label (`ubuntu-latest` stays).

## Code sections / UI locations for this loop

Owner's words (loop 106 and the loop 109 choice): the `embedded-arm` job and its image build on the CI runner. Code: the `embedded-arm` job of `.github/workflows/test.yml` (step "C++ embedded arm targets"), `cpp/embedded/run.sh` (the `docker buildx build` line, about line 133), `cpp/embedded/Dockerfile` (the apt retry lines). New: one diagnostic workflow under `.github/workflows/`. No application source, no UI.

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| The fault was intermittent (about one hour on one day); a diagnostic run may not reproduce it | the findings must then say "not reproduced", never name a likely cause | open | Medium |
| A diagnostic workflow costs runner minutes and sits in the repository | one file, manual trigger only, deleted or kept per the findings | open | Low |
