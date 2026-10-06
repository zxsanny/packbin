# Ripple log — loop 15

The loop added per-call round limits to the unpack of C#, TypeScript, Java and Rust (AZ-2216 to AZ-2219), a `limit` stage in the hostile cases (AZ-2220), pinned the credentialed publish job (AZ-2214) and made the publish containers read-only (AZ-2215). No wire format and no pack behavior changed. The packages do not import each other, so no package doc is stale because of another package. The workflow files are shell and YAML, so there is no import graph to parse. Mode: directory-proximity and `rg` over the changed names (`withLimits` and its per-language spellings, `RoundBudget`, `Cursor`, `maxRounds`, `maxSlots`, `tool-pins.txt`, `tool-pin.sh`, `publish_container`, `docker-compose.publish.yml`, `cases.txt`, `limit`) across `csharp/`, `typescript/`, `java/`, `rust/`, `cpp/`, `python/`, `fixtures/`, `.github/`, `README.md` and `_docs/`. The result is marked heuristic: a manual pass is available on request.

There is no `_docs/02_document/modules/` directory in this repo. The component description is the lowest doc level, so each changed file maps to its component description or to an entry of `module-layout.md`.

Callers and sourcers found by `rg`:

- `BinaryPacker.ReadFields` (C#) is called by `Unpack` and by `SchemeHandler<T>.Dispatch`; both now pass the scheme, so the budget follows dispatch as well
- TypeScript `unpackBody` is called only by `unpackDispatch` in `index.ts`, which passes the matched handler's scheme limits
- Java `Cursor` replaced `int[] offset` in `BinaryPacker`, `Walker`, `Containers`, `VarFields` and `Rounds` (compiler-checked rename); `RoundLimitsTest.run()` is called from `PackbinTest`
- Rust `unpack` builds its `Cursor` from the `MapScheme`; the typed `Scheme<T>` delegates `with_limits` to its layout; `repeat` and `times` store `slots`, so `field/order.rs`, `field/shape.rs` and `walk/pack.rs` only pattern-match with `..`
- `publish-gate.test.sh` sources `publish-pins.test.sh` and `publish-readonly.test.sh`; `publish-gate.sh` and `publish-build.sh` start containers only through `publish_container` in `publish-lib.sh`; `publish-position.sh` and `publish-inside.sh` work from copies; `test.yml` requires `docker-compose.publish.yml`
- `fixtures/hostile/cases.txt` is read by `check-cases.sh`, `cases.test.sh` and the replays of C#, TypeScript, Java, Rust and C++ (C++ skips the `limit` stage in `read_cases`; Python replays only `stage == "unpack"` lines, so it passes over `limit` without a code change)

Direct refresh:

- `components/01_csharp_package/description.md` — refreshed because `Packbin.cs` (`Scheme<T>.WithLimits`, `MaxRounds`, `MaxSlots`, `BinaryPacker.Default*`), `Scope.cs` (`RoundBudget`), `Walker.cs`, `Walker.Counted.cs` and `Walker.Rounds.cs` (`SlotsPerRound`) changed. Changed by AZ-2216
- `components/02_typescript_package/description.md` — refreshed because `index.ts` (`withLimits`, `SchemeLimits`, defaults), `kinds.ts` (`ViewCursor`) and `walker.ts` (`refuseRound`) changed. Changed by AZ-2217
- `components/06_java_package/description.md` — refreshed because `Scheme.java` (`withLimits`), `Cursor.java` (new), `Rounds.java` and the unpack methods of `Walker.java`, `Containers.java`, `VarFields.java` and `BinaryPacker.java` changed. Changed by AZ-2218
- `components/04_rust_package/description.md` — refreshed because `field/map_scheme.rs`, `scheme/mod.rs`, `field/mod.rs` and `walk/unpack.rs` changed and `lib.rs` exports `DEFAULT_MAX_ROUNDS` and `DEFAULT_MAX_SLOTS`. Changed by AZ-2219
- `components/01_csharp_package/tests.md`, `02_typescript_package/tests.md`, `04_rust_package/tests.md`, `06_java_package/tests.md` — a Round Limits section each, because `RoundLimitTests.cs`, `round-limits.test.ts`, `round_limits_tests.rs` and `RoundLimitsTest.java` are new and the hostile `limit` stage is replayed in the four packages. Changed by AZ-2216 to AZ-2220
- `components/03_python_package/description.md` and `components/05_cpp_package/description.md` — one paragraph each: no round limit and why (AZ-2220 README). Triggered by the same `cases.txt` change, which both skip
- `components/05_cpp_package/tests.md` — the hostile-vector row counted every case; C++ runs 17 of the 19 since `hostile_host_tests.cpp` skips the `limit` stage
- `module-layout.md` — the test files and round-limit files of the four packages, `Cursor.java`, the `limit` stage of `fixtures/hostile`, the pins files, `docker-compose.publish.yml`, `publish-pins.test.sh` and `publish-readonly.test.sh`, and the 500-line note (`publish-phases.test.sh` is exactly 500, no longer 486)

Cross-cutting refresh:

- `architecture.md` — principle on hostile input (memory of rounds is set by the scheme limits in four packages; C++ and Python need none) and the publish paragraph (read-only containers). Seam: the unpack walk has a per-call budget; the publish containers are read-only
- `system-flows.md` — F2: description and one error row for a round past a limit; F3: description (containers mount the repo read-only)
- `deployment/ci_cd_pipeline.md` — one paragraph for the pins (the read-only paragraph was already added by the AZ-2215 worker and verified against `publish-lib.sh`, `docker-compose.publish.yml` and `publish-readonly.test.sh`)
- `deployment/containerization.md` and `_docs/04_deploy/containerization.md` — the publish containers use the six services with `docker-compose.publish.yml`
- `_docs/04_deploy/docker_stack.md` — said the only compose file is `docker-compose.test.yml`; `docker-compose.publish.yml` is the second file, passed only by `publish_container`
- `_docs/04_deploy/packages.md` — build phase: the read-only repo and the `/out/artifacts/<lang>` mount
- `_docs/04_deploy/deploy_scripts.md` — `publish_container`, `tool-pins.txt` and `tool-pin.sh`
- `_docs/04_deploy/ci_cd_pipeline.md` — only the read-only paragraph, narrowed: the gate copies the TypeScript driver only when `node_modules` is absent (`publish-position.sh`). The Pins section was verified against `tool-pins.txt`, `tool-pin.sh`, `publish-lib.sh` and `publish-pins.test.sh`; `loop_end_merge: main` and `Post-deploy polling (agent configuration)` are untouched
- `tests/test-data.md` — the hostile row said 17 packets; the file holds 19 since AZ-2220 (a contradiction with `cases.txt`, fixed in passing)
- `tests/blackbox-tests.md` — FT-X-01 said four corrupted copies; `cases.test.sh` builds nine and a README copy without a section (stale since AZ-2220). The 19 and 17-of-19 counts in FT-X-01 and FT-X-04 were verified, not changed

Checked, not changed:

- `interaction-risks.md` — the token-lifetime row stays; the loop adds no material interaction risk (a limit refusal and a read-only mount are not new interactions between flows)
- `adr/*` — out of scope
- `data_model.md`, `glossary.md`, `contracts/*` — no entity, term or contract changed
- `risk_mitigations.md` — iteration 01 register, closed
- `deployment/deployment_procedures.md`, `deployment/environment_strategy.md`, `deployment/observability.md`, `_docs/04_deploy/deployment_procedures.md`, `environment_strategy.md`, `observability.md` — they name no compose file, pin or container mount
- `tests/environment.md` (docker-compose outline) and other `tests/*` — test specs and an outline, not the build stack; test-spec sync was not in the plan
- `components/*/tests.md` for Python — no test file of this loop belongs to it (its README test is unchanged)
- `README.md` — updated by AZ-2220; read for the facts above, not edited
- `_docs/00_problem/*` — no input, AC or restriction changed
- `_docs/02_task_plans/**`, `_docs/04_refactoring/**`, `_docs/04_deploy/reports/*`, `FINAL_report.md` and earlier ripple logs — dated records
- Not written by this pass, by instruction: `_docs/05_security/`, `_docs/loops/`, `_docs/03_implementation/`, `_docs/06_metrics/`
