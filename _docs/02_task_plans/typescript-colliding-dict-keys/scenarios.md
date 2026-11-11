# Scenarios — typescript-colliding-dict-keys

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | A caller packs a dictionary whose keys differ only in unpaired surrogates | confirmed | pack throws a `RangeError` naming the dictionary; no bytes; the old unreadable packet is gone | TC-1, TC-3 | intake |
| S2 | A caller packs a dictionary with no collision, one key with a lone half, or keys that need the swap to sort | confirmed | the same bytes as before; the packet unpacks | TC-2, TC-3, TC-4 | intake |
| S3 | The same dictionary is a list element or a dict value | confirmed | the same refusal naming the dictionary (one code path) | TC-1 | intake |
| S4 | Another package writes the same unreadable packet | out-of-scope | not measured here; a leftover for a later loop | — | intake |
