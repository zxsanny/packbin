# Autodev loop record - loop 106

loop: 106
branch: dev
plan_artifact: none (one CI fix, no plan file)
tasks_shipped: [AZ-4191]
decisions:
  - owner (2026-11-11): "Yes, fix it" to making the embedded-arm image build robust against the apt name-lookup failure of loop 105
  - agent: apt retries in the Dockerfile and the image build on the host network; the compose service keeps only its context
measurements:
  - the failure: `Could not resolve 'archive.ubuntu.com'` in `apt-get update` inside the image build, 5 attempts on `61505c9` over about 55 minutes; Dockerfile unchanged since AZ-3479; the same job passed on `4e9110a`
  - first try `707041c` (compose `build.network: host`): CI refused it, `additional privileges requested: pass "--allow=network.host"` (BuildKit Bake)
  - second try `e9c2ad8` (`COMPOSE_BAKE=false`): the same refusal; the local Docker Compose 2.24 has no Bake, so neither failure could be reproduced on the Mac
  - final `3c8408a`: `run.sh` builds with `docker buildx build --allow network.host --network host --load --tag packbin-embedded:local`; `dev` run 43073696051 and `main` run 43073700950 both success, `embedded-arm` green on each (20 of 20 jobs)
  - self-tests `run-parts.test.sh` and `lib.test.sh` pass; the image also builds on the Mac
review: "none (CI files only: Dockerfile, run.sh, its self-test, one compose key removed)"
leftovers:
  - the host-network build goes around the runner's bridge DNS without finding why the bridge could not resolve names; if the job fails on a name lookup again, look at the runner's Docker daemon DNS
  - from loop 105 (unchanged): owner's first `dart pub publish`; automate the signing-key upload in `publish-sign.sh`; the autodev rule file `worktree-isolation.md` is outside this repository
  - Jira: AZ-4191 In Testing; AZ-4153, AZ-4168, AZ-4169 In Testing
