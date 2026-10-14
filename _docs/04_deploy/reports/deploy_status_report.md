# Deploy status

**Date**: 2026-09-23
**Mode**: resume

Kept `_docs/04_deploy/packages.md` and `loop_end_merge: stage`.

## Deploy artifact inventory

| Item | State |
|------|--------|
| `scripts/` | absent |
| `infra/` | absent |
| `.env.example` | token names, empty values |
| `docker-compose.test.yml` | six test images, no published ports |
| `.github/workflows/test.yml` | test on push and pull request |
| `.github/workflows/publish.yml` | publish on a `v*` tag |
| `_docs/02_document/deployment/` | containerization, procedures, environment, observability |

## Host roles

| Role | Host |
|------|------|
| dev | this workstation |
| ci / builder | GitHub Actions |
| registry | npm, NuGet, PyPI, crates.io, Maven Central, vcpkg git |
| deploy | none — a registry publish is the release |

## Gap list

Remote SSH, Woodpecker, and `scripts/deploy.sh` are not gaps to fill. A laptop deploy script would be a second publisher next to `publish.yml`. Health is the golden hex, not an HTTP endpoint.

## CI run of `f30c87e` (loop 26 close push, 2026-10-14): FAIL, 2 of 3 jobs per run green

Runs 38588698291 (`dev`) and 38588700455 (`main`), `test.yml`. `embedded` PASS (6 min) in both. `scaffold`: the `suites` step (all nine suites including `swift` in `swift:6.3.3`: debug tests, fuzz, sanitizer, release) PASSED on the Ubuntu runner in both runs (16 min 47 s); the `publish gate` step FAILED in one run (exit 1 at line 1966 of its log, 19 min) and PASSED in the other (scaffold 36 min). `ring` FAILED in both at step "toolchain versions" (24 s), the first Swift ring run on a runner.
- Likely cause: `ring` — `ring-toolchains.sh` compares the runner's Swift with `RING_SWIFT` (6.3.3) at full precision and `ubuntu-latest` carries another Swift (or none that matches); read-only evidence is the step name and exit 1, the log itself needs a signed-in GitHub session (403 unauthenticated). `publish gate` — unknown without its log: one run passed on the same commit.
- Flaky vs real: `ring` real and deterministic (both runs); `publish gate` flaky or environment (same commit, one PASS and one FAIL).
- Next canonical action: read the two job logs (runs above, jobs 115937491350 and 115937490795); for `ring`, build the Swift drivers in the pinned `swift:6.3.3` image whenever the runner's Swift differs (as `ring-cxx.sh` does for GCC) and fix on `dev`, push again; for the gate, find the failing check at log line 1966.
