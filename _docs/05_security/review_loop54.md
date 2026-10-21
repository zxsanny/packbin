# Security review — a `when` of a skipped source, and the C# text reuse (loop 54, AZ-2815, AZ-2816, AZ-2823)

**Date**: 2026-10-21 · **Scope**: `git diff effdf04..HEAD` on `cpp/src/core`, `cpp/include/packbin`, `csharp/PackOut.cs`, `csharp/Walker.Counted.cs` (tests, corpus and runners read for what they pin) · **Verdict**: PASS (no Critical, High or Medium; two Low observations)

## Trust boundary

C++ `unpack` reads untrusted bytes in firmware; `when_matches` runs on that path for every `when`. C# `Pack` is called with rows the program holds; the cache holds program data, not packet data.

## Surfaces

| Input | Bound | Evidence |
|-------|-------|----------|
| Packet bytes in C++ unpack | `source_skipped` reads only table links (`Field::bit`, `Field::ref`), which `resolve` writes at scheme construction from a validated table; a link is the distance back to an earlier `when` (`mark_held`: `w < k`, at most 255), so `k -= k->bit` stays inside the table and moves strictly backwards. A packet value never selects a table index | `order.hpp` `mark_held`; `ac6_source_link_is_limited_to_255_entries`; hostile corpus (72 cases) and the fuzz corpora in step 11 |
| Recursion | `when_matches` -> `source_skipped` -> `when_matches` ends: each call goes to an earlier table entry (`find_ref` returns a source before its consumer). Its depth is the nesting of the scheme, not a count read from the packet | `find_ref`; review finding 1 (stack depth on the Cortex-M4F not measured) |
| CPU per round | a `when` in a round now costs a walk of its source's chain, once per round; the chain length is the scheme's nesting. The earlier square-of-scheme-size note (L51-1) is unchanged in order | step 11 speed suites unchanged |
| Skipped source as 0 | on unpack a plain unread source holds 0; it can no longer match `when(k == 0)`, so a packet that is shorter than the scheme's `when` expects is read as the other packages read it (`TrailingBytes` / `ShortPacket` as before for real mismatches) | `ac2_plain_members_unread_source_is_not_zero`, mutant fails |
| C# text cache | one text and its field (at most 65,535 bytes plus the header) per pack call, released with the call; no static, no sharing between calls or threads; equality is by the whole byte array | `RepeatedTextReuse.Ac4_*`, `CompactTextTests.Concurrency` |

## Observations

- **L54-1 (Low)**: a C++ scheme with more than 255 table entries between a `when` and a source it holds is now refused at construction (it built before). No scheme in the repository is near it; a refusal at build time is the safe failure.
- **L54-2 (Low)**: the recursion depth of a nested source chain is not measured on the 512 B stack budget (8 B margin). The depth is set by the developer's scheme, not by a packet; handoff 55 asks for a measurement.

No secret, key or network path is touched. No dependency is added.
