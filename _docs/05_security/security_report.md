# Security Audit Report

**Date**: 2026-10-05
**Scope**: packbin, loop 11: unpack of attacker-controlled bytes in Python, TypeScript, C#, Java and Rust (`git diff 9a7847f..HEAD`, HEAD 39d3a88), plus the session unpack path
**Verdict**: PASS_WITH_WARNINGS

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 3 |
| Low | 6 |

The loop 11 fixes hold. In 276 855 hostile packets per package (about 1.38 million unpack calls over five packages, 45 schemes) there was no hang, no panic, no out-of-bounds access and no memory blow-up from a count. The slowest packet took 2.9 ms. Python, Java and Rust agree on every verdict; TypeScript and C# differ only in the cases F4 to F6 and the ticketed items below. Three Medium findings remain, none in the count handling itself:

- one loop 11 goal is not fully met: in C# a 9-byte packet still makes `BinaryPacker.Unpack` throw (F4);
- TypeScript can be made to return a wrong decoded value without an error (F5, F6).

F4 is borderline High. It stays Medium because it throws to the caller (no memory fault, no hang, no wrong data) and the caller can catch it. It is High for any receive loop that has no `catch`, so fix it before a C# release.

The Low findings F1 to F3 are carried from loop 10; none of the CI, container or manifest files changed (see Supply chain).

## OWASP Top 10 Assessment

List: OWASP Top 10 2025, as in the 2026-09-29 and loop 10 reviews (not re-fetched; no network).

| Category | Status | Findings |
|----------|--------|----------|
| A01 Broken Access Control | N/A | — |
| A02 Security Misconfiguration | PASS | — |
| A03 Software Supply Chain Failures | PASS_WITH_WARNINGS | F1, F2, F3 (unchanged) |
| A04 Cryptographic Failures | PASS_WITH_WARNINGS | F9 |
| A05 Injection | PASS | — |
| A06 Insecure Design | PASS_WITH_WARNINGS | F6, F7 |
| A07 Authentication Failures | N/A | — |
| A08 Software or Data Integrity Failures | PASS_WITH_WARNINGS | F5, F8 (and F2) |
| A09 Security Logging and Alerting Failures | N/A | — |
| A10 Mishandling of Exceptional Conditions | PASS_WITH_WARNINGS | F4 |

## Findings

| # | Severity | Category | Location | Title |
|---|----------|----------|----------|-------|
| 4 | Medium | A10 | `csharp/Walker.Scalars.cs:79`, `csharp/ObjectValues.cs:118` | `BinaryPacker.Unpack` throws `OverflowException` for a `u64` or `i64` at the top of its range |
| 5 | Medium | A08 | `typescript/src/walker.ts:247-260` | A `dict` key `__proto__` replaces the prototype of the decoded dict and slips past the duplicate-key check |
| 6 | Medium | A06 | `typescript/src/walker.ts:122-123, 136-139` | A `when` inside `repeat` that names a field of the same round never fires, so the packet is cut at other field boundaries than in the other four packages |
| 7 | Low | A06 | `csharp/Walker.Counted.cs:350,410`; `rust/src/walk/unpack.rs:368` | Capacity is reserved from the packet's count before the bytes exist; no packet or element budget |
| 8 | Low | A08 | `typescript/src/kinds.ts:303` | The UTF-8 decoder drops a leading byte order mark |
| 9 | Low | A04 | `csharp/PackSession.cs:47`, `java/.../PackSession.java:53` | Concurrent `pack` on one session reuses a keystream |
| 1 | Low | A03 | `.github/workflows/test.yml`, `publish.yml` | `actions/checkout@v7` is not pinned to a commit (open since 2026-09-29, unchanged) |
| 2 | Low | A03 / A08 | `cpp/embedded/examples.sh:25` | `arduino-cli` tarball is downloaded and run without a checksum (unchanged) |
| 3 | Low | A03 | `cpp/embedded/Dockerfile:4`, `docker-compose.test.yml` | Base images are pinned by tag, not by digest (unchanged) |

