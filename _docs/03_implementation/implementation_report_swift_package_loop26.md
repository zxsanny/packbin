# Implementation report — Swift package (loop 26, epic AZ-2223)

12 tasks, 47 points, 10 batches (`batch_01..10_loop26_report.md`), all committed on `dev` and In Testing in Jira (AZ-2513 to AZ-2524). `swift/` holds the library (`Packbin`, 25 source files) and 335 tests in 55 suites; the repository root holds `Package.swift` and `Package.resolved` (swift-crypto 3.12.5, swift-asn1 1.3.2 pinned).

Owner rulings applied (2026-10-14): group in a map row nested both ways (Go-4 A), NFC/NFD dict keys refused, Foundation NSNumber Bool/integer refused, `swift:5.9` compile step (`swift-min`), Go added to the pack-session Consumers line. Open owner decisions: O1, O2 (`batch_08_loop26_report.md`), F44 (tag ruleset), the first tags.

Differences from TypeScript: `_docs/02_task_plans/swift-package/parity_differences.md`.

Not proven on this Mac (first CI run): the `swift:6` and `swift:5.9` containers, the Linux swift-crypto path, the thread sanitizer under Docker, the Go-Swift ring hand-offs, the full publish gate.
