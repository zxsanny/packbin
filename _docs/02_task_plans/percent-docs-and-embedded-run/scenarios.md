# Scenarios - percentage docs and device run

Source: loop 98 intake (`new-task` Step 4.7). `confirmed` = proposed behavior taken (silent proceed); no row is `unknown`.

| # | Axis | Actor / trigger / state | Behavior | Status | AC | Owning task AC |
|---|------|--------------------------|----------|--------|----|---|
| S1 | first use | A Swift developer reads the DocC page for the ECC section | Finds the percentage next to the count, with the setter, reader, formula and limits | confirmed | AC-1 | docs task AC-1 |
| S2 | first use | A Go developer runs `go doc` on the package | Finds `WithParityPercent`, `ParityPercent`, `MaxParityPercent` and the rules | confirmed | AC-2 | docs task AC-2 |
| S3 | existing data | A reader compares the pages with the README | Same numbers and rules; 0 differences | confirmed | AC-3 | docs task AC-3 |
| S4 | first use | The C++ vector runner runs on QEMU Cortex-M3 and Cortex-M33F | A percentage test runs on both, 0 failures | confirmed | AC-4 | cpp task AC-1, AC-2 |
| S5 | boundaries | p = 100 and a 40-byte message; p = 1 and a 40-byte message; a clear length that gives n above 32 | n = 32 (cap); n = 1 (rounded up); the cap holds | confirmed | AC-4 | cpp task AC-1 |
| S6 | invalid input | p = 101 on the device image | Refused as a bad scheme, not packed | confirmed | AC-4 | cpp task AC-1 |
| S7 | partial failure | Bytes damaged on a percentage packet and a repair limit above n / 2 | Repaired within n / 2; the limit is lowered, not an error | confirmed | AC-4 | cpp task AC-1; rust task AC-1 |
| S8 | existing-feature overlap | The Rust ecc probe with the count keeps running next to the percentage | Count round trip unchanged (result 0) | confirmed | AC-8 | rust task AC-3 |
| S9 | existing data | The same rows on the M3 and M33F images | Identical bytes | confirmed | AC-5 | cpp task AC-2; rust task AC-2 |
| S10 | undo | The rounding is changed to floor | A QEMU run fails (the test bites) | confirmed | AC-6 | cpp task AC-3; rust task AC-3 |
| S11 | boundaries | The new code pushes an image over a flash or stack pin | The stage fails; a re-pin needs the owner's yes | confirmed | AC-7 | cpp task AC-4; rust task AC-4 |
| S12 | concurrent, permission denied | - | Not applicable: no actor, no shared state in a docs page or a bare-metal test | confirmed | out of scope (library) | n/a |