### Finding Details

**F4: `OverflowException` escapes `BinaryPacker.Unpack`** (Medium / A10)
- Location: `csharp/Walker.Scalars.cs:79` (`ReadScalar` boxes every integer as `double`); `csharp/ObjectValues.cs:118` (`Convert.ChangeType(double, ulong or long)`).
- Description: the walker returns the value as a `double`, then the row binding converts it back to the property type. A `u64` of `0xFFFFFFFFFFFFFC00` or more rounds to 2^64 and an `i64` of `0x7FFFFFFFFFFFFE00` or more rounds to 2^63; both overflow the conversion. The error-as-value rule (AZ-2071 to AZ-2077) is broken for any C# scheme with a `U64` or `I64` field.
- Reproduction (run against the public API, scheme `Field.U64<Row>(0, x => x.U64v)` and `Field.I64<Row>(0, x => x.I64v)`): `01 ff ff ff ff ff ff ff ff` (u64) and `01 ff ff ff ff ff ff ff 7f` (i64) throw `OverflowException: Arithmetic operation resulted in an overflow`. `01 ff fb ff ff ff ff ff ff` (u64, 0xFFFFFFFFFFFFFBFF) and `01 ff fd ff ff ff ff ff 7f` (i64, 0x7FFFFFFFFFFFFDFF) are accepted. The Python, TypeScript, Java and Rust schemes with the same field return a value.
- Impact: one unauthenticated packet makes the call throw. A receive loop without a `catch` loses its thread or the process. No memory fault.
- Remediation: return exact integers (AZ-2116 covers the rounding but not this crash; add an AC), or range-check in `ConvertValue` and return the interim bad-value `ShortPacket`. Add the two packets above as vectors.

**F5: Prototype injection through a `dict` key** (Medium / A08)
- Location: `typescript/src/walker.ts:247` (`const items: Value = {}`), `:257` (duplicate check), `:260` (`items[key.value] = ...`).
- Description: assigning to the key `__proto__` on a plain object sets its prototype (for an object or array value) or does nothing (for a number), instead of adding an entry. Two `__proto__` keys both pass the duplicate check, because no own property is ever created.
- Reproduction: scheme `dict(x => x.acl, dict(x => x.inner, u8(0, x => x.x)))`, packet `01 0100 0900 5f5f70726f746f5f5f 0100 0500 61646d696e 01` (`{"__proto__": {"admin": 1}}`). Result `{ok: true}`, own keys of `acl` are `[]`, `acl.admin` is `1` and `"admin" in acl` is true. `Object.prototype` itself is not changed. With `dict(x => x.d, u8(...))` and two `__proto__` keys the result is `{ok: true}` with an empty dict. The other four packages keep the key and reject the second one.
- Impact: a packet can add keys to the decoded dict that application code sees by property access or `in`. A permission map read as `acl[resource]` can be made to grant a name the sender chose. Limited to the one decoded object; no global pollution.
- Remediation: build the dict with `new Map()`, or `Object.create(null)` plus `Object.defineProperty`, and check duplicates with `Object.hasOwn` on that object. Add a vector.

**F6: `when` inside `repeat` never matches a field of its own round in TypeScript** (Medium / A06)
- Location: `typescript/src/walker.ts:122-123` reads `values[name]`; in a `repeat` round `values[name]` is the list of all rounds so far (`appendRepeat`), so `=== f.value` is never true.
- Reproduction: scheme `repeat(0, [u8(0, k), when(1, eq(0, 1), [u8(1, v)])])`. Packet `01 01 0a`: TypeScript returns `{k: [1, 10]}`; Python, Java, C# and Rust read `k = 1`, then `v = 10` as one round. Packet `01 00 01`: TypeScript returns ok; the other four return a short packet. 106 of 106 differing packets in the first corpus and 47 in the second were this scheme; the other four packages never differed from each other on it.
- Impact: valid packets from another package are cut at other field boundaries and decoded to a different row with no error. A sender and a TypeScript gateway can see different content in the same bytes.
- Remediation: evaluate the condition on the values of the current round (as `times` already does with a fresh group), or resolve the reference at construction (AZ-2090 resolves scope but its table does not list the repeat round). Add the packet `01 01 0a` as a cross-package vector.

