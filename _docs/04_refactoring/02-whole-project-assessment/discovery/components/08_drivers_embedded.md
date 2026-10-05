# Component 08 — Cross-language drivers and the C++ embedded harness

**Run**: `02-whole-project-assessment` (Quick Assessment, Phase 1, read-only)
**Tree**: `loop/10-cpp-microcontroller` at `d108141`
**Scope**: `.github/workflows/drivers/**` (excluding `handoff-rust/target`, `csharp/bin`, `csharp/obj`), `cpp/embedded/**`, `cpp/examples/**`; the C++ build manifests they depend on (`cpp/Makefile`, `cpp/CMakeLists.txt`, `cpp/library.json`, `cpp/idf_component.yml`, `cpp/arduino/*`) read for cross-reference only.
**Method**: full read; lizard 1.24 (`-C 10 -L 50`) on drivers and harness; `grep` for duplicated lists, flags and literals.

## 1. Drivers

### Inventory

| Language | Handoff driver | Position driver | Build in `language-pair.sh` | Build in `publish-position.sh` |
|----------|----------------|-----------------|-----------------------------|--------------------------------|
| C# | `csharp/Handoff.cs` (239) + `Handoff.csproj` | `csharp/Position.cs` (32) + `Position.csproj` | `dotnet run --project` | `dotnet run --project -v q` |
| TypeScript | `handoff.ts` (205) | `position.ts` (34) | `node --experimental-strip-types` | same, plus `npm ci` when `@noble/hashes` is missing |
| Python | `handoff.py` (139) | `position.py` (25) | `PYTHONPATH=… python3` | same |
| Rust | `handoff-rust/` crate (268) | `rust/` crate (55) | `cargo run` (default target dir) | `cargo run` with `CARGO_TARGET_DIR=/tmp/packbin-position-rust` |
| C++ | `handoff.cpp` (222) | `position.cpp` (35) | `${CXX:-c++}` + 6 sources, every call | `${CXX:-g++}` + 6 sources |
| Java | `Handoff.java` (233) | `Position.java` (35) | `javac` once into `/tmp/packbin-handoff-java`, reused while `Handoff.class` exists | `rm -rf` + `javac` every call |

Each handoff driver implements the same CLI: `pack-user`, `pack-nested`, `pack-session`, `unpack-user <hex>`, `unpack-nested <hex>`, `unpack-session <hex>`. Every handoff driver already contains the position scheme and row (used by the session cases); the six position drivers duplicate them a second time in the same language.

### Consistency

| Aspect | Observation |
|--------|-------------|
| Exit code for a missing hex argument | 2 in C#, C++, Java; 1 in Python and Rust; TypeScript unpacks `""` and exits 1 |
| Unknown command | 2 everywhere |
| Value check on unpack | full structural equality in Python, TypeScript (hand-written `deepEqual`), Rust (`PartialEq`); field-by-field in C#, C++, Java |
| Hex parsing | Rust rejects odd length/non-hex; C++ `std::stoul` throws on non-hex and truncates odd length; Java `parseInt` throws; Python/TS built-ins |
| Scheme style | Rust position mixes `BoundField` with name-based `flags(4, "motion", vec![u16("heading"), …])`; Java uses raw `Map` schemes with `@SuppressWarnings({"unchecked","rawtypes"})`; C# `Position.cs` packs a `Dictionary` against a `Scheme<PositionRow>` while `Handoff.cs` packs a typed row |
| Layout | Rust uses two crates (`rust/`, `handoff-rust/`); C# uses two projects in one folder with per-project `BaseOutputPath` (the workaround in `LESSONS.md:18`); the others use two files |

The per-language field lists are duplicated on purpose: ADR-001 makes each language write its list by hand, and the drivers are the proof that the hand-written lists agree. That duplication is accepted. The **position driver** duplication is not required by anything: each handoff driver could print the position packet as one more command.

### Complexity (lizard, CCN > 10 or NLOC > 50)

