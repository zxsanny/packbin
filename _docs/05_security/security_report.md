# Security Audit Report

**Date**: 2026-10-06
**Scope**: packbin, loop 16 (`git diff 9db438e..HEAD`, 12 commits 611c68a to 5c95950, HEAD 5c95950): unpack of untrusted bytes (Java nested rounds and typed rows, u64 counts in TypeScript and Rust, split-form flag bits in TypeScript, Python, Java and C++, Python round and slot limits, Rust `Written`/`RoundLists`/`check_longer`, Python `_flag_scope.py`), session key and nonce handling, the npm JavaScript build, the vcpkg port, the tag-time guard, the `ring` CI job, the new shell scripts. Loop 14 and 15 findings carried by their original ids. Out of scope by instruction: `csharp/**` and the owner's uncommitted hunks (C# findings are carried, not re-verified). `README.md` line numbers are those of `git show HEAD:README.md`.
**Verdict**: PASS_WITH_WARNINGS

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High     | 0 |
| Medium   | 2 |
| Low      | 14 |

No Critical or High. The loop's trust-boundary work holds up under probing: no unpack path in Python, TypeScript, Java or Rust allocates from a packet count before checking the bytes left (u64 counts 2^64-1 to 0 refused in microseconds in all four), the Python round and slot budget is checked before each round, per call, overflow-free, and 29.8 million fuzzed unpack calls over 14 to 16 schemes per package (split flag bytes, flags, u64 and u32 counted fields, `u2`, `times`, `repeat`, nested rounds, list and dict elements) raised no exception. The fixed zero nonce of Python `start(16)` is closed, TypeScript `load` checks the brand, and neither the npm build, the vcpkg port nor the `ring` job adds a credential or a registry write path. Two Mediums stay (F10 narrower, F12 unchanged). Seven Lows are new to the report: a Java `unpack` that throws on a typed accessor that does not fit an anchored-group element (F18), session entry points that are not uniformly strict and have no nonce-reuse rule in the docs (F19), the `gcc:16` ring wrapper with a read-write repository and host `/tmp` mount and default network (F20, the known item Q9), `pack` writing as many rounds as the row's count says (F21), C++ unpack returning unvalidated UTF-8 (F22), gaps in the new npm and vcpkg tag-time assertions (F23) and fixed `/tmp` names that are executed (F24). F13 is narrower: the loop 15 symlink refusal is in place and verified.

## OWASP Top 10 Assessment

List: OWASP Top 10 2025, confirmed at owasp.org at the start of the audit.

| Category | Status | Findings |
|----------|--------|----------|
| A01 Broken Access Control | PASS_WITH_WARNINGS | F14 |
| A02 Security Misconfiguration | PASS_WITH_WARNINGS | F13, F20, F24 |
| A03 Software Supply Chain Failures | PASS_WITH_WARNINGS | F12, F2, F3 (F1 fixed) |
| A04 Cryptographic Failures | PASS_WITH_WARNINGS | F19 |
| A05 Injection | PASS_WITH_WARNINGS | F15, F22 |
| A06 Insecure Design | PASS_WITH_WARNINGS | F10, F21 |
| A07 Authentication Failures | N/A | — |
| A08 Software or Data Integrity Failures | PASS_WITH_WARNINGS | F13, F16, F23 |
| A09 Security Logging and Alerting Failures | N/A | — |
| A10 Mishandling of Exceptional Conditions | PASS_WITH_WARNINGS | F17, F18 |

## Findings

