# Scan — CI, publish, drivers, embedded harness, docs

**Run**: `02-whole-project-assessment` (Quick Assessment, Phase 1, read-only)
**Tree**: `loop/10-cpp-microcontroller` at `d108141`
**Scope**: `.github/workflows/*.yml`, `.github/workflows/*.sh`, `.github/workflows/drivers/**` (excl. `handoff-rust/target`, `csharp/bin`, `csharp/obj`), `docker-compose.test.yml`, `.dockerignore`, `.gitignore`, `.env.example`, `cpp/embedded/**`, `cpp/examples/**`; documentation drift across `README.md` and `_docs/`.
**Method**: full read of every file in scope; `grep` inventories (env vars, literals, `/dev/null`, `|| true`, `case "$lang"`, repo URLs, golden hex, SQL/HTML patterns); lizard 1.24 on drivers and harness; `git log`/`git tag` on publish files; a bash probe for the errexit finding (EM1). `shellcheck` is not installed — manual bash review. The local `.env` was not read.
**Detail**: `components/07_ci_publish.md` (F1–F24), `components/08_drivers_embedded.md` (DR1–DR7, EM1–EM11), `doc_drift.md` (38 rows).

## (a) Smell table S01–S32

| ID | Smell | Result | Evidence (scope) | Change / deferral |
|----|-------|--------|------------------|-------------------|
| S01 | Long Method | found | `publish-inside.sh` one `case` of 100 lines (java branch 50); `publish-registries.sh` `publish_pypi_oidc` 48 lines, `prepare_maven_bundle` 40; `arm.sh` `target_m4f` 50; `handoff-rust` `run` 79 NLOC | D5, D17; drivers deferred (flat dispatch) |
| S02 | Large Class / God module | found (mild) | `publish-registries.sh` 313 lines: credential policy, plan filtering, vcpkg port, PyPI/npm OIDC, Maven sign/zip/upload/poll, dispatch. `publish-gate.test.sh` 403 (under cap) | D5, D7, D17 |
| S03 | Long Parameter List | not_found | shell functions take ≤ 4 positional args (+ flag varargs) | — |
| S04 | Primitive Obsession | found (low) | languages as bare strings in 8 files; publish plan as a text file of names | D9 (one `PACKBIN_LANGS` source); rest accepted for shell |
| S05 | Data Clumps | found | compose: `SRC_ROOT`/`FIXTURE`/`TEST_RESULTS` + 3 volumes repeated ×6; C++ compile tuple (`CXX`, flags, sysroot, 6 sources) ×2; `(root, version, out)` threaded through 4 publish scripts | D9, D11 |
| S06 | Duplicated Code | found | driver build/run ×2 (DR1); C++ source list ×5 (DR2); AC-1 flags ×5 (EM4); version-rewrite snippet ×3, OIDC fetch ×2, npm/PyPI publish ×2, git identity ×2 (F15); golden hex ×4 in CI (F22); position scheme in 12 driver files (DR5); six `tests.md` copies (doc_drift #20); two deployment doc trees (#35) | D9, D10, D17, D21 |
| S07 | Dead Code | found | npm token path unreachable in CI (F13); `WRAPPER_CALLS` tautology (EM3); `PACKBIN_WORK`, `PACKBIN_FIXTURE` set by nothing (F12); `publish.yml:32` `if: success()` redundant; root `.dockerignore` read by no build (the only build context is `cpp/embedded`) | D16; `.dockerignore` rejected (R7) |
| S08 | Speculative Generality | found (note) | test-only knobs in production publish scripts: `PACKBIN_DOCKER`, `PACKBIN_MAVEN_BUNDLE_ONLY`, `PACKBIN_PLAN` | Kept (R8): they let tests run the real scripts |
| S09 | Lazy Class | found (note) | `drivers/rust/` crate (55 lines) and `Position.csproj` exist only to print one packet | D10 |
| S10 | Data Class | n/a | no OO data types in scope beyond driver DTOs | — |
| S11 | Feature Envy | not_found | — | — |
| S12 | Inappropriate Intimacy | found | `publish-gate.test.sh` greps literal source lines of other scripts (F24); embedded scripts share mutable globals across sourced files, `lib.sh` overwrites `run.sh`'s `here` (EM7) | D18; EM7 deferred (low) |
| S13 | Message Chains | n/a | — | — |
| S14 | Middle Man | not_found | `publish-position.sh` dispatches but also builds | — |
| S15 | Divergent Change | found | `publish-registries.sh` changes for any registry; `language-pair.sh` for any language or case | D5, D17 |
| S16 | Shotgun Surgery | found | new C++ core file → 5 lists + a count (DR2, `LESSONS.md:26`); new vector test → Makefile + `vectors_main.cpp` (EM6); new language → ~11 edits across `test.yml` ×2, `publish-lib.sh`, `report-row.test.sh`, `language-pair.sh` ×3, compose, `run-suite.sh`, `publish-position.sh`, `publish-inside.sh`, `publish-registries.sh` | D9 (C++ list); language adapter deferred (R2); EM6 deferred |
| S17 | Switch / type soup | found | six `case "$lang"` dispatchers over the same six names (`run-suite.sh:20`, `language-pair.sh:14`, `publish-position.sh:17`, `publish-inside.sh:14`, `publish-registries.sh:288`, `publish-lib.sh:14`) | D9 merges two; rest deferred (R2) |
| S18 | Temporary Field | found (note) | `CURRENT_TARGET` global set per target (`lib.sh:51`); publish plan file rewritten in place by `skip_unset` | D7 |
| S19 | Parallel Inheritance | found (note) | six handoff + six position drivers (handoff duplication is by design, ADR-001); two deployment doc trees | D10, D21; R1 |
| S20 | Magic number / string | found | Maven poll `90`×`15` s (`publish-registries.sh:264,273`); `timeout 300` (`arm.sh:102`); `checked -eq 5` (`esp.sh:41`); revoke `5` attempts; `arduino-cli` `1.1.1`; golden hex ×4 in CI | D9, D15, D17 |
| S21 | Hardcoded configuration | **INV** found — 46 rows | § (b) | rows map to D-ids or deferrals |
| S22 | String SQL | **INV** 0 hits | § (b) | — |
| S23 | Stringly-typed APIs | found | publish plan text file; Maven state by JSON substring (`publish-registries.sh:269-272`); firmware `KEY value` log protocol parsed by `awk`; `FAIL` substring in `.msg` | EM2 deferred (harness-internal); D5 for Maven |
| S24 | Mutable global SoT | found | host build trees shared into containers (F10, EM9); `/tmp/packbin-handoff-java` reused while stale (DR3); fixed `/tmp` paths | D9, D11 |
| S25 | Silent failure swallow | found | errexit disabled in all embedded targets (EM1, verified); credential-missing registries skipped with exit 0 (F5); revoke failure non-fatal (F18, by design); `run-suite.sh` ignores a `report-row.sh` failure; `publish-gate.sh:39` discards `run_pack` status (fails closed via mismatch) | D1, D7; F18 kept |
| S26 | Circular Dependency | not_found | embedded harness → `stage-arduino.sh` → nothing back; no cycles | — |
| S27 | Framework leak | n/a | — | — |
| S28 | Secret in source | not_found | no credential committed; `.env` gitignored (not read); `::add-mask::` used for minted tokens. Hygiene: tokens on argv, temp npmrc/GPG ring not removed (F17); third-party `NuGet/login@v1` tag-pinned in an `id-token: write` job (F16) | D15 (action SHA pins); F17 deferred (ephemeral runner) |
| S29 | Cognitive / cyclomatic complexity | found | lizard: `handoff.py main` CCN 25, `handoff.ts deepEqual` 17, `Handoff.cs Main` 14, `handoff.cpp main` 13, `Handoff.java userOk` 13 (9 functions > 10); all flat dispatch or equality chains | Deferred (readable; test drivers) |
| S30 | Shotgun resources | found | temp/caches invented per script: `/tmp/packbin-pytest`, `/tmp/packbin-handoff`, `/tmp/packbin-handoff-java`, `/tmp/packbin-position`, `/tmp/packbin-position-rust`, `/tmp/packbin-position-java`; four separate tool venvs (`run-suite.sh`, `publish-registries.sh`, `publish-embedded.sh`, `examples.sh`); outputs in `test-results/`, `.github/workflows/out/`, `cpp/build/embedded/`, `java/out/` | D9, D11, D15 |
| S31 | Embedded HTML | **INV** 0 hits | § (b) | — |
| S32 | Hidden domain rule | found | language presence = a marker file (F23); gate hex = last non-empty stdout line (F23); `FAIL` substring and `expect(` text count decide embedded pass/fail (EM2); which registries are mandatory vs skippable is implicit in `need` vs `skip_unset` (F5); token-vs-OIDC path chosen by which env var is set; driver exit-code contract unwritten (DR7) | D7; EM2/DR7 deferred |

**Totals**: found 22 (S01, S02, S04–S09, S12, S15–S21, S23–S25, S29, S30, S32); not_found 5 (S03, S11, S14, S26, S28); n/a 3 (S10, S13, S27); INV with 0 hits 2 (S22, S31).

## (b) Inventories

### S21 — config in code (46 rows)

Classification: `system` → env/workflow variable or pinned tool manifest; `business` → package/registry metadata owned by the product; `code-ok` → protocol or algorithm constant (reason given); `uncertain` → needs a user decision.

| # | File:line | Symbol / value | Class | Notes | Change / deferral |
|---|-----------|----------------|-------|-------|-------------------|
| 1 | `publish.yml:6` | tag pattern `v*` | code-ok | release contract (ADR-002) | — |
| 2 | `publish.yml:21` | `node-version: "24"` | system | duplicates compose `node:24` | D15 |
| 3 | `publish.yml:23` | `npm@11` | system | floating major in the publish job | D15 |
| 4 | `publish.yml:27` | NuGet `user: zxsanny` | system | account name; same owner in 7 other places (#30) | D17 |
| 5 | `test.yml:11,49`; `publish.yml:16,19,24` | `actions/checkout@v7`, `setup-node@v7`, `NuGet/login@v1` | system | tag pins in an `id-token`/`contents: write` job | D15 |
| 6 | `test.yml:15,40`; `publish-lib.sh:4`; `report-row.test.sh:7`; `language-pair.sh:87,102` | language list `csharp typescript python rust cpp java` | code-ok | product catalog, but 5 copies | D9 |
| 7 | `test.yml:33`; `run-suite.sh:11`; `language-pair.sh:8`; `publish-gate.test.sh:6` | golden hex `4001000065cd1d00a3e1110100` | code-ok | test constant; SoT is `fixtures/golden.hex` | D9 |
| 8 | `language-pair.sh:6,7,9` | `user_hex`, `nested_hex`, `session_hex` | code-ok | test vectors; could live in `fixtures/` | R9 deferral |
| 9 | `docker-compose.test.yml:3` | `mcr.microsoft.com/dotnet/sdk:10.0` | system | restriction: current LTS | deferral R3 |
| 10 | `docker-compose.test.yml:16` | `node:24` | system | current LTS | R3 |
| 11 | `docker-compose.test.yml:29` | `python:3.14` | system | current stable; floor 3.10 untested (F9) | R3; D13 |
| 12 | `docker-compose.test.yml:42` | `rust:1.98` | system | current stable | R3 |
| 13 | `docker-compose.test.yml:55` | `gcc:16` | system | current stable | R3 |
| 14 | `docker-compose.test.yml:68` | `eclipse-temurin:26-jdk` | uncertain | non-LTS JDK compiles the published jar (F1) | D2 |
| 15 | `docker-compose.test.yml:83` | `packbin-embedded:local` | code-ok | local build tag | — |
| 16 | `docker-compose.test.yml:94` | `espressif/idf:v5.3.2` | system | exact pin; floor `>=5.1` untested | D13 note |
| 17 | `docker-compose.test.yml:7-14` ×6 | `SRC_ROOT`, `FIXTURE`, `TEST_RESULTS`, volumes | system | repeated per service | D11 |
| 18 | `cpp/embedded/Dockerfile:4,9-12` | `ubuntu:24.04`; apt packages unversioned | system | toolchain versions follow the Ubuntu archive | D15 (record versions in report) |
| 19 | `publish-gate.test.sh:207` | `ubuntu:24.04` | system | test fallback image | — |
| 20 | `run-suite.sh:35,38` | `/tmp/packbin-pytest`; `pip install pytest` unpinned | system | | D15 |
| 21 | `publish-registries.sh:14`; `publish-inside.sh:10` | default version `0.1.0` | system | silent default; `publish-embedded.sh:17` requires it | D16 |
| 22 | `publish-registries.sh:16-17`; `publish-gate.sh:11`; `publish-inside.sh:104` | `.github/workflows/out` | code-ok | build output path | — |
| 23 | `publish-registries.sh:72` | container `PACKBIN_OUT=/src/.github/workflows/out` | system | ignores host override (F19) | D17 |
| 24 | `publish-registries.sh:86-93` | vcpkg.json description, homepage, license | business | package metadata; also in `library.json`, `idf_component.yml`, POM, `package.json`, `.csproj`, `Cargo.toml`, `pyproject.toml` (per-registry manifests are their own SoT) | D17 (scripts only) |
| 25 | `publish-registries.sh:95-100` | portfile body | code-ok | port definition; but builds nothing (F2) | D3 |
| 26 | `publish-registries.sh:130`; `publish-embedded.sh:72` | `https://github.com/zxsanny/packbin.git` defaults | system | env override exists | D17 |
| 27 | `publish-registries.sh:137-138`; `publish-embedded.sh:84-85` | git identity `packbin <packbin@users.noreply.github.com>` | system | ×2 | D17 |
| 28 | `publish-registries.sh:167`; `publish-inside.sh:42` | `pip install build twine` unpinned | system | publish-path tools | D15 |
| 29 | `publish-registries.sh:183`; `crates-token.sh:4` | PyPI mint-token, crates.io trusted-publishing endpoints | code-ok | registry protocol | — |
| 30 | `publish-registries.sh:262,267` | Central upload/status URLs, `publishingType=AUTOMATIC` | code-ok | registry protocol; AUTOMATIC asserted by test | — |
| 31 | `publish-registries.sh:264,273` | `seq 1 90`, `sleep 15` | system | Maven poll budget; unnamed | D17 |
| 32 | `publish-inside.sh:20` | `https://api.nuget.org/v3/index.json` | code-ok | registry protocol | — |
| 33 | `publish-inside.sh:28` | `//registry.npmjs.org/:_authToken` | code-ok | dead path in CI (F13) | D16 |
| 34 | `publish-inside.sh:69-102` | POM: groupId `io.github.zxsanny`, name, description, URLs, license, developer, SCM | business | the only Java package manifest (no `pom.xml` in `java/`); XML heredoc in a shell script | D17 (move to a template file beside `java/`) — uncertain owner, ask |
| 35 | `crates-token.sh:5,54-55` | user agent; 5 attempts; pause 5 s | code-ok / system | pause overridable by env | — |
| 36 | `publish-embedded.sh:51,60` | `pip install platformio`, `idf-component-manager` unpinned | system | publish-path tools | D15 |
| 37 | `publish-embedded.sh:63` | `--namespace zxsanny --name packbin` | business | registry coordinates; also `examples/esp_idf/main/idf_component.yml:2`, `examples.sh:95` | D17 |
| 38 | `language-pair.sh:28,40`; `publish-position.sh:31,35,47` | fixed `/tmp/packbin-*` paths | system | bash rule: `mktemp` | D9 |
| 39 | `language-pair.sh:30,34-36`; `publish-position.sh:37,41-43` | C++ flags, `CXX` default (`c++` vs `g++`), 6-file source list | system | duplicates `cpp/Makefile:1-11` | D9 |
| 40 | `cpp/embedded/lib.sh:13-15` | `core_flags`, `c_flags`, `core_srcs` | system | duplicates Makefile (EM4, DR2) | D9 |
| 41 | `cpp/embedded/lib.sh:18-19` | `flash_budget=8192`, `stack_budget=512` | code-ok | AC-5 pass lines, named and cited | — |
| 42 | `cpp/embedded/arm.sh:5-6,102` | link flags, heap wraps, `timeout 300` | code-ok / system | timeout unnamed | D1 (name it while touching) |
| 43 | `cpp/embedded/esp.sh:33,41` | flag list; expected `5` sources | system | duplicates lib.sh; magic count | D9 |
| 44 | `cpp/embedded/esp/CMakeLists.txt:15`; `esp/main/CMakeLists.txt:7` | AC-1 flags | code-ok | CMake needs them; flag audit in `esp.sh` verifies | — |
| 45 | `cpp/embedded/examples.sh:15,18,26,64-66` | platformio unpinned; `arduino-cli` 1.1.1 URL without checksum; espressif index URL ×2; `esp32:esp32` core unpinned | system | | D15 |
| 46 | `.env.example:1-6` | six token names | system | stale list; supports a forbidden laptop publish | D16 |

Not hits (scanned, excluded): `cpp/library.json:3`, `cpp/idf_component.yml:1`, `cpp/arduino/library.properties:2` (`0.1.0`, rewritten at publish time; package scope); driver seeds/nonces/values (test fixtures); `handoff.cpp:132 kMax` (buffer size); `java/test.sh:16-20` macOS JDK search paths (Java package scope — reported to the package scan).

**Totals**: 46 rows — system 27, code-ok 15, business 3, uncertain 1 (#14; #34 is business with an owner question). Mapped: D2, D3, D9, D11, D13, D15, D16, D17; deferred R3, R9.

### S22 — string SQL

**0 hits.** Scan: `grep -rniE "select .* from|insert into|update .* set |delete from|\.execute\(|executescript|sqlite|psycopg|SqlCommand|FromSqlRaw"` over `.github/workflows` (incl. drivers), `docker-compose.test.yml`, `cpp/embedded`, `cpp/examples` (excluding `target/`, `bin/`, `obj/`). The product has no database.

### S31 — embedded HTML

**0 hits.** Scan: `grep -rniE "<!doctype|<html|text/html|<body"` over the same paths. Near miss recorded: `publish-inside.sh:75-103` generates the Maven POM (XML, not HTML) from a heredoc — tracked as S21 #34.

## (c) Logical flow findings

| # | Finding | Class | Evidence | Severity | Change |
|---|---------|-------|----------|----------|--------|
| LF1 | Java jar compiled for JDK 26 bytecode (no `--release`) and published to Maven Central | logic bug | `publish-inside.sh:67` in `eclipse-temurin:26-jdk` | High (verify `javap -v` on the published jar) | D2 |
| LF2 | vcpkg port is not buildable/linkable; README promises a `packbin` target | logic bug | `publish-registries.sh:95-100`; `codec.hpp:65-67`; `README.md:329` | Medium-High | D3 |
| LF3 | Embedded targets run with errexit disabled (called under `\|\|`); unchecked commands continue; the `FAIL`-grep is the workaround | logic bug | `run.sh:31-33`, `lib.sh:54-65`; probe confirms `set -e` inside the subshell has no effect in that context | Medium | D1 |
| LF4 | Publish is not gated on the test workflow, though docs make "tests green" a release step | design contradiction | `publish.yml`; `deployment_procedures.md:5`; `system-flows.md:138` | Medium | D4 |
| LF5 | Gate ordering is correct (golden check → credentials → writes; fails closed on driver build failure) but uploads are sequential and non-atomic; the slowest, riskiest artifact (signed Maven bundle) is built last, after five registries were written | design / logic | `publish-registries.sh:284-313` | Medium-High | D5 |
| LF6 | A failed publish cannot be resumed: `npm publish`, `twine upload`, `cargo publish` fail on an existing version; each failure costs a new patch tag (`v0.1.1`–`v0.1.8` in two days) | logic bug | `publish-inside.sh:29,44,57`; `publish-registries.sh:199,211`; `git tag` | Medium | D6 |
| LF7 | Missing credentials silently shrink the release (Python, Rust, PlatformIO, ESP-IDF, Arduino) | design contradiction | `publish-registries.sh:43-59`; `publish-embedded.sh:47-76`; ADR-002:39; AC-12 | Medium | D7 |
| LF8 | Code uses OIDC trusted publishing for four registries; ADR-002, R-19 and architecture say it was rejected | documentation drift / design contradiction | doc_drift #5 | High (doc) | D19 |
| LF9 | Six-language handoff and session ring (`language-pair.sh`) never run in CI | CI coverage gap | `test.yml`; `test-run09.md:12` | Medium | D8 |
| LF10 | No coverage, lint, or type check in CI; declared minimum runtimes untested | CI coverage gap | `test.yml`; F8, F9 | Medium | D13, D14 |
| LF11 | Host build outputs shared into Linux containers (stale binary runs) | logic bug (local) | F10; `LESSONS.md:30` | Medium | D11 |
| LF12 | Embedded job: ~40 min cold on every push and every PR (twice on PR branches), no cache, no path filter, image rebuilt each run, no timeout | performance waste | `test.yml:46-57`; baseline | Medium | D12 |
| LF13 | Suites run serially in one job and stop at the first failing language | performance waste / feedback gap | `test.yml:36-42` | Low-Medium | D22 |
| LF14 | `publish-gate.test.sh` builds every driver 17× cold and copies build caches 3× | performance waste | `publish-gate.test.sh:118-177` | Low-Medium | D18 |
| LF15 | `language-pair.sh`: stale Java classes reused; C++ driver recompiled 8× | logic bug / performance waste | DR3, DR4 | Low-Medium | D9 |
| LF16 | `run_inside` ignores a host `PACKBIN_OUT` override for the Java bundle | latent logic bug | F19 | Low | D17 |
| LF17 | The gate checks drivers built from source, not the uploaded artifacts (except the embedded examples, which build from packaged layouts) | design gap | §2 of `07_ci_publish.md` | Low | Noted in D5 (verify built artifacts in phase 1) |
| LF18 | C++ partial-row-on-failure and order-id errors are not reflected in project AC-8 / architecture / glossary | documentation drift | doc_drift #4 | High (doc) | D19, D20 |
| LF19 | CI coverage per language: C#, TS, Python, Rust, Java = unit suites + golden gate; C++ = unit + compile-fail + embedded; cross-language handoffs = manual only; TypeScript type check = none; coverage = none anywhere | summary | `test.yml`, `run-suite.sh` | — | D8, D13, D14 |

## (d) Candidate changes

Points: 1 / 2 / 3 / 5. Risk: low / medium / high.

### D1: Run embedded targets with errexit in force
- **File(s)**: `cpp/embedded/run.sh`, `cpp/embedded/lib.sh`, `cpp/embedded/arm.sh`
- **Problem**: `run_target` is called from an `||` list, so `set -e` is ignored inside every target function, including the explicit `set -euo pipefail` in its subshell (verified with a probe). A failing command without `|| fail` is skipped; the `grep FAIL .msg` check papers over it.
- **Change**: Invoke each target outside a condition context (capture its status without `||`), so a failing command ends that target with FAIL; keep `note`/`fail` for the summary text; name the QEMU timeout.
- **Rationale**: S25; a harness that can pass after a failed step defeats feature AC-13 ("every target in CI").
- **Constraint Fit**: Preserves the one-row-per-target report and exit codes (0/1/2) in `run.sh:10`. No product code touched.
- **Risk**: low (may surface a currently hidden failure — that is the point)
- **Dependencies**: None
- **Points**: 2

### D2: Publish Java bytecode for a declared minimum JDK
- **File(s)**: `.github/workflows/publish-inside.sh`, `java/test.sh`, `.github/workflows/publish-gate.test.sh`
- **Problem**: The jar on Maven Central is compiled by JDK 26 with no `--release`, so its class files need Java 26; README/architecture name Android and "other Java programs" as consumers.
- **Change**: Compile (tests and publish) with `--release <floor>` and assert the class-file version in the Maven bundle check. The floor is a user decision (e.g. 17 or 11 for Android D8).
- **Rationale**: LF1. A library on a public registry must load on the runtimes it claims.
- **Constraint Fit**: Restriction "Java uses the current stable toolchain" still holds (javac 26 with `--release`). AC-12/AC-16 unchanged.
- **Risk**: medium (library source may use language features newer than the chosen floor)
- **Dependencies**: None — **needs user decision (floor version)**
- **Points**: 2

### D3: Make the vcpkg port build the library, or document it as sources-only
- **File(s)**: `.github/workflows/publish-registries.sh` (`stage_vcpkg_port`), `cpp/CMakeLists.txt` (install/export rules — C++ package scope, coordinate with that scan), `README.md:329`, ADR-003
- **Problem**: The port installs headers and copies sources into `share/`; nothing compiles `src/core/*.cpp`, no CMake config is exported, so `vcpkg install packbin` + `find_package` fails and README's "target `packbin`" is untrue.
- **Change**: Portfile configures and installs `cpp/CMakeLists.txt` (`vcpkg_cmake_configure/install`, `vcpkg_cmake_config_fixup`, LICENSE as copyright); add a CI check that builds a consumer through the port from the staged registry.
- **Rationale**: LF2; AC-12 "publishes 1 package per language … installable".
- **Constraint Fit**: ADR-003 (git registry push) unchanged; bytes unchanged.
- **Risk**: medium
- **Dependencies**: None
- **Points**: 3

### D4: Require the test workflow before publishing
- **File(s)**: `.github/workflows/test.yml`, `.github/workflows/publish.yml`, `publish-gate.test.sh` (`static_checks`)
- **Problem**: A tag publishes after the position gate alone; tests on the tagged commit are a manual precondition.
- **Change**: Make `test.yml` callable (`workflow_call`) and run it as a `needs:` job of `publish.yml`, so publish starts only when every suite and the embedded job pass on that commit.
- **Rationale**: LF4; AC-11/AC-14 intent; docs already state it.
- **Constraint Fit**: Test job still holds no secrets (secrets are scoped to the publish job). Publish takes longer by the test time.
- **Risk**: low
- **Dependencies**: D12 (keeps the added time reasonable)
- **Points**: 2

### D5: Build and verify every artifact before the first upload
- **File(s)**: `.github/workflows/publish-registries.sh`, `publish-inside.sh`, `publish-embedded.sh`
- **Problem**: Each registry is built and uploaded in turn; the Maven bundle is built, signed and zipped only after five uploads, so a late failure leaves a partial release.
- **Change**: Split publish into a build phase (nupkg, npm tarball, wheel/sdist, `cargo package`, signed Maven bundle, vcpkg/Arduino trees, PlatformIO/IDF archives) that completes for every planned target before any write, then an upload phase that only transmits. Optionally run the position driver against the built artifacts.
- **Rationale**: LF5, LF17; ADR-002 "A bad … check cannot ship five languages and skip one".
- **Constraint Fit**: Gate order and AC-14 preserved; no new registry or credential.
- **Risk**: medium
- **Dependencies**: D7
- **Points**: 3

### D6: Make a re-run of the same tag complete a partial publish
- **File(s)**: `.github/workflows/publish-registries.sh`, `publish-inside.sh`
- **Problem**: npm, PyPI and crates.io uploads fail when the version already exists, so a failed run cannot be retried; each failure has cost a new patch tag.
- **Change**: Before each upload, check whether that exact version is already published (registry query) and skip it with a logged line; `twine --skip-existing`; treat Maven `PUBLISHED` for the same version as done.
- **Rationale**: LF6; the rollback doc already forbids force-pushing a tag.
- **Constraint Fit**: Registries stay immutable; nothing is overwritten.
- **Risk**: medium
- **Dependencies**: D5
- **Points**: 3

### D7: Declare which registries are required
- **File(s)**: `.github/workflows/publish-registries.sh`, `publish-embedded.sh`, `publish-lib.sh`
- **Problem**: Mandatory vs optional registries are implicit (`need` for NuGet/Maven, silent `skip` for Python, Rust and the three embedded targets); a release can quietly miss packages.
- **Change**: One explicit list of publish targets with required/optional; a missing credential for a required target fails before any write; optional skips are written to the job summary as warnings.
- **Rationale**: LF7, S32, S25; AC-12.
- **Constraint Fit**: Gate unchanged; which targets are optional is a **user decision**.
- **Risk**: low
- **Dependencies**: None
- **Points**: 2

### D8: Run the language-pair ring in CI
- **File(s)**: `.github/workflows/test.yml`, `.github/workflows/language-pair.sh`
- **Problem**: The six-language handoffs (user, nested, session) and the per-language position run only by hand; traceability marks FT-H-01/02 as covered.
- **Change**: Add a job that provides the six toolchains at the compose versions (setup actions or one purpose-built image) and runs `language-pair.sh`, writing a report row.
- **Rationale**: LF9; AC-3 and the session ring.
- **Constraint Fit**: No secrets; versions match `docker-compose.test.yml`.
- **Risk**: medium (toolchain parity)
- **Dependencies**: D9
- **Points**: 3

### D9: One driver build path and one C++ source list
- **File(s)**: `.github/workflows/language-pair.sh`, `publish-position.sh`, `publish-lib.sh`, `cpp/embedded/lib.sh`, `cpp/embedded/esp.sh`, `test.yml`, `run-suite.sh`
- **Problem**: Driver build/run is written twice and has diverged (CXX default, Java cache, Rust target dir, fixed `/tmp` paths); the C++ core source list is in 5 places plus a magic count; the language list in 5; the golden hex in 4.
- **Change**: Shared `driver_build`/`driver_run` functions in `publish-lib.sh` used by both scripts (mktemp outputs, Java rebuilt when sources change, C++ built once per run); C++ sources and flags read from `cpp/Makefile` via the existing `print-var.mk` (as `vector_tests` already does); `esp.sh` derives its count and flag list from `lib.sh`; CI scripts read `fixtures/golden.hex` and `PACKBIN_LANGS`.
- **Rationale**: S06, S16, S24, DR1–DR4, EM4–EM5; `LESSONS.md:26`.
- **Constraint Fit**: Same drivers, same bytes; gate behavior unchanged. `cpp/CMakeLists.txt` keeps its own list (CMake consumers) — out of this change.
- **Risk**: medium (the gate depends on these scripts; `publish-gate.test.sh` covers it)
- **Dependencies**: None
- **Points**: 3

### D10: Fold the position drivers into the handoff drivers
- **File(s)**: `.github/workflows/drivers/**`, `publish-position.sh`
- **Problem**: Six position drivers, a Rust crate and a second csproj (with the dual-output workaround) repeat the position scheme each handoff driver already holds.
- **Change**: Add a `pack-position` command to each handoff driver; the gate calls it; delete the six position drivers, `drivers/rust/`, `Position.csproj`; align exit codes (missing argument = 2) across drivers.
- **Rationale**: S06, S09, DR5, DR7.
- **Constraint Fit**: ADR-001 hand-written lists preserved (one per language instead of two); golden check unchanged.
- **Risk**: medium (publish gate path)
- **Dependencies**: D9
- **Points**: 3

### D11: Keep container build outputs out of the host tree
- **File(s)**: `docker-compose.test.yml`
- **Problem**: `./:/src` exposes host `cpp/build`, `rust/target`, `csharp/**/obj`, `typescript/node_modules` and driver outputs to Linux containers (stale macOS binary runs; root-owned files on the host). Env and volumes are repeated ×6.
- **Change**: Per-service volumes over the build/output directories (named volumes for the embedded tool caches) and one YAML anchor for the shared env/volumes.
- **Rationale**: LF11, S24, S05; `LESSONS.md:30`.
- **Constraint Fit**: No published port, read-only fixture mount kept.
- **Risk**: low
- **Dependencies**: None
- **Points**: 2

### D12: Cut embedded CI cost
- **File(s)**: `.github/workflows/test.yml`, `cpp/embedded/examples.sh`
- **Problem**: ~40 min cold per run, on every push and every PR, with no cache, no path filter, no timeout.
- **Change**: Cache PlatformIO/Arduino/pip directories and the embedded image layers; run the embedded job only when `cpp/**`, the harness or the workflow change (always on tags); `concurrency` with cancel-in-progress; `timeout-minutes`.
- **Rationale**: LF12; baseline observation 5.
- **Constraint Fit**: Feature AC-13 (every target in CI) still holds for every change that can affect the targets and for every tag (D4).
- **Risk**: low
- **Dependencies**: D15 (pinned versions make cache keys stable)
- **Points**: 3

### D13: Add a lint and type-check stage
- **File(s)**: `.github/workflows/test.yml`, `run-suite.sh` (or a new job)
- **Problem**: No lint or type check runs; the docs say it does; TypeScript's `tsc` is installed and never run; shell scripts have no shellcheck.
- **Change**: `tsc --noEmit`; `cargo clippy -D warnings` + `cargo fmt --check`; `dotnet build -warnaserror` (+ `dotnet format --verify-no-changes`); a pinned Python linter; `javac -Xlint:all -Werror`; pinned shellcheck over `*.sh`. Fix findings only where they block (quality-thresholds: 0 Critical/High).
- **Rationale**: LF10; doc_drift #10; coderule quality gates.
- **Constraint Fit**: Test containers stay "current stable"; no product behavior change.
- **Risk**: medium (first run will report existing findings)
- **Dependencies**: None — new tools → Complexity Budget Check per language
- **Points**: 3

### D14: Collect coverage
- **File(s)**: `run-suite.sh`, `docker-compose.test.yml`, `test.yml`, per-package test configs
- **Problem**: Coverage is measured nowhere, so the 75 % / 90 % thresholds cannot be checked.
- **Change**: Collect and publish per-language coverage reports first (coverlet already referenced; `node --experimental-test-coverage`; pytest-cov; cargo-llvm-cov; gcov; a Java agent), then gate at the thresholds once the baseline is known.
- **Rationale**: quality-thresholds; baseline "Coverage: not measured".
- **Constraint Fit**: No product change. New tool dependencies need the Complexity Budget Check.
- **Risk**: medium
- **Dependencies**: D13 (same job layout)
- **Points**: 5

### D15: Pin tool versions and verify downloads
- **File(s)**: `publish.yml`, `test.yml`, `run-suite.sh`, `publish-registries.sh`, `publish-inside.sh`, `publish-embedded.sh`, `cpp/embedded/examples.sh`, `cpp/embedded/Dockerfile`
- **Problem**: Publish-path tools (`build`, `twine`, `platformio`, `idf-component-manager`, `npm@11`) and test tools (`pytest`, `arduino-cli`, the ESP32 Arduino core, the RP2040 platform) are unpinned; `arduino-cli` is fetched without a checksum; actions are tag-pinned in a job with `id-token: write`.
- **Change**: A constraints file for pip tools, exact npm version, checksum-verified `arduino-cli`, pinned core/platform versions, SHA-pinned actions, toolchain versions printed into the embedded report.
- **Rationale**: S21 rows #2–5, 18, 20, 28, 36, 45; F16, EM8.
- **Constraint Fit**: Language test images stay "current" (R3).
- **Risk**: low
- **Dependencies**: None
- **Points**: 2

### D16: Remove dead and laptop-only publish paths
- **File(s)**: `publish-inside.sh`, `publish-registries.sh`, `publish.yml`, `.env.example`, `cpp/embedded/arm.sh`, `cpp/embedded/arm/ac2_main.cpp`
- **Problem**: The npm token branch is unreachable from `publish.yml`; `.env.example` lists tokens for a laptop publish that R-15 forbids and misses the embedded ones; `PACKBIN_WORK`/`PACKBIN_FIXTURE` are set by nothing; `WRAPPER_CALLS` check is a tautology; `if: success()` is redundant; default version `0.1.0` publishes silently.
- **Change**: Delete those paths and knobs; require `PACKBIN_VERSION`; make `.env.example` match what scripts actually read (or drop it). Whether the PyPI token path (secret `PYPI_TOKEN`) is still used is a **user question**.
- **Rationale**: S07, S21 #21/#33/#46.
- **Constraint Fit**: R-15 (no laptop publish) reinforced.
- **Risk**: low
- **Dependencies**: None
- **Points**: 2

### D17: Deduplicate publish helpers and metadata
- **File(s)**: `publish-lib.sh`, `publish-registries.sh`, `publish-inside.sh`, `publish-embedded.sh`, `crates-token.sh`
- **Problem**: OIDC token fetch ×2, version rewrite ×3, npm/PyPI publish ×2, git identity ×2, repo URL/owner ×8, POM as a heredoc, unnamed Maven poll budget, container `PACKBIN_OUT` hardcoded.
- **Change**: One helper each (OIDC token, version rewrite, publish metadata: owner, repo URL, description, git identity) in `publish-lib.sh`; POM from a template file; named poll constants; pass the host output dir into the container.
- **Rationale**: S06, S20, S21 #4/#23/#24/#26/#27/#31/#34/#37; F15, F19.
- **Constraint Fit**: Same uploads and metadata.
- **Risk**: low
- **Dependencies**: D16
- **Points**: 2

### D18: Make the publish-gate tests cheaper and behavior-based
- **File(s)**: `.github/workflows/publish-gate.test.sh`
- **Problem**: `copy_tree` copies build/cache directories three times; the gate runs 17 cold driver builds; static checks grep source text of other scripts.
- **Change**: Exclude build outputs from `copy_tree`; reuse driver builds across scenarios; replace source greps with behavior checks where a dry run can show the property (order of steps, token checks).
- **Rationale**: LF14, F24, S12.
- **Constraint Fit**: Same ACs asserted (AC-1, AC-3, AC-4, AC-5, AC-16).
- **Risk**: low
- **Dependencies**: D9
- **Points**: 2

### D19: Record the publish and C++ decisions in ADR/AC/restrictions
- **File(s)**: `_docs/02_document/adr/` (new ADR superseding 002), `adr/README.md`, `_docs/00_problem/acceptance_criteria.md` (AC-8 C++ note, AC-12, AC-13), `restrictions.md` (R-19), `tests/traceability-matrix.md`
- **Problem**: An accepted ADR and project ACs contradict the code (OIDC; nine targets; silent skips; C++ error shape and partial rows).
- **Change**: New ADR for trusted publishing and the embedded registries; AC/restriction wording that matches the decided behavior. **User decision** on each point.
- **Rationale**: doc_drift #4, #5, #8, #9; LF8, LF18.
- **Constraint Fit**: Documentation of decisions already in code; no code change.
- **Risk**: low
- **Dependencies**: D7 (registry policy)
- **Points**: 2

### D20: Refresh the C++ documentation
- **File(s)**: `_docs/02_document/components/05_cpp_package/{description,tests}.md`, `contracts/library/pack-session.md`, `module-layout.md`, `architecture.md`, `system-flows.md`, `glossary.md`, `data_model.md`, `tests/environment.md`, `tests/traceability-matrix.md`, `_docs/01_solution/languages.md`, `README.md:322,327-329`
- **Problem**: Loop 10 changed the C++ API and added embedded targets without touching `_docs/02_document`.
- **Change**: Describe the core API, `Result`/`Error`, partial-row behavior, `RandomFn` session start, public headers, embedded/examples/arduino/manifests, CI scripts and drivers; trace the cpp-microcontroller ACs; limit README target claims to what CI proves (or add the targets).
- **Rationale**: doc_drift #1–#4, #13, #18, #19, #21–#26.
- **Constraint Fit**: Docs only.
- **Risk**: low
- **Dependencies**: D19
- **Points**: 3

### D21: Refresh the CI/deploy documentation and drop the duplicate tree
- **File(s)**: `_docs/02_document/deployment/*`, `_docs/04_deploy/*`
- **Problem**: Lint claim, six images/registries, two-language golden step, NuGet/npm-only rollback; two parallel copies that disagree.
- **Change**: One canonical deployment doc set (the other links to it), matching the workflows after D4/D7/D12.
- **Rationale**: doc_drift #6, #10–#12, #14–#16, #32–#37.
- **Constraint Fit**: Docs only.
- **Risk**: low
- **Dependencies**: D4, D7, D12
- **Points**: 2

### D22: Per-language test jobs
- **File(s)**: `.github/workflows/test.yml`
- **Problem**: One job runs six suites serially and stops at the first failure.
- **Change**: A matrix over the six compose services, plus separate jobs for the publish-gate tests and (D8) the language ring; every language reports even when one fails.
- **Rationale**: LF13.
- **Constraint Fit**: AC-11 (every push and PR) kept.
- **Risk**: low
- **Dependencies**: None
- **Points**: 2

### Rejected / deferred

| # | Idea | Decision | Reason |
|---|------|----------|--------|
| R1 | One data-driven driver for all languages | Rejected | ADR-001: each language writes its field list by hand; the drivers are the proof of agreement |
| R2 | Per-language adapter files to remove the six `case "$lang"` dispatchers | Deferred | No seventh language is planned (Kotlin out of scope, AC out-of-scope list); coderule: "future-proof" is not a justification |
| R3 | Digest-pin the six language test images | Deferred | Restriction requires "current LTS / current stable"; D2 fixes the concrete risk (Java bytecode); revisit if publish reproducibility becomes a requirement |
| R4 | Rewrite the publish pipeline in Python | Rejected | Large rewrite with no AC gain; D5–D7, D17 address the actual defects |
| R5 | Share one `Position` definition across the three C++ examples | Rejected | Examples must compile alone from the registry package |
| R6 | Collapse the six component `tests.md` copies into one template | Deferred | Docs structure only; fold into D20 if the user wants |
| R7 | Delete the root `.dockerignore` | Rejected | Harmless, asserted by the scaffold job; no benefit |
| R8 | Remove `PACKBIN_DOCKER` / `PACKBIN_MAVEN_BUNDLE_ONLY` / `PACKBIN_PLAN` test knobs | Rejected | They let the tests drive the real publish scripts without registries |
| R9 | Move the handoff hexes into `fixtures/` | Deferred | Low value; one consumer |
| R10 | Split the driver `main` functions for CCN | Rejected | Flat command dispatch; splitting adds indirection without clarity |
| R11 | Fail the job when the crates.io revoke fails | Rejected | Trusted-publishing tokens are short-lived; failing a finished publish on cleanup adds noise |
