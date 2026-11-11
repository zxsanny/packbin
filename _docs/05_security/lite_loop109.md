# Security lite — loop 109

Diff: `9f7f95e..HEAD` without `_docs/` (10 files, 629 added lines, 0 removed): the manual `diagnose-dns.yml` workflow and two comment lines (AZ-4198), and the C# element-row overloads with their tests and README text (AZ-4199, pushed by the owner's own `/implement` in a side session during this loop).

| Trigger | Hit | Note |
|---|---|---|
| T1 sensitive path | yes | `.github/workflows/diagnose-dns.yml` (new), `cpp/embedded/Dockerfile` (one comment line) |
| T2 sensitive content | no | two grep hits are not triggers: the word "secret" in a comment ("reads no secret"), and `rm -rf "$dir"` on a `mktemp -d` directory, quoted |
| T3 size | no | 3 non-test source files and 1 workflow; about 330 added non-test lines, mostly the workflow and README |
| T4 dependencies | no | no manifest, lockfile or base image tag changed (the `FROM ubuntu:24.04` line is untouched) |
| T5 carried finding | no | `security_report.md` names none of the changed files |
| T6 stale audit | no | not a ship loop |
| T7 lite concern | no | checks below found nothing above Low |

Verdict: ESCALATE by T1, answered with a diff-scoped pass below (as in loop 97). No full audit of the other areas: nothing else changed.

Checks on the changed lines:
- Who can run the workflow: `workflow_dispatch` only, so a user with write access starts it by hand; there is no `pull_request`, `pull_request_target` or schedule, so a fork cannot run it.
- Privileges: `permissions: contents: read`; no `secrets.` reference, no `uses:` (so no unpinned action; `publish-pins.test.sh` passes).
- Injection: the one input, `minutes`, reaches the script as the environment variable `MINUTES`, never as text in the script; it is checked to be digits and 10 to 20 before use.
- Containers: `docker run` without `--privileged`, mounts or the Docker socket; the probe containers run `sleep infinity` and `getent`; the host-network one reads only names; an `always()` step removes both.
- Outbound: DNS lookups of the two Ubuntu mirror names, `apt-get update` against them, and the pull of `ubuntu:24.04` (the tag the `Dockerfile` already uses).
- Secrets and logs: none printed; the log shows the runner's resolver, `docker info` and the bridge network of an ephemeral runner, including its internal DNS search domain (Low, see below).
- Error handling: no empty catch; `set +e` is deliberate and every failure is logged as `result=fail` (a note in the file says why); the `|| echo` fallbacks print the exit code.
- C# (AZ-4199): additive builders only (0 lines removed in `Field.cs`, `Fields.cs`, `FieldAccess.cs`); no reader code changed, no I/O, no `catch`. The element row feeds the existing group and collection readers, which already read an element group through the old `Field.Group(0, ...)` workaround, so no new bound on untrusted input appears. Its own review (batch report): PASS_WITH_WARNINGS, 3 Low, none security.
- Blast radius: `diagnose-dns.yml` is read by nothing; `run.sh` and the `Dockerfile` changed in comments only.

Findings: 0 Critical, 0 High, 0 Medium, 1 Low.
- Low: the diagnostic log prints the runner's internal DNS search domain (`*.internal.cloudapp.net`). It is not a secret and the runner is discarded after the job; remediation: none needed.
