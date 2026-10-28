# Scenarios: frame ring refusals (loop 78)

Source: `problem.md` and the fit walk of loop 78 (new-task Step 4.7). Status values: confirmed, out-of-scope, deferred. AC refs are the ids of `acceptance_criteria.md` until decompose maps them to task ACs.

| id | scenario | status | AC ref | note |
|----|----------|--------|--------|------|
| R1 | First use: the ring on HEAD with the 22 new refusal rows passes in all 8 languages | confirmed | AC-1, AC-4 | `refusals <lang>: 38 rows, 0 mismatched` |
| R2 | Repeat: a driver line without `dirs` and `out_len` answers as before | confirmed | AC-7 | the 64 pairs stay |
| R3 | Concurrent: the 8 drivers run at once in a phase | out-of-scope | - | already so; the drivers share no state; no change |
| R4 | Partial failure: a writer prints a word that is not hex for a good row | confirmed | AC-11 | L-2; the writer is blamed, readers get skip lines |
| R5 | Invalid input: direction 0, 4, or not loaded | confirmed | AC-5 | `BadValue`, no abort, next line answered |
| R6 | Invalid input: a line with a bad hex digit, an odd token or a missing field | confirmed | AC-8, AC-9 | non-zero exit with the line number; includes Go parse errors |
| R7 | Boundary: `out_len` exactly the needed size and one byte below | confirmed | AC-6 | `BufferFull` below, body at the exact size |
| R8 | Existing data: the 16 tampered rows are still refused as before | confirmed | AC-4 | total refusal rows 38 |
| R9 | A driver that accepts a forbidden row, or aborts on `dir=0`, turns the ring red | confirmed | AC-12 | two new self-test cases |
| R10 | `open-skip` / `verify-skip` get `skip` from every driver | confirmed | AC-10 | Python was the eighth |
| R11 | A row the reference codec names differently stops the run before any driver is read | confirmed | AC-3 | same rule as the existing rows |
| R12 | Overlap with `vectors.txt`: the same 22 cases are also checked in each package | out-of-scope | - | accepted-risk in `problem.md`; the ring adds the driver line and the no-abort proof |

## Task AC map (decompose, loop 78)

| scenario | task AC |
|----------|---------|
| R1, R8 | AZ-3354 AC-1, AC-6 |
| R2 | AZ-3354 AC-5 |
| R4 | AZ-3355 AC-1 |
| R5 | AZ-3354 AC-3 |
| R6 | AZ-3355 AC-2, AC-3 |
| R7 | AZ-3354 AC-4 |
| R9 | AZ-3354 AC-6 |
| R10 | AZ-3355 AC-4 |
| R11 | AZ-3354 AC-2 |

## Assessment round 1 (loop 78)

| id | scenario | status | AC ref | note |
|----|----------|--------|--------|------|
| U1 | Rust has no direction value for 0 and 4; its driver prints `BadValue` | confirmed | AZ-3354 AC-3 | owner 2026-10-28: keep, documented |
| R4m | a MAC writer that prints a word is blamed | confirmed | AZ-3355 AC-1 | case `mac-writer-prints-word` |

