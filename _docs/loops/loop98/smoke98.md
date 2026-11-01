# Loop 98 smoke - proposed checks

LOCAL_URL: none (library; no UI, no local deploy)
Branch: dev (batch commit 279ef54; close commit pending)

## Perform these checks (terminal and editor)

- [ ] AZ-3524 AC-1: open `swift/Sources/Packbin/Packbin.docc/Packbin.md`, section "A percentage instead of a count": it names `withLimits(parityPercent:)` and `parityPercent`, gives `n = min(32, ceil(p x L / 100))`, and 251 / 230 / 222.
- [ ] AZ-3524 AC-2: `go doc` on the Go package (or open `go/doc.go` near line 203) shows `WithParityPercent`, `ParityPercent`, `MaxParityPercent`.
- [ ] AZ-3524 AC-3: README ecc table, Go and Swift rows: the 254-byte error is `TooLong` / `.tooLong`.
- [ ] AZ-3525 AC-1, AC-2: `docker compose -f docker-compose.test.yml run --rm cpp-embedded` ends `embedded stage arm: 0 target(s) failed`; the M3 and M33F lines say `vectors run 340 asserted 340` and `percentage packets printed: 12`.
- [ ] AZ-3526 AC-1, AC-4: `docker compose -f docker-compose.test.yml run --rm rust-embedded` ends `rust embedded stage: 0 target(s) failed`; the ecc line reads `flash=19996 B (limit 19996) stack=664 B (limit 664)` and `EXTRA_RESULT 0`.
- [ ] Regression: `make -C cpp test` ends `all tests passed`.

## Notes

- Not run on this host: Go, C#, Java and Swift suites, the ring, AC-10, the publish gate, a DocC build, `go vet` (no network for `x/crypto`). The ESP stage and the CI publish gate for `codec_ecc.hpp` run on the push.
- The ecc pin moved to 19,996 B / 664 B with your yes; see `_docs/AGENT_GOTCHAS.md`.
- The `rust/tests` files were touched (mtime only, no content change) to rebuild stale host-built test binaries that had the host path compiled in.