| Function | NLOC | CCN |
|----------|------|-----|
| `handoff.py` `main` | 44 | 25 |
| `handoff.ts` `deepEqual` | 31 | 17 |
| `Handoff.cs` `Main` | 30 | 14 |
| `handoff.cpp` `main` | 26 | 13 |
| `Handoff.java` `userOk` | 20 | 13 |
| `Handoff.cs` `UnpackSession` | 17 | 12 |
| `Handoff.java` `main` / `sessionOk` | 15 / 26 | 11 / 11 |
| `handoff-rust` `run` | 79 | 10 |

All are flat command dispatchers or chains of equality checks; none is hard to follow. No change proposed for complexity alone.

### Findings

| # | Finding | Evidence | Class | Severity |
|---|---------|----------|-------|----------|
| DR1 | Driver build/run commands are written twice (`language-pair.sh:11-57`, `publish-position.sh:17-61`), including the C++ compile line with the six-file source list and flags, and diverge (`c++` vs `g++` default; Java cached vs rebuilt; Rust target dir) | files | S06 / S16 | Medium |
| DR2 | C++ core source list lives in 5 places plus a count: `cpp/Makefile:10`, `cpp/CMakeLists.txt:4-8`, `cpp/embedded/lib.sh:15`, `language-pair.sh:35-36`, `publish-position.sh:42-43`, and `esp.sh:41` (`checked -eq 5`). `LESSONS.md:26` already records the miss this causes | files | S16 | Medium |
| DR3 | `language-pair.sh` reuses `/tmp/packbin-handoff-java/Handoff.class` when it exists, so a changed Java source can be tested with stale classes | `language-pair.sh:40-50` | logic bug | Low-Medium |
| DR4 | `language-pair.sh` recompiles the C++ handoff driver on every `run_lang cpp` call (8 compiles per run) | `language-pair.sh:27-37` | performance waste | Low |
| DR5 | Six position drivers + one Rust crate + one csproj duplicate the position scheme already in the handoff drivers | table above | S06 / S09 | Low |
| DR6 | `language-pair.sh` is not run by CI, so DR1–DR4 and the session ring are only exercised by hand | `test.yml`; `test-run09.md:12` | CI gap | Medium |
| DR7 | Inconsistent exit codes and hex parsing across drivers (table above) | files | S32 (contract not written down) | Low |

## 2. Embedded harness (`cpp/embedded`)

### Structure

| File | Lines | Role |
|------|-------|------|
| `run.sh` | 65 | Host stage (build image, run `arm` and `esp` services) or in-container stage dispatch; one report row per target |
| `lib.sh` | 90 | Globals (`root`, `cpp`, `here`, `results`, `out`, `build`), AC-1 flags, core sources, budgets, `run_target`, `note`, `fail`, log helpers |
| `arm.sh` | 260 | Cortex-M0+ link, M3 QEMU (AC-2 firmware + vector runner), M4F size/stack, s390x big-endian QEMU user |
| `esp.sh` | 52 | ESP32-S3 / C3 builds, AC-1 flag audit from `compile_commands.json` |
| `examples.sh` | 105 | Pico (PlatformIO archive), ESP32 Arduino (staged library), ESP-IDF (packed component) |
| `Dockerfile` | 15 | `ubuntu:24.04` + arm-none-eabi GCC, newlib-nano, QEMU system/user, s390x g++ |
| `arm/*`, `common/*`, `esp/*` | ~600 | Linker script, startup, semihosting, heap wrappers, stack meter, all-kinds scheme, vector runner, IDF project |

Report: 10 targets → `test-results/report.csv`, logs in `test-results/embedded/`.

### Findings

