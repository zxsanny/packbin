# Scenarios — review-lows-test-guards

Source of rows: `intake` (new-task Step 4.7). Test-only loop: no fit collision with product behavior.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | the nostd loader filter drops a valid input line | confirmed | the test fails naming expected and loaded counts | AC-1 | intake |
| S2 | a line is added to corpus.txt | confirmed | the test passes with the new count | AC-2 | intake |
| S3 | a pack_error case has no pinned rule, or a rule has no case | confirmed | Go test fails naming the id | AC-3 | intake |
| S4 | keys 0x7f then 0x80 / 0x80 then 0x7f | confirmed | packs / refused | AC-5 | intake |
| S5 | keys "a","ab" / "ab","a" / equal | confirmed | packs / refused / refused | AC-6 | intake |
| S6 | keys_ascending compares signed or length first | confirmed | the new test fails | AC-7 | intake |
| X1 | pack_children held_of, Field layout, times-round flag chain | out-of-scope | later candidates | — | intake |
