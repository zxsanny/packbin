# Loop 34 notes (AZ-2627)

## Priming run (run 39039632778, `b832403`, 20 jobs, all green)

Wall **267 s** (14:10:42 to 14:15:09). Every job started at +0 s (AC-2's slot rule held; loop 33: three jobs 26 to 88 s late per run). Every Swift cache missed (the keys were new) and was saved: AC-5's miss path is today's build plus the ccache set-up.

| Job | s | Swift steps (notice) |
|-----|--:|----------------------|
| `suites (swift, tests)` | 263 | resolve 4, debug build 103, test 37, list 2, fuzz 71; ccache 0 hits, 372 misses, ready in 6 s |
| `ring` | 221 | pull-gcc 41, pull-swift 37, swift-drivers 123 (ccache 0 hits, 372 misses, ready in 9 s); wait 108, 160 s since start |
| `suites (swift, gates)` | 207 | resolve 4, tsan build 108, list 3, sanitized 50; ccache 0 / 372, ready in 6 s |
| `embedded-esp-core` | 188 | |
| `publish-gate-rest` | 186 | |
| `publish-gate-readonly-gate-bad` | 185 | |
| `suites (swift, speed)` | 180 | resolve 4, speed 115; ccache 0 / 372, ready in 7 s |
| `suites (csharp rust)` | 144 | merged |
| `suites (cpp typescript java)` | 111 | merged |

Saved entries (caches API, no token): tests 91 MB, gates 97 MB, speed 88 MB, ring 150 MB: 425 MB in all (AC-7: at most 3 GB). The apt install of ccache took 6 to 9 s on the runners (24 to 26 s on the Mac).

## Measured run A (run 39040035812, `c870aa7`, 20 jobs, all green)

Wall **210 s** (AC-1 target at most 225 s). Every job started within 1 s of the first; no cache entry was saved (all four hits).

| Job | s | Swift build step |
|-----|--:|------------------|
| `embedded-esp-core` | 207 | |
| `publish-gate-rest` | 206 | |
| `publish-gate-readonly` | 206 | |
| `publish-gate-swift` | 186 | |
| `suites (swift, tests)` | 165 | debug build 17 s (loop 33 best 48) |
| `suites (swift, speed)` | 147 | `swift_speed` 103 s (131) |
| `ring` | 127 | `swift-drivers` 22 s (84) |
| `suites (swift, gates)` | 117 | sanitizer build 26 s (85) |

ccache was asked 0 times in all four builds (0 hits, 0 misses, 0 uncacheable): the restore kept every file's time to the nanosecond, so no BoringSSL file was recompiled. Check: a test package round-tripped with GNU tar's default format rebuilt 3 of 3 C files, with `tar --posix` 0 of 3. The owner removed ccache (batch 2). The wall is now the non-Swift floor: `embedded-esp-core`, `publish-gate-rest`, `publish-gate-readonly` (206 to 207 s).
