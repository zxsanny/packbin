# Security Audit Report, loop 121 (hygiene: eight small fixes, AZ-4257 to AZ-4261)

**Date**: 2026-11-13
**Mode**: lite escalated by T1, T3, T4, T5 to the full audit, scoped to `git diff 4c1b51f..HEAD -- . ':(exclude)_docs'` and the areas below
**Verdict**: PASS (no Critical, High or Medium; 1 Low carried)

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 1 |

## Lite triggers answered
- **T1/T4** (CI files, tool pin): `tool-pins.txt` gains one line, `arduino-esp32==3.3.12`; `publish-pins.test.sh` gains the name in its allowed list. `cpp/embedded/examples.sh` reads the pin with `tool-pin.sh` and runs `arduino-cli core install "esp32:esp32@$pin"` from the same HTTPS index (`espressif.github.io/arduino-esp32/package_esp32_index.json`) it used before: no new origin, every variable quoted, the value comes from a repository file and not from input. Before, the newest core was installed on every cold run; the pin removes that exposure to an unannounced release. The installed version is read back and the row fails when it differs. **L1 (Low)**: `arduino-cli` checks no hash of the core beyond what the package index carries; same as before, not made worse. Remediation: none now; moving the pin is in `_docs/gotchas/arduino-esp32-core-pin.md`.
- **T3** size: 14 points, five packages; the library code that changed is small (below); the rest is tests, probes and scripts.
- **T5** F79: `SchemeOrder.java`, `RoundScopes.cs` and `counted.go` now memoize the first writer; the quadratic cost is gone (Java chain 0.12 s to 3 ms, C# 3.2 s to 5 ms, Go 1.8 s to 2 ms); F79 is closed.

## Phases
- Phase 1 dependency scan: no new package dependency; the Python venv of the worker used pytest 9.1.1, the pin of `tool-pin.sh`; the published manifests are unchanged.
- Phase 2 SAST of the library changes: Java `RowClassCheck.requireTopRow` makes one row with the row class's no-argument constructor, a private one too (`setAccessible(true)`), exactly as `BinaryPacker.newRow` already does at unpack; the class is the application's own row type, named in its own scheme (schemes are code: README "Untrusted input"), so no wire input reaches it; a constructor that throws builds as before (caught `ReflectiveOperationException | RuntimeException`, documented, not an empty catch). Java `Walker.storeContainer` (loop 120) and `RowClassCheck.call` rethrow every cast failure that is not the one about the row. Python `refuse_missing` and `_pack_element` raise `TypeError` before an accessor runs on `None`. The three memoized walks keep a per-build map of the scheme's own nodes (no shared or static state). C++ changes are test code and a macro: `load_factor::kSanitized` and a Makefile target; no `unsafe`, cast or allocation in the library.
- Phase 3 OWASP Top 10 (2025 list as the loop 118 report uses it, not re-fetched): A01, A04, A07 N/A. A02 PASS (no header, port or config of a service). A03 PASS (the pin lowers supply-chain exposure; L1). A05 PASS (no input reaches a query, command or markup; the shell pin is quoted). A06 PASS (the quadratic scheme build is removed). A08 PASS. A09 PASS (no log of a value; refusal texts name a member kind or id). A10 N/A.
- Phase 4 infrastructure: no Dockerfile, compose or workflow YAML changed; the two CI shell files are the pin file and its allowed-name list.

## Recommendations
None. Carried from loop 113: F80 (the ECC test, closed in loop 114).
