---
loop: 26
branch: dev
---

# Loop 26 — Swift package (AZ-2223, full parity)

Loop 26 (on `dev`; no worktree). Intake: `_docs/loops/loop25/handoff26.md` and the Jira epic AZ-2223. Owner order (2026-10-14): Swift epic, whole epic in this loop (waves, like Go in loop 24); loop 26 decisions G1 A, D1b A, P1 A accepted the same day (F44, the tag ruleset, stays with the owner).

## What

An eighth package, `swift/`: a Swift implementation of packbin that writes and reads the same bytes as C#, TypeScript, Python, Rust, C++, Java and Go for every feature they share: the wire format (scalars, flags, `when`, `repeat`/`times`, `sized`, two-bit slots, `bits`, `packed`), schemes, first-byte dispatch, field-id binding and the scheme-order check, UTF-8 strings, counted lists and dictionaries, the round limits and the shared hostile vectors, and `PackSession` (HKDF-SHA256 + ChaCha20, ciphertext equal to C#). Plus a Swift driver in the `language-pair.sh` ring, a Swift service in the CI suite (Linux `swift:6` image), the AC-10 speed loop, install from a git tag through Swift Package Manager, and a Swift section in the README. Errors are thrown as a typed error; hostile input never traps (no arithmetic overflow, out-of-range index or force unwrap reachable from input).

Swift copies every parity row decided through U26: where the seven disagree, Swift follows TypeScript at HEAD (or the decided row), as Go did. U24 is C++ only. U25 applies as a negative-id check. U26 A: the map form reads a nested-row group from the nested map. The D1b rows stay as documented (empty anchored group, `when` on a mark): Swift copies TypeScript.

## Change location

Owner (2026-10-14, accept all recommended): "a new top-level `swift/` folder, a `Package.swift` at the repository root pointing at `swift/Sources`, tags are the existing `vX.Y.Z`". Plus the shared CI files the ring and suite already own (`.github/workflows/`, `docker-compose.test.yml`, `README.md`, `fixtures/hostile/check-cases.sh`).

## Owner decisions (2026-10-14, "accept all recommended")

- **S-1** `Package.swift` at the repository root; library target path `swift/Sources/Packbin`; no mirror repository; Swift Package Manager resolves the existing `vX.Y.Z` tags (no `swift/vX.Y.Z` tag).
- **S-2** ChaCha20 is written in the package and checked against the RFC 8439 vectors (no underscored `_CryptoExtras`). HKDF-SHA256 comes from CryptoKit on Apple platforms and `swift-crypto` (`Crypto`) elsewhere: `swift-crypto` is the only dependency, declared for non-Apple platforms.
- **S-3** AC-12 and AC-14 for a fetch-only language: the publish workflow, after the Swift golden check passes, runs `swift package resolve` and a build in a throwaway consumer against the tag. No Swift Package Index listing in this loop.
- **S-4** `swift-tools-version: 5.9`, platforms iOS 15 and macOS 12, CI image `swift:6`. Language mode 5 unless Swift 6 strict concurrency costs nothing (decompose decides, recorded in the task).
- **S-5** Scope: the whole epic in this loop, in waves; no tag is pushed.
- Swift is installed on the owner's Mac (6.3.3): local runs use `swift test`; the Linux run uses the `swift:6` container.
- Defaults to confirm in New Task step 5: rows are typed structs bound by getter/setter closures plus a `[String: Any]` map form (as Go G-4); `nil` is no value, an empty array is a value with 0 items (as Go G-5).

## Out of scope

CocoaPods (trunk goes read-only in December 2026), Carthage, an Objective-C wrapper, a code generator, an Apple-platform (iOS simulator) CI job, a Swift Package Index listing, AZ-2068, the short-wave small items on handoff26, a release or tag in this loop.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| Swift traps (not throws) on arithmetic overflow, index out of range and force unwrap; a trap on hostile input kills the process and cannot be caught | Every size and index computed from input uses checked or wrapping arithmetic; hostile vectors plus unpack fuzzing run in CI; AC SW-4/SW-5 count traps | open | High |
| The epic was sized ~26 points on 2026-10-06; Go grew from ~26 to 45 with the U1 to U26 rows and round bounds | decompose sizes each child; owner sees the wave plan | open | Medium |
| Cortex-style size budgets do not apply, but `Package.swift` at the root puts a Swift manifest in a repository whose other packages are not Swift; a bad root manifest breaks `swift package resolve` for every consumer | publish test builds a throwaway consumer; `Package.swift` is covered by CI on every push | open | Medium |
| swift-crypto on Linux is the first non-stdlib dependency pulled from the network in the Swift CI | pinned exact version in `Package.resolved`; the cache is a named volume in compose | open | Low |
