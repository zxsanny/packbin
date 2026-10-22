# Scenarios — flash-search-and-corpus-guards

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | the search finds 40 B or more | confirmed | flash at most 8,040 B; packets unchanged | AC-1, AC-2 | intake |
| S2 | the search finds less than 40 B | confirmed | figure reported, AC-1 recorded as not met, no loosened bound | AC-1 | intake |
| S3 | a saving would change a refusal or a packet | confirmed | not made; corpora must be identical to HEAD | AC-2 | intake |
| S4 | the fold fits (flash at most 8,080 B, stacks not higher) | confirmed | kept, one function for both callers | AC-3 | intake |
| S5 | the fold does not fit | confirmed | restored, figures recorded | AC-4 | intake |
| S6 | `cases.txt` copy loses a line used only by a Rust unpack or limit handler | confirmed | plain Rust loader names the handler id | AC-6 | intake |
| S7 | a Rust nostd case moves from run to skip (or back) | confirmed | test fails naming the id | AC-7 | intake |
| S8 | `corpus.txt` copy gains a line | confirmed | Swift and Rust nostd take the new count; no count error | AC-8 | intake |
| S9 | Go id comparison with a missing and an unused handler | confirmed | same messages from one helper | AC-9 | intake |
| S10 | a later edit raises the flash above the pin | confirmed | arm stage fails with measured and pinned bytes | AC-10 | intake |
| S11 | the host is under load or Docker is slow | confirmed | the arm stage runs once per measurement, not per edit | AC-3 | intake |
| X1 | the other five packages' loaders | out-of-scope | not named by the review | — | intake |
| X2 | a flag-byte chain inside a `times` round | out-of-scope | not built; no AC | — | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| — | none: no wire change, no public API change | — | `static_assert(offsetof(Field, eq) == 16)` must hold |

## Not walked

- Row U24, the first tags, size limits, CS-D5, F44, epic AZ-2750, and the loop 53 candidates: owner decides separately.

## Assessment round 1 (loop 57)

| id | scenario | status | note |
|----|----------|--------|------|
| S4 | the fold fits | confirmed (accepted loop 57) | owner 2026-10-22: one decision function `held_of` counts as the fold; see `_docs/loops/loop57/assessment57.md` |
