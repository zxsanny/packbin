# Static analysis

**Date**: 2026-10-05
**Scope**: `cpp/src/core`, `cpp/include/packbin`, `fixtures/hostile`, `.github/workflows`

| Check | Result |
|-------|--------|
| Heap, exceptions, RTTI in the core | none. The M0+ link check finds `__cxa_*` 0 and heap references 0 (embedded job) |
| Unbounded copies and formatted output | `strcpy`, `sprintf`, `malloc`, `new` do not appear. Every `memcpy` is guarded: `put_bytes` checks `cap - len < n` (`core.hpp:119`); `get_bytes` checks `left() < n` (`core.hpp:129`); `store_text` checks `n > f.size` for fixed storage (`values.cpp:145`); the session copies fixed 16/32/64-byte blocks |
| Integer overflow in sizes | F0 (fixed): a 64-bit count was narrowed to a 32-bit `size_t` in `unpack_small`, `unpack_text` and `item_count`. Counts are now clamped by `clamp_count` before narrowing; the `bits`/`packed` byte length is computed in 64 bits; the capacity check compares in `int64`. Regression vector `wide_count_is_not_truncated` runs on Cortex-M3 QEMU |
| Untrusted-input fuzz | the all-kinds scheme (49 table entries, every kind) packed once (132 bytes), then 20 000 000 mutated packets (byte set, bit flip, truncate, append, 0x00/0xff) were unpacked from exact-size heap copies under AddressSanitizer + UndefinedBehaviorSanitizer (`-fno-sanitize-recover`): 5 711 734 unpacked, 14 288 266 returned an error, 0 sanitizer reports. The host is 64-bit, so the fuzz could not show F0 |
| Hostile vectors | the 17 shared cases run on the host with a 1 s watchdog and canary bytes around the row: 0 hangs, 0 writes outside the row |
| Termination | a repeat round that reads nothing now ends the repeat; any container round that reads nothing ends an unbound container. The earlier path (an unbound `times` with a zero-width body and a `u32` count of 0xffffffff ran about 10 s) was found by review and fixed in batch 5 |
| Secrets | none in the tree. `.env` is untracked; `.env.example` holds no values |
| Shell injection in new scripts | `fixtures/hostile/check-cases.sh` reads a data file with `set -f` and quoted expansions; no `eval` |
| CI downloads | `cpp/embedded/examples.sh:25` fetches the `arduino-cli` tarball without a checksum (F2) |

## Loop 11 addendum

**Date**: 2026-10-05
**Scope**: unpack in `python/src/packbin/_unpack.py`, `typescript/src/{walker,kinds,pack-fields,flag-scope}.ts`, `csharp/{Walker*,Scope,FlagGroup,FlagScopes}.cs`, `java/.../{Walker,Containers,VarFields,Scalars,SchemeOrder}.java`, `rust/src/{walk,field}/*.rs`

| Check | Result |
|-------|--------|
| Differential fuzz | 45 hand-written schemes in each package, 276 855 packets (boundary counts, negative counts, structured tails, mutations, count bytes overwritten at every offset), 3 s no-progress watchdog, per-packet allocation: 0 hangs, 0 panics, 0 walker exceptions, slowest 2.9 ms. Python, Java and Rust agree on every verdict; TypeScript and C# differ only in F5/F6 and AZ-2112 |
| Termination | every packet-driven loop (`repeat`, `times`, `list`, `dict`) stops when a round or element reads nothing; the other loops (`bits`, `packed`, `u2`) are bounded by bytes checked first. Nesting depth comes from the scheme, not the packet |
| Count narrowing | Python and TypeScript hold the count exactly (TypeScript errors on a bigint count); Java reads a count as `long` and compares with the bytes left before narrowing; C# clamps to `long` and `int` before use (`FitsItems`); Rust uses `try_from` and `checked_*` (`packed_layout`). No wrong-but-ok result for an oversize, negative, wrapped or biased count |
| Invalid UTF-8 | Python, TypeScript, C# (`Utf8.IsValid`), Java (`REPORT` decoder), Rust (`from_utf8`) return an error value. TypeScript drops a leading BOM (F8) |
| Uncaught exceptions | C# row binding overflows on the top of `u64`/`i64` (F4) and on a list or dict element that stores no value under its name (AZ-2119, also for `Flags` elements). TypeScript: none. Java, Rust, Python: none |
| Object injection | TypeScript `dict` keys write into a plain object: `__proto__` replaces the prototype (F5). The other four use maps |
| Capacity | C# `List(count)`/`Dictionary(count)` and Rust `Vec::with_capacity(count)` for `list`/`dict` use the `u16` count before the bytes are checked (F7) |
| Shared state | C# `Scope` and Java `seen` hold flag bytes per call; 2.4 million concurrent unpacks per package returned 0 wrong rows. The session counter is shared and not atomic (F9) |
| Secrets, shell, markup | no change in these files |

## Loop 13 addendum

**Date**: 2026-10-06
**Scope**: unpack in `csharp/Walker*.cs`, `typescript/src/{rounds,walker,member-names,pack-fields}.ts`, `rust/src/walk/{unpack,times,element}.rs`, `rust/src/scheme/times.rs`, `java/.../Rounds.java` (loop 12); the loop 12 and 13 diffs

| Check | Result |
|-------|--------|
| Differential fuzz, loop 11 corpora | 276 855 packets in five packages, 3 s no-progress watchdog: 0 hangs, 0 crashes, 0 walker exceptions. Against the loop 11 results, the only change is three schemes (`list_when`, `repeat_when`, `times_zero_u32`) that now fail at construction in TypeScript, C# and Java |
| Differential fuzz, loop 13 corpus | 245 523 packets over `repeat(flags)`, `repeat(k, flags, when)`, `times(flags)` in TypeScript, C#, Java and Rust: identical accept / refuse verdict on every packet, 0 exceptions, 0 hangs |
| Typed `times` (Rust) | 260 379 packets over three `Vec<E>` schemes: 0 panics, 0 hangs |
| Amplification | F10, measured per package; linear in the packet length |
| Allocation from a count | C# `Math.Min(count, bytes left)` (`Walker.Counted.cs:359,419`), Rust `capacity_hint` (`walk/unpack.rs:362`); `bits` and `packed` lists reserve up to 8 (4) slots per byte left, bounded by the packet. No new reservation from a packet count |
| Panics in decode paths | no `unwrap`, `expect`, `unsafe` or unchecked index added to Rust decode code; the added `panic!` calls are in scheme construction and name the rule |
| Object injection | TypeScript rounds are keyed by member names the scheme declares; `dict` keys from the wire are defined as own entries (`walker.ts:236`), probe on `__proto__` returns an own key and no inherited `admin` |
| Secrets, shell, markup | no key, token or password in the diff; changed scripts (`language-pair.sh`, `publish-gate.test.sh`, `examples.sh`, `lib.sh`) have no `eval`, `curl | sh`, `sudo`; the GPG key in `publish-gate.test.sh` is generated into a temporary keyring |
