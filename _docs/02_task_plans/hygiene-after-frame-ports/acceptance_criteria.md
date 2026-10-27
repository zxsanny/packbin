# Acceptance criteria — loop 76 (hygiene-after-frame-ports)

Project ACs inherited and unchanged: frame vectors 157 of 157 and crypto vectors 27 of 27 in all eight packages; the embedded pins (`cpp-m4f` 7,712 B / 540 B, `cpp-m33f` 25,720 B / 724 B, frame image 8,416 B / 912 B, `rust-m33f` pins of `rust/embedded/limits-m33f.txt`). New ones below; figures are from HEAD a50e750 on 2026-10-27.

## H1: timing selftest (item 1)

**AC-H1.1: No pipe to an early-exit reader**
Given `.github/workflows/publish-timing.selftest.sh`
When it is searched for `printf '%s\n' ... | grep` pipelines
Then there are 0 (15 today) and the checks read the captured text without a pipe from `printf`.

**AC-H1.2: Still catches what it caught**
Given the selftest and a copy of `publish-timing.test.sh` mutated so `alpha` prints no timing line
When the selftest runs
Then it exits non-zero and prints `FAIL: alpha has no timing line` (a run on the unmutated file exits 0 with 0 `FAIL` lines).

**AC-H1.3: The next failure shows its evidence**
Given a check of the selftest that does not match
When it fails
Then the captured driver output it matched against is printed with the `FAIL` line, so a pipe error and a missing line can be told apart.

**AC-H1.4: Stable under load**
Given 12 CPU burners
When the selftest runs 20 times in a row
Then all 20 exit 0. This is a sanity bound, not a proof of the cause (not reproduced: 0 of 3,000 trials of the old pattern).

## H2: C# probe project (item 2)

**AC-H2.1: Builds without the second entry point**
Given the build command of the csproj header on a copy outside the checkout
When it runs
Then it reports 0 errors and 0 warnings `CS7022` (1 today).

**AC-H2.2: Runs**
Given the built probe
When `PackbinProbe <repo> edges` runs
Then it does not die with an exception (exit 134 today); it prints one PASS or FAIL line per case and exits 0 or 1.

**AC-H2.3: The netstandard2.0 probe is unharmed**
Given `ns20/Ns20Utf8Probe.csproj`
When it is built from its own copy with the command in its header
Then it reports 0 errors.

## H3: Rust frame-only build (item 3)

**AC-H3.1: Every feature set compiles its tests**
Given `cd rust && cargo test --no-default-features --features <set> --no-run` for the 7 non-default sets `(none)`, `alloc`, `text`, `ecc`, `text,ecc`, `frame` and `text,ecc,frame`, and the default set
When each runs with Cargo 1.79 (the Mac default); the `frame` set also with the Docker toolchain of `docker compose -f docker-compose.test.yml run --rm rust`
Then all 8 exit 0 (7 of the 8 fail today; the mechanism is the repo's inner `#![cfg(...)]` attribute on the test files that need `std`, 22 files, plus the widened gate of `nostd_dict_tests.rs` and the test-module imports).

**AC-H3.2: The tests that build, pass**
Given the `frame` set
When `cargo test --no-default-features --features frame` runs
Then every test that runs passes; the count is recorded in the report.

**AC-H3.3: Nothing else moves**
Given the default-feature suite and the Rust embedded stage
When both run after the change
Then the default suite counts are unchanged from a run on HEAD in this loop and every `rust-m33f` and M4F figure is unchanged (the change is `#[cfg(test)]` only).

## H4: Swift DocC (item 4)

**AC-H4.1: Frame types listed**
Given `swift/Sources/Packbin/Packbin.docc/Packbin.md`
When it is searched for each of the 10 public frame types (`FrameSession`, `FrameConfig`, `FrameDirection`, `FrameDirections`, `FrameSlot`, `FrameOpened`, `MsgContext`, `Freshness`, `ReplayWindow`, `MacKey`)
Then all 10 appear in the "Public names" list with their public members (0 today), each member checked against the declaration in `swift/Sources/Packbin/`.

**AC-H4.2: No test moves**
Given the Swift suite
When it runs after the change
Then it passes with the same test count as HEAD (the README snippet test is not touched).

## H5: vcpkg `supports` reason (item 5)

**AC-H5.1: The stale reason is gone**
Given ADR-003 line 48 and `05_cpp_package/description.md` line 136
When they are read
Then neither names `os_random` as a reason for the Windows limit; both say the core is built and tested only with gcc on Linux and clang on macOS.

**AC-H5.2: The line and its check are unchanged**
Given `.github/workflows/publish-embedded.sh` (`"supports": "linux | osx"`) and `publish-vcpkg.test.sh:130`
When `git diff --stat` is read for the loop
Then neither file is in it, and neither is `README.md` line 27 or 469.

## H6: NFC/NFD edges check (item 6)

**AC-H6.1: C# probe**
Given the C# probe after H2
When `edges` runs with the two keys in ascending byte order (NFD `65 cc 81`, then NFC `c3 a9`)
Then the result is 64 PASS, 0 FAIL, exit 0 (63 PASS and 1 FAIL today, after H2).

**AC-H6.2: Java probe**
Given the Java probe compiled with `javac --release 17` as in `AuditProbe.java`
When `edges` runs with the same key order
Then the result is 65 PASS, 0 FAIL, exit 0 (64 PASS and 1 FAIL today).

**AC-H6.3: No package change**
Given the loop's diff
When it is read
Then no file under `csharp/*.cs` or `java/src/main` changed for H6 (the packages are right).

## H7: Session names (item 7)

**AC-H7.1: No stale name**
Given the tracked files outside `_docs/loops/`, `_docs/02_tasks/done/`, `_docs/03_implementation/` and this plan folder
When `git grep -n "TopRangeAndSessionTests\|EccSessionTextTests\|fuzz_ecc_session"` runs
Then it prints 0 lines (10 lines in 10 files today).

**AC-H7.2: Same tests, same results**
Given the C# suite, `fuzz_ecc` for Python and for TypeScript
When they run before and after the rename
Then the C# test count (4,220 listed by `dotnet test csharp --list-tests`) and result are equal, and each fuzz probe exits 0 with 0 mismatches and 0 foreign exceptions and prints the same final verdict line (the probes print no `PASS` lines).

## Loop-level

**AC-L1: Nothing normative moved**
Given the loop's diff
When `git diff --stat` is read
Then no file under `fixtures/frame/`, `fixtures/crypto/`, `fixtures/hostile/cases.txt` or the contract `pack-session.md` is in it.

**AC-L2: Total run**
Given one `scripts/loop-tests.sh --all` run at the closing commit with host load below 60
When it ends
Then every stage passes (13 stages and the publish gate); a failure is read from its log before it is called a flake.
