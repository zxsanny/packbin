# Scenarios — loop 109 (embedded-arm DNS cause)

| # | actor / trigger / state | proposed behaviour | status | AC |
|---|-------------------------|--------------------|--------|----|
| 1 | owner dispatches the workflow on `dev` (first use) | the three config blocks, then 12 minutes of lookups, job success | confirmed | AC-1, AC-2 |
| 2 | dispatched a second time, another hour | independent run, no state kept; its log is a second evidence set | confirmed | AC-3 |
| 3 | dispatched while a push CI run is going | no interference: own workflow, no shared cache, no secret | confirmed | AC-6 |
| 4 | a lookup fails during the window (partial failure) | logged as `fail` with the error text; the run goes on; job stays success | confirmed | AC-2 |
| 5 | an outside contributor or a fork (permission denied) | cannot dispatch; `permissions: contents: read`; no secrets used | confirmed | AC-6 |
| 6 | the minutes input is empty or out of range (invalid input) | default 12; a value outside 10 to 20 is replaced by the default and the log says so | confirmed | AC-2 |
| 7 | existing structure checks of `.github/workflows/*.yml` (overlap) | the new file passes them unchanged (pinned actions, permissions) | confirmed | AC-5 |
| 8 | no failure shows in any run (boundary) | findings say `not reproduced`; the host-network build stays with that reason in the comments | confirmed | AC-3, AC-4 |
