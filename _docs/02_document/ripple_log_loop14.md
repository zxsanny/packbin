# Ripple log — loop 14

The loop changed the publish pipeline and the Java package build; no public API and no wire format changed. The packages do not import each other, so no package doc is stale because of another package. The scripts under `.github/workflows/` are shell, Python and YAML, so there is no import graph to parse. Mode: directory-proximity and `rg` over the changed script and file names (`publish-*.sh`, `publish-check.py`, `publish-published.py`, `publish.yml`, `test.yml`, `api-check.sh`, `Field.java`, `Containers.java`) across `.github/`, `java/`, `docker-compose.test.yml`, `fixtures/`, `README.md` and `_docs/`. The result is marked heuristic: a manual pass is available on request.

There is no `_docs/02_document/modules/` directory in this repo. The component description is the lowest doc level, so each changed file maps to its component description or to the workflows entry of `module-layout.md`.

Importers of the changed scripts (the callers and sourcers found by `rg`):

- `publish-gate.test.sh` sources `publish-phases.test.sh` and `publish-rerun.test.sh`, and runs the real `publish-gate.sh`, `publish-registries.sh`, `publish-build.sh` and `publish-upload.sh` on a tree copy
- `publish-registries.sh` sources `publish-lib.sh` and calls `publish-build.sh` and `publish-upload.sh`; `publish-build.sh` calls `publish-inside.sh`, `publish-embedded.sh`, `publish-sign.sh` and `publish-check.py`; `publish-upload.sh` sources `publish-query.sh`, which calls `publish-published.py`
- `publish-gate.sh` and `publish-position.sh` source `publish-lib.sh` (no behavior change for them; `PACKBIN_LANGS` and `language_present` are unchanged)
- `test.yml` runs `publish-gate.test.sh` in the `scaffold` job and the Java suite through `run-suite.sh java` (which runs `java/test.sh`); `publish.yml` calls `test.yml`
- `java/test.sh` calls `java/api-check.sh`, which runs `java/tools/Fetch.java` and `java/tools/ApiCheck.java`; `PackbinTest` calls `ApiSafeReplacementsTest`

Direct refresh:

- `components/06_java_package/description.md` — refreshed because `java/test.sh` (`--release 17`, `api-check`), `java/api-check.sh`, `java/tools/*` (new), `Field.java` (`immutableCopy`), `Containers.java` (`compareUnsigned`), `Walker.java` (`Buffer` cast), `Scheme.java` changed. Changed by AZ-2094
- `components/06_java_package/tests.md` — refreshed because `ApiSafeReplacementsTest.java` (new), `api-check` and the class-major check in `publish-check.py` are new Java checks. Changed by AZ-2094, AZ-2096
- `module-layout.md` — the workflows entry lists the new publish scripts and tests and the publish ownership (`publish-lib.sh`, `publish-registries.sh`, `publish-build.sh`, `publish-upload.sh`, `publish-query.sh`, `publish-published.py`, `publish-check.py`, `publish-sign.sh`, `publish-inside.sh`, `publish-embedded.sh`, `publish-phases.test.sh`, `publish-rerun.test.sh`); the Java entry lists the API-check files. Changed by AZ-2094, AZ-2095, AZ-2096, AZ-2097

Cross-cutting refresh:

- `deployment/ci_cd_pipeline.md` — `test.yml` triggers (branch push, pull request, `workflow_call`), `publish.yml` test call, `needs`, permission split, concurrency, timeouts, two-phase build and upload, build-only mode, required and optional targets, re-run. Triggered by `test.yml`, `publish.yml`, `publish-registries.sh`, `publish-lib.sh` (AZ-2095 to AZ-2097)
- `_docs/04_deploy/ci_cd_pipeline.md` — the Pipeline section only (same changes); the `Post-deploy polling (agent configuration)` section is untouched
- `_docs/04_deploy/deploy_scripts.md` — named the publish scripts, the order after the test call, and `PACKBIN_BUILD_ONLY=1`. Triggered by the same files
- `architecture.md` — Java row (Java 17, Android API 26), CI/CD wording (branch push, publish after the called tests), one paragraph in §5: artifacts are checked before the first upload, registry tools run on the runner host, a re-run skips published versions, required and optional targets. Seam: uploads moved from language containers to the runner host (AZ-2096)
- `interaction-risks.md` — new row: the crates.io token (and the NuGet key) is exchanged before the longer build phase (batch 3 review finding 1, assessment U1, accepted option A in loop 14)
- `system-flows.md` — F3: description, data flow (build, then upload), four error rows (test job fails, build or check fails, required credential missing, upload fails after others succeeded). F3 preconditions and diagram were already updated in batch 2
- `deployment/containerization.md` — the Java suite row: `--release 17` and the cold-cache fetch of the pinned API-check jars (`java/api-check.sh`)
- `deployment/deployment_procedures.md` — release step 2 said only the C# and TypeScript bytes are compared; `publish-gate.sh` compares every present language (a contradiction with the code, fixed in passing)

Already updated in the batches and verified against the scripts, not changed again: `_docs/04_deploy/packages.md`, `_docs/04_deploy/deployment_procedures.md`, `deployment/deployment_procedures.md` (other than step 2), `tests/environment.md`, `README.md` (the Java line).

Checked, not changed:

- `adr/*` — out of scope (AZ-2097 excluded the ADR wording, tasks C29 and D19). The `ADR-002` copy inside `architecture.md` §8 still says "every push" and six registries, for the same reason
- `components/01_csharp_package`, `02_typescript_package`, `03_python_package`, `04_rust_package`, `05_cpp_package` — no source change in this loop (the packages are only built by `publish-inside.sh` and `publish-embedded.sh`, whose behavior toward them did not change)
- `_docs/04_deploy/environment_strategy.md`, `deployment/environment_strategy.md`, `04_deploy/containerization.md` — they name no publish script and no `PACKBIN_*` variable; the table rows (tokens in the tag job only) stay true
- `risk_mitigations.md` — iteration 01 register, closed; the new risk is recorded in `interaction-risks.md`
- `data_model.md`, `glossary.md`, `contracts/*` — no entity, term or contract changed
- `tests/*` other than `environment.md`, and `components/*/tests.md` for the five other languages — test specs; test-spec sync was `not_in_plan` this loop
- `_docs/00_problem/*` (`restrictions.md`, `infra_topology.md`, acceptance criteria) — no input, AC or restriction changed in this loop; the lines "tests on every push and pull request" stay true for branch pushes
- `_docs/04_refactoring/**`, `_docs/04_deploy/reports/*`, `FINAL_report.md` — dated records of earlier runs; the removed `PACKBIN_MAVEN_BUNDLE_ONLY` is still named in the `04_refactoring` discovery reports and in `_docs/02_tasks/todo/AZ-2101_java_typed_nested_rows.md`, left as history and as a task spec
