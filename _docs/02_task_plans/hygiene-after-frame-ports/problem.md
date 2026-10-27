---
loop: 76
branch: dev
---

# Hygiene after the frame ports (loop 76)

Source: `_docs/loops/loop75/handoff76.md` and `_docs/loops/loop74/handoff75.md` (candidates). The owner chose the hygiene loop on 2026-10-27 and accepted the recommended scope: items 1 to 5 and 7, item 6 investigate-first, the AVR runtime check out. The hopper was empty; the interview is that choice plus the evidence collected in Phase 2.

## Problem

Small defects left open by loops 71 to 75. None changes frame bytes, fixtures, the contract or an embedded pin.

1. `publish-timing.selftest.sh` failed once at host load near 100 with `printf: write error: Broken pipe` (L75-2).
2. `fixtures/hostile/fuzz/csharp/PackbinProbe.csproj` also compiles `ns20/Program.cs`.
3. `cargo test --no-default-features --features frame` over all targets does not compile.
4. The Swift DocC catalog's whole-API list names no frame types.
5. The vcpkg `supports: linux | osx` line was justified by `os_random`, which is gone.
6. The C# and Java `edges` hostile probes print "FAIL dict: NFC and NFD forms of é are two keys" (investigate first).
7. Test and probe names still say "Session" after the stream session was removed (names only).

## Code sections / UI locations for this loop

From the owner's choice of 2026-10-27. No UI.

| Item | Place |
|------|-------|
| 1 | `.github/workflows/publish-timing.selftest.sh` |
| 2 | `fixtures/hostile/fuzz/csharp/PackbinProbe.csproj` |
| 3 | `rust/tests/*.rs` (std-only test files), `rust/Cargo.toml` |
| 4 | `swift/Sources/Packbin/Packbin.docc/Packbin.md` |
| 5 | the vcpkg `supports` line (`publish-embedded.sh`, ADR-003 line 48) |
| 6 | `fixtures/hostile/fuzz/csharp/EdgesText.cs` and the Java `edges` probe under `fixtures/hostile/fuzz/` |
| 7 | `EccSessionTextTests`, `TopRangeAndSessionTests`, `fuzz_ecc_session.py` / `.ts` and their callers |

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Item 6 may be a real package defect against the loop 42 ascending dict-key rule, not a probe error | investigate first; a package defect gets its own task and is not fixed inside a hygiene task | open | Medium |
| A rename (item 7) may break a script that names the file | `git grep` every reader before the rename (AGENT_GOTCHAS) | open | Low |
| Item 1's cause is not proven (suspect: `printf | grep -q` under `pipefail`) | reproduce under load or prove by construction | open | Low |
