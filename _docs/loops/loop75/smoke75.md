# Loop 75 smoke — frame mode in C++, Go, Python and TypeScript

LOCAL_URL: none (library; no site). Branch: dev at a671a02. Script: `bash _docs/loops/loop75/smoke75.sh`. Run by the agent on 2026-10-27 at host load about 10, under the owner rule of 2026-10-12: one paste script, with the agent auto-passing the gate when every step passes. The Mac was held awake.

## Checks

- [x] 1. No application source is dirty
- [x] 2. TypeScript: 2,541 tests, 0 failed, strict `tsc` clean (frame 157 rows, crypto 27 rows, D1 names)
- [x] 3. Python: 3,894 passed (frame 157 rows, crypto 27 rows, D1 names)
- [x] 4. Go: `gofmt`, `go vet`, `go test -race` in `golang:1.27`
- [x] 5. C++ host suite on the Mac: 157 of 157 frame rows (5 of 5 one-digit copies caught), 27 of 27 crypto rows
- [x] 6. C++ arm and AVR rows: frame image 8,416 B flash / 912 B stack equal to the pins; older pins unchanged
- [x] 7. The 8 README frame examples equal their tests; no `Symbol.dispose` in the TypeScript declarations
- [x] 8. Fixtures and the contract's Frame mode and MAC-only sections equal their loop 74 close content
- [x] 9. Live docs and README describe frame mode in all eight packages
- [x] 10. No touched source file grew past 500 lines (the first full check found `go/frame_refusals_test.go` at 544; split in a671a02)

## Agent walk

10 PASS, 0 FAIL, 0 NOT RUN (`smoke75: 0 failed`, exit 0), on the first full run.

## For the operator

Nothing: every check ran in the script.
