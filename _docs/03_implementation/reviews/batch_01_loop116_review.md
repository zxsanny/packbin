# Batch review — loop 116, batch 01 (AZ-4242)

verdict: PASS_WITH_WARNINGS
scope: `scripts/probes/element-row/` (new: runner, README, seven package probes), `_docs/06_metrics/element-row-probe_2026-11-12.md`, queue items, OPERATOR_TODO D10 and D11. No package source.
reviewer: the parent (four workers wrote the probes; each report was checked against the package sources it cites)

| # | severity | category | finding | outcome |
|---|----------|----------|---------|---------|
| 1 | Medium | Maintainability | `cpp/probe.cpp` was 637 lines (cap 500) | fixed: split into `probe.cpp` 199, `probe_support.hpp` 290, `probe_compiled.hpp` 163; stdout byte-identical |
| 2 | Low | Spec-Gap | README did not name the suffixed lines each package prints (`-typed`, `-whole`, ...) | fixed: table added |
| 3 | Low | Bug | findings cited `python/packbin/_validate.py`; the file is `python/src/packbin/_validate.py` | fixed |
| 4 | Low | Style | the Java probe catches `Throwable` in `probe()` | kept: a probe prints every outcome; each catch prints the line (refused vs threw), nothing is swallowed |

Checks: `bash -n` and `shellcheck` clean on all eight `run.sh`; two full runs (168 lines, exit 0, 54 s / 46 s) byte-identical; `git status` shows only the new folder; the defect claims (Java `Access.get` unchecked cast, Java unpack `ArrayList` / `LinkedHashMap`, Python element pack with no `None` check) read in the sources.
