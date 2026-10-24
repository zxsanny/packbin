# Scenarios — flag-scope-times-stack

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | flag-byte `when` chain 1 to 3 deep, inside and outside a `times` round, packed and unpacked | confirmed | packets and rows byte-equal to today | AC-3 | intake |
| S2 | a flag bit set and clear, a `flags` member, a `when` with no flag byte (Inline) | confirmed | equal to today | AC-3 | intake |
| S3 | the same flag byte number reused in an outer and an inner scope | confirmed | the outer value is back after the inner scope ends, as today | AC-3 | intake |
| S4 | an error inside a scope (short packet, `TooMany`, bad value) | confirmed | same error kind and offset as today | AC-3 | intake |
| S5 | list, dict and repeat rounds with flag scopes (dict key order check) | confirmed | equal to today | AC-3 | intake |
| S6 | no shape reaches 548 B with flash at most 7,724 B | confirmed | source stays at HEAD, shape table recorded, pins not raised | AC-6 | intake |
| S7 | AVR, M0+, M3, s390x and examples | confirmed | build and pass as before | AC-4 | intake |
| S8 | a later edit deepens the walk | confirmed | the lowered `stack_pin` fails the arm stage by its own bytes | AC-5 | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| — | none: no wire change, no public API change; the only reader of the walk state is `unpack.cpp` (`Walk`, `with_outer_flags`, `unpack_children`, `unpack_items`) | — | — |

## Not walked

- Behavior of the other seven packages (not touched).
- The pack side (464 B on the 0x5e image, not the limiting side).
