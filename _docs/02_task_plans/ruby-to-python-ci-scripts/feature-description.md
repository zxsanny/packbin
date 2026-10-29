# Feature: Ruby to Python in the CI scripts (loop 82)

Complexity 8 (handoff82.md: measured, 10 scripts, about 555 lines of embedded Ruby, a release-path script, a new pinned dependency in CI; LESSONS loop 81 on measuring a replacement's size). Entry: `/new-task` Step 2 routing, handed to `/decompose --feature`.

## Description

Replace every `ruby` call in `.github/workflows/` with Python so that no script needs Ruby. YAML is read by one shared helper (for example `scripts/ci/yaml_get.py`, run with `python3 -I`, `yaml.safe_load` only) against PyYAML pinned in `.github/workflows/tool-pins.txt`; JSON in `publish-precheck.sh` is read with Python's standard library. Every check of every script is kept, and each script still fails on a deliberate mutation. Full problem, scope and out-of-scope list: `problem.md`; criteria `AC-R1` to `AC-C1` in `acceptance_criteria.md`; expected pairs in `input_data/expected_results/results_report.md`.

Scripts and what each carries (HEAD 5a78fb8):

| Script | Embedded Ruby | Note for the split |
|---|---|---|
| `publish-jobs.test.sh` (384 lines) | 197-line layout checker (lines 20-211) and an 8-line mutant editor (lines 218-226) used by 111 `mutant` calls whose second argument is a Ruby expression on the loaded hash (`jobs`, `step_named`, `gate_step`, `deep`) | Largest piece. The 111 expressions become Python edits; the file ends up over the 500-line cap if Python is longer than Ruby, so plan the split by responsibility (layout checker, mutants) |
| `publish-workflow.test.sh` (241) | 128-line structure checker including the `if:` evaluator (`eval` after a character filter) | Evaluator in Python: a small parser for `==`, `!=`, `&&`, `\|\|`, `!`, `needs.<job>.result`, `needs.<job>.outputs.<name>`, `cancelled()`, `always()`, quoted strings; no `eval` |
| `ring-wiring.test.sh` (278) | 117 lines against `test.yml` and the compose file | |
| `ring-wiring-swift.test.sh` (425) | 68 lines | 425 lines today; the port must stay at or under 500 |
| `publish-pins.test.sh` (374) | 39 lines + the `command -v ruby` guard at line 361 | The guard becomes a PyYAML guard |
| `publish-precheck.sh` (release path) | 17-line lookup | JSON only, standard library; no PyYAML |
| `publish-precheck.test.sh` | 6 lines (run builder) + 11 sed mutants that match Ruby text (`r["head_sha"] == ARGV[2]`) | The sed mutants must be rewritten for the Python text; each must still change the script and fail a scenario |
| `report-row.test.sh`, `run-suite.test.sh`, `run-suite-swift.test.sh` | one `ruby -ryaml -e` each | Use the helper |

Documents that name Ruby as a need and change with the code: `_docs/02_document/module-layout.md` (line 280), `_docs/02_document/deployment/ci_cd_pipeline.md` (line 12), and any other `_docs/02_document` line a search for `Ruby` finds.

CI: `test.yml` has `setup-python` only in `ring`; `scaffold`, `publish-gate-*` and `suites` have none. The jobs that run a ported script need the pinned PyYAML installed before the script (AC-Y3); which jobs run which script is a decompose fact to trace, not to guess.

## Scenarios

The matrix of `scenarios.md` (12 rows, all `confirmed`):

1. Host with `python3` and PyYAML, no Ruby: all 10 scripts pass (AC-R2).
2. Host with `python3`, no PyYAML: YAML scripts fail naming PyYAML; the precheck works (AC-Y5, AC-P2).
3. CI job running a ported script installs the pin; the pin test fails without the step (AC-Y3).
4. Mutation of a guarded rule: non-zero exit naming the check (AC-K2).
5. Precheck on a bad answer / curl failure: `green=false`, exit 0 (AC-P1).
6. `if:` with a quote, semicolon, backtick or `$(`: refused before evaluation (AC-E2).
7. `on:` as the key `True`, and quoted `"on"`: both read (AC-Y2).
8. Helper failure inside `$(...)` under `set -e`: the script fails, no empty value passes (AC-Y5).
9. Runner with both Ruby and Python: Python used, Ruby not referenced (AC-R1).
10. Parallel runs by `scripts/loop-tests.sh`: the helper keeps no state (AC-Y1).
11. Anchors, merge keys, `yes`/`no`/`on` as values: read as `safe_load` reads them (AC-Y1, AC-Y2).
12. Pin bump: one edit in `tool-pins.txt` (AC-Y3).

## Fit decisions

- **How CI installs PyYAML** (auto-applied, one clear recommendation): `pip install -c`-style install of the single pinned `pyyaml==X.Y.Z` line from `tool-pins.txt` through the existing `tool-pin.sh` reader, in each job that runs a ported script; not the distro package (it would not be the pinned version). The pin value is a decompose fact: use a version at least two weeks old on PyPI; this host has 6.0.3.
- **Order of work:** the helper and the precheck first (the release path, smallest, no PyYAML), then the one-liners, then the pins and the CI install step, then the four big scripts (`publish-workflow`, `ring-wiring`, `ring-wiring-swift`, `publish-pins`), last `publish-jobs` (111 mutants). Each task keeps its scripts' checks and ends with its own scripts green on this host and failing on one mutation.
- **No stand-in:** a script that cannot keep a check is reported to the owner, not shipped without it.

## Flagged concerns

See `problem.md` (release-path precheck High, `open`; the others Medium or Low).
