# Feature: Go package (AZ-2222, loop 24)

A seventh language package, `go/` (module `github.com/zxsanny/packbin/go`), hand-written in Go with the standard library plus `golang.org/x/crypto/chacha20` (ADR-001: no shared walker, no generator). It packs and unpacks the same bytes as the six packages for every feature they share (wire format, schemes and dispatch, strings/lists/dicts, rounds and limits, hostile vectors, `PackSession`), takes rows as typed structs bound by getter/setter closures or as `map[string]any`, returns errors as values and never panics on hostile input. Go joins the CI suite, the language-pair ring (every kind, both ways), the golden gate of the publish, and ships as a `go/vX.Y.Z` tag pushed by `publish.yml` at the `vX.Y.Z` commit. Problem, decisions G-1 to G-6, ACs GO-1 to GO-16: `problem.md`, `acceptance_criteria.md` in this folder.

## Scenarios

See `scenarios.md` (S1 to S12, all `confirmed`; AC refs GO-1 to GO-16).

## Fit decisions

| card | collision | chosen option |
|------|-----------|---------------|
| 1 | ADR-002 and AC-13 name six registry packages | A — new ADR-004 "Go ships as a git tag from the same commit", amending ADR-002's count |
| 2 | The golden gate is all-or-nothing | A — Go joins the gate: a Go mismatch publishes 0 packages and 0 Go tags |
| 3 | Ring kinds run in different language subsets | A — Go joins each kind's ring both ways with every member |
| 4 | Where the six differ, which does Go copy | A — TypeScript at HEAD, except documented TypeScript-only exceptions (U6), where Go follows the five |
| 5 | `check-cases.sh` counts six names; "Go" is a substring | A — checker, the 41 README pack sections and the Go hostile loader in one task; whole-word match |

## Assumptions confirmed (new-task Step 5, auto-applied 2026-10-13)

1. TypeScript is Go's row-for-row reference (card 4).
2. `components/07_go_package` and a `module-layout.md` Go block are added by decompose 1.5 (owner-decided component).
3. One worker writes in `go/` at a time; shared CI, ring and publish files go to separate workers once the Go API exists.
4. No tag is pushed in loop 24; GO-10 is proven by the publish tests and a dry run.
