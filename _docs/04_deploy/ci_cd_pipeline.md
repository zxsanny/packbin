# CI/CD pipeline

## Loop-end channel (ordinary product loops)

loop_end_merge: main

Owner decision 2026-10-06: this project closes every product loop on `main`, not on `stage`. `origin` has no `stage` branch (`arduino`, `dev` and `main` only) and none is wanted. The value `main` is this project's own definition; the autodev protocol table lists only `none`, `stage` and `stage+main`.

At every loop close, after smoke PASS, the local merge on `dev` and the `dev` push, the agent does one more step from the launcher: it fast-forwards `origin/main` to `HEAD` (`git push origin HEAD:main`) and then watches the `test.yml` run on `main` as set in the polling section below. It never force-pushes. If `origin/main` is not an ancestor of `HEAD`, it stops and reports. Pushing `main` publishes nothing: a registry publish happens only on a `v*` tag (`publish.yml`), and a tag is always a separate, explicit owner decision.

## Pipeline

GitHub Actions. `test.yml` runs on every branch push (`branches: ["**"]`, not tags), every pull request, and as a called workflow (`workflow_call`); `scaffold` has `timeout-minutes: 60`, `embedded` 90. `publish.yml` runs on a `v*` tag: its `test` job calls `test.yml` (read-only token, no secrets), and the `publish` job `needs` it, so a failing test job skips the publish. `publish` alone has `contents: write` and `id-token: write` (`timeout-minutes: 60`), and a `concurrency` group `publish-${{ github.ref }}` (no cancel-in-progress) serializes runs of one tag.

The publish job builds and checks every artifact first (`publish-build.sh`; `PACKBIN_BUILD_ONLY=1` runs this phase alone, with no credential and no registry write), then uploads what is not yet published (`publish-upload.sh`). Required targets (NuGet, npm, PyPI, crates.io, Maven Central, vcpkg) need their credential or the run fails before any write; optional targets (PlatformIO, ESP-IDF, Arduino) are skipped with a warning when it is missing. Re-running the tag finishes a partial publish. See `packages.md`.

`publish-gate.test.sh` (run by the `scaffold` job) checks this structure by parsing the workflow YAML with Ruby `yaml`.

## Read-only repo in the publish containers

The six golden-gate containers and the five language builds start only through `publish_container` in `publish-lib.sh`, which passes `docker-compose.test.yml` and then `docker-compose.publish.yml`. The second file mounts the repo at `/src` read-only and replaces `/test-results` with a tmpfs (volumes merge by target; `docker compose run -v` over an existing mount is silently ignored on Compose 2.24.3, so it is not used). A build writes only `artifacts/<lang>`, mounted at `/out/artifacts/<lang>` with `PACKBIN_OUT=/out`; C# packs from a copy of `csharp/` and `README.md`, and the gate runs the C# driver (and the TypeScript driver when `node_modules` is absent) from a container-local copy. Nothing a container runs (including `npm ci` and the pip downloads) can change a script, a source file or `.git` that the host runs next with the credentials. Never add `docker-compose.publish.yml` to the test-suite calls: those write `bin`, `obj`, `node_modules` and `target`. `publish-readonly.test.sh` (run by `publish-gate.test.sh`) probes the write refusals in all six services, hashes the tree before and after the gate and a full build-only run, and fails if the override is dropped. Docker Desktop cannot show Linux file ownership: the first green `scaffold` run on `ubuntu-latest` is the proof that the artifact folders end up owned by the runner user.

## Pins and how to bump them

Every non-local `uses:` in `.github/workflows/*.yml` is `owner/repo@<40 lowercase hex commit> # <tag>`, and every tool the publish and test scripts install has one exact version in `.github/workflows/tool-pins.txt` (`name==version` per line: `npm`, `twine`, `platformio`, `idf-component-manager`, `build`, `setuptools`, `pytest`). `.github/workflows/tool-pin.sh <name>` prints one version and fails for a name that is not pinned. `publish-lib.sh` (`ensure_tool`), `publish-inside.sh` (the Python build, where the same file is the pip constraints file that holds `setuptools`), `run-suite.sh`, `cpp/embedded/examples.sh`, the npm step of `publish.yml` and the gate tests all read it, so a second copy of a version number is a defect. `publish-gate.test.sh` (through `publish-pins.test.sh`) fails on a tag, a branch, a short or upper-case SHA, a missing tag comment, two SHAs for one action, a literal `npm@<digit>`, and a pin that is missing or has become a range.

- Bump an action: `git ls-remote --tags https://github.com/<owner>/<repo>.git <tag> '<tag>^{}'`. Take the `^{}` (peeled) line when one is listed, otherwise the single line; it is the commit of that tag in that repository (an annotated tag has its own object, the peeled line is the commit behind it). Edit every `uses:` line of that action, in every workflow file, to that SHA and the new tag comment. Paste the lookup output into the commit message.
- Bump a tool: edit its one line in `tool-pins.txt`, then wait for a green `test.yml` (the `scaffold` job installs the pip tools and runs the real `pio pkg pack`, `compote component pack` and the Python build; pytest runs in the suite container). `npm` and the two actions that only the publish job runs are proven by the first `v*` tag run.
- Not covered: the transitive Python dependencies of the tools still float (no hash lock), and `ensure_tool` keeps a tool that is already on `PATH`.

## Post-deploy polling (agent configuration)

enabled: yes
long_running: yes (the `embedded` job alone takes about 40 minutes cold; a green `test.yml` takes 45 to 60 minutes)
poll_interval_seconds: 90
applies_after: a push of `dev` or `main`, and a push of a `v*` tag
status_tool: the GitHub Actions REST API read with `curl` (no `gh` on the agent host, no token needed: the repository is public)
primary_gate: `test.yml` (jobs `scaffold`, `embedded`) on the pushed commit; for a tag, the `publish` workflow run (`test`, then `publish`)
report_to: the chat; on FAIL, `autodev/protocols/ci-fail-triage.md`

There is no deploy host to probe. The test and publish results are the GitHub Actions checks.

### Post-deploy pipeline watch (procedure)

1. Take the pushed commit: `sha=$(git rev-parse HEAD)` for a branch push, or the tag's commit for a tag push.
2. Every `poll_interval_seconds`, read the runs of that commit: `curl -s "https://api.github.com/repos/zxsanny/packbin/actions/runs?head_sha=$sha"` and take `workflow_runs[].name`, `status`, `conclusion`. Unauthenticated calls are limited to 60 per hour per address, so the interval is 90 seconds (about 40 calls per hour). A `403` with `x-ratelimit-remaining: 0` means wait for `x-ratelimit-reset`; it is not a test result.
3. Terminal states: `status: completed` with `conclusion` `success` (PASS), or `failure`, `cancelled`, `timed_out` (FAIL). No run for the commit after 5 minutes is a blocked trigger (report it; do not start a run by hand).
4. On FAIL read the failed job's log through the run page the API returns (`html_url`) and apply `ci-fail-triage.md`: three lines, read only. Do not re-run, re-tag or push a fix without the owner.
5. Report PASS or FAIL in the chat as soon as the run is terminal. Never end a turn with "check CI later".

A `v*` tag push also has uploads to six registries; its run is the only proof of the registry-side checks (see `packages.md`).
