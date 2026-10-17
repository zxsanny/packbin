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