**F7: Capacity reserved from an attacker-chosen count** (Low / A06)
- Location: `csharp/Walker.Counted.cs:350` (`new List<object?>(count)`), `:410` (`new Dictionary<string, object?>(count)`); `rust/src/walk/unpack.rs:368` (`Vec::with_capacity(count)`). The `u16` count is not compared with the bytes left. Counts of `bits`, `packed` and `sized` are compared first and are safe.
- Evidence: a 3-byte packet `01 ff ff` (list or dict, count 65 535) allocates 0.5 to 2.6 MB in C# and 4.2 MB in Rust. In C# this lands on the large object heap and forces a generation 2 collection about every 10 packets: 62 µs a packet for `dict_u8`, against 8 µs for a small valid packet (20 000 packets, 2 000 generation 2 collections). Rust only reserves virtual memory (under 10 µs a packet). Linear amplification with a valid packet of 1 MB (measured): C# `times` 265 MB allocated, Rust `bits` 256 MB live, TypeScript `bits` 190 MB, Python `bits` 100 MB resident, Java `repeat` 70 MB allocated. Python needs 0.3 to 0.6 s of CPU for 1 MB.
- Impact: bounded and linear in the packet size, so a transport limit contains it; the C# small-packet case costs about 7 times a normal packet plus GC pauses for all threads.
- Remediation: reserve `Math.Min(count, bytesLeft)` (and `bytesLeft / 4` for a dict); state a maximum packet size in the README and tell callers to enforce it.

**F8: TypeScript drops a leading byte order mark** (Low / A08)
- Location: `typescript/src/kinds.ts:303`: `new TextDecoder("utf-8", { fatal: true })` strips `EF BB BF` by default.
- Reproduction: scheme `utf8(0, x => x.s)`, packet `01 0600 efbbbf 616263` returns `"abc"` in TypeScript and `"﻿abc"` in Python, Java and C# (Rust keeps it by `str::from_utf8`). `01 0300 efbbbf` returns `""`. A `dict` with keys `a` and `EF BB BF 61` returns an error in TypeScript (the keys collide) and two entries elsewhere.
- Impact: the same bytes give different strings; a name check or a key comparison made after decoding differs between packages.
- Remediation: pass `ignoreBOM: true`.

**F9: Session counter is not thread-safe in C# and Java** (Low / A04)
- Location: `csharp/PackSession.cs:47` (`_sendCount++`), `:58`; `java/src/main/java/packbin/PackSession.java:53`, `:63`.
- Evidence: 8 threads called `Pack` 20 000 times each on one session with the same plaintext: C# gave 46 893 distinct ciphertexts of 160 000, Java 44 546 of 160 000. Equal ciphertext for equal plaintext means one counter, so one ChaCha20 keystream, was used twice. Rust takes `&mut self` and cannot do this; Python and TypeScript are single-threaded by runtime.
- Impact: two packets under one keystream leak their XOR. The README does not state that a session must not be shared between threads. Not a loop 11 change.
- Remediation: use `Interlocked.Increment` / `AtomicLong` (and take the counter before packing), or document one session per thread.

**F1, F2, F3** (Low / A03): unchanged from loop 10 and still open. `actions/checkout@v7` appears in `test.yml` (lines 11, 51) and `publish.yml` (line 16); `examples.sh:25-27` still downloads `arduino-cli` without a checksum; the base images are tags. F3 also covers every image in `docker-compose.test.yml` (`dotnet/sdk:10.0`, `node:24`, `python:3.14`, `rust:1.98`, `gcc:16`, `eclipse-temurin:26-jdk`), not only the two named in loop 10. Remediation as in the loop 10 report.

## Evidence

