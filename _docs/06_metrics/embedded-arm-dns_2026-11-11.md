# Embedded-arm image build: name lookup failure on the runner (AZ-4198, loop 109)

Date: 2026-11-11. Question: why could the bridge network of the `embedded-arm` image build not resolve `archive.ubuntu.com` on the runner (runs of commit `61505c9`, AZ-4191)?

## Verdict

**Not reproduced; the cause is not known.** Two manual runs of `.github/workflows/diagnose-dns.yml` covered 24 minutes and saw no failed lookup on any path. The host-network build of AZ-4191 stays, with that reason.

## What the failing runs show

| run (commit) | job | started (UTC) | line |
|---|---|---|---|
| 43051226349 (`61505c9`, `dev`) | `embedded-arm` 130648051396 | 16:16:49 | `#7 14.56 Err:1 http://archive.ubuntu.com/ubuntu noble InRelease` then `Could not resolve 'archive.ubuntu.com'` |
| 43051232665 (`61505c9`, `main`) | `embedded-arm` 130642783993 | 16:07:58 | the same `Could not resolve 'archive.ubuntu.com'` in step `#7` |

The two runs were created at 15:43 UTC; their `embedded-arm` jobs started 24 to 33 minutes later. The same job passed before and after, on the same runner image:

| run | path | started (UTC) | runner image |
|---|---|---|---|
| 43026701119 (`4e9110a`) | bridge build, resolved (`#7 1.035 Get:1 http://archive.ubuntu.com/ubuntu noble InRelease [256 kB]`) | 13:10:17 | `ubuntu-26.04` 20261101.186.1 |
| 43073696051 (`3c8408a`) | host-network build | 18:01:10 | `ubuntu-26.04` 20261101.186.1 |
| 41261625018 (`10bff03`, 2026-11-01) | bridge build | 01:34:15 | `ubuntu-24.04` 20261025.353.1 |

The failing and passing runs share the runner image, so the image version does not separate them. `ubuntu-latest` moved from 24.04 to 26.04 between 2026-11-01 and 2026-11-11.

## Diagnostic runs

`diagnose-dns.yml`: lookups of `archive.ubuntu.com` and `security.ubuntu.com` every 5 seconds from the host, a bridge container and a host-network container, and an `apt-get update` image build once a minute.

| run | window (UTC) | host | bridge | host-network | builds |
|---|---|---|---|---|---|
| 43098620838 (`8aefec7`) | 20:57:19 to 21:09:15 | 246 ok, 0 failed | 246 ok, 0 failed | 246 ok, 0 failed | 11 ok, 0 failed |
| 43100819627 (`412ccc4`) | 21:13:03 to 21:25:01 | 248 ok, 0 failed | 248 ok, 0 failed | 248 ok, 0 failed | 11 ok, 0 failed |

The first run's job went red on its summary step, not on a lookup: Actions starts bash with `-e` and `grep -c` exits 1 on a zero count. Fixed in `412ccc4`; the second run is green. Both runs happened while GitHub reported an Actions outage (runs queued for 40 minutes), and the lookups were still clean.

Settings read from both runs (`ubuntu-26.04` 20261101.186.1, Docker 29.4.2, no `/etc/docker/daemon.json`):

- host `/etc/resolv.conf`: `nameserver 127.0.0.53` (systemd-resolved stub), whose upstream is `168.63.129.16` (`resolvectl status`, link eth0);
- bridge container `/etc/resolv.conf`: `nameserver 168.63.129.16` directly (Docker took the upstream file `/run/systemd/resolve/resolv.conf`); no `8.8.8.8` fallback;
- the host-network container and the host use the stub.

So the bridge path and the host path ask different resolvers. Whether that difference mattered at 16:07 to 16:17 UTC is not shown by any log.

## Decision

- Keep `docker buildx build --allow network.host --network host` in `cpp/embedded/run.sh` (AZ-4191): the failure is unexplained and not reproduced, the host path was clean in 24 of 24 minutes and the `embedded-arm` job is green on it (`3c8408a`, `aacbf04`, `412ccc4`).
- Keep the apt retries in the `Dockerfile`.
- Keep `diagnose-dns.yml` (manual only, no secret, about 14 runner minutes): if `embedded-arm` fails on a name lookup again, start it at once, while the fault may still last, and read the `path=` lines; `result=fail` on `bridge` and `build` with `host-network` ok would be the first evidence of a bridge-only fault.
- Not done: any change to the runner label or to the other Docker builds.
