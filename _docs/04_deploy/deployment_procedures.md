# Deployment procedures

1. Tests are green on the commit. `publish.yml` calls `test.yml` on the tagged commit first; the `publish` job needs it, so a red test job publishes nothing. A tag runs the tests once, through `publish.yml`.
2. The golden hex matches in every present language.
3. Push a version tag. GitHub Actions builds and checks every artifact first, then uploads to the six required registries (and the three optional embedded ones whose credential is set); a failed build uploads nothing, and a missing required credential stops the run before any build. When `go/` is in the tree the last step pushes the tag `go/vX.Y.Z` at the same commit (without force) and checks the module through `proxy.golang.org` (`go list -m`, up to 30 minutes; ADR-004). A failed registry means no Go tag. `PACKBIN_BUILD_ONLY=1` runs the build phase alone with no credential and no network write.

There is no HTTP health endpoint. The check is the position pack `4001000065cd1d00a3e1110100`.

Re-run: if an upload failed, re-run the tag's `publish.yml` run in Actions (or start a new run for the same tag ref). Registries that already hold the version are skipped with `already published <target> <version>` and the rest is uploaded. The Go tag is found at the same commit and not pushed again (at another commit the run fails naming both commits); the proxy check runs again. Do not publish by hand and do not move the tag. Two runs for one tag queue, they do not overlap.

Required registries: NuGet, npm, PyPI, crates.io, Maven Central, vcpkg. Final target (after all others): the Go tag `go-tag`. A missing credential or a failed upload fails the run. Optional: PlatformIO, ESP-IDF, Arduino. A missing credential skips the target with a `::warning::` and a job-summary line; a failed upload still fails the run. Details: `_docs/04_deploy/packages.md`.

Rollback is unlist or deprecate the published version. Do not force-push the tag. A Go version cannot be unpublished: never delete or move `go/vX.Y.Z` (the proxy and the checksum database remember it); mark it `retract vX.Y.Z` in the `go.mod` of the next version and ship that as the next patch.

## Loop smoke gate (library repo; owner decision 2026-10-12)

This repo is a library: there is no site, no local deploy and no URL (`LOCAL_URL: none`). The loop smoke is a bash script, `_docs/loops/loop{NN}/smoke{NN}.md`, that prints `[n/N] title`, `PASS (Ns) <result>` or `FAIL` with the last log lines per step, and ends with `N/M steps passed`.

- **The agent runs the smoke script itself** at the commit that closes the loop (the commit before the close commit; the tree must be clean, which step 1 checks), in the order of the script, every step with stdin from `/dev/null` and a time limit. It trial-runs a new script first and fixes the script, not the check, when the script itself is wrong.
- **All `N/N` steps pass: the gate passes without asking the owner.** The agent writes the result into the `## Result` section of `smoke{NN}.md` (commit hash, `N/N steps passed`, "agent run, owner rule 2026-10-12 in `deployment_procedures.md`") and into the loop record (`smoke: PASS`, `smoke_artifact`), then continues with the loop close commit, the `dev` push and the CI watch of `ci_cd_pipeline.md`.
- **Any step fails (or the script cannot run): the gate does not pass.** The agent stops, reports the failing step with the log lines, diagnoses, and asks the owner before the close commit or any push. A step that is skipped, timed out or edited to pass is a failure.
- The script is the same list of checks the CI `test.yml` runs plus the focused loop checks; since loop 24 the suites it mirrors are seven (`csharp`, `typescript`, `python`, `rust`, `cpp`, `java`, `go`: the `go` step is `docker compose -f docker-compose.test.yml run --rm go`, `run-suite.sh go`, about 2 minutes with the 60 s fuzz, and check `uptime` first because the Go speed bound is a timing bound); it does not replace the CI run on `dev`, which stays the proof for timing bounds (loop 17 and loop 20 lessons).
