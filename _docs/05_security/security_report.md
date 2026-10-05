# Security Audit Report

**Date**: 2026-10-06
**Scope**: packbin, loop 13 and the loop 12 changes that had no audit: unpack of attacker-controlled bytes in all six packages (`git diff 39d3a88..HEAD`, HEAD fb9e34c; production sources changed in C#, TypeScript and Rust in loop 13, in Java, Python and C++ in loop 12 only), supply chain and CI
**Verdict**: PASS_WITH_WARNINGS

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 1 |
| Low | 4 |

The loop 13 changes hold against hostile packets. Over 2.63 million unpack calls (the loop 11 corpora, 276 855 packets in each of five packages, plus two new corpora aimed at loop 13's aligned rounds and Rust's typed `times`: 245 523 packets in four packages and 260 379 in Rust) there was no hang, no panic, no walker exception, no out-of-bounds access and no allocation from a count before the bytes were checked. Against the loop 11 results the only differences are three schemes that now fail at construction, as intended (a `when` that names a field outside its own scope).

One finding is new and Medium: unpacking a `repeat` or `times` round now costs memory and time that grow with the names the round can hold (F10). A 1 MiB packet of one-byte rounds peaks at 401 MB in TypeScript, 525 MB in C#, 570 MB in Java and 311 MB (1.4 GB with eight set flag bits) in Rust. It is linear in the packet length and never grows with a count the packet states, so a packet-length cap contains it, but the library has no budget of its own. The owner accepted it during the loop 13 assessment (X10) and the README states it; it is rated Medium, and High for a service that reads packets of a megabyte or more without a cap. F11 (Low) is the missing test that would catch a regression.

F4 to F9 (loop 11) are fixed and still hold on HEAD. F1 to F3 (Low, supply chain) are unchanged.

## OWASP Top 10 Assessment

List: OWASP Top 10 2025, as in the earlier reviews (not re-fetched).

| Category | Status | Findings |
|----------|--------|----------|
| A01 Broken Access Control | N/A | — |
| A02 Security Misconfiguration | PASS | — |
| A03 Software Supply Chain Failures | PASS_WITH_WARNINGS | F1, F2, F3 (unchanged) |
| A04 Cryptographic Failures | PASS | — (session code unchanged since loop 11; F9 fix verified) |
| A05 Injection | PASS | — |
| A06 Insecure Design | PASS_WITH_WARNINGS | F10, F11 |
| A07 Authentication Failures | N/A | — |
| A08 Software or Data Integrity Failures | PASS | — (F5, F8 fixes verified) |
| A09 Security Logging and Alerting Failures | N/A | — |
| A10 Mishandling of Exceptional Conditions | PASS | — (F4 fix verified; the C# typed `Unpack` of a round is the known AZ-2092, below) |

## Findings

| # | Severity | Category | Location | Title |
|---|----------|----------|----------|-------|
| 10 | Medium | A06 | `csharp/Walker.Rounds.cs`, `typescript/src/rounds.ts`, `java/.../Rounds.java`, `rust/src/walk/{unpack,times}.rs` | Unpack of a `repeat` / `times` round costs memory and time per name per round, with no budget |
| 11 | Low | A06 | `fixtures/hostile/cases.test.sh`, the six hostile replays | No test bounds unpack cost by packet size |
| 1 | Low | A03 | `.github/workflows/test.yml`, `publish.yml` | `actions/checkout@v7` is not pinned to a commit (open since 2026-09-29, unchanged) |
| 2 | Low | A03 / A08 | `cpp/embedded/examples.sh:25` | `arduino-cli` tarball is downloaded and run without a checksum (unchanged) |
| 3 | Low | A03 | `cpp/embedded/Dockerfile:4`, `docker-compose.test.yml` | Base images are pinned by tag, not by digest (unchanged) |

### Finding Details

**F10: Unpack of a round amplifies memory and time** (Medium / A06)
- Location: C# `Walker.Rounds.cs` (round slicing and alignment), TypeScript `rounds.ts` (`RoundLists`, padding with `undefined`), Java `Rounds.java` (aligned unpack, loop 12), Rust `walk/unpack.rs` and `walk/times.rs` (one `Values` per round).
- Description: since the aligned-round change (AZ-2087, AZ-2091, AZ-2086 in loop 13; AZ-2089 in Java in loop 12) a `repeat` or `times` round keeps one slot for every name it can hold, even for a round that read nothing, so a row packs again to the same bytes. The cost per round grows with the names in the body. Rust keeps one `Values` map per round instead, about 300 bytes per one-byte round regardless of the names, and about 1.3 KB when the round sets eight flag bits.
- Evidence (1 MiB packet of one-byte rounds, one `when` body of N `u8` names, every round skipping the body; peak resident set and time of one `unpack`, one process each; macOS arm64, Node 22.23, .NET 10.0.103, Java 21.0.2, Rust 1.79 release build with overflow checks):

| Package | Names | Before (`ce85fe0`) | HEAD |
|---------|-------|--------------------|------|
| TypeScript | 1 / 4 / 16 / 36 | 130 MB, 62 ms (1) / 129 MB, 64 ms (36) | 138 / 160 / 240 / 401 MB; 77 / 90 / 135 / 228 ms |
| C# | 1 / 4 / 16 / 36 | 94 MB, 312 ms (1) / 93 MB, 314 ms (36) | 109 / 142 / 289 / 525 MB; 328 / 474 / 752 / 1300 to 1538 ms |
| Java (not changed in loop 13) | 1 / 4 / 16 / 36 | not measured | 106 / 162 / 361 / 570 MB; 94 / 142 / 541 / 715 to 1185 ms |
| Python (lists only the rounds that read a name) | 1 to 36 | not measured | 33 MB; 700 to 865 ms |
| Rust map `repeat` | any | 277 MB, 125 to 141 ms | 278 MB, 130 to 185 ms |
| Rust map `times` | 1 / 36 | 36 MB, 136 ms | 311 MB, 184 to 211 ms |
| Rust typed `times` (`Vec<E>`) | 1 byte per round | not measured (3-argument form removed) | 311 MB, 178 ms |
| Rust typed `times`, flags with 8 bool members all set | 1 byte per round | not measured | 1346 to 1425 MB, 1294 to 1400 ms |

- The cost is linear in the packet length (the loop 11 checks hold: no allocation from a count before the bytes exist) and grows by about 7.5 (TypeScript), 12 (C#) and 13 (Java) bytes per name per round.
- Impact: one packet of about 1 MiB makes the reader allocate 0.3 to 1.4 GB and burn up to 1.5 s of one core. Ten concurrent 1 MiB packets hold about 5 GB in C# and about 14 GB in the Rust eight-flag case. A packet-length cap contains it (64 KiB costs 16 times less); without one this is a remote denial of service from an unauthenticated peer.
- README: "Limits to keep in mind" states the cap requirement and the figures. Corrected in this audit: C# "about 550 MB" to 530 MB, Java "about 540 MB" to 570 MB, Rust eight flag bits "about 1.3 GB" to 1.4 GB, C# "about a second" to 1.4 seconds.
- Remediation (owner decision; the first is today's state): (1) keep the documented cap requirement; (2) add an optional per-call budget (maximum rounds and maximum slots), default off, refused with the existing short-packet error; (3) shrink the representation: keep one list per name that held a value plus the round indices, and pad on demand; in Rust decode a typed `times` straight into its `Vec<E>` instead of through `Values`.

**F11: No test bounds unpack cost by packet size** (Low / A06)
- Location: `fixtures/hostile/README.md` (1 s per case), `cases.txt`, the six replays.
- Description: every hostile vector is a few bytes, so the 1 s budget never trips. A change that doubles the per-name cost, or makes a round quadratic, passes all six suites. F10 was found by measuring by hand, not by a test.
- Remediation: one size-scaled case (a 256 KiB packet of one-byte rounds with a body of 16 names) replayed against each package with a time budget and, where the runtime exposes it, an allocation budget per packet byte. Ticket it with F10's decision.

**F1, F2, F3** (Low / A03): unchanged and still open. `actions/checkout@v7` in `test.yml` (lines 11, 51) and `publish.yml` (line 16); `examples.sh` downloads `arduino-cli` without a checksum (the file changed only to move its cache to `.cache/embedded/`); base images and the six test images in `docker-compose.test.yml` are tags, not digests.

## Closed since loop 11 and verified on HEAD

| # | What | How it was checked |
|---|------|--------------------|
| F4 | C# row binding threw `OverflowException` on the top of `u64` / `i64` | 0 occurrences of `Overflow` in 276 855 packets; AZ-2123 |
| F5 | TypeScript `dict` key `__proto__` replaced the prototype | probe packet `01 0100 0900 5f5f70726f746f5f5f 0100 0500 61646d696e 01`: `ok`, own keys `["__proto__"]`, `acl.admin` undefined |
| F6 | TypeScript `when` inside `repeat` never matched a field of its round | `repeat_when2` and `times_when2` (a `when` on a field of its own round): all five packages return the same verdict on every one of their 12 420 packets; AZ-2090 |
| F7 | capacity reserved from the count | `Math.Min(count, bytes left)` in C# (2 sites), `capacity_hint` in Rust (2 sites) |
| F8 | TypeScript dropped a leading byte order mark | `ignoreBOM: true` at `typescript/src/kinds.ts:345` |
| F9 | session counter not thread-safe in C# and Java | `Interlocked` in `PackSession.cs`, `Atomic*` in `PackSession.java` |

## Known open items confirmed (ticketed; not re-opened)

| Ticket | What the probes showed |
|--------|------------------------|
| AZ-2092 | C# typed `Unpack` of a packet that holds a `repeat` or `times` round throws `InvalidCastException`: 95 064 of the 95 703 packets the walker accepted in corpus 3. It is the valid packet that throws, not a hostile one; the README says so |
| AZ-2112 | TypeScript rejects a `u64` / `i64` count even when small: 87 packets in corpus 1, 1 779 in corpus 2, as in loop 11 |
| AZ-2126, AZ-2181 | which kinds a `when` or a count may name; open, Medium, unchanged |
| AZ-2197 | TypeScript pack tests a `when` on the row you give it; pack-side, no untrusted input |

## Recommendations

### Immediate (Critical/High)
None.

### Short-term (Medium)
- F10: the owner picks (1) keep, (2) budget, or (3) compact representation, and records it; if (2) or (3), one ticket per package family (C#, TypeScript and Java share the padded form; Rust has its own).

### Long-term (Low / Hardening)
- F11: one size-scaled hostile case.
- F1 to F3: pin the action to a commit, check the `arduino-cli` checksum, pin base images by digest (all unchanged).

## Evidence

Method: scratch programs outside the repository (`/private/tmp/claude-501/-Users-zxsanny-dev-zxsanny-packbin/b668625c-993b-4bc1-972f-098e72477246/scratchpad/`: `fuzz/` for the corpora, `amp/` for the amplification probes); the sources were read from the repository or copied from it (the Rust copy and the baseline come from `git archive`); nothing in the repository was changed by the audit.

| Item | Result |
|------|--------|
| Corpora 1 and 2 (loop 11) | 97 514 and 179 341 packets, 45 hand-written schemes, five packages. 0 hangs, 0 crashes, 0 walker exceptions in all five; slowest packet 37.5 ms (TypeScript), 31.1 ms (Python), 11.5 ms (Java), 3.4 ms (C#), 0.2 ms (Rust). Against the loop 11 results: no difference in Python or Rust; in TypeScript, C# and Java the only differences are `list_when`, `repeat_when` and `times_zero_u32` (2 652 / 2 652 / 2 874 packets in corpus 1), which now fail at construction because their `when` names a field outside its own scope (AZ-2087, AZ-2090; Java since loop 12) |
| Corpus 3 (new) | 245 523 packets over `repeat(flags(bool on, u8 n))`, `repeat(u8 k, flags(bool on, u8 n), when(k == 1, u8 v))` and `u8 c; times(c, u8 k, flags(bool on, u8 m))`: every 0 to 2 byte body, 4 000 structured and 2 000 random streams per repeat scheme, mutations of valid packets, every count 0 to 299 plus 255 / 256 / 257 / 511 / 512. TypeScript, C#, Java and Rust: 95 703 accepted, 149 820 refused, **0 packets differ between the four packages**, 0 exceptions, 0 hangs, slowest 25.7 ms (Rust) |
| Corpus 4 (new, Rust only) | 260 379 packets over three typed `times` schemes (`Vec<Point>`, `Vec<Leg>` with `flags(opt_u8)`, `Vec<Item>` with `when` + `utf8` + `flags(bool)`), counts matched to the rounds in 60% of the valid-shaped packets: 14 337 accepted, 246 042 refused, 0 panics, 0 hangs, slowest 0.15 ms |
| Amplification | table in F10, one process per measurement, `/usr/bin/time -l` for the peak resident set |
| Static analysis | no `unsafe`, `unwrap` or `expect` added to a Rust decode path (the added `panic!` calls are in scheme construction and name the rule); allocations in the new C#, TypeScript and Rust unpack code are bounded by the packet length (`Math.Min(count, bytes left)`, `capacity_hint`); no `eval`, `curl | sh`, `sudo` or `chmod 777` in the changed scripts; no key, token or password in the diff; the GPG key the publish-gate test imports is generated into a temporary keyring by the test (`publish-gate.test.sh:199-205`) |
| Dependencies | `npm audit` (registry reachable): 0 vulnerabilities; `dotnet list package --vulnerable --include-transitive` for the test project and the C# driver: none; `cargo audit` failed to load the advisory database (the installed 0.21.1 cannot parse CVSS 4.0 entries), but `rust/Cargo.lock` lists only the crate itself and the driver crate depends only on it; Python, Java and C++ have no dependencies |
| Not covered | C++ (no production source changed since the loop 10 audit's 20 M sanitizer run, apart from the loop 12 bool rule at construction); the session code (unchanged); DAST (library, no service) |
