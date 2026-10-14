# Batch 9 report — loop 26

Task: AZ-2523 (Swift release: ADR-005, golden gate and the consumer resolve check, 5 points; stream B, publish scripts). No per-batch review (owner preference).

| Task | Status | Evidence |
|------|--------|----------|
| AZ-2523 | Done except the Docker/Linux stages | 5 of 5 ACs; `publish-swift.test.sh` passes (worker, about 7 minutes, including a REAL `swift package resolve` + `swift build` of a consumer pinned `.package(url: <local bare repo>, exact: "0.1.9")` at tag `v0.1.9`, re-run on the same commit passing, a moved tag failing at once with both commits named, bare-repo refs unchanged, no tag created); parent re-run: `publish-go.test.sh`, `ring-wiring.test.sh`, `ring-wiring-swift.test.sh`, `run-suite.test.sh` pass; 28 mutation proofs (27 in-test + 1); the full `publish-gate.test.sh`, the read-only/Docker stages and any Linux run are the step 11 stage. |

CI-parity: as batch 2; the publish workflow text is checked by tests only (`publish.yml` unchanged: the check runs inside the existing registries step, as `go-tag` does). No tag was created, moved or pushed; the three tags in the clone (`v0.1.9`, `v0.2.1`, `v0.2.2`) are older.

## Network

The real consumer resolve fetched swift-crypto 3.12.5 and swift-asn1 from github.com through SwiftPM (owner decision S-2). A consumer resolves swift-asn1 1.7.3 (it ignores a dependency's `Package.resolved`), not the root's 1.3.2: a consumer on Swift 5.9 relies on SwiftPM skipping versions its tools version cannot read (the `swift-min` CI step covers the root, not a consumer).

## Discovered during implementation

| # | Finding | Handling | clear/unclear |
|---|---------|----------|---------------|
| 1 | the check uses the runner's Swift, unpinned (as Go's host `go`) | note | clear |
| 2 | SwiftPM names a path dependency after its directory: with the root at `/src` the driver package failed (`unknown package 'packbin'`); `publish-position.sh` builds a copy in a directory named `packbin` | fixed in the script; the Linux container run is unproven | clear |
| 3 | a pin at the wrong commit or version fails at once (like Go's moved tag); only resolve/build failures retry (30 min window) | as designed | clear |
| 4 | `publish.yml` `timeout-minutes: 60` could be exceeded in the worst case (Go proxy window 30 min + Swift window 30 min + uploads) | loop 27 handoff: raise or shorten the windows | unclear |
| 5 | the full `publish-gate.test.sh` now includes the real-swift scenario (about 3.5 min on the Mac; compiles swift-crypto twice on Linux) and the mutation block (about 3 min); the scaffold job's 60-minute limit is tight | measured at step 11 / first CI run | unclear |
| 6 | a failed Swift check leaves the Go tag in place (the Swift check runs after `go-tag`, as ADR-004's tag-before-proxy); the run still fails | as specified | clear |
| 7 | `publish-gate.test.sh` shrank to 492 lines; the new scenarios are in `publish-swift.test.sh` (347) and `publish-swift-gate.test.sh` (306) | done | clear |
