# Scenarios - loop 84 (CI wiring, all_kinds.cpp, review cleanups)

Proposed behaviors, all `confirmed` (silent proceed). Source: new-task Step 4.7.

| # | Task | Axis | Actor / trigger / state | Behavior | AC |
|---|------|------|-------------------------|----------|----|
| 1 | T1 | partial failure | the "CI YAML reader" step is deleted from test.yml | wiring check exit 1, message names `scripts/ci/yaml_get.test.sh` | T1 AC-1.4 |
| 2 | T1 | partial failure | the "CI workflow helpers" step is deleted | exit 1, names `workflow_yaml.test.sh` | T1 AC-1.4 |
| 3 | T1 | invalid input | either step gets an `if:` or `continue-on-error` | rejected like the three existing scripts | T1 AC-1.3 |
| 4 | T1 | existing-feature overlap | the real test.yml | 0 violations | T1 AC-1.2 |
| 5 | T2 | first use | host `make -C cpp test` | same pass count, 0 warnings | T2 AC-2.2 |
| 6 | T2 | partial failure | a consumer lists only the old file | link fails (undefined `chain_*`); caught by the build, not hidden | T2 AC-2.3 |
| 7 | T2 | existing-feature overlap | ARM, ESP, big-endian stages | updated sources; a stage the host cannot run is NOT RUN | T2 AC-2.5 |
| 8 | T2 | boundaries | each part at 500 lines or below | the cap holds for every file in `embedded/common/` | T2 AC-2.1 |
| 9 | T3 | boundaries | a header used by its part | kept | T3 AC-3.1 |
| 10 | T3 | partial failure | 10 rows sorted ahead of the `id-padded` needle | test still passes; a lying go driver still fails it | T3 AC-3.3 |
| 11 | T3 | existing-feature overlap | `kMax`, `frame_hex` | unchanged, probe recorded | T3 AC-3.4 |
| 12 | T4 | partial failure | a job has `python-version: "3.14"` literal | rejected | T4 AC-4.3 |
| 13 | T4 | invalid input | `RING_PYTHON` differs from the compose image tag | rejected | T4 AC-4.2 |
| 14 | all | concurrent | workers in one loop | T1 and T4 in one worker (same two files); T2, T3 disjoint; no git write by workers | plan |