| # | Finding | Evidence | Class | Severity |
|---|---------|----------|-------|----------|
| EM1 | `run_stage_target` calls `run_target "$@" \|\| failed=…`. Bash ignores `-e` for every command run inside a function called from an `\|\|` list, **including the explicit `set -euo pipefail` in the target subshell**. So inside every target function a failing command that is not followed by `\|\| fail` is ignored (e.g. `curl`/`tar` in `examples_tools`, `pio pkg pack`, `cp -a`, `sed -i`, `arm-none-eabi-nm`, `make` in `vector_tests`). The comment at `lib.sh:61-62` ("errexit is not reliable inside functions") names the symptom; the `grep -q FAIL "$msg"` check is the workaround | `run.sh:31-33`, `lib.sh:54-65` | logic bug / S25 | Medium |
| EM2 | Hidden pass/fail conventions: the substring `FAIL` in `<id>.msg` fails a target; the count of the text `expect(` in each test file must equal the runtime assert-site count (`check_vectors`), so a commented-out `expect(` or a helper that wraps `expect(` changes the result; firmware results are a `KEY value` text protocol parsed with `awk` | `lib.sh:63`, `arm.sh:109-130`, `lib.sh:38-42` | S32 / S23 | Low-Medium |
| EM3 | `WRAPPER_CALLS` is printed as the constant `0` by `ac2_main.cpp:57`; the check `log_value WRAPPER_CALLS = 0` (`arm.sh:163`) can never fail. A wrapper call is caught by the QEMU exit code 99 instead | `arm/ac2_main.cpp:57`, `arm/wrap.c:11-16`, `arm.sh:162-163` | S07 (tautological check) | Low |
| EM4 | AC-1 flag list written 5 times: `lib.sh:13`, `esp.sh:33`, `esp/CMakeLists.txt:15`, `esp/main/CMakeLists.txt:7`, `cpp/Makefile:2,7` | files | S06 | Low |
| EM5 | `esp.sh:41` expects exactly 5 packbin sources (4 core + all-kinds) — a magic count tied to DR2 | file | S20 | Low |
| EM6 | The vector-test list is in `cpp/Makefile:13` (read through `print-var.mk`, good), but the runner functions are declared by hand in `common/vectors_main.cpp:12-16,61-65`; adding a vector file needs both edits | files | S16 | Low |
| EM7 | Globals shared across sourced files: `lib.sh` overwrites `here` set by `run.sh`; `arm.sh`/`esp.sh`/`examples.sh` read `cpp`, `here`, `build`, `out`, `root`, `CURRENT_TARGET` | `lib.sh:5-10,51` | S12 / S18 | Low |
| EM8 | Toolchain downloads per run with no cache in CI and no integrity check: `arduino-cli` 1.1.1 tarball by `curl` (no checksum), `pip install platformio` (unpinned), `arduino-cli core install esp32:esp32` (unpinned), PlatformIO `raspberrypi` platform (unpinned), the image rebuild, the `espressif/idf` pull. Local runs cache under `cpp/build/embedded`, which is the shared host/container tree | `examples.sh:7-30,63-66`, `Dockerfile`, `test.yml:46-54` | performance waste / supply chain | Medium |
| EM9 | `build="$cpp/build/embedded"` sits in the bind-mounted `cpp/build`, which the host `make` also owns (`cpp/.gitignore`); containers write it as root | `lib.sh:10`, compose volumes | S24 / S30 | Low-Medium |
| EM10 | Claims not exercised by CI: README lists Cortex-M33, nRF52, STM32 and "ESP-IDF ≥ 5.1"; CI covers M0+ (link), M3 and M4F (QEMU run), s390x, ESP32-S3/C3 and ESP32 (build), RP2040 (Pico build) on IDF 5.3.2 | `README.md:322,328`, `run.sh:39-56` | documentation drift | Medium |
| EM11 | No `timeout-minutes` on the embedded job; QEMU runs are bounded (`timeout 300`), toolchain downloads are not | `test.yml:46`, `arm.sh:102` | CI design | Low |

What is good and should be kept: one report row per target with the log path; link-map checks for `__cxa_*`, heap and OS-random symbols; heap wrappers plus `--gc-sections` reachability; host vector tests run unchanged on the target CPU and on big-endian s390x; examples built from the **packaged** layouts (PlatformIO archive, Arduino layout, IDF component) rather than the source tree; AC-5 budgets named (`flash_budget`, `stack_budget`) and cited.

## 3. `cpp/examples`

Three standalone README examples (Pico/PlatformIO, ESP32/Arduino, ESP-IDF). The `Position` struct and scheme are copied in all three and in `drivers/position.cpp` and `handoff.cpp`. Accepted: examples must compile on their own from the registry package. `examples/esp_idf/main/idf_component.yml` pins `version: "*"` (fine for an example). `examples/pico/platformio.ini:8` uses the registry name; `examples.sh:46` rewrites it to the local archive with GNU `sed -i` (runs only in the Linux image).
