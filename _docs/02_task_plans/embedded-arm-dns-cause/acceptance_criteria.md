# Acceptance criteria — loop 109 (embedded-arm DNS cause)

Project criteria are inherited unchanged (`_docs/00_problem/acceptance_criteria.md`); this loop adds the CI criteria below. No library behaviour changes.

| id | criterion | measure |
|----|-----------|---------|
| AC-1 | One manually started run of the diagnostic workflow on `ubuntu-latest` prints the host resolver config, the daemon DNS settings and a bridge container's `/etc/resolv.conf` | 3 of 3 blocks present in the job log |
| AC-2 | The same run repeats the lookups of `archive.ubuntu.com` and `security.ubuntu.com` from a bridge container, a host-network container and the host | at least 60 lookups per path over at least 10 minutes, each result (ok or the error text) in the log |
| AC-3 | The findings document names the cause with the log line that shows it, or states "not reproduced" with every run id read and the minutes covered | 1 document; 0 sentences naming a cause without a log line |
| AC-4 | The decision on the workaround follows the findings: fixed at the cause, or kept with the reason; the comments in `run.sh` and the `Dockerfile` match the findings | 0 comments that say a cause the findings do not show |
| AC-5 | The `embedded-arm` job is green after the change | the dev run of the final push: 20 of 20 jobs success |
| AC-6 | No application source and no secret is touched | `git diff --stat` of the loop lists only `.github/`, `cpp/embedded/`, `_docs/` |
