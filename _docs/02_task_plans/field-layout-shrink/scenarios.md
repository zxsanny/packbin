# Scenarios — field-layout-shrink

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | repeat, times, list and dict rounds packed and unpacked | confirmed | packets and rows byte-equal to today | AC-4 | intake |
| S2 | bits and packed arrays (items are small numbers) | confirmed | packets and rows equal to today | AC-4 | intake |
| S3 | an Array member that is absent (unbound, Optional) | confirmed | same outcome as today: count 0, nothing written, no read of an item | AC-4 | intake |
| S4 | count equal to capacity, and one past it on unpack | confirmed | same `TooMany` error and offset as today | AC-4 | intake |
| S5 | nested arrays (list of lists, dict whose value is an array, a round inside a round) | confirmed | equal to today | AC-4 | intake |
| S6 | a later edit grows `Field` again | confirmed | compile-time size check fails | AC-9 | intake |
| S7 | flash saving under 56 B, or stack above 504 B | confirmed | source stays at HEAD, figures recorded, pin not raised | AC-6, AC-3 | intake |
| S8 | 16-bit targets (AVR, AZ-2068) and the example targets | confirmed | build as before; an entry larger than today on AVR goes to the owner | AC-1, AC-5 | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| — | none: no wire change, no public API change; the readers of `item` and `count` are `pack.cpp`, `unpack.cpp`, `values.cpp` and the two builders in `fields_counted.hpp` / `table.hpp` | — | — |

## Not walked

- Behavior of other seven packages (not touched).
