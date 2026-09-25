# Scenarios — python-single-accessor

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | A caller declares a field with one attribute accessor and packs a new position row | confirmed | The hex is `4001000065cd1d00a3e1110100` | AC-1 | intake |
| S2 | The same row is packed a second time | confirmed | The hex matches the first pack | AC-1 | intake |
| S3 | Unpack of that hex runs once | confirmed | sid 1, lat 500000000, lon 300000000, profile 1, bytes left 0 | AC-2 | intake |
| S4 | A mapping row is packed and unpacked through one key accessor | confirmed | The key value comes back, wrong fields 0 | AC-3 | intake |
| S5 | Optional heading, speed, and altitude are absent | confirmed | The position hex stays `4001000065cd1d00a3e1110100` | AC-1 | intake |
| S6 | The accessor is not a plain member read | confirmed | Declaration fails, accepted count 0 | AC-4 | intake |
| S7 | Someone reads the README Python example | confirmed | A bind helper appears 0 times | AC-5 | intake |
| S8 | Another language declares the same position row | out-of-scope | — | — | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | Two-function field calls stop working | A — one accessor only | yes |

## Not walked

- Two callers packing at once. The library has no shared mutable scheme state in this change.
- Permission denied. There is no auth.
- Undo. Pack does not store a previous buffer.