Method: scratch programs outside the repository (`/private/tmp/claude-501/-Users-zxsanny-dev-zxsanny-packbin/02da6560-84eb-45e8-a2b7-c41bfedae5cd/scratchpad`: `gen.py`, `py/run.py`, `ts/run.ts`, `rs/run`, `java/Run.java`, `cs2/Run.cs`, driver `drive.py`, comparison `cmp.py`). The sources were read from the repository or copied; nothing in the repository was changed.

| Item | Result |
|------|--------|
| Schemes | 45, written by hand in each package: counts `u8/u16/u32/u64/i8/i64` for `sized`, `bits`, `packed` (width 1 and 2, bias 0 and -1) and `times`; `utf8`; `list`, `dict`, nested `list`/`dict`; zero-width elements; `repeat`, `when`, `flags`, flag behind a clear bit, `u2`, scalar `u64/i64/f32/f64` |
| Packets | corpus 1: 97 514 (boundary counts 0 to 2^64-1, negative counts, structured tails, random token streams, mutations); corpus 2: 179 341 (mutations of the accepted packets, count bytes overwritten at every offset). Rust skipped 3 schemes it refuses at build (an outer field named from inside a `repeat`/`times`/`list`) and ran `repeat_when2`/`times_when2` in their place |
| Guard | each packet in the driver process with a 3 s no-progress watchdog that kills and records the packet: 0 hangs, 0 crashes in all five packages. Slowest packet 2.9 ms. Rust ran with overflow checks and debug assertions on and again with them off: identical verdict on all 97 514 packets |
| Exceptions | Python, TypeScript, Java, Rust: 0 from the walker. C#: 0 from the walker, 78 from the row binding on `u64`/`i64` (F4) |
| Wrong but ok | none for a count. Python, Java, Rust, C# and TypeScript agree that every oversize, negative, wrapped or biased count is an error, except the known TypeScript `u64`/`i64` counts (AZ-2112, they error even when small) and F6 |
| Memory | no allocation from a count before the bytes were checked; see F7 for the two reservations that remain. 1 MB packets of `bits`, `packed`, `times`, `repeat`, `utf8` were measured in all five packages |
| Threads | 8 threads, 2.4 million unpack calls each in C# and Java on a split-flag scheme with two alternating packets: 0 rows with the other packet's flag. Python (fresh dict per call), Rust (local map) and TypeScript need no check |
| Session | 8 hostile bodies (oversize `u32` count, negative `i8` count, invalid UTF-8, list of lists of zero-width, dict with zero-width value, `bits` and `times` with a `u64`/`u32` count) sent through `PackSession` in all five packages: the waiter returns the same error as the clear unpack and the next valid message unpacks (counter advanced by one) |
| Construction | the orphan flag bit rules (flag byte in a `when`, byte outside a `repeat`, bit before its byte) refuse in TypeScript, C#, Java and Rust. They are not needed for termination: every loop that the packet can lengthen (`repeat`, `times`, `list`, `dict`) stops at runtime when a round or element reads nothing, in all five packages, so a scheme that bypasses or lacks a build check (Python, Rust bool/empty group) still ends. Not run: Rust on a 32-bit target (no target installed); the `try_from` conversions were read instead |

The session has no authentication tag. That is the accepted session criterion, not a finding.

## Known open items confirmed (ticketed; not re-opened)

| Ticket | What the probes showed |
|--------|------------------------|
| AZ-2112 | TypeScript rejects a `u64` or `i64` count even when small (`01` + 8 bytes of 0 + `sized`: error; the other four accept). 87 packets in corpus 1, 1 779 in corpus 2 |
| AZ-2116 | C# returns every integer as `double`; F4 is the crash this causes at the top of the range and should be added to the ticket |
| AZ-2119 | C# `KeyNotFoundException` escapes `Unpack` for a list or dict whose element does not store under its own name. It also happens for a `Flags` element, not only a group: `List(x => x.Xs, Flags(0, U8(0, x => x.X)))`, packet `01 0100 00` |
| AZ-2092 | C# typed binding of a `repeat` or `times` of scalar fields throws `InvalidCastException` on a valid packet (`times` count 1, one byte: `01 01 ee`) |
| AZ-2079, 2080, 2082, 2083 | nine flag bits build in C#, TypeScript, Rust and Python; Java refuses. A `bool` outside `flags` builds in Python, TypeScript, C#, Java |
| AZ-2087, 2089, 2090, 2113 | a `when` or count that names a later field builds in C#, TypeScript, Java, Python; Rust refuses |
| AZ-2100 | Python cannot build a split-form flag byte (`ValueError: field id 1 is not the next order 2`) |
| AZ-2114 | no C#, Java or Rust session test, but the behaviour is correct (Evidence, Session) |
| not ticketed, documented for Rust only | an outer field named from inside a `repeat` or `times`: Rust refuses at build; Python and Java see the outer value; C# sees none in `repeat` and none in `times`; TypeScript sees it in `repeat` and none in `times`. No hang in any |

