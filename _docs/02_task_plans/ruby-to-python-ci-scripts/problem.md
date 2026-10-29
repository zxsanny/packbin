---
loop: 82
branch: dev
---

# Ruby to Python in the CI scripts (loop 82)

Source: `_docs/loops/loop81/handoff82.md` ("Owner decision: loop 82 is the Ruby-to-Python port of the CI scripts") and the owner's confirmation of the Phase 1 summary on 2026-10-29. The hopper was empty; the interview is that decision plus the measurements in the handoff (HEAD ed7d144, re-checked on 5a78fb8: the same 10 scripts name `ruby`).

## Problem

Ruby is not the test runner (that is bash). It is the YAML and JSON reader inside 10 scripts of `.github/workflows/`. A host without Ruby cannot run four `scaffold` scripts and two checks of the publish gate. Loop 81 ran on such a host and the owner waived those six checks. About 555 lines of embedded Ruby plus 5 one-liners:

| script | role | embedded Ruby |
|---|---|---|
| `publish-jobs.test.sh` | job layout of `test.yml`; its mutation tests are Ruby expressions over the workflow hash | 197 lines heredoc |
| `publish-workflow.test.sh` | translates GitHub `if:` expressions to Ruby and `eval`s them | 128 lines |
| `ring-wiring.test.sh` | ring job wiring against `test.yml` and the compose file | 117 lines |
| `ring-wiring-swift.test.sh` | same for the Swift ring | 68 lines |
| `publish-pins.test.sh` | pins in the workflow | 39 lines |
| `publish-precheck.test.sh` | builds JSON runs for the precheck | 6 lines |
| `publish-precheck.sh` | **release path** (`publish.yml`): reads the runs API JSON | 1 call, a 17-line lookup (JSON only) |
| `report-row.test.sh`, `run-suite.test.sh`, `run-suite-swift.test.sh` | one `ruby -ryaml -e` each | 1 line each |

This Linux host has no `ruby` and no JDK; the JDK is a separate gap and is not touched here. PyYAML 6.0.3 is installed for the system `python3`; Python's standard library has no YAML reader.

## Change location

No UI. The 10 scripts above in `.github/workflows/`, `.github/workflows/test.yml` (the jobs that run them), `tool-pins.txt` (the file that holds every tool the scripts install) and the setup docs. Confirmed by the owner as the place on 2026-10-29.

## Points the design must settle

- **PyYAML pin.** `pyyaml==<pin>` in `tool-pins.txt`, an install step in the CI jobs that run the ported scripts (`test.yml` has no `pip install` today; the ring job has `setup-python` only), and a line in the setup docs.
- **One shared helper** (for example `scripts/ci/yaml_get.py`, run with `python3 -I`) against ten copies of the loading code.
- **`publish-workflow.test.sh`:** the `if:` evaluator needs a Python equivalent with the same refusals (unsupported term, does not evaluate); no bare `eval` on workflow text without the same character filter.
- **`publish-jobs.test.sh`:** the `mutant "<label>" '<ruby expression>'` calls become Python edits of the loaded dict; each mutant keeps its expected refusal.
- **`publish-precheck.sh`:** a change on the release path; its test must still hold the good and bad runs.
- **YAML 1.1 quirk:** `on:` loads as the key `True` in PyYAML as in Ruby's Psych; the existing code reads `w["on"] || w[true]`.
- **No stand-in:** each ported script keeps all its checks; a port that drops one is a failure.

## Out of scope

The ring work and its toolchain pins; CS-D5; the first `v*` and `go/v*` tags and F44; AZ-2750; U24; the vcpkg `supports` question; the `handoff.cpp` split; installing a JDK on this host.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| `publish-precheck.sh` is on the release path; a wrong port can pass a run that should refuse (or refuse a good run) and block or mis-gate a publish | its test keeps the good and bad runs, and a mutation of the port must fail it | open | High |
| A new pinned dependency in CI (PyYAML) | owner chose the port knowing this (handoff82) | accepted-risk | Medium |
| The `if:` evaluator is `eval`-like; the port must not widen what it accepts | same character filter and same refusals; a test per refusal | open | Medium |
| CI is the first run of the six scripts that did not run on the loop 81 host | read the CI log of the push before closing | open | Low |
| Python 3.14 here against `setup-python` in CI (the version differs) | the helper uses only features of the CI version; CI is the check | open | Low |
