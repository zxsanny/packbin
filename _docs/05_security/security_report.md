# Security Audit Report

**Date**: 2026-10-06
**Scope**: packbin, loop 14 (`git diff c6c389c..HEAD`, HEAD 43af2f6): the publish pipeline (`publish.yml`, `test.yml`, `publish-{registries,build,upload,query,sign,inside,embedded,lib}.sh`, `publish-{check,published}.py`, `crates-token.sh`, the three publish test scripts) and the Java API-26 work (`java/api-check.sh`, `tools/Fetch.java`, `tools/ApiCheck.java`, `java/test.sh`, `Field.immutableCopy`, `Containers.compareUnsigned`, the `Buffer` cast). Loop 13 findings carried forward.
**Verdict**: PASS_WITH_WARNINGS

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 3 |
| Low | 7 |

No Critical or High. The pipeline is fail-closed where it matters (a registry query that cannot answer stops the run; a required target without its credential stops it before anything is built; build-only mode cannot write to a registry or push), job permissions are least-privilege, and no shell injection through `github.ref_name` or a registry answer exists. Two Medium findings are new and both concern the credentialed part of the publish job: it installs unpinned code while holding every registry secret (F12), and the build/upload separation of AZ-2096 holds for environment variables but not for the filesystem (F13). F10 (Medium) and F11, F1 to F3 (Low) are carried unchanged; F14 to F16 are new Low items. The Java API-26 replacements do not change unpack behavior, and the three jars fetched at test time match their pinned SHA-256 and Maven Central's checksums.

## OWASP Top 10 Assessment

List: OWASP Top 10 2025, confirmed at owasp.org at the start of the audit.

| Category | Status | Findings |
|----------|--------|----------|
| A01 Broken Access Control | PASS_WITH_WARNINGS | F14 |
| A02 Security Misconfiguration | PASS_WITH_WARNINGS | F13 (root containers, repo mounted read-write) |
| A03 Software Supply Chain Failures | PASS_WITH_WARNINGS | F12, F1, F2, F3 |
| A04 Cryptographic Failures | PASS | — |
| A05 Injection | PASS_WITH_WARNINGS | F15 |
| A06 Insecure Design | PASS_WITH_WARNINGS | F10, F11 |
| A07 Authentication Failures | N/A | — |
| A08 Software or Data Integrity Failures | PASS_WITH_WARNINGS | F13, F16 (token handling) |
| A09 Security Logging and Alerting Failures | N/A | — |
| A10 Mishandling of Exceptional Conditions | PASS | — (fail-closed queries verified) |

## Findings

| # | Severity | Category | Location | Title | Status |
|---|----------|----------|----------|-------|--------|
| 10 | Medium | A06 | `csharp/Walker.Rounds.cs`, `typescript/src/rounds.ts`, `java/.../Rounds.java`, `rust/src/walk/{unpack,times}.rs` | Unpack of a `repeat` / `times` round costs memory and time per name per round, no budget | carried (open, unchanged: no production source of those packages changed in loop 14 beyond Java API-26 replacements) |
| 12 | Medium | A03 | `publish-upload.sh:129-140`, `publish-lib.sh:123-135`, `publish-embedded.sh:128,134`, `publish.yml:32,36,37,50` | Unpinned code runs in the credentialed job: pip installs of `twine`, `platformio`, `idf-component-manager` with all tokens in the environment, `npm@11`, `NuGet/login@v1` | new |
| 13 | Medium | A08 / A02 | `docker-compose.test.yml:12` (and 25, 38, 51, 64, 77), `publish-build.sh:44-50`, `publish-upload.sh:153` | Build containers mount the whole repo read-write; what is checked is not what is later run or uploaded | new |
| 11 | Low | A06 | `fixtures/hostile/cases.test.sh`, the six hostile replays | No test bounds unpack cost by packet size | carried (open) |
| 1 | Low | A03 | `publish.yml:29,32`, `test.yml:17,58` | `actions/checkout@v7`, `actions/setup-node@v7` not pinned to a commit | carried (open since 2026-09-29; line numbers moved; `setup-node` added to scope) |
| 2 | Low | A03 / A08 | `cpp/embedded/examples.sh:25` | `arduino-cli` tarball downloaded and run without a checksum | carried (open, file unchanged) |
| 3 | Low | A03 | `cpp/embedded/Dockerfile:4`, `docker-compose.test.yml` | Base images pinned by tag, not by digest | carried (open, unchanged) |
| 14 | Low | A01 | `publish.yml:3-6,21-26` | Any writer's `v*` tag publishes; no deployment environment, approval or documented tag protection | new |
| 15 | Low | A05 | `publish.yml:48`, `publish-registries.sh:22-23`, `publish-inside.sh:36-37,81-109` | Tag name is the version with no validation | new |
| 16 | Low | A08 | `publish-upload.sh:49,97,103,109,146,153`, `publish-query.sh:113`, `crates-token.sh:18,57` | Registry tokens on the command line | new |

