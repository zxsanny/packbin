# Loop 24 acceptance criteria — Go package (AZ-2222)

Inherited project criteria stay in force: AC-1 to AC-16 (`_docs/00_problem/acceptance_criteria.md`) and the session criteria (`_docs/02_task_plans/pack-session/acceptance_criteria.md`). This feature makes Go the seventh language for each of them. AC-13 (the first tag's six registry packages) is history and does not change; Go has no registry (G-6).

## Inherited map

| Project AC | Go criterion |
|------------|--------------|
| AC-1, AC-2, AC-3 | GO-1 |
| AC-4 to AC-9 | GO-2, GO-3 |
| AC-10 | GO-8 |
| AC-11 | GO-9 |
| AC-12, AC-14, AC-15, AC-16 | GO-10 |
| Session AC-1 to AC-7 | GO-6 |
| Hostile vectors (`fixtures/hostile/`) | GO-4 |
| Round limits and work bounds (loops 16 to 21) | GO-5 |

## Criteria

- **GO-1 Golden bytes.** Go packs the AC-1 row to `4001000065cd1d00a3e1110100` and unpacks it to the same five fields with 0 motion fields. Mismatched bytes: 0. Field mismatches: 0.
- **GO-2 Data types.** For every data-type example in `README.md` (integers, floats, fixed bytes, big-endian, UTF-8, list, dictionary, flags, bool, when, repeat, sized, two-bit slots, bits, packed, times), Go packs the README hex and unpacks it back. Mismatched bytes: 0. A short buffer returns an error naming the field, the bytes needed and the bytes left, with 0 values; 1 or more trailing bytes return an error with 0 values.
- **GO-3 Parity rows.** Every parity row the TypeScript suite pins (the U1 to U26 rows that apply to Go, including the loop 21 to 23 AC-3 parity table) gives the same hex in Go, or a refusal where TypeScript refuses. Hex mismatches: 0. Refusal-vs-bytes disagreements: 0. Every refusal names the field id (and the count where there is one).
- **GO-4 Hostile vectors.** All 65 cases in `fixtures/hostile/cases.txt` (and any added in this loop) give an allowed outcome in Go. Panics: 0. Each `unpack` case returns in ≤ 1 second. `check-cases.sh` counts seven packages in every pack section's `Run by` / `Not run by` lines and passes.
- **GO-5 Round limits.** Default limits equal the other packages' (65 535 rounds; the byte and slot budgets of loops 19 to 21). A `limit` case with the lowered limit returns `too_many` or `bad_value` with `needed` 0. A raised limit unpacks the old worst packet. Unpack fuzzing (`go test -fuzz`) runs ≥ 60 seconds in CI with 0 panics and 0 allocations above the slot budget's ceiling.
- **GO-6 Session.** For the same 32-byte seed, 16-byte value and row, Go's ciphertext equals C#'s. Mismatched bytes: 0. Session AC-2 to AC-7 hold in Go (round trip both ways, a second packet, two clients not sharing a stream, 0 sessions from a bad seed or join value, 0 payloads before start or join).
- **GO-7 Ring.** For each of the 15 kinds in `language-pair.sh`, Go joins that kind's existing ring in both directions with every member: Go packs and each language of that ring unpacks Go's bytes; each language of that ring packs and Go unpacks. For the three `-short` kinds Go refuses with no row. Go's `pack-session` prints the C# ciphertext, and Go joins the session ring both ways. Go's position driver prints the golden hex. Failed handoffs: 0.
- **GO-8 Speed.** 100 000 pack-then-unpack round trips of the AC-1 fixture take ≤ 1 second on one core in CI.
- **GO-9 CI.** `test.yml` runs the Go suite on 100% of pushes and pull requests: `go test` (race detector on), `go vet` with 0 findings, `gofmt -l` with 0 files. A failing test fails the check. `docker-compose.test.yml` has a `go` service that runs `run-suite.sh go` on `golang:1.27`.
- **GO-10 Release.** A `vX.Y.Z` tag whose Go golden check passes gets exactly 1 `go/vX.Y.Z` tag at the same commit, and `go list -m github.com/zxsanny/packbin/go@vX.Y.Z` through proxy.golang.org returns that version within 30 minutes. A tag whose Go golden check fails gets 0 Go tags. A tree without `go/` gets 0 Go tags. `go/LICENSE` is MIT; non-MIT identifiers: 0. No tag is pushed in this loop.
- **GO-11 Dependencies.** `go.mod` declares `go 1.26` (or `go 1.26.0`, as `go get` writes it) and has exactly 1 direct requirement outside the standard library (`golang.org/x/crypto`); indirect requirements `go mod tidy` adds for it (`golang.org/x/sys`) are allowed; the modules of every package built with tests are the main module and `golang.org/x/crypto` only. cgo files: 0.
- **GO-12 No value.** A nil pointer or nil slice is no value (its flags bit is clear, a U11 count behind a clear `when` is refused as in the five); an empty slice is a value with 0 items (count 0 written). The map form reads a nested-row group from the nested map (U26 A). Each of these rows is pinned by at least 1 Go test.
- **GO-13 README.** The README has a Go section (install from the tag, one pack and unpack example, the data-type table marks Go). The example is compiled and run in CI and prints the README hex. Mismatched bytes: 0.
- **GO-14 Concurrency.** A built scheme is safe for concurrent `Pack` and `Unpack` from many goroutines: `go test -race` with 8 goroutines x 10 000 round trips on one scheme reports 0 races and 0 mismatches. A `PackSession` is used by one goroutine at a time (documented).
- **GO-15 Invalid Go values.** A nil row, a nil map, a map value of the wrong Go type, or a struct getter that returns an out-of-range value gives a pack error naming the field id, with nil bytes. Panics: 0. Partial output returned: 0 bytes.
- **GO-16 Tags never move.** A re-run of the publish for the same `vX.Y.Z` finds `go/vX.Y.Z` at the same commit and passes without pushing; found at another commit, it fails. A published Go version is never deleted or moved; a bad one is retracted in `go.mod` of the next version.