## Supply chain and CI

No file outside the five package directories and `_docs` changed since 9a7847f (`git diff --name-only`). No workflow, Dockerfile, compose file, script, manifest or lockfile changed. Dependencies are the loop 10 set: TypeScript `@noble/hashes` 2.4.0, no dependencies in the other four. `npm audit`, `cargo audit` and `dotnet list package --vulnerable` need the network and were not run; results of 2026-09-29 stand.

## Dependency Vulnerabilities

| Package | CVE | Severity | Fix Version |
|---------|-----|----------|-------------|
| none | — | — | — |

## Recommendations

### Immediate (Critical/High)

None. Fix F4 before any C# release.

### Short-term (Medium)

- F4: exact integers or a range check in `ConvertValue`; vectors `01 ff*8` (u64) and `01 ff*7 7f` (i64), and `01 ff fb ff*6` / `01 ff fd ff*5 7f` as the accepted neighbours.
- F5: build `dict` results without a prototype chain; vector with the key `__proto__`.
- F6: evaluate `when` on the current round; vector `01 01 0a`.

### Long-term (Low / Hardening)

- F7: reserve `min(count, bytes left)`; document a maximum packet size.
- F8: `ignoreBOM: true`.
- F9: atomic counter or a documented one-thread rule.
- F1 to F3 as in loop 10 (pin `actions/checkout` to a commit, check the `arduino-cli` archive against a SHA-256, pin images by digest).
- Add the AZ-2119 and AZ-2116 additions above to those tickets.

## Loop 11 re-verification

