# Scenarios — review-lows-loop59-cleanup

Source of rows: `intake` (new-task Step 4.7). Test-only loop: no fit collision with product behavior.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | one of the 7 pairs returns the wrong `Error` | confirmed | failure names the pair and prints the `Error` returned and the one expected | AC-1, AC-2 | intake |
| S2 | `put_key` gets a key longer than its capacity | confirmed | its own failure, and the pair is not packed | AC-3 | intake |
| S3 | a corpus line has an upper-case hex digit | confirmed | not counted as an input | AC-4 | intake |
| S4 | a corpus line has a kind outside `[a-z0-9_]+` | confirmed | not counted as an input | AC-4 | intake |
| S5 | an input line is added to corpus.txt | confirmed | both counts +1, test passes | AC-4, AC-5 | intake |
| S6 | the real corpus.txt | confirmed | count equals the loader's (34) | AC-4 | intake |
| X1 | `pack_children` held_of, Field layout, times-round flag chain | out-of-scope | later candidates | — | intake |