| # | Severity | Category | Location | Title | Status |
|---|----------|----------|----------|-------|--------|
| 10 | Medium | A06 | `python/src/packbin/_unpack.py:33-58`, `csharp/Scope.cs:25-37`, `typescript/src/walker.ts:34-38`, `java/.../Cursor.java:20-26`, `rust/src/walk/unpack.rs:33-49`; counted fields `rust/src/walk/unpack.rs:268-290`, `typescript/src/kinds.ts:99-113`, `python/src/packbin/_unpack.py:96-109` | Unpack memory: the limits cap round growth, but the default ceiling is 110 to 430 MiB per call and `bits`, `packed` and list or dict elements stay linear at up to 257 times the packet | reduced again (README now states the bound; Python now limited) |
| 12 | Medium | A03 | `publish-lib.sh:134-157`, `publish-upload.sh:129-140`, `publish-embedded.sh:128,134`, `publish.yml:29,36,50` | The credentialed job still installs about 60 unpinned, unhashed transitive wheels; the Maven key is visible to host pip in the build phase; `PYPI_TOKEN` beside OIDC; checkout credentials persist | reduced in loop 15, unchanged in loop 16 |
| 13 | Low | A08 / A02 | `publish-check.py:155-158,257-276`, `publish-upload.sh:153-154`, `publish-sign.sh:30-45`, `docker-compose.publish.yml:9-12` | Container-written trees: symlinks now refused; non-regular files, the check-to-upload gap and `stage/` against the `.crate` remain; container is root with default network and capabilities | reduced (symlink route closed) |
| 17 | Low | A10 | `csharp/Packbin.cs:62-67` | A typed C# `Unpack` of a packet that holds a round throws `InvalidCastException` | carried, not re-verified (C# out of scope) |
| 18 | Low | A10 | `java/src/main/java/packbin/Containers.java:204`, `Walker.java:395`, `Packbin.java:112-118` | Java `unpack` throws `ClassCastException` when a typed accessor sits in an anchored-group list or dict element | new to the report (pre-existing, documented in the Javadoc) |
| 19 | Low | A04 | `python/src/packbin/_session.py:33-36,47-58`, `typescript/src/index.ts:176-178,185-199`, `README.md:458-460` | Session entry points are not uniformly strict, and an explicit nonce has no reuse rule | new |
| 20 | Low | A02 / A08 | `.github/workflows/ring-cxx.sh:15-25`, `test.yml:73-122` | The `gcc:16` ring wrapper mounts the repository and host `/tmp` read-write, default network and capabilities, image by tag | new (known item Q9) |
| 21 | Low | A06 | `rust/src/walk/pack.rs:366-399`, `typescript/src/pack-fields.ts:181`, `python/src/packbin/_pack.py:279` | `pack` writes as many `times` rounds as the row's count states | new |
| 22 | Low | A05 | `cpp/tests/core/hostile_host_tests.cpp:353-358`, `cpp/src/core/unpack.cpp:62-83`, `README.md:1082` | C++ `unpack` returns unvalidated UTF-8 | new to the report (documented, AZ-2078 open) |
| 23 | Low | A08 | `publish-check.py:93-122,193-217` | The tag-time npm and vcpkg assertions leave gaps | new |
| 24 | Low | A02 | `language-pair.sh:50,65-68,77`, `publish-position.sh:56,60,72-73` | Fixed `/tmp` names are executed or deleted | new |
| 14 | Low | A01 | `publish.yml:3-6,21-26` | Any writer's `v*` tag publishes; no environment, approval or documented tag protection | carried (open) |
| 15 | Low | A05 | `publish.yml:48`, `publish-registries.sh:22-23`, `publish-inside.sh:36-37`, `publish-embedded.sh:63-76` | Tag name is the version with no validation | carried (open; the vcpkg JSON heredoc is a new sink, fail-closed) |
| 16 | Low | A08 | `publish-upload.sh:49,97,103,109,146,153`, `publish-query.sh:113`, `crates-token.sh:18,57` | Registry tokens on the command line | carried (open) |
| 2 | Low | A03 / A08 | `cpp/embedded/examples.sh:29-31,71-72` | `arduino-cli` tarball run without a checksum; the ESP32 core installed without a version | carried (open; lines moved; test job only, no secret) |
| 3 | Low | A03 | `cpp/embedded/Dockerfile:4-8`, `docker-compose.test.yml`, `test.yml:112` | Base images pinned by tag, not by digest; `apt-get install` unpinned; `gcc:16` is also the ring compiler | carried (open) |
| 1 | Low | A03 | `publish.yml:29,32,37`, `test.yml:17,63,92,93,96,99,102` | Actions on moving tags | **fixed** (10 non-local `uses:`, all 40-hex commits equal to their tags) |
| 11 | Low | A06 | `fixtures/hostile/cases.txt:20-21`, the six replays | No test bounds unpack cost by packet size | **fixed** for C#, TypeScript, Java, Rust and Python (`python/tests/test_hostile_vectors.py:24,45-50`); C++ closed with its fixed-capacity bound |

Counts: Medium 2 (F10, F12), Low 14 (F13, F17, F18, F19, F20, F21, F22, F23, F24, F14, F15, F16, F2, F3). F1 and F11 are fixed and not counted.

