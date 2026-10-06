# OWASP Top 10 review

**Date**: 2026-10-06
**List**: OWASP Top 10 2025, confirmed at https://owasp.org/Top10/2025/ at the start of this audit (A01 to A10 names unchanged from earlier reviews)
**Scope**: loop 14: publish pipeline (trust boundaries between build, check, upload), Java API-26 check. The library code paths are unchanged apart from API-26 replacements in Java.

## Loop 14

| Category | Status | Notes |
|----------|--------|-------|
| A01 Broken Access Control | PASS_WITH_WARNINGS | library has no request path. CI: publishing is gated only by repository write access (a `v*` tag push, by design); no `environment:` with required reviewers, no documented tag protection (F14, Low). Job permissions are least-privilege: workflow `contents: read`, only the `publish` job holds `contents: write` and `id-token: write` (`publish.yml:8-9,23-25`); the called `test` workflow and its jobs hold `contents: read` and no secret (`publish.yml:16-19`, `test.yml:9-10`; no `secrets: inherit` anywhere) |
| A02 Security Misconfiguration | PASS_WITH_WARNINGS | build containers mount the whole repo read-write as root (`docker-compose.test.yml:12,25,38,51,64,77`) (F13); no published port; `timeout-minutes` now set on every job |
| A03 Software Supply Chain Failures | PASS_WITH_WARNINGS | F1 (actions on moving tags, incl. `setup-node@v7`), F2, F3 unchanged. **F12 (new, Medium)**: unpinned `pip install` (`twine`, `platformio`, `idf-component-manager`) and `npm install -g npm@11` run in the credentialed job, `NuGet/login@v1` (third party) holds the OIDC token. Positive: the Animal Sniffer, ASM and Android signature jars are pinned by SHA-256 and verified before use (`java/api-check.sh:14-17`, `Fetch.java:34-37`); hashes match Maven Central |
| A04 Cryptographic Failures | PASS | session code unchanged; TLS verified on every registry call (no `-k`, no `http://`, no redirects followed); OIDC trusted publishing used for npm, PyPI and crates.io; short-lived crates.io token revoked in an `always()` step (`publish.yml:58-62`). Long-lived `PYPI_TOKEN` secret still passed although OIDC is coded (F12 remediation) |
| A05 Injection | PASS_WITH_WARNINGS | no shell injection: `ref_name` goes through `env:`, every expansion is quoted, no `eval`. Version string is unvalidated (F15, Low): reaches `-p:Version=` (MSBuild `;` splits properties), TOML/JSON/XML templates, URL paths and a git tag name. No registry response reaches a shell |
| A06 Insecure Design | PASS_WITH_WARNINGS | F10 (cost per round, Medium, carried), F11 (Low, carried). Pipeline design is sound in intent: build then check then upload, required before optional, fail-closed registry queries (below); F13 shows where the build/upload boundary is weaker than it reads |
| A07 Authentication Failures | N/A | no accounts. Registry auth: OIDC where available |
| A08 Software or Data Integrity Failures | PASS_WITH_WARNINGS | **F13 (new, Medium)**: what `publish-check.py` approves is not what is later uploaded or run: the repo including `publish-upload.sh` is writable by every build container, artifacts are `a+rwX` (`publish-build.sh:50`), `build.log` carries no digest, and `cargo publish` re-archives `stage/` from the host rather than uploading the checked `.crate`. F5, F8 fixes verified in loop 13 and unchanged |
| A09 Security Logging and Alerting Failures | N/A | libraries do not log. Pipeline logs carry no secret (see static_analysis.md); `already published` / `skipping optional target` are visible in the log and job summary |
| A10 Mishandling of Exceptional Conditions | PASS | **fail-closed verified**: a registry query that errors, times out, returns 3xx/4xx other than 404, or returns an unexpected body ends the run with exit 1 before any upload (`publish-query.sh:15-18,34-42,49-50,75,80,89-92`); a 404 or a `no` answer is the only path to upload. `exit` inside those functions runs in the main shell, not a command substitution, except `platformio_owner`, whose failure is caught by `|| exit 1` (`:118`). Re-run: published targets are skipped, the first failed upload stops the run (`set -e`), required targets first (`publish-upload.sh:173-185`). Registries reject a duplicate version (npm, crates.io, PlatformIO), tolerate it (`--skip-existing`, `--skip-duplicate`, `--allow-existing`) or fail closed on the tag (Arduino `--atomic`, no force), so a lagging index cannot cause a double publish of different content. F4 fix verified |

### Question (6) in detail: who can publish what

- Tag push `v*` by anyone with write access starts `publish` (by design). The workflow file used is the one at the tagged commit, and the secrets are repository-level, so write access already implies the ability to run arbitrary code with the publish secrets (a branch with an edited `publish.yml` plus a `v*` tag). Unreviewed content can therefore be published by any writer; protection must come from repository settings (tag rules, a deployment environment with reviewers, registry-side trusted-publisher bound to that environment), none of which this repository can show (F14).
- `needs: test` makes `publish` wait for the called `test` workflow at the same commit (`publish.yml:22`); a failed or skipped test skips the publish.
- Concurrency group `publish-${{ github.ref }}` with `cancel-in-progress: false` serializes runs of the same tag; different tags run in parallel but publish different versions (a `vcpkg` or `arduino` branch push race fails the second as non-fast-forward, and a re-run fixes it).
- vcpkg: a re-run of a deleted-and-recreated tag at another commit rewrites the version entry for the same version (`publish-embedded.sh:88-90`), the only target where an existing version can change content; Arduino refuses (tag exists elsewhere).

## Earlier loops (condensed)

- Loop 10/11/13 A01 to A10: no access control (library); F5/F8/F9/F4 fixed; F6, F7 fixed; F10, F11 opened in loop 13; A03 PASS_WITH_WARNINGS from F1, F2, F3. Full tables are in git history (`git show fb9e34c:_docs/05_security/owasp_review.md`).
