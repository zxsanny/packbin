---
loop: 126
branch: dev
---

# Loop 126 — A scheme nested deeper than 256 levels is refused when it is built, in all nine packages

Loop 126 (on `dev`; no worktree). Intake: the owner's answer to D18 on 2026-11-14 ("Shared limit (256)"), the queue item `scheme-depth-limit-all-nine` (`queue_item.md` beside this file), findings in `_docs/06_metrics/scheme-depth-probe_2026-11-14.md`.

## What and why

No package limits how deep a scheme nests. At 1,000 to 50,000 levels TypeScript, Python, Dart and Java throw a raw language stack error, C#, C++, Rust and Swift crash the process, and Go and Swift (nested groups) and Rust's heap-free API (`when`) do not finish. The owner decided: one limit for all nine, 256 levels, refused when the scheme is built, with the package's own scheme error and one shared text.

After this loop a scheme whose nesting depth is above 256 cannot be built in any package: the build gives the package's scheme error (`scheme_error` in the shared hostile cases) and nothing is packed; a scheme at 256 builds, packs and unpacks as before with the same bytes. The probe of loop 125 (`scripts/probes/scheme-depth/run.sh`) prints no `threw`, `crashed` or timeout at depths 1,000, 5,000 and 50,000, and its 1,000-deep lines are `refused`.

Nesting depth = the number of container fields around a field on the path from the row to it, a container being a `when`, a `flags` (or flag bit), an anchored or unanchored group, a list or dict element row, a `repeat` or a `times` round body.

Not in this loop: packet value depth, scheme width, the wire format, and Rust's own `MAX_FIELDS` (32,768) which stays.

## Code sections

The scheme build of each package (named in the loop 125 findings): `python/src/packbin/_validate.py` and `_scheme.py`, `typescript/src/fields.ts` and `index.ts`, `dart/lib/src/build.dart` and `checks.dart`, `csharp/SchemeOrder.cs`, `cpp/include/packbin/order.hpp`, `go/places.go` and `scheme.go`, Rust `MapScheme::new` and `rust/src/nostd/check.rs`, `swift/Sources/Packbin/Scheme.swift`, the Java scheme build. Shared: `fixtures/hostile/cases.txt` and `README.md`, the root `README.md`, `_docs/02_document/contracts/library/` (new `scheme-depth.md`).

## Flagged concerns

| concern | policy / owner | status | severity |
|---------|----------------|--------|----------|
| Python stops between 400 and 500 levels for `when` / group chains; a container that costs more frames per level (a list element row, a round) may stop below 256 | each package task proves 256 levels of every container kind build, pack and unpack at the default stack; a package that cannot is reported and the limit is not lowered silently | open | Medium |
| A scheme deeper than 256 that built before (a probe, never a real one: the deepest known use is a handful of levels) stops building | owner, 2026-11-14 | accepted-risk | Low |
