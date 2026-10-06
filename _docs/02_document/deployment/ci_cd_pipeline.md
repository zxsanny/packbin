# CI/CD pipeline

Host: GitHub Actions on `https://github.com/zxsanny/packbin`.

| Stage | When | Gate |
|-------|------|------|
| Test | every branch push, every pull request, and once per version tag (`publish.yml` calls `test.yml`) | a failing test fails the check. The `embedded` job runs the C++ targets (Cortex-M and s390x on QEMU, ESP-IDF builds and examples) with `cpp/embedded/run.sh`; a failing target fails the workflow. The `ring` job runs the cross-language ring (`language-pair.sh`) with the six toolchains of the suites, so a language that drifts from the others fails the check; because `publish.yml` calls `test.yml`, a failing `ring` job also skips `publish` |
| Publish | a version tag, after the called test jobs pass and the golden bytes match | a failing test job skips `publish`; a mismatch count greater than 0 publishes 0 packages; a failed build or check leaves every registry untouched |

The first tag publishes npm `packbin`, NuGet `Packbin`, PyPI `packbin`, crates.io `packbin`, Maven Central `packbin`, and vcpkg `packbin` from the same commit. The same tag also feeds the C++ embedded registries (PlatformIO, ESP-IDF component, Arduino branch and tag). A language that is not in the tree is not published. Registry tokens come from GitHub Actions secrets. The test job does not need them.

`test.yml` runs on `push` limited to branches (`branches: ["**"]`, so a tag push does not start it), on `pull_request`, and on `workflow_call`. Its permissions are `contents: read`; `scaffold` has `timeout-minutes: 60`, `embedded` 90 and `ring` 30. `publish.yml` has workflow permissions `contents: read`, a `test` job that calls `./.github/workflows/test.yml` (`contents: read`, no `secrets:` key), and a `publish` job that `needs: test` and alone holds `contents: write` and `id-token: write` (`timeout-minutes: 60`). A `concurrency` group `publish-${{ github.ref }}` without `cancel-in-progress` serializes runs of one tag. `publish-gate.test.sh` parses both files with Ruby `yaml` and fails on a change of this structure.

The `publish` job runs `publish-gate.sh` (the golden check and the plan), exchanges the NuGet and crates.io tokens, then runs `publish-registries.sh`, which has two phases. The build phase (`publish-build.sh`) builds and checks every planned target into `.github/workflows/out/artifacts/<target>/` with no registry token in its environment. The upload phase (`publish-upload.sh`) starts only when every planned target logged `build ok`, queries each registry for the version, skips what is already published and uploads the rest with the registry tools on the runner host. A re-run of the tag finishes a partial publish. NuGet, npm, PyPI, crates.io, Maven Central and vcpkg are required: a missing credential fails the run before anything is built or written. PlatformIO, ESP-IDF and Arduino are optional: a missing credential is a `::warning::` and a job-summary line, a failed upload fails the run. `PACKBIN_BUILD_ONLY=1` runs the build phase alone with no credential and no registry write. Details: `_docs/04_deploy/packages.md`.

The containers of the golden gate and of the build phase mount the repo read-only (`docker-compose.publish.yml`, passed by `publish_container` in `publish-lib.sh`) and write only their own `artifacts/<lang>` folder, so nothing they run can change a script the host executes next with the credentials. `publish-readonly.test.sh` probes this in every service and fails if the read-only mount is dropped. Details: `_docs/04_deploy/ci_cd_pipeline.md`.

The publish and test workflows pin every non-local `uses:` to a 40-hex commit with a tag comment, and every tool the scripts install has one exact version in `.github/workflows/tool-pins.txt` (read through `tool-pin.sh`); `publish-pins.test.sh`, run by `publish-gate.test.sh`, fails on a tag, a branch, a range or a missing pin. How to bump a pin: `_docs/04_deploy/ci_cd_pipeline.md`.

Lint and the byte tests run in the test stage. There is no separate security scanner stage in this plan. The publish stage is the deploy.

## Loop close and CI watch

Every product loop closes on `main`: after the `dev` push the agent fast-forwards `origin/main` to the same commit (never a force-push). Pushing `main` publishes nothing; only a `v*` tag publishes. After a push of `dev`, `main` or a tag the agent polls the GitHub Actions run of that commit every 90 seconds until it is terminal and reports PASS or FAIL in the same session. The settings and the procedure are in `_docs/04_deploy/ci_cd_pipeline.md` (`loop_end_merge: main`, `enabled: yes`).
