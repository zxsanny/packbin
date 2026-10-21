# Scenarios — held-when-one-path-and-flash

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| F1 | a `when` whose body reads no flag byte, held | confirmed | children follow in the same loop, no flag scope; packets unchanged | AC-2, AC-6 | intake |
| F2 | a `when` whose body reads a flag byte, held | confirmed | flag scope entered once; packets unchanged | AC-2, AC-6 | intake |
| F3 | the table is built by the host builders and by the generated tables | confirmed | the resolve-time bit is set on both paths | AC-2 | intake |
| F4 | flash image after the saving | confirmed | at most 8040 B | AC-1 | intake |
| H1 | a held `when` or flag bit reached from `unpack_one` (`unpack_table`, `times` round, flags member) | confirmed | same function as from `unpack_children`; same result | AC-3, AC-6 | intake |
| H2 | the 3-deep chain and the flag-byte chain | confirmed | stack not above 504 B / 500 B | AC-4 | intake |
| H3 | the 3-deep chain reached through a `times` round | confirmed | measured, at most 512 B, figure recorded | AC-5 | intake |
| H4 | the fold does not fit the flash | confirmed | not made; the record gives the byte figures | AC-3 | intake |
| H5 | AVR and `PACKBIN_NO_TEXT` builds | confirmed | inside their margins | AC-4 | intake |
| C1 | `cases.txt` gains a valid line | confirmed | the loader reports the missing handler by id, not a count | AC-7, AC-8 | intake |
| C2 | `cases.txt` loses a line | confirmed | the loader reports the unused handler by id | AC-8 | intake |
| C3 | the Rust loader of cases.txt | confirmed | found at task time; counts derived | AC-7 | intake |
| X1 | the other five packages' loaders | out-of-scope | not named by the review | — | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| — | none: no wire change, no public API change; `Field` stays 16 bytes before `eq` (a free bit of `flags`, 128, carries the resolve-time answer) | — | `static_assert(offsetof(Field, eq) == 16)` must hold |

## Not walked

- Row U24, the first tags, and the loop 53 candidates: owner decides separately.

## Assessment rounds

| id | scenario | status | behavior | AC ref | source |
|----|----------|--------|----------|--------|--------|
| F4b | flash saving short of 8,040 B (8,080 B reached) | out-of-scope (accepted loop 56) | owner chose accept and carry; byte search and fold retry later | — | assess-round-1 |
