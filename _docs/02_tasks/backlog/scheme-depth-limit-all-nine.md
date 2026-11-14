---
kind: queue-item
order: 500
source: loop 125 findings `_docs/06_metrics/scheme-depth-probe_2026-11-14.md` (AZ-4291); queue item `dart-deep-when-chain-stack-overflow`
origin: agent
severity: medium
depends_on: []
status: blocked
blocked_on: OPERATOR_TODO D18 (which limit, or iterative walks, or nothing)
created: 2026-11-14
---
# A deep scheme is refused with the package's own error in all nine packages

## Problem
No package limits how deep a scheme may nest. Loop 125 measured that TypeScript, Python, Dart and Java throw a raw language stack error (Python from about 450 levels, TypeScript from about 1,500), C#, C++, Rust (map API) and Swift crash the process at 50,000, Go and Swift do not finish a 5,000-deep chain of groups in 60 s, and Java unpack overflows at 5,000 `when`s.

## Outcome
Per D18: with option A, every package refuses a scheme nested deeper than one shared limit when it is built, with its scheme error and one shared text, and the probe of loop 125 shows no raw error, crash or hang at the three depths; with option B, the walks are iterative.

## Code sections
The recursive walks named in the findings: `python/src/packbin/_validate.py`, `typescript/src/fields.ts`, `dart/lib/src/build.dart` and `checks.dart`, `csharp/SchemeOrder.cs`, `cpp/include/packbin/order.hpp`, `go/places.go`, Rust `MapScheme::new`, Swift `Scheme.init`, the Java scheme build and unpack; the shared hostile cases under `fixtures/`.

## Acceptance checks
- `scripts/probes/scheme-depth/run.sh` prints `refused` (or `built` below the limit) on every line, with no `threw`, `crashed` or timeout.
- One shared hostile case for the limit, accepted by all nine as `scheme_error`.

## Needs
D18 answered.

## Constraints
No packet bytes change; a scheme at or under the limit builds as before.
