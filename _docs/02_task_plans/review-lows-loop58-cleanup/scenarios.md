# Scenarios — review-lows-loop58-cleanup

Source of rows: `intake` (new-task Step 4.7). Test-only loop: no fit collision with product behavior.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | a three-field comment with a hex last token | confirmed | not counted as an input | AC-2 | intake |
| S2 | an input line is added to corpus.txt | confirmed | both counts +1, test passes | AC-2 | intake |
| S3 | the loader filter drops a valid input | confirmed | test fails naming both counts | AC-3 | intake |
| S4 | put_key gets a key longer than its capacity | confirmed | test failure, nothing copied | AC-4 | intake |
| S5 | one pair of the seven gives the wrong result | confirmed | failure names that pair | AC-5, AC-6 | intake |
| X1 | `-` placeholder in corpus.txt | out-of-scope | not part of the format | — | intake |
| X2 | pack_children held_of, Field layout, times-round flag chain | out-of-scope | later candidates | — | intake |
