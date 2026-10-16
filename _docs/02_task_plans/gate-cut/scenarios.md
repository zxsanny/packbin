# Scenarios — gate-cut

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | Maintainer runs the whole gate on the Mac with all tools present | confirmed | 14 timing lines, a total of at most 800 s, `publish gate tests passed`, exit 0 | GC-2, GC-10 | intake |
| S2 | Maintainer runs the gate twice in a row (state from run 1 still on disk) | confirmed | both pass with equal assertion and mutant counts; nothing of run 1 is reused | GC-4, GC-9 | intake |
| S3 | The pool runs the gate while another stage uses the host (two gates at once) | confirmed | no fixed path shared; both pass | GC-9 | intake |
| S4 | A group fails or is killed halfway | confirmed | the aborted timing line is printed, later groups do not run, the run's temp directories are removed | GC-9, GC-10 | intake |
| S5 | A tool is missing (no swift, no docker, no vcpkg) | confirmed | NOT RUN is named as before and is not a pass; counts of run groups unchanged | GC-4 | intake |
| S6 | A guarded behaviour is broken in a copy after a cut | confirmed | the gate fails with the group's own message, one mutant per changed scenario | GC-5 | intake |
| S7 | Cold runner (images pulled, no caches) | confirmed | the median of 3 runs is at most 1 080 s including the pull step | GC-1 | intake |
| S8 | The loop test script and the timing selftest read the gate's group names and lines | confirmed | both pass unchanged | GC-10 | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | Sharing state between scenarios can let a mutation proof pass for the wrong reason | A — share only read-only fixtures built once per run; each mutant keeps its own copy (recommended, auto-applied) | yes (Constraints) |

## Not walked

- none
