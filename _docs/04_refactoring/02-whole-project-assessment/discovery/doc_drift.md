# Documentation drift

**Run**: `02-whole-project-assessment` (Quick Assessment, Phase 1, read-only)
**Tree**: `loop/10-cpp-microcontroller` at `d108141`
**Scope**: `README.md`, `_docs/00_problem/*`, `_docs/01_solution/*`, `_docs/02_document/*` (architecture, system-flows, module-layout, glossary, data_model, components, contracts, tests, deployment, ADRs), `_docs/04_deploy/*` — against the code in the six packages and the CI/publish scripts.
**Method**: read each doc; check each factual claim about API, files, registries, CI and errors against the code (`grep` + reads). Loop 10 changed 119 files and touched **no file under `_docs/02_document/`** (`git diff --stat d346cbd HEAD`), so every C++ statement there predates the allocation-free core.

**Severity**: High = a reader following the doc writes code or makes a release decision that fails (wrong API, a gate that does not exist, an accepted ADR the code contradicts). Medium = an incomplete or stale description of current behavior that misleads planning or testing. Low = stale wording, naming, or a historical statement.

## Drift table

| # | Doc file:line | Claim | Actual code evidence | Severity |
|---|---------------|-------|----------------------|----------|
| 1 | `_docs/02_document/components/05_cpp_package/description.md:19-21` | C++ API is `Scheme`, `BinaryPacker::pack` → bytes, `BinaryPacker::unpack` → row or error | `BinaryPacker` removed; `constexpr auto s = scheme<T>(…)`, `pack(s, row, out, cap)` → `Result`, `unpack(s, data, len, row)` / `unpack(data, len, on(…)…)` (`cpp/include/packbin/codec.hpp:72,97,107,158`; `README.md:335-358` migration table) | High |
| 2 | `…/05_cpp_package/description.md:25-39` | Input is a name→value map (`Value`); output `Bytes`; `ShortPacket{field: string, needed, left}` | Struct rows with `Opt<T>`, `View`, `Text<N>`, `Array<T,N>`, `Entry<V>`; `Result{error, offset, field (int order id), needed}` (`cpp/include/packbin/core.hpp:13-34`) | High |
| 3 | `…/05_cpp_package/description.md:45-49` | `load` → a session or nothing; `start` takes none or 16 bytes and returns 16 bytes; `pack` returns a payload | `bool load(seed, len)`, `bool start(nonce, len)`, `bool start(RandomFn, ctx, nonce_out)`, `Result pack(s, row, out, cap)`, `unpack` removes the pad in place (`cpp/include/packbin/session.hpp:31-74`) | High |
| 4 | `…/05_cpp_package/description.md:69-70`; `_docs/02_document/architecture.md:22`; `system-flows.md:99,104,114,120`; `glossary.md:36`; `data_model.md:11,22`; `_docs/01_solution/languages.md:38`; `_docs/00_problem/acceptance_criteria.md:17` (AC-8) | A short packet returns an error and **0 values**; the error **names** the field and the bytes **remaining** | C++ `unpack(scheme, …, row)`: "On failure the fields read before the failure keep their values" (`codec.hpp:104-105`); the error carries the order id and byte offset, not a name or bytes-left (`core.hpp:24-31`). The feature restriction approves the id (`_docs/02_task_plans/cpp-microcontroller/restrictions.md:15`), but the project-level AC-8 and the docs above carry no C++ exception (unlike `restrictions.md:6` and AC out-of-scope, which do) | High |
| 5 | `_docs/02_document/adr/002_publish-from-version-tag.md:18,31,44`; `architecture.md:69,119-124,150,178`; `_docs/00_problem/restrictions.md:31`; `tests/traceability-matrix.md:139` (R-19) | Trusted publishing (OIDC) "not selected"; registry credentials stay in the CI secret store; long-lived tokens rotated by hand | OIDC is used for NuGet (`publish.yml:24-27` `NuGet/login@v1`), crates.io (`crates-token.sh` exchange/revoke), PyPI (`publish-registries.sh:153-200` mint-token) and npm (`publish-registries.sh:202-213`, `npm@11`). ADR-002 is `Accepted` and not superseded | High |
| 6 | `deployment/deployment_procedures.md:5`; `_docs/04_deploy/deployment_procedures.md:3`; `system-flows.md:18,138`; `tests/environment.md:73` | Tests green on the commit is a release step; the test stage runs "before a tag is allowed to publish" | `publish.yml` has no dependency on `test.yml` (no `needs`, no `workflow_call`); a tag publishes after the position gate alone | High |
| 7 | `README.md:329`; `adr/003_cpp-vcpkg-git-registry.md:24`; `_docs/04_deploy/packages.md:26` | `vcpkg install packbin` gives a usable package; "vcpkg port `packbin` … → target `packbin`" | The portfile installs headers and copies `src/` to `share/packbin/src`; it builds nothing and exports no CMake target (`publish-registries.sh:95-100`), while `pack_table`/`unpack_table`/session live in `cpp/src/core/*.cpp` | High |
| 8 | `_docs/00_problem/acceptance_criteria.md:28` (AC-13); `restrictions.md:29`; `adr/002…:24`; `deployment/ci_cd_pipeline.md:10`; `deployment/deployment_procedures.md:7`; `_docs/04_deploy/packages.md:19-32`; `architecture.md:32-42,119-124`; `system-flows.md:150,169,183`; `tests/blackbox-tests.md:150-166`; `tests/traceability-matrix.md:19` | Six registries / "exactly 6 packages" | The tag also publishes PlatformIO, the ESP-IDF component registry and an Arduino branch + `arduino-<version>` tag (`publish-registries.sh:296-298` → `publish-embedded.sh:96-99`): up to 9 targets. `languages.md:19` already lists them | Medium |
| 9 | `adr/002…:39`; `acceptance_criteria.md:27` (AC-12) | A tag cannot ship some languages and skip one; one package per present language | Python and Rust are skipped when their credential is missing, and PlatformIO/ESP-IDF/Arduino are skipped when theirs is; the job stays green (`publish-registries.sh:43-59`; `publish-embedded.sh:47-58,73-76`) | Medium |
| 10 | `deployment/ci_cd_pipeline.md:12` | "Lint and the byte tests run in the test stage" | No lint or type-check step: `test.yml` runs suites only; `typescript/package.json:18` is `node --test` (tsc never runs); no clippy, `dotnet format`, ruff, shellcheck | Medium |
| 11 | `deployment/ci_cd_pipeline.md:5-10`; `_docs/04_deploy/ci_cd_pipeline.md:9` | Test stage = the six suites | `test.yml:46-57` adds the `embedded` job (QEMU, ESP-IDF, examples, ~40 min cold) | Medium |
| 12 | `deployment/containerization.md:3-14`; `_docs/04_deploy/containerization.md:3` | Six images, "current stable" | Plus `cpp-embedded` (built from `ubuntu:24.04`) and `cpp-embedded-esp` (`espressif/idf:v5.3.2`) (`docker-compose.test.yml:80-103`) | Medium |
| 13 | `tests/environment.md:86` | "Hardware dependencies found: none" | Embedded targets run on QEMU Cortex-M (`mps2-an385/386`) and `qemu-s390x`, plus ESP-IDF builds (`cpp/embedded/run.sh:36-57`) | Medium |
| 14 | `tests/environment.md:75` | Timeout 5 minutes for the whole suite | Embedded job ~40 min cold (baseline); `test.yml` sets no `timeout-minutes` | Medium |
| 15 | `tests/environment.md:12-19,38-49` | Services `csharp-tests` … `java-tests` | Services are `csharp` … `java`, `cpp-embedded`, `cpp-embedded-esp` (`docker-compose.test.yml`) | Low |
| 16 | `tests/environment.md:31`; `data_model.md:30`; `tests/test-data.md:24` | Fixture volume / seed is `results_report.md` | CI reads `fixtures/golden.hex` (`docker-compose.test.yml:13`, `run-suite.sh:6`, `publish-gate.sh:9`) | Low |
| 17 | `tests/traceability-matrix.md:36-37` (FT-H-01, FT-H-02) | Six-language handoffs "Covered" | Executed only by `.github/workflows/language-pair.sh`, which no workflow runs (`_docs/loops/loop09/test-run09.md:12`) | Medium |
| 18 | `tests/traceability-matrix.md` (whole file) | Traces project and earlier feature ACs | No rows for `cpp-microcontroller` AC-1…AC-13 (no-heap link check, QEMU vectors, big-endian, size/stack budgets, packaged examples) | Medium |
| 19 | `components/05_cpp_package/tests.md:14,194,268-280,295,353,389` | AC-8 "names field … returns 0 values"; ST-01 "returns no value"; only the vcpkg archive | See #4 and #8; no embedded, compile-fail (`cpp/Makefile:25-33`) or QEMU tests listed | Medium |
| 20 | `components/0{1..6}_*/tests.md` | — | Six 423-line copies differing only in registry names (diff of C# vs C++ = 6 lines); the C++ copy did not follow loop 10 | Low |
| 21 | `module-layout.md:84-87,145` | C++ public API is `cpp/include/packbin/packbin.hpp`; everything else internal | Ten public headers (`codec.hpp`, `session.hpp`, `core.hpp`, `fields*.hpp`, `order.hpp`, `table.hpp`, `os_random.hpp`); `cpp/arduino/packbin.h` includes `codec.hpp` and `session.hpp` directly; `src/core/values.hpp` is the internal header | Medium |
| 22 | `module-layout.md:80-92,119-126`; `module-layout.md:6` (Last Updated 2026-09-22) | `cpp/` and workflows described as above | Not mapped: `cpp/embedded/`, `cpp/examples/`, `cpp/arduino/`, `cpp/library.json`, `cpp/idf_component.yml`, `cpp/CMakeLists.txt`; the 13 CI/publish scripts and the six-language `drivers/` | Medium |
| 23 | `architecture.md:14,53-54,73-78` | C++ "for a C++ program", "current stable"; test containers = six | C++17 freestanding core for host and 32-bit microcontrollers (`restrictions.md:6`); embedded CI images | Medium |
| 24 | `contracts/library/pack-session.md:20-24,32` (Version 1.0.0, status current) | `Load` returns a session; `Start()` draws 16 bytes | C++: `load` returns `bool`; `start` needs a caller `RandomFn` (`session.hpp:35-39`); host passes `packbin::os_random` (`README.md:333`). Contract version not bumped | Medium |
| 25 | `system-flows.md:46-48,64` | Pack error returns "0 bytes" | C++ pack writes into the caller buffer and reports `offset`; the feature AC only promises 0 bytes beyond the reported offset (`cpp-microcontroller/acceptance_criteria.md:35`) | Low |
| 26 | `README.md:322`; `_docs/01_solution/languages.md:19` | Builds for Cortex-M33, nRF52, STM32 | CI covers M0+, M3, M4F, s390x, ESP32-S3/C3/ESP32, RP2040 (Pico build) only (`cpp/embedded/run.sh:39-56`) | Medium |
| 27 | `README.md:328` | ESP-IDF ≥ 5.1 | `idf_component.yml:7` declares `>=5.1`; CI builds on 5.3.2 only | Low |
| 28 | `README.md:327` | Arduino Library Manager: `packbin` | The pipeline pushes an `arduino` branch and tag; listing in Library Manager also needs a one-time entry in the Arduino library registry, which no doc mentions | Low (uncertain) |
| 29 | `README.md` (whole) | — | Install commands appear only for C++ (`README.md:324-329`); none for npm, NuGet, PyPI, crates.io, Maven Central (they exist in `_docs/04_deploy/packages.md:19-26`) | Low |
| 30 | `_docs/01_solution/languages.md:25` | "The first tag waits until all six match" | 13 tags exist (`v0.1.1`…`v0.1.13`) | Low |
| 31 | `_docs/01_solution/languages.md:31` | A short-packet error names the same field string in every language | C++ reports the order id (#4) | Low |
| 32 | `deployment/deployment_procedures.md:6` | The C# and TypeScript bytes match | The gate checks every present language (`publish-gate.sh:34-45`) | Low |
| 33 | `deployment/deployment_procedures.md:15`; `_docs/04_deploy/deployment_procedures.md:9` | Rollback = unlist NuGet, deprecate npm | Nine targets; Maven Central, crates.io, vcpkg/Arduino git refs, PlatformIO and ESP-IDF each need their own step | Low |
| 34 | `deployment/environment_strategy.md:7` | Registries are npmjs.org and nuget.org | Up to nine targets (#8); `_docs/04_deploy/environment_strategy.md:7` says six — the two copies disagree with each other | Low |
| 35 | `_docs/02_document/deployment/*` vs `_docs/04_deploy/*` | — | Two parallel copies of ci_cd_pipeline, containerization, deployment_procedures, environment_strategy, observability with different wording (#34) | Low |
| 36 | `tests/blackbox-tests.md:167` (FT-P-08 max 15 min) | Publish finishes within 15 minutes | Maven polling alone may take 90 × 15 s = 22.5 min (`publish-registries.sh:264-273`) | Low |
| 37 | `.env.example` | Lists six registry tokens for local use | `publish.yml` passes `PLATFORMIO_AUTH_TOKEN`, `IDF_COMPONENT_API_TOKEN`, `GITHUB_TOKEN` (missing from the example) and never passes `NPM_TOKEN`; a laptop publish is forbidden (`restrictions.md:28`) | Low |
| 38 | `_docs/04_deploy/deploy_scripts.md:3` | Publisher runs after `publish-gate.sh` | Accurate. Listed as verified, no drift | — |

## Severity count

| Severity | Rows |
|----------|------|
| High | 7 (#1–#7) |
| Medium | 15 (#8–#14, #17–#19, #21–#24, #26) |
| Low | 15 (#15, #16, #20, #25, #27–#37) |
| Verified (no drift) | 1 (#38) |

## Notes

- `README.md` C++ section (`:278-358`) itself matches the code, including the 0.1.x → now migration table; the drift is in `_docs/`.
- Rows #4, #5, #8 and #9 touch accepted ADRs, ACs or restrictions; fixing them is a decision (supersede ADR-002, add the C++ AC-8 exception, restate AC-12/AC-13 for nine targets), not an edit. They map to change D19 in `scan_ci_docs.md`.
- Row #7 is also a publish logic bug (change D3).
