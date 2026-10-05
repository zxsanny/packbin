# Batch Report

**Batch**: 5 (assessment round 1 extension: AZ-2179, one driver worker per package, `language-pair.sh` by the parent)
**Tasks**: AZ-2179_rounds_ring
**Date**: 2026-10-05

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-2179_rounds_ring | Done | 7 files (the ring script, 5 drivers, 1 new Rust driver module) | `language-pair.sh` passes with the two new rings (about 65 s) | C# is producer-only (no public reader, AZ-2092) |

Files: `.github/workflows/language-pair.sh` (constants `roundflags_hex`, `roundwhen_hex`, ten `handoff` lines), `drivers/handoff.ts`, `drivers/Handoff.java`, `drivers/handoff.cpp`, `drivers/csharp/Handoff.cs` (pack commands only), `drivers/handoff-rust/src/main.rs` and new `src/rounds.rs`. No production package file changed.

The rings: `roundflags` = `repeat(flags(bool on, u8 n))`, on = [true, false, true], n = [1, 2, 3], bytes `01030102020303`, readers see on = [true, null, true]; `roundwhen` = `repeat(u8 k, when(k == 1, u8 v))`, k = [1, 2], v = [9], bytes `01010902`, readers see v aligned as [9, null] (Rust and C++ read two rounds, the second without a `v`). Producers: C#, TypeScript, Rust (map form), Java, C++. Readers: TypeScript, Rust, Java, C++ (each reads the row, checks it is exactly the aligned expectation, repacks the read row and compares with the input bytes). Python joins with AZ-2134.

## Code Review Verdict: PASS_WITH_WARNINGS

One fresh reviewer (read-only, scratch copies). Mutation results: every mutant failed the ring (non-zero): TypeScript padding dropped, round order reversed, wrong expected row; Rust absent entry filled with `U8(0)`, round order reversed; Java null store removed, pack index reversed; C++ bool made present, `when` always taken, pack order reversed; C# `n` changed. 29 negative inputs per ring and per reading language (wrong hex, a third or fourth round, a missing round, truncated, header-only, empty, wrong type byte, non-hex, odd length) all exit non-zero, except the two findings below. C++ `Array<_,4>` refuses a fifth round (`TooMany`), it does not truncate. The full script ran end to end in a scratch copy (81 s cold). Zero warnings (C++ `-Wall -Wextra -Werror`, cargo build and clippy, `dotnet build`).

- Medium F1 (accepted by the spec, AC-3): C# is producer-only; its read side is unchecked across languages until AZ-2092 lands a public reader (`BinaryPacker.Read` is internal; the typed `Unpack` throws `InvalidCastException` for a round list). The ring comment and the spec's flagged concern name it. The driver worker stopped at the missing API instead of using reflection.
- Low F2 fixed: the TypeScript unpack compared its repack with a literal, so a trailing `zz` or an odd-length tail passed; it now compares with the input hex (like Java, Rust, C++) and rejects both.
- Low F4 fixed: Java `repacks` helper got `@SuppressWarnings("rawtypes")`; `javac -Xlint:all` is silent on the driver.
- Low F3 (pre-existing, not reachable from the ring): the C++ driver's `parse_hex` drops an odd last nibble.
- Low F5: `rounds.rs` must be added to git (the commit does) and the README badge block is the owner's separate change.

## Test Suite

- No package code changed in this batch: C# 390, TypeScript 241, Python 103, Rust 217, Java 4 runners 0 failures, C++ all tests passed (same as batch 4)
- Failed: 0
- `language-pair.sh`: all rings pass, including `roundflags` and `roundwhen` (re-run after the two driver fixes: exit 0, 65 s)
- CI-parity: PASS — `docker compose -f docker-compose.test.yml run --rm {typescript,rust,csharp,python,cpp,java}` (all six exit 0), `bash fixtures/hostile/cases.test.sh`, `bash .github/workflows/report-row.test.sh`, `tsc --noEmit --strict` over `typescript/src/index.ts`, `bash .github/workflows/language-pair.sh`.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | C# has no public API that reads an aligned round row: `BinaryPacker.Read` is internal and the typed `Unpack` throws `InvalidCastException`; a NuGet consumer cannot read a repeat/times row at all | AZ-2179 AC-3; assessment C11 | AZ-2092 (typed binding of round lists); the ring's C# read side stays unchecked until then; README upgrade note | unclear |
| 2 | Rust expresses a bool as an empty `group` with `Value::U8(1)`/`U8(0)` and rounds as `Value::Groups` rows, so aligned lists are per-round rows in the Rust ring | AZ-2179 AC-1, AC-2 | Documented in the ring comment and spec | clear |
| 3 | The C++ driver's `parse_hex` drops an odd last nibble (pre-existing) | review F3 | Leave; fix with AZ-2194 if the hex parsing is shared | clear |
| 4 | The cross-language ring is still a manual gate (not run by CI) | AZ-2193 | AZ-2193 | unclear |

## Commit

`[AZ-2179] Add the rounds ring to language-pair.sh`. Body: one line + `Loop: 13`.

## Next: feature assessment round 2 (step 10.5), then Run Tests (11), Update Docs (13), Security Audit (14), Retrospective (17), local deploy and smoke
