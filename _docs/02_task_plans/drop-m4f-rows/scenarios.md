# Scenarios - drop-m4f-rows

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | first full arm and Rust embedded run after the change, no source edit | confirmed | every remaining row passes with the baseline figures; the two M4F rows are absent | AC-1, AC-5 | intake |
| S2 | `rust-m33f` run alone | confirmed | passes; it needs no other row's log | AC-3 | intake |
| S3 | a later edit changes the Rust route packet bytes on one target | confirmed | the on-device unpack of the sample (`FAILURES`) and the golden decode fail; no cross-target compare is left | AC-3 | intake |
| S4 | a seeded panic or heap defect in a Rust probe | confirmed | `rust-mutants` catches it on the M33F link | AC-4 | intake |
| S5 | a later edit of `cpp/src/core` grows the 14-field, string-free image | confirmed | nothing gates it any more; the M33F pins (64 KiB / 8 KiB ceilings, 25,760 B / 724 B pins) are the bar | AC-7 | intake |
| S6 | a reader looks for an M4F figure in the README or CI | confirmed | none is claimed as current; history stays dated | AC-7 | intake |
| S7 | host builds with `PACKBIN_NO_TEXT` and `PACKBIN_NO_ECC` | confirmed | unchanged (`cpp/Makefile` tests, Uno example) | AC-5 | intake |
| S8 | CI job `embedded-arm` on the close push | confirmed | installs only the M33F Rust target and runs both stages green | AC-7, AC-8 | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| route packet reference | `rust-m33f` compared `ROUTE_HEX` with `rust-m4f`; with the row gone the reference is gone | drop the cross-target compare (simplest; no new file) | the probe already unpacks the packet it packs and compares with the sample on the device, and the golden fixture decodes there |
| mutants target | `rust-mutants` links `thumbv7em` libraries | build and link the seeded probes for `thumbv8m.main-none-eabihf` with the M33F script | no new row, same checks |

## Not walked

- An ARM run of the string-free, ECC-free configuration: removed with the row (stated limit, flagged concern).
