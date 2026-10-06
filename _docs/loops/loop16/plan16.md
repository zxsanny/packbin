# Autodev Loop Plan — Loop 16

loop: 16
kind: product
confirmed: true
branch:
ship: false

Loop works on `dev` (no worktree: this chat is the launcher, as loops 11 to 15). Intake: `_docs/loops/loop16/handoff16.md` (the verified hopper of 41 open specs under epic AZ-2069, written 2026-10-06). Owner answers 2026-10-06 that shape this plan: the hopper comes first and as many tasks as possible; the Go package follows loop 16; the proposed defaults are taken for the nine held decisions; AZ-2126 and AZ-2181 decided (integer-only counts, `when` names an integer or a bool); **the uncommitted C# multi-target work stays uncommitted and lands after loop 16, so every C# change waits**.

## Foreign work in the tree (do not touch, do not commit)

Not the agent's, owner decision "leave it uncommitted": `csharp/{PackSession,Packbin,SessionPad,Walker,Walker.Counted,Walker.Rounds,Walker.Scalars}.cs`, `csharp/Packbin.csproj`, `csharp/tests/{Packbin.Tests.csproj,SessionTests.cs}`, untracked `csharp/Compat.cs` and `csharp/tests/TargetParityTests.cs`, `.github/workflows/{publish-check.py,publish-phases.test.sh,run-suite.sh}`, `README.md`, `_docs/02_document/epics.md`. A backup of the diff and a baseline hash are in the session scratchpad (`foreign/`); every commit stages explicit paths, never `git add -A`; at loop close the hash of these files must equal the baseline. The dirty-tree gate and the implement prerequisite "application source clean" are overridden for these paths by the owner decision. `README.md` edits of this loop go through the patch route (edit a copy of the `HEAD` blob, apply the patch to the index and to the tree) so no foreign hunk is staged.

## Scope

