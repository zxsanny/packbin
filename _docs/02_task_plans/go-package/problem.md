---
loop: 24
branch: dev
---

# Loop 24 — Go package (AZ-2222, full parity)

Loop 24 (on `dev`; no worktree). Intake: `_docs/loops/loop24/handoff24.md` and the Jira epic AZ-2222. Owner order (2026-10-13): **Go first**; the short wave (U24 B, U25 A, U26 A, Low-1 A, decided the same day) waits for a later loop.

## What

A seventh package, `go/`: a standard-library Go implementation of packbin that writes and reads the same bytes as C#, TypeScript, Python, Rust, C++ and Java for every feature they share: the wire format (scalars, flags, `when`, `repeat`/`times`, `sized`, two-bit slots, `bits`, `packed`), schemes, first-byte dispatch, field-id binding and the scheme-order check, UTF-8 strings, counted lists and dictionaries, the round limits and the shared hostile vectors, and `PackSession` (HKDF-SHA256 + ChaCha20, ciphertext equal to C#). Plus a Go driver in the `language-pair.sh` ring, a Go service in the CI suite, the AC-10 speed loop, release from a git tag, and a Go section in the README. Errors are returned as values; hostile input never panics.

Go copies every parity row decided through U26: where the six disagree, Go follows the five (or the decided row). U24 is C++ only. U25 applies to Go as a negative-id check (Go ids are `int`). U26 A: the map form reads a nested-row group from the nested map.

## Change location

Owner (2026-10-13, accept all recommended): "a new top-level `go/` folder, module `github.com/zxsanny/packbin/go`, tags `go/vX.Y.Z` next to `vX.Y.Z`". Plus the shared CI files the ring and suite already own (`.github/workflows/`, `docker-compose.test.yml`, `README.md`).

## Owner decisions (2026-10-13, "accept all recommended")

- **G-1** Module path `github.com/zxsanny/packbin/go` in `go/`; tags `go/vX.Y.Z` next to `vX.Y.Z`.
- **G-2** Minimum Go 1.26 in `go.mod`; CI and compose use `golang:1.27`. Go is not installed on the owner's Mac: local runs go through Docker only.
- **G-3** Session crypto: stdlib `crypto/hkdf` plus `golang.org/x/crypto/chacha20`, the only dependency.
- **G-4** Rows: typed structs bound by getter/setter closures (as Rust and C#), plus a `map[string]any` form that reads nested maps (as TypeScript; U26 A).
- **G-5** No value: a nil pointer or nil slice is no value; an empty slice is a value with 0 items.
- **G-6** Publish (AC-12, AC-14): `publish.yml`, run from the `vX.Y.Z` tag, pushes `go/vX.Y.Z` at the same commit only after the Go golden check passes, then checks the module with `go list -m` through proxy.golang.org. A failed golden check means no Go tag. A tag still needs the owner's explicit go with the exact commit.

## Out of scope

cgo, a code generator, TinyGo or any embedded target, a registry upload (Go has none), Swift (AZ-2223), AZ-2068, the short-wave rows (U24, U25, U26, Low-1 in the six packages), a release or tag in this loop.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Epic sized at ~26 points in 2026-10-06; loops 17 to 23 added the U1 to U26 parity rows and round CPU/memory bounds, so the real size is larger | decompose sizes each child; owner sees the wave plan | open | Medium |
