# Scenarios — when-chain-and-speed-headroom

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| A1 | a source three `when`s deep, all true | confirmed | consumer follows the source; packet equals Python's | AC-A3 | intake |
| A2 | the outermost false, or an inner one false | confirmed | consuming `when` false; mode byte (or the held part) only | AC-A3 | intake |
| A3 | the chain image on the Cortex-M4F | confirmed | stack at most 512 B, figure recorded, image guards it | AC-A1, AC-A2 | intake |
| A4 | the chain exceeds 512 B | confirmed | stack saving or non-recursive check, packets unchanged; a depth limit only by owner decision | AC-A4 | intake |
| A5 | AVR and `PACKBIN_NO_TEXT` builds with the chain | confirmed | inside their margins, or a saving first | AC-A2 | intake |
| B1 | bool source in a false `when`, true in the row | confirmed | consuming `when` false on pack and unpack | AC-B1 | intake |
| B2 | bool source written, true / false | confirmed | true: body written; false: absent, body not written | AC-B2 | intake |
| B3 | empty group (presence bit) as the source | confirmed | same as B1 and B2 in C++ and Rust, which are the only packages that accept it | AC-B3 | intake |
| B4 | the other six packages with an empty-group source | confirmed | out of the corpus: they refuse it at construction (existing rule, not changed) | AC-B3 | intake |
| D1 | the 65,535 x 200 case in Go and Swift | confirmed | new test, passes within half the bound | AC-D1, AC-D2 | intake |
| D2 | a package above half its bound | confirmed | walker keeps the last round's encoded text, bytes unchanged | AC-D3 | intake |
| D3 | CI runner slower than this Mac | confirmed | the CI figure is read after the push and written in the record | AC-D4 | intake |
| D4 | closing row U24, session stack, nostd ring driver | deferred (owner decides separately) | — | — | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| — | none: no wire change, no public API change | — | — |

## Not walked

- Wall-clock bound changes: bounds stay as set (1 s; C++ 3 s); only tests and, if needed, walkers change.
