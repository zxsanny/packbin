# List of Changes

**Run**: 02-whole-project-assessment
**Mode**: automatic
**Source**: self-discovered (four parallel discovery passes: `discovery/scan_csharp_java.md` A1–A17, `discovery/scan_typescript_python.md` B1–B24, `discovery/scan_rust_cpp.md` C1–C22, `discovery/scan_ci_docs.md` D1–D22)
**Date**: 2026-10-05

## Summary

85 candidate changes from the four scopes, merged into 31. The dominant theme is **one wire rule, six implementations that disagree**: bool presence, the 8-bit flags limit, zero-progress `repeat`, references to later or outer fields, hostile counts, per-call unpack state, and error labels are each enforced by some packages and missing or different in others. Most logic bugs found are a package that skipped a rule another one enforces. A shared walker is not proposed (ADR-001, LESSONS 2026-09-23): each package fixes its own walker against one written rule set, proven by shared vectors.

Priority (proposed for the Phase 1 gate): **P0** = before the `v0.2.0` tag (wrong bytes across languages, hangs or crashes on hostile input, data races, unloadable artifacts, false README promises, a broken publish); **P1** = next loop; **P2** = later. **[decision]** = needs a user decision first.

## Changes

### C01: One `bool` presence rule in all six packages [decision] — P0
- **File(s)**: `csharp/Walker.cs:29,39`, `typescript/src/walker.ts`, `typescript/src/kinds.ts`, `java/src/main/java/packbin/Walker.java:22`, `python/src/packbin/_pack.py`, `rust/src/walk/pack.rs`, `cpp/src/core/pack.cpp`, `cpp/src/core/unpack.cpp`
- **Problem**: `bool false` sets its flags bit in C# and TypeScript (`0101`) but not in Java and Python (`0100`); C# reads it back as `true`. A `bool` (or an empty `group`) outside `flags` writes nothing and unpacks as `true` in C++, and is absent in Rust. Same row, different bytes (project AC-3).
- **Change**: one rule everywhere — the bit is set only for `true`; a `bool`/empty group is accepted only inside `flags` / a flag byte (construction error elsewhere). Add the case to the cross-language vectors.
- **Rationale**: byte disagreement between packages is the one failure packbin exists to prevent.
- **Constraint Fit**: preserves golden hex (no golden row uses `bool false`); changes bytes only for the currently divergent case; needs the user to confirm the rule (A1/B2).
- **Risk**: medium (behavior change in two packages) · **Points**: 5 (≈1 per package) · **Dependencies**: None · Sources: A1, B2, C7.

