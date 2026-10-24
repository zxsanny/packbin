# Scenarios — publish-gate-load-aware

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | The Go proxy check runs on a loaded host and one `go` call takes longer than the 3 s window | confirmed | the "never answers" case still sees at least 2 asks | AC-1 | intake |
| S2 | `proxy_check` regresses to stop after one try | confirmed | the same test fails naming "asked once only" | AC-2 | intake |
| S3 | A quiet host runs `publish-go.test.sh` | confirmed | exit 0 within 60 s | AC-3 | intake |
| S4 | The container pip install of `build` fails and pip's error is before `build failed: python` | confirmed | the failure message shows the last 25 lines, pip's error included | AC-4 | intake |
| S5 | The host venv pip install of `platformio` fails under `set -e` | out-of-scope | its error already goes to the share log | — | intake |
| S6 | The phases group runs on a quiet host | confirmed | exit 0 within 400 s | AC-5 | intake |
| S7 | The kept pip error names a network or index failure | confirmed | a bounded retry may be added to the pip step and the owner is told; otherwise no change beyond the log | AC-6 | intake |
| S8 | The full gate runs on a busy host | confirmed | the two checks are read from share logs and reported with the host load | AC-7 | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| — | none: test support only; `proxy_check` and the real publish path stay unchanged unless AC-6 fires | — | yes |

## Not walked

- pip failing for a reason other than the network (a pin that left the index): the kept error will show it; a new task if so.
