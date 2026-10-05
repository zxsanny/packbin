# Code review: batch 5, loop 10

Verdict: PASS_WITH_WARNINGS

Reviewer: independent subagent over the uncommitted diff, then the batch author fixed what follows.

Scope: AZ-2070, AZ-2078, AZ-2081. Checked: flag-byte save and restore on every exit path, zero-progress rule for bound and unbound repeat, `check_shape` recursion, hostile runner thread safety, bash 3.2 and Linux portability of the fixture scripts, embedded header and stack constraints, acceptance-criteria coverage.

No wire-affecting bug and no data race were found.

| # | Severity | Finding | Handling |
|---|----------|---------|----------|
| 1 | Medium | `unpack_items`: an unbound `times` or `list` with a zero-width body and a huge count spins (about 9 s for `01 ff ff ff ff`) | Fixed: a round that reads nothing ends any unbound container; test added |
| 2 | Medium | Stack exactly 512 B of 512 B because of the RAII guard | Fixed: plain save and restore on success paths; 488 B measured on Cortex-M4F |
| 3 | Low | `check-cases.sh` word-splits with globbing on | Fixed: `set -f` |
| 4 | Low | A trailing `\|` in `expected` passed the check | Fixed: the field must match `term(\|term)*` |
| 5 | Low | `std::thread` without `-pthread` | Fixed: `-pthread` on the test link line |
| 6 | Low | Corruption cases in `cases.test.sh` depend on column spacing | Accepted: a reformat fails loudly, not silently |
| 7 | Low | No test for an empty group inside `repeat`, `times`, `list` | Fixed: three cases added |
| 8 | Low | No compile-fail case for an empty group | Fixed: `empty_group_outside_flags.cpp` |
| 9 | Info | The two `zero_progress_repeat_*` shared vectors resolve to `scheme_error` in C++, so the repeat guard is proven by `container_tests.cpp`, not by the vectors | Accepted; both outcomes are allowed by the vector file |
