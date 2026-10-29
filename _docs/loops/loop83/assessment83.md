# Feature assessment - loop 83

FEATURE ASSESSMENT loop 83 round 1: COMPLETE - 11 covered / 0 out-of-scope / 0 gap-clear / 0 gap-unclear

Inputs: `scenarios.md` (11 rows), `batch_01_loop83_report.md` (`## Discovered during implementation`: 4 rows, all `clear`, all handled in the batch), the three specs' `### Excluded` lines, the review (PASS_WITH_WARNINGS, 5 cleanups, 0 bugs).

| # | Scenario | Status | AC | Test | Code path |
|---|----------|--------|----|------|-----------|
| 1 | `PACKBIN_CPP_HANDOFF` forces a compile each call | covered | AZ-3387 AC-4 | worker run: 3 `run_lang` calls, 3 compiles with the variable, 1 without | `ring-lib.sh` cpp case |
| 2 | a new source fails to compile | covered | AZ-3387 AC-4 | deliberate error in each of the 3 sources: `run_lang cpp` rc=1, no stale binary | `ring-lib.sh` `|| return` |
| 3 | malformed frame/ECC line | covered | AZ-3387 AC-3 | 108-invocation `cmp` against the HEAD binary, error paths included | `handoff_frame.cpp`, `handoff_ecc.cpp` |
| 4 | unreadable workflow YAML | covered | AZ-3388 AC-3 | 52 cases byte-identical to HEAD checkers (exit 2 cases included) | `ring-wiring*-check.py`, `yaml_get.py` |
| 5 | checker run by `python3 -I` from another directory | covered | AZ-3388 AC-4 | worker run from `/`, exit 0 | `sys.path.insert` + `workflow_yaml.py` |
| 6 | a helper edited wrongly | covered | AZ-3388 AC-5 | `workflow_yaml.test.sh` (16 checks) fails on 5 mutations; CI step added | `scripts/ci/workflow_yaml.py` |
| 7 | key33 + second refusal | covered | AZ-3389 AC-3 | `ring-frame.sh`: 72 refusal rows x 8, 0 mismatched | `fixtures/frame/ring-cases.txt`, 6 packages |
| 8 | id7 + `outshort` | covered | AZ-3389 AC-3 | same run | same |
| 9 | Rust/C++ cannot be handed the value | covered | AZ-3389 AC-3 | README and row comment say it; `ring-frame-drivers.test.sh` 276 checks | drivers print `BadValue` by construction |
| 10 | a package answers `TooLong` first | covered | AZ-3389 AC-4/AC-6 | Python key check moved after the size checks: 7 mismatches, exit 1 | `ring_frame.py` |
| 11 | three workers in one tree | covered | plan | separate tree copies; owned paths diffed against HEAD before merge | parent merge |

Not walked: none. Leftover (not a gap of this feature): the scaffold wiring check does not require the CI steps of `yaml_get.test.sh` and `workflow_yaml.test.sh` (review finding 1).
