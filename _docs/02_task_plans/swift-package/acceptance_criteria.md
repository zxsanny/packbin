# Loop 26 acceptance criteria — Swift package (AZ-2223)

Inherited project criteria stay in force: AC-1 to AC-16 (`_docs/00_problem/acceptance_criteria.md`) and the session criteria (`_docs/02_task_plans/pack-session/acceptance_criteria.md`). This feature makes Swift the eighth language for each of them. AC-13 (the first tag's six registry packages) is history and does not change; Swift has no registry (S-3). The epic's seven acceptance rows are SW-1 (row 1), SW-2/SW-3 (row 2), SW-8 (row 3), SW-4 (row 4), SW-6 (row 5), SW-7 (row 6), SW-9/SW-10 (row 7).

## Inherited map

| Project AC | Swift criterion |
|------------|-----------------|
| AC-1, AC-2, AC-3 | SW-1 |
| AC-4 to AC-9 | SW-2, SW-3 |
| AC-10 | SW-8 |
| AC-11 | SW-9 |
| AC-12, AC-14, AC-15, AC-16 | SW-10 |
| Session AC-1 to AC-7 | SW-6 |
| Hostile vectors (`fixtures/hostile/`) | SW-4 |
| Round limits and work bounds (loops 16 to 21) | SW-5 |

## Criteria

- **SW-1 Golden bytes.** Swift packs the AC-1 row to `4001000065cd1d00a3e1110100` and unpacks it to the same five fields with 0 motion fields. Mismatched bytes: 0. Field mismatches: 0.
- **SW-2 Data types.** For every data-type example in `README.md` (integers, floats, fixed bytes, big-endian, UTF-8, list, dictionary, flags, bool, when, repeat, sized, two-bit slots, bits, packed, times), Swift packs the README hex and unpacks it back. Mismatched bytes: 0. A short buffer throws an error naming the field, the bytes needed and the bytes left, with 0 values; 1 or more trailing bytes throw an error with 0 values.
- **SW-3 Parity rows.** Every parity row the TypeScript suite pins (the U1 to U26 rows that apply to Swift, including the loop 21 to 23 AC-3 parity table) gives the same hex in Swift, or a refusal where TypeScript refuses. Hex mismatches: 0. Refusal-vs-bytes disagreements: 0. Every refusal names the field id (and the count where there is one).
- **SW-4 Hostile vectors.** All 65 cases in `fixtures/hostile/cases.txt` (and any added in this loop) give an allowed outcome in Swift. Traps and crashes: 0. Each `unpack` case returns in ≤ 1 second. `check-cases.sh` counts eight packages in every pack section's `Run by` / `Not run by` lines and passes.
- **SW-5 Round limits and fuzzing.** Default limits equal the other packages' (65 535 rounds; the byte and slot budgets of loops 19 to 21). A `limit` case with the lowered limit throws `too_many` or `bad_value` with `needed` 0. A raised limit unpacks the old worst packet. Unpack fuzzing (the shared corpora in `fixtures/hostile/fuzz/` plus a seeded random run) runs ≥ 60 seconds in CI with 0 traps and 0 allocations above the slot budget's ceiling.
- **SW-6 Session.** For the same 32-byte seed, 16-byte value and row, Swift's ciphertext equals C#'s. Mismatched bytes: 0. Session AC-2 to AC-7 hold in Swift (round trip both ways, a second packet, two clients not sharing a stream, 0 sessions from a bad seed or join value, 0 payloads before start or join). The in-package ChaCha20 matches all RFC 8439 block and stream vectors (2.3.2, 2.4.2); mismatches: 0.
- **SW-7 Ring.** For each of the 15 kinds in `language-pair.sh`, Swift joins that kind's existing ring in both directions with every member. For the three `-short` kinds Swift refuses with no row. Swift's `pack-session` prints the C# ciphertext, and Swift joins the session ring both ways. Swift's position driver prints the golden hex. Failed handoffs: 0.
- **SW-8 Speed.** 100 000 pack-then-unpack round trips of the AC-1 fixture take ≤ 1 second on one core, release build, in CI.
- **SW-9 CI.** `test.yml` runs the Swift suite on 100% of pushes and pull requests: `swift test` and `swift build -c release` with 0 warnings. A failing test fails the check. `docker-compose.test.yml` has a `swift` service that runs `run-suite.sh swift` on `swift:6`.
- **SW-10 Release.** A `vX.Y.Z` tag whose Swift golden check passes is resolved by `swift package resolve` and built in a throwaway consumer (dependency `https://github.com/zxsanny/packbin` at exactly `X.Y.Z`) within 30 minutes of the tag. A tag whose Swift golden check fails publishes 0 packages. A tree without `Package.swift` or `swift/` skips the Swift check. `Package.swift` declares `// swift-tools-version: 5.9`, iOS 15 and macOS 12, and the license in the repository root stays MIT; non-MIT identifiers: 0. No tag is pushed in this loop.
- **SW-11 Dependencies.** The only package dependency is `swift-crypto`, on non-Apple platforms (`.when(platforms: [.linux, ...])`); on Apple platforms the package has 0 dependencies. `Package.resolved` pins an exact version. Unsafe flags and C targets: 0.
- **SW-12 No value.** `nil` is no value (its flags bit is clear; a U11 count behind a clear `when` is refused as in the seven); an empty array is a value with 0 items (count 0 written). The map form reads a nested-row group from the nested dictionary (U26 A). Each of these rows is pinned by at least 1 Swift test.
- **SW-13 README.** The README has a Swift section (install from the tag with `.package(url:from:)`, one pack and unpack example, the data-type table marks Swift). The example is compiled and run in CI and prints the README hex. Mismatched bytes: 0.
- **SW-14 Concurrency.** A built scheme is `Sendable` and safe for concurrent `pack` and `unpack` from many tasks: 8 tasks × 10 000 round trips on one scheme report 0 data races (thread sanitizer run) and 0 mismatches. A `PackSession` is used by one task at a time (documented).
- **SW-15 Invalid Swift values.** A row whose getter returns an out-of-range value, a dictionary value of the wrong Swift type, or a missing dictionary key gives a thrown pack error naming the field id, with no bytes returned. Traps: 0. Partial output returned: 0 bytes.
- **SW-16 Tags never move.** A re-run of the publish for the same `vX.Y.Z` resolves the same commit and passes; the Swift check never moves or deletes a tag. A bad version is fixed by the next patch.
