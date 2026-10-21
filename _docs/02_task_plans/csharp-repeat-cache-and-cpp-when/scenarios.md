# Scenarios — csharp-repeat-cache-and-cpp-when

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| C1 | a program packs one long text in 200 rounds of a `times` | confirmed | the text is encoded once for the call and the 199 repeats copy the field; at most 250 ms idle | AC-C1, AC-C2 | intake |
| C2 | the text changes in the middle, alternates, or differs only in its last character | confirmed | a changed text is encoded again; the packet equals the uncached one | AC-C3 | intake |
| C3 | two pack calls in a row, or two threads at once, with the same text | confirmed | each call owns its cache; nothing is shared or kept after the call | AC-C4 | intake |
| C4 | a text of 65,536 UTF-8 bytes in a round | confirmed | refused with today's message, the cache never sees it | AC-C5 | intake |
| W1 | the source of a `when` is in a false `when`, its value in the row differs from the `when` value | confirmed | consuming `when` is false; nothing written; unpack agrees | AC-W1 | intake |
| W2 | same, and the `when` value is 0 (the value an unread field holds on unpack) | confirmed | consuming `when` is false on pack and on unpack | AC-W2 | intake |
| W3 | the source is written (outer `when` true) | confirmed | the consuming `when` follows the source's value; round trip | AC-W3 | intake |
| W4 | the source is two `when`s deep, either one false | confirmed | consuming `when` is false | AC-W4 | intake |
| W5 | one `when` holds both the source and its consumer | confirmed | consumer follows the source whenever the source is written | AC-W5 | intake |
| W6 | any of the other seven packages packs or unpacks the same scheme | confirmed | same bytes; the shared case runs in all eight | AC-W6 | intake |
| W7 | the Cortex-M4F, AVR and no-text builds | confirmed | budgets hold or a saving comes first | AC-W7 | intake |
| W8 | a scheme with no skipped source | confirmed | bytes unchanged | AC-W8 | intake |
| W10 | the source of a `when` sits more than 255 entries behind its holding `when` | confirmed | the scheme is refused when it is checked, as for a count; 255 builds | AC-W9 | assess-round-1 |
| W9 | closing row U24 (three C++ runner skips) | deferred (owner decides separately, not asked for this loop) | — | — | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| — | none: both changes are internal; no wire change, no public API change | — | — |

## Not walked

- A `when` source that is a bool or a group presence bit (the table allows `true` only): the existing rule for those sources stays; one probe in the C++ task, no AC.
- Skipped sources reached through `flags` / `u2` bit bodies (the hostile corpus has `pack_late_when_in_bit_body`): covered by AC-W8 staying byte-identical, and by the shared case if a package differs.
