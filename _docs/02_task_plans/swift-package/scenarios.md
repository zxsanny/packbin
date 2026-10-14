# Scenarios — swift-package

Source of rows: `intake` (new-task Step 4.7, epic handoff). Status: confirmed / out-of-scope / deferred. AC refs are the feature ACs in `acceptance_criteria.md`; decompose writes the owning task AC next to each.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | An iOS or macOS app packs a row and a server (any ring language) unpacks it | confirmed | the bytes equal the other languages'; the consumer gets the same row | SW-1, SW-7 (AZ-2522 AC-1) | intake |
| S2 | A Swift client unpacks a hostile or truncated packet | confirmed | a thrown error naming the field, needed and left; no row; no trap; ≤ 1 s | SW-2, SW-4 (AZ-2513 AC-3, AZ-2519 AC-1) | intake |
| S3 | Many tasks pack and unpack with one built scheme at once | confirmed | safe (`Sendable`); 0 races under the thread sanitizer; a session is one task at a time | SW-14 (AZ-2513 AC-6) | intake |
| S4 | Pack fails halfway (third field out of range) | confirmed | error naming the field; no bytes, no partial output | SW-15 (AZ-2513 AC-5) | intake |
| S5 | A caller's getter returns a wrong value, or a dictionary holds the wrong Swift type or lacks a key | confirmed | pack error naming the field id; no trap | SW-15 (AZ-2513 AC-5) | intake |
| S6 | Rows at the limits (65 535 rounds, 1 048 576 slots, 16 MiB output) and one past | confirmed | at the limit packs and unpacks; one past is refused as in TypeScript; no integer overflow trap | SW-5 (AZ-2517 AC-1) | intake |
| S7 | Packets written by v0.2.2 of the seven packages reach Swift | confirmed | Swift unpacks them (golden and ring payloads) | SW-1, SW-7 (AZ-2522 AC-1) | intake |
| S8 | The same values given as a typed struct and as a `[String: Any]` map | confirmed | the same bytes; `nil` = no value, empty array = 0 items; nested-row group read from the nested map | SW-12 (AZ-2516 AC-3, AC-5) | intake |
| S9 | A bad version was tagged | confirmed | tags never move or get deleted; the fix ships as the next patch | SW-16 (AZ-2523 AC-3) | intake |
| S10 | The publish workflow re-runs for the same tag | confirmed | the Swift check resolves the same commit and passes | SW-16 (AZ-2523 AC-3) | intake |
| S11 | A new app adds `.package(url: "https://github.com/zxsanny/packbin", from: "X.Y.Z")` | confirmed | resolves from the root `Package.swift`; builds on macOS and Linux; one dependency (`swift-crypto`) on non-Apple platforms only | SW-10, SW-11 (AZ-2523 AC-2, AZ-2518 AC-5) | intake |
| S12 | Two Swift clients from the same seed with different 16-byte values | confirmed | their streams differ (session AC-5); same seed and value as C# gives C#'s ciphertext; ChaCha20 equals RFC 8439 | SW-6 (AZ-2518 AC-2) | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | ADR-002/ADR-004 name six registry packages plus a Go tag; Swift installs from the existing `vX.Y.Z` tag | A — new ADR-005 "Swift installs from the root `Package.swift` at the `vX.Y.Z` tag", no extra tag | yes (release task) |
| 2 | The golden gate is all-or-nothing | A — Swift joins the gate: a Swift mismatch publishes 0 packages | yes (release task) |
| 3 | Ring kinds run in different language subsets | A — Swift joins each kind's ring both ways with every member | yes |
| 4 | Where the seven packages differ, which does Swift copy | A — TypeScript at HEAD, except documented TypeScript-only exceptions (U6), where Swift follows the others | yes |
| 5 | `check-cases.sh` counts seven names | A — checker, the README pack sections and the Swift hostile loader change in one task; whole-word match | yes |

## Not walked

- Permission denied: a library has no actors or roles.
- A Swift toolchain below 5.9: `Package.swift` refuses it; no behavior to define.
