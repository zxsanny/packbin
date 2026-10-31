# Scenarios - arm-no-text-no-ecc-run

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | first arm stage run after the change, no source edit | confirmed | the reduced image links, runs `FAILURES 0`, sites run equal asserted; every other row shows the baseline figures | AC-1, AC-2, AC-6 | intake |
| S2 | a later edit adds `malloc`, `new` or an exception to the packet-only path | confirmed | the reduced image has a heap or exception symbol and the stage fails naming it | AC-3, AC-5 | intake |
| S3 | a later edit makes the `PACKBIN_NO_TEXT` build pull in the string codec | confirmed | a codec symbol or table is found in the image and the stage fails | AC-4, AC-5 | intake |
| S4 | a later edit breaks packing a scheme with no string, or forwarding a `Packed` | confirmed | a check fails on the device (`FAILURES` above 0) | AC-2, AC-5 | intake |
| S5 | a later edit lets a scheme with parity bytes through in the `PACKBIN_NO_ECC` build | confirmed | the refusal check fails on the device | AC-2 | intake |
| S6 | a later edit grows the reduced image's flash or stack | out-of-scope | not gated: run-only is the owner's choice (accepted-risk Low) | - | intake |
| S7 | QEMU or the ARM toolchain is missing, or the image hangs | confirmed | fails like the other M33F steps (no QEMU result is a failure, 300 s limit kills a hang) | AC-1 | intake |
| S8 | host `no-text-test`, `no-ecc-test`, `object-check` and the Uno build | confirmed | unchanged | AC-6 | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| where the run sits | a new row needs `lib.test.sh` and `run-parts.test.sh` changes and the CI row list; a step inside `cpp-m33f` needs none but a failure reads as an `cpp-m33f` failure | a step inside `target_m33f`, with its own `fail` messages naming the reduced image (simplest; no new row table entry) | if the step grows past ~40 lines or its time passes 60 s, split it into a row |
| which tests run | the two host tests each `#error` unless their own flag is set and each defines `main()` | compile the two existing sources unchanged for the M33F with both flags and `-Dmain=<name>`, call both from one small runner | no copy of the test code; if a source does not compile with both flags together, the batch report names it and the task stops for a decision |

## Not walked

- A flash or stack bar for the reduced image (owner, 2026-10-31: run-only).
