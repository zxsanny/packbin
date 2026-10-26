# Feature: remove the stream session; one set of frame names; crypto kept for the frame ports

Loop 74 (owner, 2026-10-26; `problem.md`, ADR-009, decisions D1 to D6). Complexity of the whole: 13 points or more (8 packages, the cross-language ring, CI scripts, fixtures, docs), so it is decomposed here.

Remove the stream `PackSession` from all eight packages, with its tests, ring stages and commands, hostile probes, README sections and docs. Rename the frame types of Rust, Java and Swift to the C# set (`FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `ReplayWindow`, `Freshness`, `MacKey`; Java also `FrameSealed`). In C++, Go, Python and TypeScript, move the SHA-256, HMAC-SHA256, HKDF-SHA256 and ChaCha20 code into an internal module tested on the 27 rows of `fixtures/crypto/vectors.txt`. Frame-mode bytes do not change. As additional tasks, write the specs for frame mode in C++, Go, Python and TypeScript (loop 75).

The file inventory (read-only, 2026-10-26, HEAD 10cc0be) classifies every site as stream-only (delete), mixed (edit) or kept; it is summarized per task in the task specs. The couplings that force an order:

1. The ring (`.github/workflows/language-pair.sh`) calls `pack-session`, `unpack-session`, `pack-session-ecc`, `unpack-session-ecc` on all 8 drivers, and `ring-wiring-rows.test.sh`, `ring-wiring-swift.test.sh`, `ring-wiring-session-ecc.test.sh`, the `test.yml` step "session-ecc ring wiring" and `scripts/loop-tests.sh` parse or run it. The ring task goes first, with all 8 driver edits.
2. `.github/workflows/run-suite.sh`, `run-suite.test.sh` and `run-suite-swift.test.sh` hold sections for Rust (cargo lines, the count of 15), Swift (tsan suite list) and Go (the `x/crypto` allowlist, which stays under D2). The ring task owns them in the first batch.
3. `rust/tests/nostd_docs_tests.rs` requires the text "`session`" in `README.md`, `module-layout.md` and the Rust component description: the docs task owns that test.
4. `swift/Tests/PackbinTests/ReadmeExampleTests.swift` requires the README "Encrypted session / Swift" block; `scripts/frame/readme-examples.sh` requires each README frame example to equal its example test. A task that changes one of those tests changes its README block in the same batch; `README.md` is written by one writer at a time.
5. C++ file paths are compiled in `.github/workflows/ring-lib.sh:47`, `publish-position.sh:68`, `fixtures/hostile/fuzz/cpp/build_cpp.sh:9`, required by `publish-vcpkg.test.sh:105`, and `cpp/embedded` reads `VECTOR_TESTS` from the Makefile: all in the C++ task.
6. `rust/embedded/feature-sets.txt`, `limits.txt`, `limits-m33f.txt`, `checks.test.sh` (its mutant deletes the `session` line) change in one task.
7. `pack-session.md` "2.0.0" is cited in `fixtures/frame/vectors.txt` (a wire-change file) and in sources: the file name stays, the version becomes 3.0.0, the frame text is unchanged since 2.0.0 (D3).

## Scenarios

See `scenarios.md` (S1 to S12, all `confirmed`).

## Fit decisions

See `scenarios.md` § Fit decisions (cards 1 to 3, all resolved).