### Finding Details

**F12: Unpinned code runs in the credentialed job** (Medium / A03)
- Location: `publish-upload.sh:129-140` (`prepare_tools` runs `ensure_tool twine twine`, `ensure_tool pio platformio`, `ensure_tool compote idf-component-manager`), `publish-lib.sh:132` (`pip install --quiet "$pkg"`: no version, no hash, no `--only-binary`), `publish.yml:36` (`npm install -g npm@11`), `publish.yml:37-40` (`NuGet/login@v1`), `publish.yml:50-55` (long-lived secrets), `publish-embedded.sh:128,134` (the same pip installs in the build phase).
- Description: `publish-upload.sh` runs in the same shell and step as all secrets: `NUGET_TOKEN`, `PYPI_TOKEN`, `CARGO_REGISTRY_TOKEN`, `MAVEN_CENTRAL_TOKEN`, `MAVEN_GPG_PRIVATE_KEY`, `PLATFORMIO_AUTH_TOKEN`, `IDF_COMPONENT_API_TOKEN`, `GITHUB_TOKEN` (`contents: write`), and the OIDC request token. `prepare_tools` runs before the first upload (`:140`) and installs whatever PyPI serves today, plus 12 to 15 transitive packages (`platformio`: `requests`, `starlette`, `uvicorn`, `bottle`, ...; `idf-component-manager`: `pydantic`, `psutil`, ...). In the build phase the same installs run with `MAVEN_GPG_PRIVATE_KEY` in the environment, because the subshell keeps it for every target (`publish-registries.sh:108`) although only `publish-sign.sh` needs it. `npm install -g npm@11` and `NuGet/login@v1` (a third-party action, tag-pinned) run with the OIDC request variables present. The checkout step also leaves the job's `contents: write` token on the runner (`publish.yml:29`, no `persist-credentials: false`; storage in v7 not verified).
- Attacker scenario: an attacker who publishes a malicious new release of `twine`, `platformio`, `idf-component-manager` or one of their dependencies (or of `npm@11`, or who moves the `NuGet/login@v1` tag), or a dependency-confusion upload, gets code execution in the next publish. It reads `os.environ`, and either exfiltrates every token or, without exfiltrating, mints OIDC tokens for npm, PyPI and crates.io and pushes a trojaned release of packbin to all registries and to the repository branches. Likelihood is low (requires a compromise upstream) and the impact is a compromise of every distribution channel, which is why this is Medium and not Low. No advisory exists today for those packages (OSV, 2026-10-06).
- Remediation: (1) install the tools in a step before the credentialed step, from a hash-locked `requirements.txt` (`pip install --require-hashes --only-binary=:all:`) and pin the action and npm versions (commit SHA for `NuGet/login`, `setup-node`, `checkout`; `npm@11.x.y`); (2) run the build phase without `MAVEN_GPG_PRIVATE_KEY` and pass it only to `publish-sign.sh`; (3) drop the `PYPI_TOKEN` secret and use the OIDC path already coded in `pypi_oidc_token`; (4) `persist-credentials: false` on the publish checkout.

