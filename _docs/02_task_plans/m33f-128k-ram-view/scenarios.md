# Scenarios - m33f-128k-ram-view

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | first run of both M33F rows after the change, no code edit | confirmed | both pass with the figures of HEAD | AC-1, AC-2 | intake |
| S2 | a later edit makes an image need more than 128 KiB of static RAM | confirmed | the link fails with the linker's overflow message and the row fails | AC-3 | intake |
| S3 | a later edit of the script moves the window (4 MB back, or 64 KiB) | confirmed | both M33F rows fail naming the expected and the found stack top | AC-4 | intake |
| S4 | the stack grows (a deeper call) | confirmed | the existing stack pins and the 8 KiB ceiling fail first; the window adds no new stack rule | AC-2 | intake |
| S5 | the Rust row links into the same script | confirmed | it runs in the same window with the same guard | AC-1, AC-2, AC-4 | intake |
| S6 | other rows (M3, M4F, s390x, AVR) | confirmed | unchanged; they use other scripts or none | AC-5 | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| - | none: the script is read by exactly two rows, both probed green at 128 KiB | - | - |

## Not walked

- A real non-secure image (TrustZone), RRAM, timing: not reachable on `mps2-an505` (stated limit, flagged concern).
