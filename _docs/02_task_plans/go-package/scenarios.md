# Scenarios — go-package

Source of rows: `intake` (new-task Step 4.7, 13-point handoff). Status: confirmed / out-of-scope / deferred. AC refs are the feature ACs in `acceptance_criteria.md`; decompose writes the owning task AC next to each.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | A Go service packs a row and a TypeScript (or any ring) service unpacks it | confirmed | the bytes equal the other languages'; the consumer gets the same row | GO-1, GO-7 (AZ-2440 AC-1, AZ-2449 AC-1) | intake |
| S2 | A Go service unpacks a hostile or truncated packet | confirmed | an error value naming the field, needed and left; no row; no panic; ≤ 1 s | GO-2, GO-4 (AZ-2440 AC-3, AZ-2446 AC-1) | intake |
| S3 | Many goroutines pack and unpack with one built scheme at once | confirmed | safe; 0 races under `-race`; a session is one goroutine at a time | GO-14 (AZ-2440 AC-6) | intake |
| S4 | Pack fails halfway (third field out of range) | confirmed | error naming the field; nil bytes, no partial output | GO-15 (AZ-2440 AC-5) | intake |
| S5 | A caller passes a nil row, a nil map or a wrong Go type in a map | confirmed | pack error naming the field id; no panic | GO-15 (AZ-2440 AC-5) | intake |
| S6 | Rows at the limits (65 535 rounds, 1 048 576 slots, 16 MiB output) and one past | confirmed | at the limit packs and unpacks; one past is refused as in TypeScript | GO-5 (AZ-2444 AC-1) | intake |
| S7 | Packets written by v0.2.2 of the six packages reach Go | confirmed | Go unpacks them (golden and ring payloads) | GO-1, GO-7 (AZ-2449 AC-1) | intake |
| S8 | The same values given as a typed struct and as a `map[string]any` | confirmed | the same bytes; nil pointer/slice = no value, empty slice = 0 items; nested-row group read from the nested map | GO-12 (AZ-2442 AC-3, AZ-2443 AC-3) | intake |
| S9 | A bad Go version was tagged | confirmed | tags never move or get deleted; the fix ships as the next patch, the bad version is retracted | GO-16 (AZ-2450 AC-5) | intake |
| S10 | The publish workflow re-runs for the same tag | confirmed | `go/vX.Y.Z` at the same commit passes without a push; at another commit it fails | GO-16 (AZ-2450 AC-3) | intake |
| S11 | A new Go module runs `go get github.com/zxsanny/packbin/go@vX.Y.Z` | confirmed | resolves through proxy.golang.org; builds with cgo off; one dependency (`golang.org/x/crypto`) | GO-10, GO-11 (AZ-2450 AC-2, AZ-2448 AC-2) | intake |
| S12 | Two Go clients from the same seed with different 16-byte values | confirmed | their streams differ (session AC-5); same seed and value as C# gives C#'s ciphertext | GO-6 (AZ-2445 AC-2) | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | ADR-002 and AC-13 name six registry packages; Go ships as a tag | A — new ADR-004 "Go ships as a git tag from the same commit", amending ADR-002's count | yes (AZ-2450) |
| 2 | The golden gate is all-or-nothing for the tag | A — Go joins the gate: a Go mismatch publishes 0 packages and 0 Go tags | yes (AZ-2450) |
| 3 | Ring kinds run in different language subsets | A — Go joins each kind's ring both ways with every member (ring CI time about doubles) | yes |
| 4 | Where the six packages differ, which does Go copy | A — TypeScript at HEAD, except documented TypeScript-only exceptions (U6), where Go follows the five | yes |
| 5 | `check-cases.sh` counts exactly six names; "Go" is a substring of other words | A — checker, the 41 README pack sections and the Go hostile loader change in one task; whole-word match | yes |

## Not walked

- Permission denied: a library has no actors or roles.
- A Go version below 1.26: `go.mod` refuses it; no behavior to define.