**Date**: 2026-10-05
**Tree**: HEAD 39d3a88 plus the uncommitted fixes AZ-2122 (TypeScript), AZ-2123 (C#), AZ-2124 (Java), AZ-2125 (Rust). Same method and read-only rules; the "before" runs of this audit were kept for comparison, and HEAD was also built in the scratchpad (`git archive`) as a baseline.
**Verdict**: PASS_WITH_WARNINGS. Open: 0 Critical, 0 High, 0 Medium, 4 Low (F1, F2, F3, and the remaining part of F7). No new finding.

| # | Result | Evidence with the inputs from this report |
|---|--------|-------------------------------------------|
| F4 | Fixed | C# `Unpack` of `01 ff ff ff ff ff ff ff ff` (u64) and `01 ff ff ff ff ff ff ff 7f` (i64) returns ok; also `…fc00`/`…7ffffffffffffe00` and the accepted neighbours. HEAD baseline throws `OverflowException` on the same packets. The fixed value is exact: 2 109 `u64`/`i64` packets from the corpora decode to the same number as `int.from_bytes` (0 mismatches); at HEAD they were rounded doubles |
| F5 | Fixed | TypeScript `{"__proto__": {"admin": 1}}` (`01 0100 0900 5f5f70726f746f5f5f 0100 0500 61646d696e 01`) now gives own key `__proto__`, `acl.admin` undefined, `"admin" in acl` false. Two `__proto__` keys return an error (short packet, field `d`). `Object.prototype` untouched |
| F6 | Fixed | `repeat(u8 k, when(eq(k,1), u8 v))`: `01 01 0a` is ok in all five packages with the same row (`k=[1], v=[10]`; Python and Java checked row for row, TypeScript, Rust and C# by verdict); `01 00 01` is a short packet (field `v`) in all five; `01 00 01 0a 00` gives `k=[0,1,0], v=[10]`. In both corpora the 106 and 47 TypeScript-only differences on this scheme are gone |
| F7 | Partly fixed | The reservation from the packet's count is gone: a 3-byte `01 ff ff` list/dict packet now costs C# 0.4 µs and 0 generation 2 collections (was 62 µs, 2 000 collections per 20 000 packets); largest allocation for any small hostile packet fell from 2.5 MB to 51 KB in C# and from 4.2 MB to 20 KB in Rust. Still open (Low): no packet or element budget, so the linear amplification is unchanged (1 MB packet: Rust `bits` 256 MB, C# `times` 265 MB, TypeScript `bits` 190 MB, Python 100 MB) and the README says nothing about a maximum packet size |
| F8 | Fixed | TypeScript `01 0600 efbbbf 616263` returns `U+FEFF a b c` (as Python, Java, C#); `01 0300 efbbbf` returns `U+FEFF`; keys `a` and `EF BB BF 61` give two entries |
| F9 | Fixed | 8 threads × 20 000 `Pack` of an 8-byte field on one session: C# 160 000 distinct ciphertexts of 160 000 (HEAD: 85 481); Java 160 000 of 160 000 (HEAD: 77 891). The first F9 test used a 1-byte field, so distinct values were capped at 65 536 by chance; the new test is not capped. Hostile session payloads (8 bodies, five packages) still return the clear-unpack error and the next valid message unpacks |
| F1, F2, F3 | Still open | unchanged files |

**Regression run.** Same 45 schemes and the same 97 514 + 179 341 packets in all five packages, watchdog and allocation guard as before: 0 hangs, 0 crashes, 0 walker exceptions, slowest packet 11 ms on the first run (a one-off spike on a 40-byte packet; a rerun gave 0.65 ms in Python and 4.8 ms in TypeScript), no growth in time or allocation for small packets.
- Python, Java, Rust and C# verdicts are identical to the previous run on every packet. TypeScript differs from its previous run only on `repeat_when2` (106 and 47 packets, the F6 fix). Against Python the remaining differences are the unchanged ones: TypeScript `u64`/`i64` counts (AZ-2112) and the outer-field-in-`times` case, C# outer field in `repeat`/`times`, Rust build refusals.
- Decoded values, not only verdicts: TypeScript rows from HEAD and the fixed tree are identical on all accepted packets except `repeat_when2`. C# rows are identical except `u64`/`i64` fields (now exact). So the TypeScript repeat/round rewrite, the own-property dict and the C# 64-bit typing changed nothing else.
- Counts: no wrong-but-ok result for an oversize, negative, wrapped or biased count in any package after the fixes (C# `ulong`/`long` counts included; the sized/bits/packed/times u64 and i64 schemes agree with Python). C# `BIND_OverflowException` fell from 70 and 78 to 0; the remaining `InvalidCastException` (3 801 and 7 255, repeat/times of scalar properties) is AZ-2092 and is unchanged.
- Thread safety of flag state: 2.4 million concurrent unpacks each, C# and Java, 0 wrong rows.

**Notes, no finding.**
- The TypeScript dict now carries `__proto__` as an own property, like `JSON.parse`. Spread (`{...acl}`) is safe; `Object.assign({}, acl)` re-triggers the setter on the target and gives that target `admin` (local, `Object.prototype` is not changed). Callers that copy decoded dicts with `Object.assign` or a deep merge should skip `__proto__`.
- The receive counters (`_recvCount`, `recvCount`) are still plain increments. Concurrent `unpack` on one session has no valid order, so this is not a keystream reuse.
- Tickets AZ-2116 (exact types for the narrower scalars) and AZ-2119 (`Flags` element: `01 0100 00` with `List(Flags(0, U8))` throws `KeyNotFoundException`) are still open as before; the two additions suggested above for them stand (AZ-2116's crash part is now covered by AZ-2123).
