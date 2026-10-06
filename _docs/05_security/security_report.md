# Security Audit Report

**Date**: 2026-10-06
**Scope**: packbin, loop 15 (`git diff b45335d..HEAD`, commits b351b4a, 7341a54, 4300410; HEAD 4300410): the round limits of C#, TypeScript, Java and Rust (AZ-2216 to AZ-2219, F10), the CI pins (AZ-2214, F12), the read-only build containers (AZ-2215, F13) and the hostile cases (AZ-2220). Loop 14 findings carried forward by their original ids.
**Verdict**: PASS_WITH_WARNINGS

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High     | 0 |
| Medium   | 2 |
| Low      | 7 |

No Critical or High. The loop did what it set out to do and the evidence holds: every way a repeat or times round can be reached takes the limit check before any per-round or per-name storage is made (four packages, no preallocation from a packet count, no arithmetic that can overflow), and the build containers can no longer change a script, a source file or an artifact of another language (merged compose config and a real C# pack from a copy verified). Two items are narrower than the loop's own status block claims, so F10 and F12 stay Medium as **reduced**, not fixed: the ceiling the default limits allow is 130 to 430 MiB per unpack call (3 to 5 times the README figures, which measure rounds that skip their names), and the counted fields `bits` and `packed` still cost 36 to 257 times the packet length; the credentialed job still installs about 60 unpinned, unhashed transitive wheels. F1 is fixed and F13 drops to Low (the remaining route needs a compromised Java or Rust build image). One Low is new to the report: a C# typed `Unpack` throws on any packet that holds a round (F17, pre-existing, documented in the README).

## OWASP Top 10 Assessment

List: OWASP Top 10 2025, confirmed at owasp.org at the start of the audit.

| Category | Status | Findings |
|----------|--------|----------|
| A01 Broken Access Control | PASS_WITH_WARNINGS | F14 |
| A02 Security Misconfiguration | PASS_WITH_WARNINGS | F13 (root containers, default network and caps; repo now read-only) |
| A03 Software Supply Chain Failures | PASS_WITH_WARNINGS | F12, F2, F3 (F1 fixed) |
| A04 Cryptographic Failures | PASS | — |
| A05 Injection | PASS_WITH_WARNINGS | F15 |
| A06 Insecure Design | PASS_WITH_WARNINGS | F10 (reduced) |
| A07 Authentication Failures | N/A | — |
| A08 Software or Data Integrity Failures | PASS_WITH_WARNINGS | F13, F16 |
| A09 Security Logging and Alerting Failures | N/A | — |
| A10 Mishandling of Exceptional Conditions | PASS_WITH_WARNINGS | F17 |

## Findings

| # | Severity | Category | Location | Title | Status |
|---|----------|----------|----------|-------|--------|
| 10 | Medium | A06 | `csharp/Scope.cs:25-37`, `typescript/src/walker.ts:34-38`, `java/.../Cursor.java:20-26`, `rust/src/walk/unpack.rs:33-49`; counted fields `rust/src/walk/unpack.rs:268-290`, `typescript/src/kinds.ts:121-135` | Unpack memory: the limits cap round growth, but the default ceiling is 130 to 430 MiB per call and `bits`/`packed` stay linear at up to 257 times the packet | reduced (was: unbounded growth, 0.3 to 1.4 GB per MiB) |
| 12 | Medium | A03 | `publish-lib.sh:134-157`, `publish-upload.sh:129-140`, `publish-embedded.sh:128,134`, `publish.yml:29,36,50` | The credentialed job still installs about 60 unpinned, unhashed transitive wheels; the Maven key is visible to host pip in the build phase; `PYPI_TOKEN` beside OIDC; checkout credentials persist | reduced (direct tools, npm, actions and setuptools pinned; wheels only) |
| 13 | Low | A08 / A02 | `publish-check.py:135-138`, `publish-upload.sh:153-154`, `publish-sign.sh:30-45`, `docker-compose.publish.yml:9-12` | Container-written trees are not validated at upload: `cargo publish` re-archives `stage/` and follows symlinks, host sign steps write through container-planted symlinks, no digest between check and upload | reduced (was Medium: scripts, sources and other targets' artifacts are now unreachable) |
| 17 | Low | A10 | `csharp/Packbin.cs:62-67` | A typed `Unpack` of a packet that holds a `repeat` or `times` round throws `InvalidCastException`; a peer can trigger it with any such packet | new to the report (pre-existing, documented in the README) |
| 14 | Low | A01 | `publish.yml:3-6,21-26` | Any writer's `v*` tag publishes; no deployment environment, approval or documented tag protection | carried (open, unchanged) |
| 15 | Low | A05 | `publish.yml:48`, `publish-registries.sh:22-23`, `publish-inside.sh:36-37` | Tag name is the version with no validation | carried (open, unchanged) |
| 16 | Low | A08 | `publish-upload.sh:49,97,103,109,146,153`, `publish-query.sh:113`, `crates-token.sh:18,57` | Registry tokens on the command line | carried (open, unchanged) |
| 2 | Low | A03 / A08 | `cpp/embedded/examples.sh:26-28,66` | `arduino-cli` tarball run without a checksum; the ESP32 core is installed without a version | carried (open; moved from line 25; test job only, no secret) |
| 3 | Low | A03 | `cpp/embedded/Dockerfile:4-8`, `docker-compose.test.yml` | Base images pinned by tag, not by digest; `apt-get install` unpinned | carried (open, unchanged; the five publish build images are these tags, see F13) |
| 1 | Low | A03 | `publish.yml:29,32,37`, `test.yml:17,59` | Actions on moving tags | **fixed** (all five `uses:` are 40-hex commits; SHAs verified against the tags) |
| 11 | Low | A06 | `fixtures/hostile/cases.txt:20-21`, the four replays | No test bounds unpack cost by packet size | **fixed** for C#, TypeScript, Java and Rust (closed with the stated C++ and Python limit) |

Counts: Medium 2 (F10, F12), Low 7 (F13, F17, F14, F15, F16, F2, F3). F1 and F11 are fixed and not counted.

### Finding Details

**F10: Unpack memory is capped by the limits, not by the packet; the cap is high and counted fields are still linear** (Medium / A06, reduced)
- Fixed part (verified in code and by probe): every repeat and times round takes `TryStartRound` / `refuseRound` / `startRound` / `start_round` before its scope, list or map is allocated (`csharp/Walker.cs:292`, `Walker.Counted.cs:273`; `typescript/src/walker.ts:131,191`; `java/.../Rounds.java:50,70`; `rust/src/walk/unpack.rs:212,358`). No count the packet states sizes a buffer first: C# `FitsItems` and `Math.Min(count, bytes left)` (`Walker.Counted.cs:190-192,250-252,362,422`), Java `count > left` / `nbytes > left` before `new ArrayList<>(count)` (`VarFields.java:148-154,212-218`), Rust `cur.take(nbytes)` before `Vec::with_capacity(n)` and `capacity_hint(count, left)` (`unpack.rs:286-287,325-326,402`), TypeScript pushes with no preallocation (`new Array<number>(nbytes)` appears only in pack, from the scheme). The arithmetic cannot overflow: C# and Java test `slots > maxSlots - used` with `used <= maxSlots` in `long`; Rust does the same in `usize` (`unpack.rs:39`), TypeScript compares safe integers; `rounds++` cannot pass `int.MaxValue` because the packet would need that many bytes. Every unpack call builds its own budget (C# `Packbin.cs:192`, TypeScript `walker.ts:276-283`, Java `BinaryPacker.java:62`, Rust `unpack.rs:445`), so dispatch, sessions and list or dict elements are covered; the element scopes carry the same budget (`Walker.Counted.cs:365,436`, `Containers.java` shares `cur`). A `times` inside a `repeat` is refused at construction in C#, TypeScript and Java (`RoundScopes.cs`, `rounds.ts:validateRoundNesting`, `SchemeOrder`); Rust allows it and counts the inner rounds against the shared slot budget (`map_scheme.rs` `count_fields`, probe `times_in_repeat`).
- What remains: (1) the default slot limit is a ceiling, not a small number. Measured by me on a scratch copy, net of the runtime, one unpack call of a packet built to sit at the slot limit with every name set (300-name body): C# 192 MB, TypeScript 132 MB, Java 353 MB; Rust, a round of 64 set flag bits: 431 MB for a 0.47 MB packet. The README figures (86 to 92 MiB) measure rounds that skip their 36 names. The limits are per call, so N concurrent calls multiply them. (2) `bits` and `packed` take their count from an integer field (up to u64) and are bounded only by the bytes left: a 1 MiB packet of `u32 n` plus `bits` with n = 8,388,608 costs 270 MB in Rust (257 times), 233 MB in TypeScript, 38 MB in C# and Java, 79 MB in Python (all net, measured). Nothing in the limits touches this. (3) `README.md:1046` says memory in these four packages "is bounded by the scheme's round limits, not by the packet"; (2) contradicts it.
- Attacker scenario: a service on the Rust or TypeScript package with a `u32` count and a `bits` or `packed` field reads packets from the network without a length cap. A 4 MiB packet makes it allocate about 1 GB; ten parallel connections about 10 GB. The README tells the reader only to cap length for time.
- Remediation: (a) make the README sentence true: memory is bounded by the limits for rounds and by about 36 to 257 times the packet length for counted fields, so cap the packet length; (b) lower the default `maxSlots` or add a byte budget per call (an allocation counter that every counted field and round charges); (c) in Rust, store set bits as `Vec<u8>` or a bitset rather than 32-byte `Value::U8` items.

**F12: Unpinned code in the credentialed job** (Medium / A03, reduced)
- Fixed: the five actions are commits; `npm@11.21.0`, `twine==7.0.0`, `platformio==6.2.0`, `idf-component-manager==3.1.2`, `build==1.6.1`, `pytest==9.1.1` come from one file (`tool-pins.txt`, read by `tool-pin.sh`); every pip install is `--only-binary=:all:`, so no sdist `setup.py` runs at install; `PIP_CONSTRAINT` holds `setuptools` in the isolated Python build (probe: the same file with `setuptools==83.0.0` made `python -m build` install 83.0.0). All pinned versions exist on PyPI and npm with wheels, none yanked, and OSV lists no advisory for them or for the 61 packages of their wheel closure.
- Remaining: (1) the transitive closure floats and carries no hash: `twine` 22 packages, `platformio` 23, `idf-component-manager` 28 (`requests`, `urllib3`, `pydantic`, `starlette`, `uvicorn`, ...; resolved today and downloadable as wheels for Linux and Python 3.12), plus `packaging` and `pyproject_hooks` for `build` in the Python container. A wheel can run code on import or through a `.pth` file. They run in the step that holds every secret (`publish.yml:44-57`, `publish-upload.sh:129-140`). (2) `MAVEN_GPG_PRIVATE_KEY` stays in the build subshell (`publish-registries.sh:111-118`), so the host-side `pip install`, `pio pkg pack` and `compote` of `publish-embedded.sh:128,134` run with it. (3) `PYPI_TOKEN` is still passed next to OIDC (`publish.yml:50`, used at `publish-upload.sh:92-97`). (4) `actions/checkout` still persists credentials (`publish.yml:29`): v7.0.1 writes the token to a file in `RUNNER_TEMP` and puts only its path in `.git/config` (`git-auth-helper.ts:327-375` at the pinned commit), so a host process, but not a container mount, can read it. (5) `ensure_tool` keeps a tool already on `PATH` (`publish-lib.sh:146-149`), so a preinstalled `twine` or `pio` bypasses the pin.
- Attacker scenario: unchanged in kind, narrower in reach. A malicious new release of any of the ~58 floating transitive packages (or of `packaging`) is installed into the next publish and runs with the whole environment: it can read every token and mint OIDC tokens for npm, PyPI and crates.io. Likelihood is low; impact is every channel, which keeps this Medium.
- Remediation: generate a hash-locked requirements file per tool (`pip-compile --generate-hashes`) and install with `--require-hashes`; pass `MAVEN_GPG_PRIVATE_KEY` only to `publish-sign.sh`; drop `PYPI_TOKEN`; `persist-credentials: false`; fail when a pinned tool is already on `PATH` at another version.

**F13: Container-written trees are not validated at upload** (Low / A08, A02, reduced from Medium)
- Fixed: `docker-compose.publish.yml` makes `/src` read-only for the six services (merged config checked, below); a container writes only `artifacts/<lang>` at `/out/artifacts/<lang>`, sees no other language's folder, passes no secret in and reaches no script, `.git` or source file for writing. The loop 14 `chmod -R a+rwX` is gone (`publish-build.sh`; the container chowns its own folder, `publish-inside.sh:33`). Python is the only build that downloads code, and it can now change only `artifacts/python`.
- Remaining: (1) the host re-archives a tree a container wrote. `cargo publish --no-verify --allow-dirty --manifest-path artifacts/rust/stage/Cargo.toml` (`publish-upload.sh:153-154`) packs `stage/`, while `publish-check.py:135-138` checks the `.crate` and only the version in `stage/Cargo.toml`, not the file set. Cargo follows file symlinks (probe: a symlink to a host file was packed with that file's content). (2) The container can read `/src/.git/config`, which names the checkout credential file (`includeIf ... path = $RUNNER_TEMP/git-credentials-<uuid>.config`). (3) Host steps write through container-planted symlinks: `publish-sign.sh:30-45` writes `.md5`, `.sha1` and `.asc` next to each `.pom` and `.jar`, so a planted link to `.github/workflows/publish-upload.sh` is overwritten (DoS, fail-closed: the script then holds a hex digest; the content is a digest or a signature, not controllable code; the `gpg` write-through itself could not be run here). (4) No digest between check and upload; reduced to the pip-installed host tools, which run only in the upload phase. (5) The check does not reject non-regular files in any container-written folder.
- Probed: a symlinked `-javadoc.jar` is not signed (`find -type f`, `publish-sign.sh:45`), is put into the bundle by `rglob` and `is_file()` (`publish-sign.sh:52-53`), and the check then refuses the bundle for the missing `.asc`, and Central would refuse a forged one: the Java route is closed by two accidents, not by a rule. The Rust route has no such stop.
- Attacker scenario: the `rust:1.98` image (pulled by tag, F3) or the Rust toolchain in it is compromised. Its build writes `artifacts/rust/stage/leak -> /home/runner/work/_temp/git-credentials-<uuid>.config` (path read from `/src/.git/config`). The check passes (the `.crate` is clean), `cargo publish` uploads the file's content inside the crate to crates.io, and the job's `contents: write` token is public until the job ends (the Maven poll alone can hold the job for 22 minutes). The same compromised image could instead trojan the crate itself, which no design here prevents. Likelihood very low, impact high, so Low.
- Remediation: in `publish-check.py` reject any symlink or non-regular file under every container-written folder (walk with `lstat`); publish the Rust crate from the checked `.crate` by extracting it into a fresh directory on the host and packing that, or compare the staged file list with the `.crate` members; record SHA-256 of every artifact at check time and verify before upload; `persist-credentials: false`; run the containers with `--cap-drop ALL`, `no-new-privileges` and no network after dependencies are fetched.

**F17: A typed C# `Unpack` throws on a packet that holds a round** (Low / A10, new to the report)
- Location: `csharp/Packbin.cs:62-67` (`Dispatch` calls `ObjectValues.To<T>(raw.Values)` after `ReadFields` accepted the packet); documented at `README.md` (Limits to keep in mind, third bullet).
- Description: the row type has no member that can hold a list per round, so `To<T>` throws `InvalidCastException`. Probe: a 65,536-byte packet of one-byte rounds, inside the limits, returned `InvalidCastException` from `BinaryPacker.Unpack`. `README.md:1046` says unpack "does not throw" for C#.
- Impact: any peer that can send one packet with a round makes the receive call throw; a receive loop without a catch stops (denial of service of that service).
- Remediation: catch the cast in `Dispatch` and return a typed error until a public round-reading call exists, or refuse `repeat` and `times` in `Scheme<T>` for typed unpack; correct the README sentence.

**F14, F15, F16** carried unchanged (no `environment:` in `publish.yml`; no version check anywhere; tokens still on argv at the cited lines). **F2**: `examples.sh:26-28` downloads `arduino-cli` 1.1.1 with no checksum, and `:66` installs the `esp32:esp32` core from `espressif.github.io` without a version; both run only in the `embedded` test job (no secret). **F3**: no image or Dockerfile changed. **F1** fixed, **F11** fixed: see the table and `infrastructure_review.md`.

## Loop 15 status: F10 and F11 (AZ-2216 to AZ-2220), as audited

This block replaces the one the implementation wrote.

| # | Package | Status | Evidence |
|---|---------|--------|----------|
| F10 | C# | reduced | check before allocation, per-call budget; ceiling about 192 MB at the slot limit; `bits` 36 times the packet; typed `Unpack` of a round throws (F17) |
| F10 | TypeScript | reduced | same; ceiling about 132 MB; `bits` 222 times |
| F10 | Java | reduced | same; ceiling about 353 MB; `bits` 36 times |
| F10 | Rust | reduced | same, typed rows share the layout check; ceiling about 431 MB (64 set flag bits per round) and 66 MB for 8 flag bits; `bits` 257 times, `packed(2)` 129 times |
| F10 | C++ | bounded by design, unchanged | fixed `Array<T, N>` storage, `Error::TooMany` (`cpp/include/packbin/table.hpp:67,82`); not re-probed |
| F10 | Python | bounded for rounds, unchanged | net 19 MB for the 36-name 1 MiB packet; `bits` 79 MB net (75 times) |
| F11 | C#, TypeScript, Java, Rust | fixed | accept at the limit, refuse at limit plus 1, `left` 983,041 for 1 MiB, two `limit` hostile cases replayed (`fixtures/hostile/cases.txt:20-21`) |
| F11 | C++, Python | closed with the stated limit | no size test added |

## Dependency Vulnerabilities

| Package | CVE | Severity | Fix Version |
|---------|-----|----------|-------------|
| none known | `npm audit` 0; `dotnet list package --vulnerable --include-transitive` 0 (test project); OSV 0 for `twine` 7.0.0, `platformio` 6.2.0, `idf-component-manager` 3.1.2, `build` 1.6.1, `setuptools` 84.0.0, `pytest` 9.1.1, `npm` 11.21.0 and the 61 packages of their wheel closure; `cargo audit` could not parse the advisory database (CVSS 4.0), lockfile holds only the crate | — | — |

## Recommendations

### Immediate (Critical/High)
None.

### Short-term (Medium)
- F10: correct `README.md:1046` and the memory bullet (ceiling figures with every name set, linear cost of counted fields, packet-length cap for memory too); lower the default `maxSlots` or add a byte budget; before the first real release.
- F12: hash-locked tool installs; key only to `publish-sign.sh`; drop `PYPI_TOKEN`; `persist-credentials: false`.

### Short-term (Low, cheap)
- F13: reject symlinks and non-regular files under every container-written folder in `publish-check.py`; upload the Rust crate from the checked `.crate`; digests between check and upload. F17: catch the cast in `Dispatch`.

### Long-term (Low / Hardening)
- F14 environment with reviewers and tag ruleset; F15 version regex; F16 tokens off argv; F2 checksum for `arduino-cli`, pinned ESP32 core; F3 images by digest (now also the trust base of the publish build containers).

## Evidence and limits

Method: read every changed source file of the four packages and the CI files; ran my own probes on a throwaway copy under the session scratch directory (Rust 1.79 release, Node 22, .NET 10, Java 21, Python 3.14, macOS arm64, `/usr/bin/time -l` peak resident set; baselines: .NET 44.7 MB, Java 47.0 MB, Node 87.3 MB, Rust 1.6 MB, Python 15.2 MB, subtracted for "net"); read-only queries (`git ls-remote`, raw GitHub source of the pinned actions, PyPI and npm JSON, OSV, owasp.org); `npm audit`, `dotnet list package --vulnerable`, `cargo audit` (failed). `docker compose ... config` for the merged files. No publish, no registry write, no credential used; nothing in the repository other than `_docs/05_security/` changed; the test scripts were not run.

Verified myself against the batch reports: C# 1 MiB 36-name refused 85.6 MiB (report 86) and unlimited 528 MiB (530); TypeScript 84.5 MiB (86), 65,535 rounds accepted 104.8 MiB (106), unlimited 401 MiB (about 400); Java 96 MiB (92) and unlimited 573 MiB (560); Rust 8 flag bits 64.4 MiB (64), refused with `left` 983,041. Not matching: Rust 8 flag bits with limits lifted measured 966 MiB, the README says 1.3 to 1.4 GiB. Not verified: the Rust `times` one-byte figures (21 and 310 MiB) and the Python figure on Python 3.14 beyond the net 19 MB; the C++ package (not re-probed); the compose merge on Compose 2.38.2 and file ownership on Linux (I ran Compose 2.24.3 on macOS); whether `gpg` follows a planted `.asc` symlink (no `gpg` on this host, the sign step ran against a stub that wrote the same files); cargo's symlink behaviour on the runner's cargo (checked on 1.79); that wheels install on `ubuntu-latest` Python 3.12 (resolved and downloaded for `manylinux2014_x86_64`, not installed); the `/proc/self/environ` variant of F13; repository settings (tag rules, environments, trusted-publisher bindings); a local `.env` exists in the audit host's working tree (untracked, not read). Test scripts `publish-pins.test.sh`, `publish-readonly.test.sh` and the gate test were read for credentials, `curl`, `push`, registry URLs and container arguments: they run builds with `PACKBIN_BUILD_ONLY=1` (which unsets every credential), stubs, local bare repositories and tree copies, and pass no secret to a container.
