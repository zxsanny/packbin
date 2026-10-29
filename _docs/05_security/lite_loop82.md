# Security lite — loop 82

Diff: `5a78fb8..HEAD` plus the working tree, without `_docs/` (about 25 files, +1.9k/-0.8k lines): the release-path script `publish-precheck.sh` and its test, the new reader `scripts/ci/yaml_get.py` and its test, five new Python checkers under `.github/workflows/` (`publish-workflow-structure.py`, `publish-jobs-layout.py`, `publish-jobs-mutate.py`, `ring-wiring-check.py`, `ring-wiring-swift-check.py`, plus `publish-pins-actions.py` and `publish-pins-install.py`), the ported shell tests, `test.yml` (two jobs get `setup-python` and a PyYAML install), `tool-pins.txt` (`pyyaml==6.0.3`), `scripts/loop-tests.sh`.

| Trigger | Hit | Note |
|---|---|---|
| T1 sensitive path | yes | `.github/workflows/`: `publish-precheck.sh` is the `precheck` job of `publish.yml` (release path); `test.yml` gains steps |
| T2 sensitive content | yes | one `exec` (in `publish-jobs-mutate.py`), the `if:` evaluator, `curl` in the precheck (unchanged), a pip install in CI |
| T3 size | yes | 25 files, 8 points feature (28 points of tasks) |
| T4 dependencies | yes | new pinned tool `pyyaml==6.0.3` in `tool-pins.txt` |
| T5 carried finding | no | `security_report.md` names none of the files |
| T6 stale audit | no | not a ship loop |
| T7 lite concern | yes | the release path |

Verdict: ESCALATE by T1, T2, T4 and T7, answered with a diff-scoped pass below (as in loops 78 to 81, no product code path changed; this loop changes the CI scripts that check the publish workflow).

Checks on the changed lines:
- Release path (`publish-precheck.sh`): the lookup is a fixed Python program passed with `python3 -I -c "$lookup"`; the run body, repository and commit reach it as `argv`, never as text in the program. The repository and commit are still validated by `grep -Eq` before use (exit 2), the token is still only in the `Authorization` header, and `publish-precheck.test.sh` still fails if it is printed. The verdict conditions are the same six (commit, event, status, conclusion, workflow path, repository), each with a scenario and a mutant (11 of 11 rejected). A body that is not UTF-8, deeply nested JSON or an unreadable file gives `green=false` (a named `bad:` reason) instead of a stack trace; the publish workflow then runs the whole test workflow.
- `exec` / `eval`: the `if:` evaluator is a tokenizer and a recursive-descent parser over a closed token set; the file has 0 calls to `eval`, `exec` or `compile` (a check in `publish-workflow.test.sh` keeps it so) and a character outside the set is refused before parsing. The single `exec` of the diff is in `publish-jobs-mutate.py`: it runs the mutation snippets of `publish-jobs-mutants.test.sh`, a tracked file; no workflow, compose or environment text reaches it.
- YAML reading: `yaml.safe_load` only (`yaml_get.test.sh` scans the tree for any other loader; the one other importer, `publish-jobs-mutate.py`, only dumps). The files read are repository-owned. PyYAML aliases can expand, which matters only for hostile YAML; none is read.
- Supply chain: `pyyaml==6.0.3` is exact in `tool-pins.txt`, installed with `--only-binary=:all:` from the pins file by `tool-pin.sh`, after `actions/setup-python` pinned to the same commit SHA as the `ring` job (`5fda3b95a4ea91299a34e894583c3862153e4b97 # v7.0.0`). No hash lock, as for the other pip tools (`ci_cd_pipeline.md` "Not covered"). `pyyaml` runs only in the `scaffold` and `publish-gate-rest` jobs, which have `contents: read` and no secret. The publish job is unchanged and does not install it.
- Permissions: no `permissions:`, `secrets:`, `if:` or `continue-on-error` added to any job; `publish-jobs.test.sh` (115 rejects) and `publish-workflow.test.sh` (43 rejects) still hold the layout and the permission rules.
- Errors: a reader that cannot read exits 2 with its cause (`PyYAML is required...`, `cannot read`, `is not valid YAML`); the test helpers count only exit 1 as a refusal, so a missing module cannot pass a check vacuously.
- Out of the diff: nothing installed on the host.

Findings: 0 Critical, 0 High, 0 Medium, 0 Low new.