### C02: Enforce the 8-bit limit of `flags` / flag byte everywhere — P0
- **File(s)**: `csharp/` flags construction, `typescript/src/fields.ts`, `python/src/packbin/_nodes.py`, `rust/src/field/mod.rs` (`FlagByte`), `rust/src/field/order.rs`
- **Problem**: a 9th flag bit is silently dropped (C#), accepted then rejected by its own unpack (TS), panics with shift overflow in Rust debug and lands on bit 0 in release. C++ and Java already reject it.
- **Change**: construction fails with a scheme error naming the field.
- **Risk**: low · **Points**: 2 · **Dependencies**: None · Sources: A5 (9th bit), B4, C2.

### C03: Hostile input never hangs or throws — P0
- **File(s)**: walkers in `csharp/Walker*.cs`, `java/.../Walker.java`, `java/.../VarFields.java`, `typescript/src/walker.ts`, `python/src/packbin/_unpack.py`, `rust/src/walk/unpack.rs`
- **Problem**: a `repeat` whose body can read 0 bytes loops forever on leftover bytes (TS, Python, C#, Java, Rust); negative or oversize counts throw instead of returning an error (C#, Java); invalid UTF-8 and counts behind a clear flag bit throw (TS, Python). A crafted packet hangs or crashes the receiver.
- **Change**: a repeat round that consumes 0 bytes ends the repeat with an error; bad counts / bad UTF-8 return the package's unpack error value. Add one hostile-packet vector set run by every package.
- **Risk**: low · **Points**: 5 (split per package pair) · **Dependencies**: C16 for the error label only · Sources: A3, B8, B17, C1 (repeat part). Also input to the security audit.

### C04: Reject references to later or outer fields at construction — P0
- **File(s)**: `csharp/Packbin.cs` (`SchemeOrder`), `java/.../SchemeOrder.java`, `typescript/src/fields.ts` (`validateFieldIds`, `findNameById`), `rust/src/field/order.rs`, `rust/src/scheme/mod.rs`
- **Problem**: a `when`/count naming a later field is accepted (C# then cannot read its own bytes; Java silently drops the group); in Rust a `when` inside `repeat`/`times` naming an outer field never matches and unpack grows memory forever; in TS nested references bind to the outer field with the same id. C++ already rejects these.
- **Change**: the C++ rule in every package — a reference must name an earlier field in the same scope; otherwise a scheme error.
- **Risk**: low · **Points**: 3 · **Dependencies**: None · Sources: A4, B7, C1 (outer refs), A7 (Java id scope part).

### C05: Unpack state per call, not on shared objects — P0
- **File(s)**: `csharp/Walker.cs` (`FlagGroup.Unpacked`), `java/.../Walker.java`, `java/.../FlagGroup.java`, `rust/src/field/mod.rs` (`FlagByte.next_bit`), `cpp/src/core/unpack.cpp` (`Walk::flag_bytes`)
- **Problem**: C# and Java store the flags byte read during unpack on the scheme — two threads unpacking one scheme gave 2 860 (C#) / 11 593 (Java split form) wrong rows in 400 000. Rust flag-bit numbers come from a shared counter on the handle. C++ (this loop) keys flag-byte values by number 0..7, so a container that reuses the number overwrites the outer value.
- **Change**: keep flag state in the walk (per call, per scope); bit positions from field order.
- **Risk**: low · **Points**: 3 · **Dependencies**: None · Sources: A2, C6, C14.

### C06: TypeScript pack refuses values that do not fit — P0
- **File(s)**: `typescript/src/kinds.ts` (`writeInt`, `writePacked`)
- **Problem**: `u8 300` writes `2c`, `-1` writes `ff`, `1.7` writes `01`, `i32 3e9` wraps — silently. Architecture §4: pack refuses an integer that does not fit. Python raises.
- **Risk**: low · **Points**: 2 · **Dependencies**: None · Source: B1.

### C07: Rust silent corruption in typed schemes — P0
- **File(s)**: `rust/src/scheme/bound.rs`, `rust/src/scheme/mod.rs`, `rust/src/walk/pack.rs`, `rust/src/walk/unpack.rs`
- **Problem**: two bound lists/dicts in one typed scheme share an internal name — the second list is packed for both; typed `times` fails for count ≥ 2 and drops on unpack (no test); `list(flags)`, `list(group)`, `flags` in `times`, `repeat` in `repeat` silently lose data; `when` compares `Value` variants so `eq(3, U16(1))` on a `u8` never matches.
- **Change**: unique binder names; typed `times` binds a `Vec<E>` (or is removed — C18); unsupported composite children fail at construction; `when` compares numbers.
- **Risk**: medium · **Points**: 5 · **Dependencies**: C18 decides typed `times` keep/remove · Sources: C3, C4, C5, C21.

### C08: C# fails loudly instead of dropping values — P0
- **File(s)**: `csharp/Walker.cs`, `csharp/ObjectValues.cs`, `csharp/Packbin.cs`
- **Problem**: a null nullable on a non-flag field is left out (Java throws); a field declared on another row type is left out; a `when` on a NaN float throws; the scheme keeps the caller's array and mutates shared `Field`/`Condition` objects during construction.
- **Risk**: medium · **Points**: 3 · **Dependencies**: C04 (same resolver) · Sources: A5 (other parts), A11, A17.

### C09: C# nested rows and list/dict elements bind per scope — P0 (README headline example throws)
- **File(s)**: `csharp/ObjectValues.cs`, `csharp/FieldAccess.cs`, `csharp/Walker.Counted.cs`, `csharp/tests/*`
- **Problem**: values travel in one flat name-keyed dictionary; nested members with the same name overwrite outer ones; lists and dicts of row objects throw on pack and unpack — the README's C# example (`f.List(x => x.Roles, r => r.Utf8(...))`) does not run. The AC-10 test times the dictionary path (81 ms), not the typed path callers use (719–933 ms of the 1 s budget).
- **Change**: bind each nested row / element through its own field accessors; AC-10 test times the public typed path.
- **Risk**: high (core of the C# walker) · **Points**: 5 + 1 · **Dependencies**: C08 · Sources: A6, A8.

### C10: Java artifacts load on the declared minimum JVM and Android [decision] — P0
- **File(s)**: `.github/workflows/publish-inside.sh:67`, `java/test.sh`, `docker-compose.test.yml:68`, `java/src/main/java/packbin/*` (`Arrays.compareUnsigned`)
- **Problem**: the Maven Central jar is compiled by JDK 26 without `--release`; Java 17/21 and Android cannot load it; `Arrays.compareUnsigned` needs Android API 33.
- **Change**: compile with `--release <floor>`, assert the class-file version in the gate, replace APIs above the floor.
- **Risk**: medium · **Points**: 2 · **Dependencies**: user picks the floor (A14/D2) · Sources: A14, D2, S21 row 14.

### C11: The publish run is all-or-nothing and re-runnable [decision] — P0 (the `v0.2.0` tag triggers it)
- **File(s)**: `.github/workflows/publish.yml`, `publish-registries.sh`, `publish-inside.sh`, `publish-embedded.sh`, `publish-gate.sh`
- **Problem**: publish does not wait for `test.yml`; uploads run one registry at a time and the signed Maven bundle is built last, after five registries are written; a re-run of the same tag fails on registries that already hold the version (v0.1.1–v0.1.8 were cut in two days, mostly to fix publishing); a missing credential skips Python, Rust and three embedded registries with exit 0.
- **Change**: publish requires a green `test.yml` on the tagged commit; build and verify every artifact before the first upload; a re-run skips versions already published; a declared list of required registries fails the run when its credential is missing.
- **Risk**: medium · **Points**: 2 + 3 + 3 + 1 · **Dependencies**: user declares required registries (D7) · Sources: D4, D5, D6, D7.

### C12: The vcpkg port builds the library (or the README stops promising it) — P0
- **File(s)**: `.github/workflows/publish-registries.sh:80-100`, `README.md` (C++ install table), `cpp/CMakeLists.txt`
- **Problem**: the port copies sources into `share/` and builds nothing; README (this loop) promises a CMake target `packbin` through vcpkg.
- **Change**: portfile builds `cpp/CMakeLists.txt` and exports `packbin` with a consumer build check — or the README row says sources only.
- **Risk**: medium · **Points**: 3 (or 1 for the README) · **Dependencies**: None · Source: D3.

### C13: C++ core public namespace and internal limits — P0 (0.2.0 is already a breaking C++ release)
- **File(s)**: `cpp/include/packbin/table.hpp`, `core.hpp`, `order.hpp`, `codec.hpp`, `cpp/src/core/pack.cpp:155`, `cpp/tests/core/session_host_tests.cpp`, `cpp/include/packbin/fields_counted.hpp:186`
- **Problem**: table internals (`Field`, `Kind`, `Node`, `Access`, `Item`, `Count`, `flag::*`, `check_table`, `put_num`/`get_num`) are in the public `packbin` namespace; `u2` silently caps at 64 children (S21 uncertain); the OS-reference test hard-codes 6 header names; a comment says dict keys keep caller order while pack rejects unsorted keys.
- **Change**: move internals to `packbin::detail` (or document them as public before the tag), make the `u2` cap a construction error, scan every core header, fix the comment.
- **Risk**: medium · **Points**: 3 · **Dependencies**: None · Sources: C16, C20, C7 (u2), S21.

### C14: Embedded harness runs with errexit in force — P0
- **File(s)**: `cpp/embedded/run.sh:31-33`, `cpp/embedded/lib.sh`
- **Problem**: `run_target` is called under `||`, which turns `set -e` off inside every target; unchecked `curl`, `tar`, `pio pkg pack`, `cp`, `sed` failures continue; the "FAIL" note grep added this loop is a workaround.
- **Risk**: low · **Points**: 2 · **Dependencies**: None · Source: D1.

### C15: Uniform error labels and error types across packages [decision] — P1 (decide before P0 work lands)
- **File(s)**: error types in all six packages (`csharp/Packbin.cs:104,134`, `java/.../BinaryPacker.java:19`, `typescript/src/index.ts`, `python/src/packbin/_unpack.py`, `rust/src/walk/unpack.rs` 15 sites, `rust/src/session/mod.rs:65`, `cpp/include/packbin/core.hpp`)
- **Problem**: short-packet `field` is the member name (C#, TS), the order id (Java, Python, C++), `""` for flags bytes and counts; trailing bytes and session-not-open are fake short packets (TS); Rust reports bad values as `ShortPacket { needed: 0 }` at 15 sites and `PackSession::pack` collapses errors into "not open"; `languages.md` promises one label.
- **Change**: one label rule and distinct error kinds (short, trailing, type mismatch, bad value, too many, scheme) in every package.
- **Risk**: medium (public API in every package) · **Points**: 8 · **Dependencies**: user picks the label (A9/B9) · Sources: A9, B9, B16, C8, C9.

### C16: Python correctness gaps — P1
- **File(s)**: `python/src/packbin/_nodes.py`, `_pack.py`, `_unpack.py`, `_session.py`, `__init__.py`
- **Problem**: split-form `flag_byte` cannot be used in any `Scheme` (bits counted twice by order validation; no test); repeat/times on a dataclass with defaults unpack as `[0, 10, 30]`; `repeat` containing `flags`/`when`/`group` crashes on pack; `PackSession(seed)` skips the 32-byte check; `import *` shadows `bool`/`bytes`/`dict`/`list`.
- **Risk**: low–medium · **Points**: 5 · **Dependencies**: C21 if done after the walker split · Sources: B10, B11, B12, B21, B22, B14 [decision: element row style].

### C17: TypeScript structure bugs — P1
- **File(s)**: `typescript/src/walker.ts`, `typescript/src/fields.ts`
- **Problem**: flags inside nested groups are dropped on pack; a nested member silently overwrites a parent field with the same name; flag-byte values leak into the unpacked row; list/dict of `group`/`flags` throws on pack (spec allows it); 64-bit `when` never matches on unpack (`bigint` vs `number`).
- **Risk**: medium · **Points**: 6 · **Dependencies**: C04 · Sources: B3, B5, B6, B13.

### C18: Rust typed-scheme parity [decision] — P2
- **File(s)**: `rust/src/scheme/bound.rs` (514 lines), `rust/src/field/mod.rs`, `rust/src/value.rs`, `rust/src/lib.rs`
- **Problem**: typed schemes cannot bind every kind (no `opt_i16` — the golden row's `altitude` — no typed u2, group, flag byte, repeat, generic list/dict), against LESSONS 2026-09-24; `MapScheme` is public with no public pack/unpack; `value.rs` exposes `motion_field_count`, a product field list (S21 business).
- **Change**: user chooses: add the missing typed kinds (generated scalar constructors) or narrow the spec; trim public API to what callers can use.
- **Risk**: medium–high (public API) · **Points**: 8 (to split) · **Dependencies**: decision · Sources: C11, C12, C13, S21 business row.

### C19: Java typed nested rows [decision] — P1
- **File(s)**: `java/src/main/java/packbin/Walker.java`, `Field.java`, `Packbin.java`
- **Problem**: unpacking a typed nested row throws `ClassCastException`; nested rows share field ids with the parent; `repeat` with `flags`/`when`/`group` throws NPE on pack.
- **Change**: `group(...)` takes a child factory (public API change), ids scoped per nested row.
- **Risk**: medium · **Points**: 3 · **Dependencies**: C04 · Source: A7.

### C20: npm package ships JavaScript and type declarations — P1
- **File(s)**: `typescript/package.json`, `typescript/tsconfig*.json` (new), `.github/workflows/publish-*.sh`
- **Problem**: the package exports raw `.ts`; Vite builds work, plain Node fails (`ERR_UNSUPPORTED_NODE_MODULES_TYPE_STRIPPING`), but `languages.md` lists Node as a consumer.
- **Risk**: medium (publish layout) · **Points**: 3 · **Dependencies**: None · Source: B15.

### C21: Split the walkers per kind (per package, same behavior) — P1/P2
- **File(s)**: `typescript/src/walker.ts` (`unpackFields` ≈CCN 70 / 216 lines, `packFields` 43), `python/src/packbin/_unpack.py` (57), `_pack.py` (48), `rust/src/walk/pack.rs` (72 / 212), `rust/src/walk/unpack.rs` (66 / 325)
- **Change**: per-kind functions with one walk context, as the C++ core now does (CCN ≤ 23); no behavior change, suites and vectors as the safety net. One task per package.
- **Risk**: medium · **Points**: 5 + 5 + 5 · **Dependencies**: after C01–C07, C16, C17 (bug fixes land first, with tests) · Sources: B18, B19, C10.

### C22: Remove dead code and unused public surface — P1
- **File(s)**: `csharp/ObjectValues.cs:7` (`Bound<T>`), `csharp/FieldAccess.cs:9-10,39-52`, `typescript/src/walker.ts:216,423` (unreachable `case "flags"`), `rust/src/walk/mod.rs`, Rust public helpers, `java/.../Field.java` (15-arg ctor → factories)
- **Risk**: low (C# `Bound<T>` is a breaking removal if NuGet 0.1.x has users [decision]) · **Points**: 3 · **Dependencies**: C09, C18 · Sources: A10, A16, B20, C15.

### C23: Test hygiene and missing tests — P1
- **File(s)**: `csharp/tests/LayoutTests.cs` (517 lines), all six test trees, `java/test.sh`
- **Problem**: one test file over the 500-line cap; no tests for split flag form (Python), typed `times` (Rust), hostile packets, cross-thread unpack; TypeScript is never type-checked (`tsc` installed, not run); `java/test.sh` carries dead JDK 11/17 fallbacks that cannot compile the sources.
- **Risk**: low · **Points**: 3 · **Dependencies**: travels with C01–C07 · Sources: A13, A15, B23.

### C24: Run the six-language ring in CI with one driver build path — P1
- **File(s)**: `.github/workflows/test.yml`, `language-pair.sh`, `publish-position.sh`, `.github/workflows/drivers/**`, `cpp/embedded/lib.sh`, `cpp/embedded/esp.sh`
- **Problem**: `language-pair.sh` (handoff + session ring) runs in no workflow; the C++ source list lives in 5 places plus a hard-coded count; position drivers duplicate the handoff drivers; `language-pair.sh` reuses stale Java classes from `/tmp`; the gate tests do 17 cold driver builds.
- **Risk**: medium · **Points**: 3 + 3 + 3 + 2 · **Dependencies**: None · Sources: D8, D9, D10, D18.

### C25: Build outputs and CI cost — P1
- **File(s)**: `cpp/Makefile`, `docker-compose.test.yml`, `.github/workflows/test.yml`, `cpp/embedded/*`
- **Problem**: `cpp/build/` and other build trees are shared between the macOS host and Linux containers (stale macOS binary run by the container, twice this loop); the embedded job takes ~40 min cold on every push and PR with no cache, path filter or timeout.
- **Change**: per-toolchain build directories / container-only build volumes; `actions/cache` keyed on pinned toolchain versions, a path filter and a timeout for the embedded job.
- **Risk**: low · **Points**: 2 + 3 · **Dependencies**: C27 (pinned versions make cache keys stable) · Sources: C19, D11, D12.

### C26: Lint, type-check and coverage in CI [decision — new tools, Complexity Budget] — P2
- **File(s)**: `.github/workflows/test.yml`, per-package configs
- **Problem**: no lint, no type check, no coverage anywhere; the 75 % / 90 % thresholds cannot be checked; declared minimum versions (Python 3.10, Node 22, ESP-IDF 5.1) are untested.
- **Risk**: medium (first runs will surface findings) · **Points**: 3 + 3 + 2 · **Dependencies**: C25 · Sources: D13, D14, D22.

### C27: Pin publish-path tools and verify downloads — P2
- **File(s)**: `publish.yml` (`npm@11`, action tags), `publish-registries.sh`, `publish-inside.sh`, `publish-embedded.sh` (unpinned pip installs), `run-suite.sh:35,38`, `cpp/embedded/Dockerfile`, `cpp/embedded/examples.sh` (arduino-cli without checksum, unpinned `esp32:esp32` core, platformio), `rust/Cargo.toml` (`repository`)
- **Risk**: low · **Points**: 3 · **Dependencies**: None · Sources: D15, C22, S21 system rows 2–5, 18, 20, 28, 36, 45.

### C28: Publish script cleanup — P2
- **File(s)**: `publish-registries.sh` (313 lines), `publish-inside.sh` (POM heredoc), `publish-embedded.sh`, `.env.example`
- **Problem**: dead and laptop-only paths (`PACKBIN_DOCKER`, `PACKBIN_MAVEN_BUNDLE_ONLY`, unreachable npm-token path, stale `.env.example` supporting a forbidden laptop publish); helpers and metadata duplicated (version rewrite ×3, OIDC fetch ×2, git identity ×2, registry coordinates ×3); Maven POM as a shell heredoc; silent default version `0.1.0`.
- **Risk**: low · **Points**: 3 · **Dependencies**: C11 · Sources: D16, D17, S21 rows 4, 21, 23, 24, 26, 27, 31, 34, 37, 46.

### C29: Documentation matches the code [decision: ADR wording] — P0 for C++ docs, P1 rest
- **File(s)**: `_docs/02_document/components/05_cpp_package/description.md` (documents the removed 0.1.x API), `_docs/01_solution/schema.md` (old C# calls `Packet.Of`), architecture/ADR-002/R-19 ("OIDC not selected" — all four OIDC registries use it), AC-13/ADRs ("six registries" — up to 9 now), AC-8/glossary/system-flows vs C++ partial-row behavior, lint claims, README M33/nRF52/STM32 claims CI never builds; 38 rows in `discovery/doc_drift.md` (7 High, 15 Medium, 15 Low)
- **Change**: refresh per package (loop plan step 13 covers C++); a new ADR superseding ADR-002 for OIDC, the publish targets and the C++ AC-8 exception.
- **Risk**: low · **Points**: 5 · **Dependencies**: C11 (registry policy), C15 (error labels) · Sources: A12, B24, C17, C18, D19, D20, D21.

### C30: Session and seed checks consistent — P1
- **File(s)**: `python/src/packbin/_session.py`, `rust/src/session/mod.rs:65,117`
- **Problem**: Python accepts a wrong-size seed in the constructor path; Rust `pack` turns a pack error into "not open"; Rust has no non-`/dev/urandom` source (Windows) — deferred (no AC for Windows).
- **Risk**: low · **Points**: 1 · **Dependencies**: C15 · Sources: B21, C9, S21 rust row 5 (deferral).

### C31: Shell and embedded harness hygiene — P2
- **File(s)**: `cpp/embedded/*.sh`, `language-pair.sh`, `publish-position.sh`
- **Problem**: fixed `/tmp/packbin-*` paths instead of `mktemp`; magic counts (`checked -eq 5`, `timeout 300`); `WRAPPER_CALLS` tautology in the AC-2 firmware log; `KEY value` log parsed by `awk` substring.
- **Risk**: low · **Points**: 2 · **Dependencies**: C24 · Sources: EM3, EM6, S21 rows 38, 43.

## Rejected (recorded with reasons in the scan files)

- One shared walker or shared crypto across languages — violates ADR-001 and LESSONS 2026-09-23.
- New crypto dependencies (Rust crates, C++ libraries) — the in-house HKDF/ChaCha20 matches across six languages; no AC asks for a change.
- Auto-sorting C++ dict keys on pack — would need a mutable copy or heap; pack refuses unsorted keys instead (this loop).
- Splitting files purely for length — only where a file is over the cap or mixes responsibilities (C21, C23).

## Points

P0: C01–C14 ≈ 49 points. P1: C15–C17, C19–C24, C30 ≈ 51 points. P2: C18, C25–C28, C31 ≈ 33 points.