### Finding Details

**F10: Unpack memory is capped by the limits, not by the packet; the cap is high and counted fields and elements are linear** (Medium / A06, reduced again)
- Fixed since loop 15: (a) `README.md:1075` and `:1133` now say what holds: the limits bound the memory of rounds, a `bits` or `packed` count is bounded only by the bytes left, the limits are per call, cap the packet length, with the figures of the audit; (b) Python has the budget (`_unpack.py:33-58`, `Scheme.with_limits` at `_scheme.py:62-70`, defaults 65,535 rounds and 4,194,304 slots, a first round of a run also pays 8 slots per name for its lists). Verified in code and by probe: the check precedes the round, `started >= max_rounds` or `slots + cost > max_slots` cannot overflow, a fresh budget per call (`_scheme.py:110`), a limit below 1, a float, a bool, `None` or a string is refused.
- What remains: (1) the ceiling is high. Python, 300-name body stopped by the slot limit at 1 MiB: +112 MB (peak 140 MB over a 25 MB runtime); 36-name body refused at round 65,536: +36 MB; the earlier figures stand for the others (C# 192 MB, TypeScript 132 MB, Java 353 MB, Rust 431 MB). (2) Counted fields and elements stay linear in the packet: Python `bits` with 8,388,608 items in 1 MiB +69 MB, `packed(2)` +36 MB, 16 lists of 65,535 group elements (1 MiB) +212 MB (202 times); TypeScript `bits` +136 MB; Rust 270 MB and TypeScript 233 MB peak in loop 15. Elements are bounded by one byte each and by u16 per container, not by a budget. (3) The limits are per call, so concurrent calls add up.
- Attacker scenario: a service reads unauthenticated packets without a length cap into a Rust or TypeScript scheme with a count field and a `bits` field. A 4 MiB packet allocates about 1 GB; ten connections about 10 GB.
- Remediation: lower the default `maxSlots` or add a byte budget per call that counted fields and elements also charge; in Rust store set bits as `Vec<u8>` or a bitset instead of 32-byte `Value::U8` items; keep telling readers to cap the packet length where they read it.

**F12: Unpinned code in the credentialed job** (Medium / A03, unchanged in loop 16)
- Loop 16 adds no installer to that job (`publish.yml`, `publish-lib.sh`, `publish-upload.sh` unchanged). Remaining as in loop 15: (1) about 60 transitive wheels of `twine`, `platformio`, `idf-component-manager` float and carry no hash (`pip_install_pinned`, `publish-lib.sh:134-157`), run in the step that holds every secret (`publish.yml:44-57`); (2) `MAVEN_GPG_PRIVATE_KEY` stays in the build subshell (`publish-registries.sh:111-118`), visible to the host-side `pip install`, `pio pkg pack` and `compote` (`publish-embedded.sh:128,134`); (3) `PYPI_TOKEN` is passed beside OIDC (`publish.yml:50`); (4) `actions/checkout` persists credentials (`publish.yml:29`); (5) `ensure_tool` keeps a tool already on `PATH` (`publish-lib.sh:146-149`).
- Remediation: hash-locked requirements per tool (`pip-compile --generate-hashes`, `--require-hashes`); pass the Maven key only to `publish-sign.sh`; drop `PYPI_TOKEN`; `persist-credentials: false`; fail when a pinned tool is already on `PATH` at another version.

**F13: Container-written trees are not fully validated at upload** (Low / A08, A02, reduced)
- Fixed (commit 049d27c, verified in loop 16): `refuse_symlinks` (`publish-check.py:257-276`) refuses any symlink under the tree of each of the five container targets before the target check; probe: a symlink planted in `artifacts/rust` gives `check failed: rust: planted is a symlink`. The symlink route to `cargo publish` packing a host file (loop 15 F13 item 1) and the signing write-through (item 3) are closed. `docker-compose.publish.yml:9-12` keeps `/src` read-only.
- Remaining: (1) non-regular files are not refused: a FIFO and a hard link in the folder pass `refuse_symlinks` (probe) and a FIFO could block a host tool that opens it, such as `twine upload artifacts/python/*` (not run); (2) `cargo publish --no-verify --allow-dirty --manifest-path artifacts/rust/stage/Cargo.toml` (`publish-upload.sh:153-154`) re-archives `stage/`, while the check reads the `.crate` and only `stage/Cargo.toml`'s version and the absence of `stage/target` (`publish-check.py:155-158`); (3) no digest is recorded between check and upload; (4) the container is root with default capabilities and network and can read `/src/.git/config`; (5) the Java sign step still relies on `find -type f` (`publish-sign.sh:45`).
- Remediation: reject any non-regular file and any file with a link count above 1 under the container folders (walk with `lstat`); publish the Rust crate from the checked `.crate` (extract into a fresh host directory and pack that) or compare the staged file list with the `.crate` members; record SHA-256 of every artifact at check time and verify before upload; run the containers with `--cap-drop ALL`, `--security-opt no-new-privileges` and no network after dependencies are fetched.

**F17: A typed C# `Unpack` throws on a packet that holds a round** (Low / A10, carried)
- Location `csharp/Packbin.cs:62-67`; not re-verified (the file has uncommitted owner hunks). Impact, probe and remediation as in loop 15: catch the cast in `Dispatch` and return a typed error, or refuse `repeat` and `times` in `Scheme<T>` for typed unpack; keep the README exception.

**F18: Java `unpack` throws `ClassCastException` for a typed accessor in an anchored-group element** (Low / A10, new to the report)
- Location: `java/src/main/java/packbin/Containers.java:204` (`Walker.newRow(element)` returns a `HashMap` because an anchored group element has no child factory), `Walker.java:395` (`field.set.set(row, value)`), documented in the Javadoc at `Packbin.java:112-118` ("It does not check anchored group, flags or u2 elements ... so typed accessors in them fail when the row is unpacked"). `README.md:1075` says `unpack` "does not throw" for Java.
- Probe: a typed row `Row { List<Pt> pts }` with `Packbin.list(.., Packbin.group(0, Packbin.u8(0, row -> ((Pt) row).x, (row, v) -> ((Pt) row).x = ...)))` and the packet `01 02 00 05 06`: `BinaryPacker.unpack` throws `java.lang.ClassCastException: class java.util.HashMap cannot be cast to class Typed$Pt`.
- Impact: for a scheme built this way, any peer that sends one packet with a list element makes the receive call throw; a receive loop without a catch stops (denial of service of that service). The same class as F17. It is a scheme-author mistake that the constructor does not refuse; the loop 17 handoff lists the options.
- Remediation: refuse a typed accessor under an anchored group, `flags` or `u2` element at construction (the check `SchemeOrder` already makes for nested rows with and without a factory), or catch `RuntimeException` around the setter calls in `Walker.unpackScalar` and return the bad-value error; correct the README sentence until then.

**F19: Session entry points are not uniformly strict; an explicit nonce has no reuse rule** (Low / A04, new)
- Location: Python `_session.py:33-36` (constructor checks `len` only), `typescript/src/index.ts:176-178` (the `private` constructor is private only in the `.d.ts`; the npm package now ships plain JavaScript), `:185-199` (`start` and `join` do not use the `isUint8Array` brand), `README.md:458-460` and `_docs/02_document/contracts/library/pack-session.md:36` (`Start(nonce)` "when the caller already has those 16 bytes", no reuse warning).
- Probes: Python `PackSession([7]*32)`, `PackSession(range(32))` and a 32-key dict build a session (README says the constructor raises unless the seed is 32 bytes); `PackSession.load` of the same inputs returns `None`. TypeScript `new PackSession(new Uint8Array(5))` (via `any`) builds a session and opens; `start("a".repeat(16))`, `start([..16])` and `start(null)` throw `TypeError` where `load` returns `null`. Python, with the same seed, `start(b"\0"*16)` on two sessions gives the same nonce and so the same pad.
- Impact: a caller that passes a constant or reused nonce with one seed reuses the ChaCha20 pad for every packet position (two-time pad: the XOR of two clear packets leaks); the fixed zero nonce of loop 16's Python `start(16)` was this route by accident. A wrong-typed argument throws from `start` in TypeScript instead of returning `null`.
- Remediation: say in the README and the contract that `start(nonce)` is for interop and tests, that a nonce must never repeat for one seed and that `start()` draws a fresh one; make the Python constructor and the TypeScript `start`/`join` apply the same exact-type check as `load` (or make the constructor private in JavaScript too); optionally a per-process set of used nonces per seed.

**F20: The `ring` job's `gcc:16` wrapper is not hardened** (Low / A02, A08, new; known item Q9)
- Location: `.github/workflows/ring-cxx.sh:15-25`, `test.yml:73-122`. The wrapper runs as the runner user but mounts the repository and the host `/tmp` read-write, keeps the default bridge network and default capabilities, and takes the image by tag. See `infrastructure_review.md` for the table of what the ring needs.
- Impact: a tampered `gcc:16` image or compiler can rewrite repository files that the host runs next in the same job (including `language-pair.sh`, which bash reads while it runs) or plant classes and binaries in `/tmp` that the ring reuses (`language-pair.sh:67-68,77`): a false green ring on every push, pull request and tag. The job has `contents: read` and no secret, the checkout credential file is outside the mounts, so no secret is exposed. Not run here (no Docker); from reading.
- Remediation: `--network none --cap-drop ALL --security-opt no-new-privileges --pids-limit 256`; mount the repository and the working directory `:ro`; replace `/tmp:/tmp` with a per-run `mktemp -d` bound at its own path and exported through `PACKBIN_CPP_HANDOFF`, `PACKBIN_CPP_BIN` and `PACKBIN_JAVA_HANDOFF`; pin `gcc:16` by digest.

**F21: `pack` writes as many `times` rounds as the row's count states** (Low / A06, new)
- Location: `rust/src/walk/pack.rs:366-399` (`for i in 0..n`), `typescript/src/pack-fields.ts:181`, `python/src/packbin/_pack.py:279`. A `times` whose round writes at least one byte with no value (a `flags` byte) packs `n` rounds.
- Probe: `u32 n` and `times(flags(u8))`, row `{n}` only: Rust n=10,000,000 gives 10,000,005 bytes in 1.2 s at 577 MB resident (n=4,000,000,000 would allocate over 200 GB); TypeScript 10,000,005 bytes in 1.4 s; Python n=5,000,000 in 7.2 s. C#, Java and C++ not measured.
- Impact: a service that packs a row whose count comes from untrusted input (an echo or relay) is a memory and CPU amplifier of 1 byte of count per 1 to 4 GB. No default receiver could read it back: the default round limit refuses more than 65,535 rounds.
- Remediation: refuse in `pack` a `times` count above the scheme's `maxRounds` (the symmetric check), and say in the README that the count is the caller's to validate.

**F22: C++ `unpack` returns unvalidated UTF-8** (Low / A05, new to the report; documented)
- Location: `cpp/src/core/unpack.cpp:62-83` (`unpack_text` hands back borrowed bytes), `cpp/tests/core/hostile_host_tests.cpp:353-358` ("open concern (AZ-2078)": the two invalid-UTF-8 hostile vectors unpack Ok), `README.md:1082` ("it does not check that a string is valid UTF-8"). The other five packages refuse invalid UTF-8 in a string or dictionary key.
- Impact: a C++ consumer that passes the returned `string_view` to code that assumes valid UTF-8 (a JSON or XML writer, a UI, a path or log sink) accepts overlong or invalid sequences chosen by the peer.
- Remediation: validate in `unpack_text` (a small branch-only validator, no heap, fits the embedded budget) and return the bad-value error, or ship and document a `packbin::is_valid_utf8` and mark the two vectors C++-exempt in `fixtures/hostile/cases.txt`; decide AZ-2078.

**F23: The tag-time npm and vcpkg assertions leave gaps** (Low / A08, new)
- Location: `publish-check.py:97` (`NPM_RELATIVE_IMPORT` matches `from "./x"`, `import "./x"` and `import("./x")`, runs over comments and strings, and ignores `require(...)` and bare specifiers, so an undeclared dependency in `dist` is not caught), `:193-217` (`check_vcpkg` asserts the host dependencies, `CMakeLists.txt` and `LICENSE` text and the versions files, but not `supports`, not the content of `portfile.cmake` and not that the vendored files equal `cpp/`; the equality is a test, `publish-vcpkg.test.sh:108-111`, not a guard).
- Impact: a regression that drops `"supports": "linux | osx"` or changes the portfile reaches the registry with `check ok: vcpkg`; a dist that imports a package that is not a dependency passes the guard. Both sources are the host's own repository files and the builds run before the check, so this is a regression guard, not an attacker path.
- Remediation: assert `supports == "linux | osx"`, the four `vcpkg_*` calls of the portfile and a byte comparison of the vendored files with `cpp/`; check `dist` imports with a real parse (or `node --check` plus a resolution pass) against `dependencies`.

**F24: Fixed `/tmp` names are executed or deleted** (Low / A02, new)
- Location: `language-pair.sh:50` (`/tmp/packbin-handoff`), `:65-68,77` (`/tmp/packbin-handoff-java`: reused when `Handoff.class` and `HandoffElements.class` exist and no source is newer, then `java -cp`), `publish-position.sh:56` (`/tmp/packbin-position-rust` as `CARGO_TARGET_DIR`), `:60` (`/tmp/packbin-position` binary), `:72-73` (`rm -rf` then `mkdir -p` of `/tmp/packbin-position-java`).
- Impact: on a shared developer or self-hosted machine another local user can pre-create the directory with fresh class files, a binary or a Cargo target tree, and the next ring or gate run executes them as the developer. On a single-user runner or laptop nothing changes.
- Remediation: `mktemp -d` plus a `trap` for each, or a path under `$RUNNER_TEMP`/`$TMPDIR`; keep the environment overrides.

**F14, F15, F16** carried (no `environment:` in `publish.yml`; no version check anywhere, and `publish-embedded.sh:63-76` writes `$version` into `vcpkg.json` unquoted, which `check_vcpkg` rejects when the parsed value differs from the tag; tokens on argv at the cited lines). **F2**: `examples.sh:29-31` downloads `arduino-cli` 1.1.1 with no checksum, `:71-72` installs `esp32:esp32` without a version; `embedded` job only, no secret. **F3**: no image or Dockerfile changed; `gcc:16` is now also the ring compiler (F20). **F1** and **F11**: fixed, see the table.

## Loop 16 status: F10 and F11 per package, as audited

This block replaces the one of loop 15.

| # | Package | Status | Evidence |
|---|---------|--------|----------|
| F10 | C# | reduced, not re-probed | out of scope (owner's uncommitted work); loop 15 figures stand; typed `Unpack` of a round throws (F17) |
| F10 | TypeScript | reduced | check before allocation, per-call budget (`walker.ts:34-38,274-281`); u64 counts refused in under 1 ms for `times`, `bits`, `packed`, `sized` at 2^64-1, 2^63, 2^53, 2^53-1, 4e9; `bits` 8,388,608 items in 1 MiB +136 MB |
| F10 | Java | reduced | `Cursor.startRound` before each round, also for nested rounds; 65,535 outer rounds of `repeat -> times` +15 MB, 1 MiB refused in 42 ms; typed accessor mismatch throws (F18) |
| F10 | Rust | reduced | unpack unchanged (`walk/unpack.rs`); u64 counts refused in 3 to 27 microseconds at 2 MB resident, no overflow in a debug-assertions build; pack count checked (`borrowed_count`); ceiling and `bits` 257 times as in loop 15 |
| F10 | C++ | bounded by design, unchanged | fixed `Array<T, N>` storage, `Error::TooMany` (`cpp/include/packbin/table.hpp:67,82`); full suite green under ASan and UBSan; UTF-8 not validated (F22) |
| F10 | Python | now limited (loop 15 listed it as "no limit needed") | `Scheme.with_limits`, defaults 65,535 and 4,194,304, checked per round and per call; 1 MiB one-byte rounds refused at round 65,536 (`left` 983,041); ceiling +112 MB (300 names at the slot limit); `bits` +69 MB, element lists +212 MB per 1 MiB |
| F11 | C#, TypeScript, Java, Rust, Python | fixed | accept at the limit, refuse at limit plus 1, `left` 983,041 for 1 MiB; the two `limit` hostile cases replayed by each package (`fixtures/hostile/cases.txt:20-21`; Python `test_hostile_vectors.py:24,45-50`, `test_round_limits.py`) |
| F11 | C++ | closed with its fixed-capacity bound | no size test needed; capacity at most 65,535 per container |

## Dependency Vulnerabilities

| Package | CVE | Severity | Fix Version |
|---------|-----|----------|-------------|
| none known | `npm audit` 0 (also `--omit=dev`); `dotnet list package --vulnerable --include-transitive` 0 (test project, HEAD copy); OSV 0 for `npm` 11.21.0, `twine` 7.0.0, `platformio` 6.2.0, `idf-component-manager` 3.1.2, `build` 1.6.1, `setuptools` 84.0.0, `pytest` 9.1.1, `@noble/hashes` 2.4.0, `typescript` 5.9.3 and the four NuGet test packages; the loop 15 wheel closure (61 packages) not re-resolved, pins unchanged; `cargo audit` could not parse the advisory database (CVSS 4.0), lockfiles hold only path crates | — | — |

## Recommendations

### Immediate (Critical/High)
None.

### Short-term (Medium)
- F10: lower the default `maxSlots` or add a byte budget that counted fields and elements also charge; Rust bitset for `bits`; before the first real release.
- F12: hash-locked tool installs; Maven key only to `publish-sign.sh`; drop `PYPI_TOKEN`; `persist-credentials: false`.

### Short-term (Low, cheap)
- F18: refuse typed accessors under anchored-group, `flags` and `u2` elements at construction (Java). F17: catch the cast in `Dispatch` (C#).
- F19: README and contract text on nonce reuse; strict `start`/`join` in TypeScript and the Python constructor.
- F20: harden the ring wrapper (`--network none`, `--cap-drop ALL`, `:ro`, private temp, digest) after the first green `ring` run.
- F21: refuse a `times` count above `maxRounds` in `pack`. F13: reject non-regular files; upload the Rust crate from the checked `.crate`; digests between check and upload.
- F23: assert `supports`, the portfile and the vendored files in `check_vcpkg`; parse `dist` imports.

### Long-term (Low / Hardening)
- F22 validate UTF-8 in the C++ core (AZ-2078); F24 `mktemp -d` for the ring and position defaults; F14 environment with reviewers and tag ruleset; F15 version regex; F16 tokens off argv; F2 checksum for `arduino-cli`, pinned ESP32 core; F3 images by digest (now also the ring compiler and the publish build containers).

## Evidence and limits

Method: read the changed source of Python, TypeScript, Rust, Java (diff and surrounding code) and the C++ delta, the CI and publish scripts, the embedded harness and the new test scripts; ran my own probes on a `git archive HEAD` copy in the session scratch directory (Python 3.14.6, Node 22.23, JDK 21.0.2, Rust 1.79 release with debug assertions and overflow checks, Apple clang with ASan and UBSan, macOS arm64, `ru_maxrss` and `ps` resident sizes, runtime baselines subtracted where stated); fuzz of 14 schemes (Python, TypeScript) and 16 (Java), 29.8 million unpack calls, 0 exceptions; `cargo test --release` on the HEAD copy (360 tests in the library and 9 integration files, all pass) and the C++ suite under sanitizers (pass); read-only network queries (`npm audit`, `git ls-remote`, OSV, owasp.org, the NuGet vulnerability feed through `dotnet list package`). No publish, no registry write, no credential used; this audit modified nothing outside `_docs/05_security/` and its scratch directory (every build, install and probe ran on the `git archive` copy); the five reports of loop 15 were overwritten without asking, as the skill allows for autodev Step 14.

Not checked, and why: any C# code or test (the owner's uncommitted multi-target work is in the tree; F17 carried from loop 15); Docker (not allowed here), so the `ring-cxx.sh` wrapper, the merged compose files and file ownership on Linux were read, not run; the real-vcpkg gate and consumer test (`publish-vcpkg.test.sh`) and the first CI run of the new `ring` job, which only the runner shows (node 24, JDK 26, Python 3.14, gcc 16, Linux glibc); Rust unpack under fuzz (unchanged since loop 15, whose 2.63 million calls stand) and C++ under fuzz (the loop 10 fuzz predates `unpack_when`; the suite ran under sanitizers); Java typed rows inside rounds (typed setters in a round were not probed, only the anchored-group element case); `pack` count amplification in C#, Java and C++; the 61-package wheel closure of the pinned tools (not re-resolved), `pip-audit`, OWASP dependency-check and `shellcheck` (not installed; `bash -n` and grep used); whether each pinned action commit is on its repository's default branch; whether `gpg` follows a planted `.asc` symlink (no `gpg` on this host; the symlink is now refused earlier); repository settings (tag rules, environments, trusted-publisher bindings); a local `.env` exists in the audit host's working tree (untracked, not read); DAST. Line numbers of `README.md` are those of HEAD, because the working tree holds uncommitted owner lines.
