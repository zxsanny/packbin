# Scenarios — hygiene-after-frame-ports

Source of rows: `intake` (new-task Step 4.7, loop 76). Status: confirmed / out-of-scope / deferred. Fit analysis found no collision with today's behavior (no problem card): every change is in test, probe, CI-script or documentation files, and the packages and their bytes stay as they are.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | A maintainer runs the timing selftest and one check does not match | confirmed | it prints the `FAIL` line and the captured driver output it matched against | AZ-3330 AC-3 | intake |
| S2 | The selftest runs under Apple bash 3.2 on the Mac and under bash 5 in CI | confirmed | same pass or fail in both; the checks use no pipe from `printf` | AZ-3330 AC-1, AC-4 | intake |
| S3 | A maintainer copies the C# probe folder (with `ns20/`) outside the checkout and builds it | confirmed | it builds with 0 `CS7022` warnings and `edges` runs | AZ-3329 AC-1, AC-2 | intake |
| S4 | A maintainer builds the netstandard2.0 probe from its own folder | confirmed | still 0 errors | AZ-3329 AC-3 | intake |
| S5 | A firmware user compiles the tests with `--no-default-features --features frame` | confirmed | compiles; the tests that run pass | AZ-3331 AC-1, AC-2 | intake |
| S6 | The other feature sets (`none`, `text`, `ecc`, `alloc`, `text,ecc`, `text,ecc,frame`) build their tests | confirmed | each compiles; a set that fails for a missing std-only gate or a missing import is fixed in this loop | AZ-3331 AC-1 | intake |
| S7 | The Rust embedded stage compiles `session_core` for the device | confirmed | every figure unchanged (the change is in `#[cfg(test)]` code and in test-file attributes only) | AZ-3331 AC-3 | intake |
| S8 | A Swift reader opens the DocC "Public names" list | confirmed | the 10 frame types are listed with their public members | AZ-3332 AC-1 | intake |
| S9 | A reader of ADR-003 or the C++ description asks why the vcpkg port is Linux and macOS only | confirmed | the answer is "built and tested only with gcc on Linux and clang on macOS", not `os_random` | AZ-3332 AC-3 | intake |
| S10 | A maintainer runs the C# or Java `edges` probe with two dictionary keys in descending byte order | out-of-scope | the dictionary-order tests of the packages already pin the refusal; the probe keeps the one ascending case | — | intake |
| S11 | A script, doc or CI file names a file that item 7 renames | confirmed | none is left: `git grep` finds 0 stale names | AZ-3333 AC-1 | intake |
| S12 | The renamed Python and TypeScript fuzz probes run | confirmed | exit 0, 0 mismatches and the same final verdict line as before the rename (these probes print no PASS lines) | AZ-3333 AC-2 | intake |
| S13 | The Python and TypeScript `edges` probes build the NFC/NFD case | confirmed | NFD key first; the info line reads "accepted as two keys" (owner, 2026-10-27, assessment round 1 row A1) | AZ-3334 AC-1, AC-2 | assess-round-1 |
| S14 | A maintainer runs `cargo test` in a non-default Rust feature set (none, alloc, text, ecc, text+ecc, text+ecc+frame) | confirmed | each set's tests run once and the counts are recorded; a failing set is a finding, not a fix in this loop (owner, 2026-10-27, row A2) | AZ-3331 AC-1 (compile), the recorded run in the assessment report | assess-round-1 |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| — | none found | — | — |

## Not walked

- The AVR `chacha20_xor` runtime check on a 16-bit `size_t` (owner: out of scope, needs an emulator).
- Whether the vcpkg port should drop `supports` and claim Windows (owner decision, needs a Windows build first).