**F13: Build containers mount the whole repo read-write; the check does not bind the upload** (Medium / A08, A02)
- Location: `docker-compose.test.yml:12,25,38,51,64,77` (`./:/src`, read-write, root); `publish-build.sh:44-50`; `publish-upload.sh:150-155` (cargo), `publish-build.sh:50` (`chmod -R a+rwX`); `publish-check.py:125-138`; `python/pyproject.toml:12` (`setuptools>=61`), `publish-inside.sh:52-53` (`pip install build`).
- Description: the build runs without credentials in its environment (verified: containers receive only `SRC_ROOT`, `PACKBIN_VERSION`, `PACKBIN_OUT` and the compose constants), but each language container sees `/src`, which holds (a) `.github/workflows/publish-upload.sh`, `publish-lib.sh`, `publish-query.sh`, the scripts the host runs next with every credential, (b) `PACKBIN_OUT`, i.e. the artifacts of the targets built earlier (order: csharp, typescript, python, rust, then cpp, then java), already checked, and (c) `.git` and any `.cargo/config.toml`. The Python container downloads the newest `setuptools` and `build` from PyPI as root before it builds. Separately, `check` approves files but `build.log` records only `build ok <target>` with no digest, artifacts are made world-writable, and for Rust `cargo publish --no-verify --allow-dirty` on the host re-archives `artifacts/rust/stage/` (only its `Cargo.toml` version and the absence of `target/` are checked, `publish-check.py:135-138`), not the `.crate` that was checked.
- Attacker scenario: a compromised `setuptools` (or any build-time download in a container) runs as root in the python container, rewrites `/src/.github/workflows/publish-upload.sh` (or drops `/src/.cargo/config.toml` redirecting `cargo publish`, or replaces `artifacts/csharp/Packbin.<v>.nupkg` after it passed its check, or adds a file to `artifacts/rust/stage/`). The host then executes the modified script, or uploads the replaced artifact, with all registry credentials. The no-credential build phase therefore does not contain a compromised build dependency. Only the Python build downloads code from a registry at build time today (csharp, typescript, rust, java builds have no dependencies), so exploitability rests on the same upstream-compromise precondition as F12.
- Remediation: mount only the source directories read-only (`./csharp:/src/csharp:ro`, ...) plus one writable `artifacts/<lang>` directory per container; run the upload scripts from a copy made before any container starts (or fail if `git status --porcelain` shows a change under `.github/` before upload); write `sha256sum` of every artifact at check time and verify it immediately before upload; upload the checked `.crate` for Rust (`cargo publish` cannot upload a prebuilt crate, so verify the staged tree by hash, or publish from a clean checkout in the upload step); pin `setuptools` and `build` with hashes; drop the world-writable `chmod` (use `chown` to the runner user inside the container or `--user`).

