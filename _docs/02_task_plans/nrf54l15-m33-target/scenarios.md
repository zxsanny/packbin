# Scenarios — nrf54l15-m33-target

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | first run of the stage with the new row | confirmed | `cpp-m33f` builds, runs on `mps2-an505`, passes | AC-1, AC-2 | intake |
| S2 | a later edit raises flash or stack above a pin | confirmed | the row fails naming the figure and the pin | AC-3, AC-4, AC-6 | intake |
| S3 | a later edit raises flash above 64 KB or stack above 8 KB | confirmed | the row fails naming the ceiling; the meter reports a number above 8,192 B | AC-3, AC-4, AC-6 | intake |
| S4 | the M33F image and the M3 image pack the all-kinds row | confirmed | identical packet bytes | AC-2 | intake |
| S5 | the M4F target and its pins | confirmed | unchanged; M4F stays the small-part bar | AC-7 | intake |
| S6 | CI runs the arm stage | confirmed | `embedded-arm` runs the new row through the table | AC-8 | intake |
| S7 | the QEMU machine or toolchain lacks the M33 machine | confirmed | the row fails with the QEMU error (named blocker), nothing is skipped silently | AC-1, AC-2 | intake |
| S8 | the owner later drops M4F | deferred | not this loop; the row and pins are independent of M4F | — | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| — | none: no source change; `arm_link_common` is read by the link helpers, the M33F row sets its own linker script and no other row reads it | — | — |

## Not walked

- Real nRF54L15 hardware, TrustZone non-secure images (128 KiB of RAM) and the RISC-V FLPR coprocessor; the QEMU machine is the Secure-state AN505 image.
- Timing (cycles) on the part.
