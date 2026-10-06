# Loop 16 handoff — written 2026-10-06 when the session stopped (usage limits)

Nothing of loop 16 is started: no plan, no claim, no commit for it. This note is the intake the next `/autodev` run starts from (launcher on `dev`, `kind: product`, step 9, loop counter 15 = last closed).

## Where things stand

- Loops 14 and 15 are closed; `v0.2.2` is published (tag `d451e25`, publish run 37450142810 green, all required registries checked). `origin/dev` and `origin/main` are at `9db438e`, CI green. Local `dev` is one commit ahead (`611c68a`, moves the done spec AZ-2116 to `done/`, not pushed: a docs-only push costs a 7-minute CI run; push it with the next real change).
- Jira: every task whose spec is in `done/` (100 specs) is Done. The 41 specs in `todo/` are open (one, AZ-2134, is partly done: C# and TypeScript shipped, Python open).
- Loop end channel is `main` (`_docs/04_deploy/ci_cd_pipeline.md`); polling is `enabled: yes` (GitHub API, one call per poll, 90 s or more). A tag push needs the owner's explicit go with the exact commit.
- Epics: AZ-2069 (cross-language bug fixes, the hopper below), AZ-2222 (Go package), AZ-2223 (Swift, created by the owner on 2026-10-06, no order set).

## Do not start before checking

1. **Uncommitted work in the tree that is not the agent's** (seen 2026-10-06): C# multi-target compatibility (`csharp/Compat.cs`, `csharp/tests/TargetParityTests.cs`, changes in `csharp/{PackSession,Packbin,SessionPad,Walker*}.cs`, both `.csproj` files, `csharp/tests/SessionTests.cs`), `.github/workflows/{publish-check.py, publish-phases.test.sh, run-suite.sh}`, a "Supported languages" list in `README.md` and `_docs/02_document/epics.md`. Ask the owner whether to commit it first or finish it, before any C# or CI task of loop 16 (eight of the C# specs overlap those files). Never `git add -A`: commit explicit paths.
2. **Order of the two owner requests**: the Go package with full feature parity (owner, 2026-10-06, "after v0.2.2": see the memory note `go-package-next-loop`) and "pick up as much as possible" of the hopper. Ask which comes first; the hopper below is ready to batch, the Go loop needs its own problem statement.

## The hopper (41 open specs in `_docs/02_tasks/todo/`, 91 points; every spec was verified against the code on 2026-10-06, 40 open, 1 partial)

**Ready now, no owner decision open (30 specs, 69 points):**

| Package | Specs (points) |
|---------|----------------|
| C# (18 points with the three held below) | AZ-2092 scoped binding (5), AZ-2093 AC-10 public path (1, needs 2092), AZ-2119 group list element (3), AZ-2120 `when` under flags pack (2), AZ-2180 flag group clone (2), AZ-2191 dict pack strict (1) |
| TypeScript | AZ-2102 list/group elements (3), AZ-2103 npm JavaScript build (3), AZ-2112 u64 counts (2), AZ-2183 flags under a split bit (2), AZ-2185 times list longer (1), AZ-2197 `when` on written values (3) |
| Java | AZ-2127 nested rounds (3), AZ-2187 times list longer (1) |
| Python | AZ-2100 split-form repeat (3), AZ-2104 session star import (1), AZ-2113 later-field refs (3), AZ-2134 aligned round values, Python part (2), AZ-2186 times list longer (1) |
| Rust | AZ-2105 session pack error (1), AZ-2117 named reference scope (4), AZ-2118 pack checked count (1, a live debug-build panic) |
| Cross-package | AZ-2114 hostile session tests (2), AZ-2115 split-form reference bytes (2), AZ-2121 flag-scope container tests (2), AZ-2128 flag group presence parity (3), AZ-2135 split bits field order (5) |
| Harness / CI | AZ-2194 hostile `pack` stage (2; its numbers are stale: the case count is 19 and `check-cases.sh` accepts `unpack`, `construct`, `limit`), AZ-2099 embedded errexit (2), AZ-2068 AVR build (3, optional stretch) |

User-visible bugs worth taking first: AZ-2112 (TypeScript cannot repack a u64 count), AZ-2120 (C# silently drops a field under `when` in `flags`), AZ-2118 (Rust debug panic), AZ-2092 (C# scoped binding defects).

**Held for an owner decision (11 specs, 22 points; each spec lists its options and a recommendation):**

| Spec | Decision | Recommended in the spec |
|------|----------|-------------------------|
| AZ-2098 vcpkg port builds (3) | vendored sources or `vcpkg_from_github` | vendored |
| AZ-2101 Java typed nested rows (3) | the old overload on a typed row fails at construction or is allowed when pre-initialized | decide with the owner |
| AZ-2126 `eq` on bool (3) and AZ-2181 C# count integer only (2) | which kinds a `when` or count may name (integer or bool only everywhere, or keep floats with a defined equality) | integer only, which reverses C# AZ-2088 AC-6 |
| AZ-2182 C# non-list round value (2) | A broadcast a lone scalar and refuse a lone collection, B refuse when more than one round, C round 0 only | A |
| AZ-2184 TypeScript dict keys (2) | keep accepting an anchored group given as a nested object | keep, same bytes |
| AZ-2188 TypeScript duplicate member names (1) | A leave, B refuse outside every `when`, C refuse all but `when` siblings | B |
| AZ-2189 Rust map `times` list under flags (1) | A refuse, B document, C aligned list with nulls | A |
| AZ-2190 Java integer/float strictness (1) | keep `Long -1` for u64 (so unpack-then-repack works); refuse BigInteger | keep |
| AZ-2192 Python float strict (1) | refuse Decimal and Fraction | refuse |
| AZ-2193 CI runs `language-pair.sh` (3) | A a CI job on every push, B keep it a manual release gate | A |

## Suggested plan (not confirmed, not written)

- One loop plan from the ready table; four parallel workers per batch on disjoint paths (`csharp/`, `typescript/`, `java/` + `python/`, `rust/`), the cross-package and harness specs last; one `/code-review` per batch for the package batches; Run Tests, docs pass, security audit, retrospective, smoke script as in loops 14 and 15 (recipes and traps are in `_docs/AGENT_GOTCHAS.md`: strict `tsc` flags, `PACKBIN_CXX_SYSROOT`, the Pico amd64 container, no `git stash` in workers, at most two Docker-heavy workers at once on this Mac).
- Linux-only behavior still needs the first CI run after the push; watch it before `main` is fast-forwarded.
- A release (`v0.2.3` or `v0.3.0`) is a separate owner go.

## Open for the owner (carried)

F10 and F12 reduced, F13 and the Lows (F14 to F17, F2, F3) have no tickets; no `tsc --noEmit --strict` job in `test.yml`; `docker-compose.publish.yml` service list is hand-written; the C# element case of the round limits waits for AZ-2119.
