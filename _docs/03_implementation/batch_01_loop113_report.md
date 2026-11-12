# Batch Report

**Batch**: 1 (loop 113)
**Tasks**: AZ-4210_repeat_last_hostile_cases_and_readme
**Date**: 2026-11-12

## Task Results

| Task | Status | Files Modified | Tests | Issues |
|------|--------|---------------|-------|--------|
| AZ-4210_repeat_last_hostile_cases_and_readme | Done | 5 files (`fixtures/hostile/cases.txt` +13, `fixtures/hostile/README.md` +107, `fixtures/hostile/cases.test.sh` +8, `README.md` +27 -8, `module-layout.md` 1 line) and the contract (1.0.1, by the parent) | `check-cases.sh`: `hostile cases ok: 88` (75 before); `cases.test.sh`: passed (44 check runs, about 240 s at host load 20); Swift README snippet test: 19 tests passed | None |

AC-1 to AC-5: PASS. The 77 older lines of `cases.txt` are byte-identical (`git diff --numstat` 13 / 0). The 98 code blocks of `README.md` are byte-identical to HEAD, so no package snippet test changes. A corrupted copy of a new line fails the check in three ways (a wrong hex, an unknown outcome term, a missing section).

New case ids: `construct_repeat_then_field` (R1), `construct_repeat_in_when_then_field` (R2), `construct_repeat_in_flags_then_field` (R3), `construct_repeat_in_group_then_field` (R4), `construct_repeat_then_repeat` (R5), `construct_repeat_then_exclusive_when` (R6), `construct_repeat_in_list_element` (R7), `construct_repeat_in_dict_element` (R8), `construct_repeat_in_times_round` (R9); `pack_repeat_last` `01090506` (K1), `pack_repeat_last_in_when` `01010506` (K2), `pack_repeat_last_in_flags` `0103090506` (K3), `pack_times_then_field` `0102050609` (K4).

## Code Review Verdict: deferred

One total review for the loop after the last package task (owner rule 2026-10-06). The parent read the whole diff of this task before the commit.

## Test Suite

- `fixtures/hostile` checks: 88 cases valid, the case tests passed.
- The nine package suites are red on the 13 new ids until each package's own task lands (Risk 1 of the spec). This commit stays local.
- CI-parity: `bash fixtures/hostile/check-cases.sh`, `bash fixtures/hostile/cases.test.sh` and the Swift README snippet test (the three CI checks that read the changed files): PASS.

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The contract's Java text for a repeat inside a round ended "a round cannot hold another repeat or times", but Java and C++ keep building a `times` inside a round, so the sentence is false there | contract Refusal, case 3; AZ-4214 AC-5 | Done by the parent: contract 1.0.1, the text is `repeat <anchor> is inside a repeat or times round; a repeat reads to the end of the packet, so another round cannot follow it; use times`; README, hostile README, the Java spec and the worker rules follow. Recorded as decision D7 (applied; the owner can overturn it) | clear (an error text must be true) |
| 2 | The README quotes the two new texts with `<anchor>` and `<field>`, because no package wording existed when it was written | AZ-4210 AC-4 | A concrete TypeScript example replaces or joins them in the docs step, once AZ-4211 has fixed the wording | clear |
| 3 | K2 to K4 were run in TypeScript only; the `Run by` lists name all nine packages on the contract's word | AZ-4210 Risk 2 | Each package worker packs K1 to K5 on its unchanged code first; a package that cannot pack one gets a `Not run by` entry here | clear |
| 4 | `cases.test.sh` needs about 4 minutes on this host under load (44 check runs) | none (process) | A step limit of the smoke script for it is at least 600 s | clear |
| 5 | The three README lines "Schemes Go / Swift / Dart refuses and TypeScript builds" list other schemes and do not touch this rule | AZ-4210 Scope | Left unchanged | clear |

## Commit

`[AZ-4210] Shared cases and README: a repeat must be last`

## Next Batch: AZ-4211 to AZ-4219 (a pool of at most four workers: TypeScript, Rust, C#, Java first; then Python, Go, Swift, Dart; C++ after Rust)
