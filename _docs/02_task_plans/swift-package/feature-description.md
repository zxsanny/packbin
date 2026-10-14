# Feature: Swift package (AZ-2223, loop 26)

An eighth language package, `swift/` (library target `Packbin`, manifest `Package.swift` at the repository root), hand-written in Swift (ADR-001: no shared walker, no generator, no wrapper of the C++ core). It packs and unpacks the same bytes as the seven packages for every feature they share (wire format, schemes and dispatch, strings/lists/dicts, rounds and limits, hostile vectors, `PackSession`), takes rows as typed structs bound by getter/setter closures or as `[String: Any]`, throws a typed error and never traps on hostile input. Swift joins the CI suite (`swift:6`), the language-pair ring (every kind, both ways), the golden gate of the publish, and installs through Swift Package Manager from the existing `vX.Y.Z` tag. Problem, decisions S-1 to S-5, ACs SW-1 to SW-16: `problem.md`, `acceptance_criteria.md` in this folder.

## Scenarios

See `scenarios.md` (S1 to S12, all `confirmed`; AC refs SW-1 to SW-16).
