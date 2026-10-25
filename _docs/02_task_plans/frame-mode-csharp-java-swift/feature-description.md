# Feature: frame mode in C#, Java and Swift (AZ-3192 follow-up)

Complexity: 17 points (scope 3 packages plus docs, novelty low (the Rust port is the reference and the vectors exist), risk medium (constant-time compare, key wipe and error kinds differ by runtime); routing: mandatory `/decompose --feature`, 13 or more).
Loop: 71 (branch `dev`). Umbrella ticket: AZ-3192. Epic: AZ-3199 (Frame mode) reopened for the follow-up, or a new epic if the owner prefers (decompose asks Jira).

## Description

Bring frame mode (contract `pack-session.md` 2.0.0, ADR 008) to the C#, Java and Swift packages: a `FrameSession` type beside the stream `PackSession` (Fit decision 1) with `load` of a 32-byte key, an epoch (24 bits) and a configuration (tag length 4, 8, 16; directions up, down, group), an optional previous (key, epoch), `seal`, `open` with a caller-owned 64-message `ReplayWindow` and the previous slot, and a `MacKey` for the MAC-only call (label key derived with HKDF, message hashed in parts, 4/8/16/32-byte tags, constant-time verify). Bytes are those of the contract; the oracle is `fixtures/frame/vectors.txt` (157 data rows) and `fixtures/crypto/vectors.txt` (27 data rows, PB-02 for these three packages). Crypto: the platform HMAC-SHA256 and HKDF-SHA256 where the package already uses them, the existing hand-written ChaCha20 block; a hand-folded constant-time compare in all three; keys and pad states wiped on dispose, close or deinit.

Owner decisions (2026-10-25, "accept all recommended"): all three packages in this loop (order C#, Java, Swift); PB-02 primitive tests included; API on its own type, always built (no feature switch); one replay window per caller object as in Rust; same vectors, error kinds and bytes as Rust; README example per language and component descriptions; no cross-language ring.

| Task | Points | Scope | Depends on |
| --- | --- | --- | --- |
| C# frame mode | 5 | `FrameSession`, `ReplayWindow`, `MacKey`, error kinds, vector and primitive tests, hostile and tamper tests, `net10.0` and `netstandard2.0` | none |
| Java frame mode | 5 | the same under `java/`, hook into `test.sh`, Android API 26 check | none |
| Swift frame mode | 5 | the same under `swift/` (swift-testing), `Kind` cases and the pinned list, strict concurrency, thread-sanitizer file names | none |
| Docs | 2 | README `### C#`, `### Java`, `### Swift` examples (run by a test each), component descriptions, `module-layout.md`, contract Change Log note of the three consumers | the three above |

Loop-level acceptance criteria: `acceptance_criteria.md` (AC-G1.* to AC-G3.*).

## Code sections / UI locations

`csharp/` (`PackSession.cs`, `SessionPad.cs`, `Compat.cs`, new frame files, `csharp/tests/`), `java/src/main/java/packbin/` (`PackSession.java`, `SessionPad.java`, `Packbin.java` error classes, new frame files, `java/src/test/java/packbin/`, `java/test.sh`), `swift/Sources/Packbin/` (`PackSession.swift`, `SessionKeys.swift`, `ChaCha20.swift`, `PackbinError.swift`, new frame files, `swift/Tests/PackbinTests/`), README, `_docs/02_document/components/{01_csharp_package,06_java_package,08_swift_package}/`, `_docs/02_document/module-layout.md`. Read only: `fixtures/frame/`, `fixtures/crypto/`, the Rust reference `rust/src/nostd/frame/`, `rust/src/session_core/`.

## Scenarios

`scenarios.md` S1 to S13 (S11 out of scope).

## Fit decisions

1. A new `FrameSession` type beside `PackSession`; the stream class is untouched.
2. Three new error kinds (`TagMismatch`, `Duplicate`, `TooOld`), added the way each package already adds kinds.
3. "0 SHA-256 compressions" becomes "0 MAC computations" via an internal test-only counter.

## Constraints and sizing notes for decompose

- The three package tasks write disjoint trees (`csharp/`, `java/`, `swift/`) and can run in parallel; the Docs task waits for them. README, `_docs/` and `.github/workflows/` are the parent's.
- Source files at most 500 lines; tests in Arrange-Act-Assert form; a wall-clock assertion uses the package's load factor; no formatter or linter write outside owned files; C# tests run with `MSBUILDDISABLENODEREUSE=1`; Swift on this Mac: `xcode-select -p` is Xcode, plain `swift test`; one `swift build` at a time.
- Wire stability: a changed row in `fixtures/frame/vectors.txt` is a wire change; this loop does not edit the fixtures.
- Do not implement in sibling repositories; meshbell's side is its own.