In (non-C# specs, 43 points whole plus the non-C# parts of five cross-package specs and the harness):

| Package | Specs |
|---------|-------|
| TypeScript | AZ-2112, AZ-2102, AZ-2185, AZ-2188, AZ-2183, AZ-2184, AZ-2197, AZ-2103; parts: AZ-2128, AZ-2115, AZ-2135 |
| Rust | AZ-2118, AZ-2105, AZ-2117 (with AZ-2121 AC-3), AZ-2189; parts: AZ-2128, AZ-2114, AZ-2121 AC-4 |
| Java | AZ-2127, AZ-2187, AZ-2190, AZ-2101; parts: AZ-2128, AZ-2114, AZ-2121, AZ-2135 |
| Python | AZ-2113, AZ-2104, AZ-2186, AZ-2192, AZ-2100, AZ-2134; part: AZ-2128 |
| C++ | part: AZ-2135 G1 (`find_flag_byte` looks inside a `when`) |
| Harness | AZ-2099 (embedded errexit), AZ-2193 (CI runs `language-pair.sh`), AZ-2098 (vcpkg port builds, vendored sources) |

Held (stay in `todo/`): AZ-2092, AZ-2093, AZ-2119, AZ-2120, AZ-2180, AZ-2181, AZ-2182, AZ-2191 (C#); AZ-2126 (six packages and a new hostile vector that the C# loader would read); AZ-2194 (changes all six vector loaders, C# included); the C# parts of AZ-2114, AZ-2115, AZ-2121, AZ-2128, AZ-2135; AZ-2068 (optional stretch, stale claim `loop: 10` stays). A cross-package spec whose non-C# parts ship stays in `todo/` with a `## Loop 16 progress` table by package (precedent: AZ-2134), its Jira ticket stays In Progress.

## Steps
| id | step | name | include | reason |
|----|------|------|---------|--------|
| new-task | 9 | New Task | no | specs exist in `todo/` (hopper hit) |
| decompose-feature | 9.5 | Decompose Feature | no | specs are 1 to 5 points; AZ-2135 is split per package inside the batch |
| implement | 10 | Implement | yes | four waves: B1 and B2 one worker per package (`typescript/`, `rust/`, `java/`, `python/`), B3 TypeScript + Java + C++ + harness, B4 AZ-2098; see `## Implementation` |
| feature-assess | 10.5 | Feature Assessment | yes | always after implement |
| run-tests | 11 | Run Tests | yes | always; C# suite runs from a clean checkout of `HEAD` (the foreign work is not part of this loop) |
| test-spec-sync | 12 | Test-Spec Sync | no | project ACs and scenarios unchanged; no hostile vector is added (AZ-2126 and AZ-2194 are held) |
| update-docs | 13 | Update Docs | yes | refusals and wire behavior change in four packages; README through the patch route |
| security | 14 | Security Audit | yes | unpack of untrusted bytes (Java nested rounds, u64 counts, split-form, hostile session tests) and publish scripts (AZ-2103, AZ-2098) change |
| performance | 15 | Performance Test | no | no latency or throughput NFR in scope |
| deploy | 16 | Deploy | no | not a ship loop |
| release | 16.5 | Release | no | a tag is a separate owner go with the exact commit |
| migration | 16.7 | Data/Traffic Cutover | no | none |
| retrospective | 17 | Retrospective | yes | about 60 points over four packages and CI |
| local-deploy | — | Local deploy + open site | yes | always at close; no site: the package suites and the gate tests are the local run |
| smoke | — | Smoke acceptance | yes | always at close; one-paste script in `smoke16.md` |

Only rows with `include: yes` are executed (plus close steps).

## Implementation

Optional. Created or patched when a batch diverges (`protocols/plan-diff-sync.md`).

### Files that change

Each worker owns exactly one directory; nobody else writes there. Shared and parent-only: `README.md` (patch route), `_docs/**`, `fixtures/hostile/**` (no change planned), `.github/workflows/**` (harness worker only, and never the three foreign files).

### Order of work

| Batch | Worker | Specs in order | Points |
|-------|--------|----------------|--------|
| B1 | TypeScript (`typescript/`) | AZ-2112, AZ-2102, AZ-2185 | 6 |
| B1 | Rust (`rust/`) | AZ-2118, AZ-2105, AZ-2117 + AZ-2121 AC-3, AZ-2189 | 7 |
| B1 | Java (`java/`) | AZ-2127, AZ-2187, AZ-2190 | 5 |
| B1 | Python (`python/`) | AZ-2113, AZ-2104, AZ-2186, AZ-2192 | 6 |
| B2 | TypeScript | AZ-2188, AZ-2128 (TS part), AZ-2183, AZ-2184, AZ-2197 | 9 |
| B2 | Rust | AZ-2128 (Rust part), AZ-2114 (Rust), AZ-2121 AC-4 | 2 |
| B2 | Java | AZ-2101, AZ-2128 (Java part), AZ-2114 (Java), AZ-2121 (Java) | 6 |
| B2 | Python | AZ-2100, AZ-2134, AZ-2128 (Python part) | 6 |
| B3 | TypeScript | AZ-2103, AZ-2115 (TS), AZ-2135 (TS part) | 6 |
| B3 | Java | AZ-2135 (Java part) | 2 |
| B3 | C++ (`cpp/include`, `cpp/src`, `cpp/tests`) | AZ-2135 (C++ G1) | 1 |
| B3 | Harness (`cpp/embedded/`, `.github/workflows/test.yml`, `language-pair.sh`) | AZ-2099, AZ-2193 | 5 |
| B4 | one worker | AZ-2098 (vendored port sources; README row through the patch route) | 3 |

B1 is 24 points and B2 is 23, above the 20-point guide: the specs are 1 to 3 points and a worker serializes inside its package; one review per batch stays per package. Inside a worker the order follows the dependencies (AZ-2128 before AZ-2183 in TypeScript).

Workers run host toolchains only (node 22, Python venv, cargo 1.79, JDK 21). The parent runs the Docker suites (CI toolchains: node 24, Python 3.14, rust 1.98, gcc 16, Java 26) after each join, one at a time, with a status line every 30 s (memory `long-runs-visible-status`).

### Divergences from the plan (plan-diff-sync, batch 1)

- Files that change gained `.github/workflows/drivers/handoff-rust/src/main.rs` (AZ-2105 changes the `PackSession::pack` return type; the one-line caller fix is the parent's).
- The hostile construct vector `when_names_inner_field_after_times` (AZ-2117 flagged concern) is not added: a new case needs the six loaders, so it waits with AZ-2194 and the C# work.
- B1 had a fix pass after the review: Rust, Java and Python workers resumed for findings (owner decisions on the Python test and the Java inner `repeat`: both option A). Counts after B1: TypeScript 323, Rust 261, Java 1064 checks, Python 190.
- Verification trees: the live tree for TypeScript, Python and Rust (no C# involved); an overlay of the committed `HEAD` plus the batch's changed files for Java, the hostile-file checks and the ring, so the owner's uncommitted C# work is never in a gate.

### Round 2 (after the assessment, owner: implement everything now)

Specs written by spec authors who reproduced every probe (`_docs/02_tasks/done/AZ-2230` to `AZ-2240`, all eleven done); Jira tickets created under epic AZ-2069. Wave A, one worker per package on disjoint paths: Python (AZ-2230 split bits by scheme order, AZ-2231 `load` bytes only), Java (AZ-2233 orphan bit refused, AZ-2234 loud pack for nulls, absent rows and `u2` in rounds, AZ-2235 typed element groups checked), TypeScript (AZ-2236 direct element kinds refused), Rust (AZ-2237 map pack decides `when` from written values, longer `times` list refused). Wave B, harness: H1 vcpkg `supports` and `SameMinorVersion` with the tag-time guard asserts (AZ-2232, AZ-2240; the guard edits only TypeScript and vcpkg hunks of the owner's `publish-check.py` and `publish-phases.test.sh` through the patch route), H2 `language-pair.sh` and drivers (AZ-2238 hygiene, AZ-2239 `listgroup` ring). Then review per package, fix pass, verification, docs delta, second assessment round (`assess_round` 2 is the last allowed), then steps 11, 14, 17 and loop close.

Round 2 result (batch 5, `_docs/03_implementation/batch_05_loop16_report.md`): one review per package plus one for the harness, three Medium found in Rust (F1 to F3) and fixed, Low fixes in Python, TypeScript, Java and the harness; counts after round 2: TypeScript 463, Python 326, Rust 331, Java 1501 checks; all harness stages green on a `HEAD` overlay (the real-vcpkg gate included). Divergences: the root `README.md` line 27 (C++ platforms bullet) sits in the owner's uncommitted lines, so the patch route cannot touch it; the text is recorded for the owner. The TypeScript `BinaryPacker.unpack` handler typing defect (`SchemeHandler<object>` is invariant for a typed row) surfaced in the README check and is an open item, not a spec.

Round 3 (batch 6, `_docs/03_implementation/batch_06_loop16_report.md`, after assessment round 2): AZ-2243 to AZ-2249 (TypeScript `load`, Python `start`/`join`, duplicate names in Python, Java and Rust, Python short `times` list, Python element accessors), owner answers option A for X3, X4, X5 (X5 confirmed twice). Workers per package; TypeScript reviewed (PASS); the Rust, Python and Java reviews were stopped by the owner's direction of 2026-10-06 ("do not review each change, do not test each change"): finish the current tasks, write down the state, prepare the remaining todo as non-overlapping batches for the next session (`_docs/loops/loop17/handoff17.md`), then one total review and one total test run. Assessment round 3 is not run for the same reason; the open angles go to the loop 17 handoff. Counts after round 3: TypeScript 470, Python 492, Rust 360, Java all checks pass (+124).

### Proof

Per batch: package suites on the CI toolchains through `docker compose -f docker-compose.test.yml run --rm <lang>`; `typescript` strict `tsc --noEmit` command from `_docs/AGENT_GOTCHAS.md`; hostile case file check; `/code-review` per batch; foreign-work hash equals the baseline. Loop end: all suites, C# from a clean `HEAD` checkout, `language-pair.sh` with `PACKBIN_CXX_SYSROOT`, then the first CI run after the push decides the Linux-only parts.

### Risks

- The foreign work shares the tree: a worker that touches a foreign file or runs `git stash` / `checkout` / `reset` / `clean` breaks it. Mitigation: forbidden list in every prompt, hash check after every join, baseline copy in the scratchpad.
- Wire-changing specs (AZ-2135 TypeScript and Java move to the Rust bytes; C# stays behind until its part lands) widen the C# gap for the handle-reuse shapes only. Mitigation: AZ-2135 is the last package wave; `README.md` upgrade note lists the C# part as open.
- AZ-2128 carries two open Medium flagged concerns (`when` / `times` as a `flags` member). Mitigation: workers implement the AC table only and record the concern as a discovery for the owner; no guessed behavior.
- Host Rust is 1.79 against 1.98 in CI. Mitigation: the Docker `rust` service is the gate.
- 7-minute CI run per push; docs-only pushes wait for a real change.

## Assessment rounds

| round | verdict | new specs | report |
|-------|---------|-----------|--------|
| 1 | CLARIFY (10 undecided angles, 5 clear gaps, 9 out of scope by the owner's earlier holds) | owner answered 2026-10-06: take all recommendations and implement everything now: AZ-2230 to AZ-2240 (11 specs, 24 points). Q6 (other non-value `flags` members) joins the held `when` / `times` / `repeat` decision, no work; Q9 container hardening of the `gcc:16` wrapper waits for the first green `ring` run (the local half is AZ-2238); Q8 (annotated README accessor examples) and the docs carry-over ride the docs pass | _docs/loops/loop16/assessment16.md |
| 2 | CLARIFY (2 gap-clear, 3 gap-unclear, 11 covered, 11 out-of-scope) | owner answered 2026-10-06 (all three option A): X3 Python, Java and Rust refuse a member name used twice when the scheme is built (AZ-2245, AZ-2246, AZ-2247); X4 Python accepts a short or empty `times` list for an optional member (AZ-2248); X5 Python refuses an attribute-style accessor in a list or dict element group (AZ-2249); clear gaps X1 TypeScript `PackSession.load` returns null for a seed that is not a 32-byte Uint8Array (AZ-2243), X2 Python `start` and `join` refuse a nonce that is not bytes-like of 16 bytes (AZ-2244). Round 3 assessment is the last allowed | _docs/loops/loop16/assessment16.md (`## Round 2`) |
| 3 | not run (owner direction 2026-10-06: stop expanding todo, one total review and one total test run) | none; the open angles are in `_docs/loops/loop17/handoff17.md` | |
