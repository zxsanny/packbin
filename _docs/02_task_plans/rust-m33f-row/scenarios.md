# Scenarios — rust-m33f-row

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | first run of the stage with the new row | confirmed | `rust-m33f` links, runs on `mps2-an505`, passes for the five sets | AC-1, AC-2 | intake |
| S2 | a later edit of `rust/src` raises a set's flash or stack above its M33F pin | confirmed | the row fails naming the figure, the set and the pin | AC-5, AC-6 | intake |
| S3 | a figure goes above 64 KB or 8 KB | confirmed | the row fails naming the ceiling | AC-5, AC-6 | intake |
| S4 | the M33F image and the M4F image pack the route and decode the golden fixture | confirmed | identical bytes | AC-4 | intake |
| S5 | the M4F row, its limits and the mutants | confirmed | unchanged | AC-7 | intake |
| S6 | CI runs `embedded-arm` | confirmed | the workflow installs both targets; the row runs and passes | AC-8 | intake |
| S7 | a library for the M33F target is missing | confirmed | the row fails naming the path (`run.sh libs`), nothing skipped silently | AC-1, AC-2 | intake |
| S8 | CI's Rust 1.98 gives other figures than a local toolchain | confirmed | pins come from a run with 1.98; the CI figure is read after the push and a gap above the pin is a named blocker, not a raised pin | AC-5 | intake |
| S9 | the owner drops the M4F row later | deferred | not this loop; the M33F row shares no state with it | — | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| — | none: `target.sh` runs one row; the new row reuses its link helpers with its own architecture flags and linker script; no other row reads them | — | — |

## Not walked

- Real nRF54L15 hardware, TrustZone non-secure images (128 KiB of RAM), the RISC-V coprocessor; the QEMU machine is the Secure-state AN505 image.
- Cycle timing on the part.
