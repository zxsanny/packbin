# Security lite — loop 80

Diff: `b970f2e..56eb43f` without `_docs/` (4 files, +27/-3): `scripts/frame/ring_frame.py` (two `try`/`except ff.Fault` blocks), `.github/workflows/ring-frame.test.sh` (a traceback check in `run`, two cases), `scripts/loop-tests.sh` (`stamp_pass` ignores `_docs/_autodev_state.md`) and its test `scripts/loop-tests.test.sh` (one case).

| Trigger | Hit | Note |
|---|---|---|
| T1 sensitive path | yes | `.github/workflows/ring-frame.test.sh`: a test script; `test.yml` unchanged; no `uses:`, `permissions:`, secret or env added |
| T2 sensitive content | no | the regex finds nothing on the 30 changed lines |
| T3 size | no | 4 files, 30 changed lines, 1 point |
| T4 dependencies | no | no manifest or lockfile changed |
| T5 carried finding | no | `security_report.md` names none of the files |
| T6 stale audit | no | not a ship loop, 1 point |
| T7 lite concern | no | see checks |

Verdict: ESCALATE by T1, answered with a diff-scoped pass below (as in loops 78 and 79: CI test scripts and a test-infrastructure checker, no product code path changed).

Checks on the changed lines:
- Injection / process args: the sed expressions of the two new cases are literals over the repository's own `ring-cases.txt`; `ring_frame.py` puts the file line, the case id and the reference's error name into a message, all from the row file the repository owns. `stamp_pass` passes a fixed pathspec to `git status`.
- Secrets and logs: none read, written or printed (the key hex in a row is a test vector already in the file); no network call added.
- Error handling: each new `except ff.Fault` names one expected exception and raises the file error the loader already handles; nothing is swallowed and the exit code stays 1.
- Blast radius: `ring_frame.py` is read by `ring-frame.sh` (CI job `ring`) and `loop-tests.sh`; `ring-frame.test.sh` runs in the `frame ring self-test` step of the CI `scaffold` job and in `loop-tests.sh`, and now fails any case whose output holds `Traceback` (all 34 pass); `loop-tests.sh` is a local runner, not read by CI, and the stamp change only lets a stage stamp when the position file alone is dirty (any other dirty path still blocks it, tested).

Findings: 0 Critical, 0 High, 0 Medium, 0 Low new. The Info of loop 79 (a refused `seal` or `mac` row crashes the loader without naming the row) is closed by AZ-3369.