**F14: A tag push by any writer publishes; no approval gate** (Low / A01)
- Location: `publish.yml:3-6` (tags `v*`), `:21-26`, secrets at repository level (`:50-55`); no `environment:` key.
- Description: by design a `v*` tag triggers the publish. The workflow file used is the one at the tagged commit and secrets are repository-wide, so any user with write access (or a compromised account or token with it) can publish unreviewed content: push a branch, tag it. `needs: test` only proves the tests of that same commit pass. A re-run of a run publishes the same commit again and is harmless (registries refuse a duplicate). Whether tag rulesets, branch protection or registry-side trusted-publisher restrictions (workflow, environment) exist cannot be seen from the repository. vcpkg is the only target where an existing version's entry can be rewritten (`publish-embedded.sh:88-90`).
- Impact: a stolen writer credential equals a release of arbitrary code to six ecosystems.
- Remediation: put the job in a GitHub `environment` with required reviewers (move the secrets there and bind the registries' trusted publishers to the environment name); protect `v*` tags with a ruleset; document both in `_docs/04_deploy/`.

**F15: The tag name is the version, unvalidated** (Low / A05)
- Location: `publish.yml:48`, `publish-registries.sh:22-23`, `publish-inside.sh:36-37`, `:81-109`, `publish-embedded.sh:59-67`, `publish-query.sh:104-109`.
- Description: `git check-ref-format` accepts `v1.0.0$(x)`, `v1.0.0;Foo=1`, `v1/x`, `v1"2`, `v1#2`. No shell executes the value (env transport, quoting, no `eval`), but it flows to `dotnet pack -p:Version=` (a `;` adds MSBuild properties), to TOML/JSON/XML templates, to URL paths and to the tag `arduino-<version>`. The artifact checks (`publish-check.py`) refuse most distortions after the fact, so this is defence in depth, not an exploit; the only party who can pick the tag name is a writer (F14).
- Remediation: first step of `publish-registries.sh`: `[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || { echo ...; exit 1; }`; same check in `publish-build.sh` and `publish-upload.sh`.

**F16: Registry tokens on the command line** (Low / A08)
- Location: `publish-upload.sh:97` (`twine -p`), `:146` (`dotnet nuget push --api-key`), `:153` (`cargo publish --token`), `:103,109` and `publish-query.sh:113` (`curl -H "Authorization: Bearer ..."`), `publish-upload.sh:49`, `crates-token.sh:18,57` (OIDC request token, crates.io token).
- Description: arguments are readable in `/proc/<pid>/cmdline` by every local process for the lifetime of the command (up to 22 min for the Maven poll loop). Logs are safe (GitHub masks the values; nothing prints them; the Maven status JSON holds no token). On a hosted runner the processes that could read it can already read the environment, so the added risk is limited to shared or self-hosted runners.
- Remediation: pass tokens through the tools' environment variables or stdin where supported (`TWINE_PASSWORD`, `CARGO_REGISTRY_TOKEN` alone, `curl -H @file` with a 0600 temp file or `--config -`, `dotnet nuget push` has no env form: use a `NuGet.Config` source with an API key file or accept).

**F10, F11, F1, F2, F3** are carried as in loop 13: see the table. F10 detail (measured peak resident set per package, remediation options 1 to 3) is unchanged: 0.3 to 1.4 GB per 1 MiB packet of one-byte rounds; the README states the cap requirement; a packet-length cap contains it; High for a service that reads packets of a megabyte or more without a cap. F1 now also covers `actions/setup-node@v7` (`publish.yml:32`); the third-party `NuGet/login@v1` is treated in F12.

## Loop 15 status: F10 and F11 (AZ-2216 to AZ-2220)

The loop's security audit rewrites this report; this block records only the F10 and F11 status after the implementation.

| # | Status | Why |
|---|--------|-----|
| F10 | fixed for C#, TypeScript, Java and Rust (AZ-2216 to AZ-2219) | A scheme carries `maxRounds` (default 65,535 per `repeat` or `times` field) and `maxSlots` (default 4,194,304 per unpack call). A round past either is refused when it would start, with the package's interim bad-value error, no row, handler not called; a scheme raises the limits with `WithLimits`, `withLimits` or `with_limits`. A refused 1 MiB packet of one-byte rounds now peaks at 86 to 92 MiB (36-name body in C#, TypeScript, Java) and 21 to 64 MiB (Rust) instead of 0.3 to 1.4 GB; measured again in AZ-2220 (README, Untrusted input). Tests: `csharp/tests/RoundLimitTests.cs`, `typescript/tests/round-limits.test.ts`, `java/.../RoundLimitsTest.java`, `rust/tests/round_limits_tests.rs`; each suite passes in its container (C# 410 tests, TypeScript 279, Rust 234, Java all runners) |
| F11 | closed for C#, TypeScript, Java and Rust | The four size tests above hold a packet of `maxRounds` one-byte rounds accepted, one of `maxRounds + 1` refused, and a refused 1 MiB packet with `left` 983,041; the two shared `limit` cases (`repeat_rounds_over_limit`, `times_rounds_over_limit`, `fixtures/hostile/cases.txt`) are replayed by the four packages against a scheme with `maxRounds` 3 |
| F10 and F11, C++ and Python | bounded by design, no size test added | C++ unpacks into caller-owned `Array<T, N>` storage of capacity at most 65,535 and returns `Error::TooMany` for a longer count (`cpp/include/packbin/table.hpp`, `core.hpp`); Python keeps only the values it reads (`python/src/packbin/_unpack.py`, `_append`), about 36 MiB for the packet above. F11 is closed with this stated limit, not fully |

## Loop 13 findings: status

| # | Status | Why |
|---|--------|-----|
| F1 | open, carried | moving tags still in use; scope widened to `setup-node`; credentialed use of `NuGet/login` raised under F12 |
| F2 | open, carried | `cpp/embedded/examples.sh:25-27` unchanged, only runs in the embedded job, no secret |
| F3 | open, carried | no image or Dockerfile changed in loop 14 |
| F4 to F9 | fixed, unchanged | C#, TypeScript, Rust production sources untouched in loop 14; Java changes limited to API-26 replacements that keep behavior |
| F10 | open, carried (Medium) | no change to round handling; owner-accepted in the loop 13 assessment |
| F11 | open, carried (Low) | no test added |

## Dependency Vulnerabilities

| Package | CVE | Severity | Fix Version |
|---------|-----|----------|-------------|
| none known | `npm audit` 0; OSV 0 for `twine`, `platformio`, `idf-component-manager`, `build`; `cargo audit` could not run (CVSS 4.0 parse failure), lockfile holds only the crate itself | — | — |

## Recommendations

### Immediate (Critical/High)
None.

### Short-term (Medium)
- F12 and F13 together, in one change to the publish job: hash-locked tool install before the credentialed step, key and tokens only where used, repo mounted read-only (or upload from a pre-container copy), digests between check and upload. Do this before the first real release.
- F10: the owner picks keep, budget, or compact representation.

### Long-term (Low / Hardening)
- F14 environment with reviewers and tag ruleset; F15 version regex; F16 tokens off argv; F11 size-scaled hostile case; F1 to F3 pin actions to commit SHAs, check the `arduino-cli` checksum, pin base images by digest.

## Evidence and limits

Method: read every changed file in full (`git diff c6c389c..HEAD --stat`: 43 files); read-only network queries (OSV, PyPI JSON, Maven Central, owasp.org); `npm audit`; `cargo audit` (failed to parse the advisory database); the three Maven Central artifacts of `api-check.sh` were downloaded to a throwaway directory, hashed, compared with the pinned values and Central's `.sha1`, and deleted. Nothing in the repository other than `_docs/05_security/` was changed; no publish, no registry write, no credential used; the test scripts were not run.

Could not verify: (1) how `actions/checkout@v7` stores the job token (F12); (2) repository settings: tag rulesets, branch protection, environments, and the registries' trusted-publisher bindings (F14); (3) whether `twine` is preinstalled on `ubuntu-latest` (if it is, only `platformio` and `idf-component-manager` are installed from PyPI, F12 stands); (4) which transitive dependencies of `platformio` and `idf-component-manager` ship only as sdists (those run setup code at install); (5) DAST (not applicable); `cargo audit` result (tool failure). Test scripts (`publish-gate.test.sh`, `publish-phases.test.sh`, `publish-rerun.test.sh`) use stubbed `curl`, `dotnet`, `npm`, `twine`, `cargo`, `pio` and local bare git repositories; they were searched (not read line by line) for tokens, `curl`, `push`, `PATH=` and `gpg`: none contains a real credential, and the registry URLs they match are stub patterns.
