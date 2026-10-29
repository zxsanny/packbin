# Scenarios - loop 83 (ring and driver tidy)

Proposed behaviors, all `confirmed` (silent proceed). Source: new-task Step 4.7.

| # | Task | Axis | Actor / trigger / state | Behavior | AC |
|---|------|------|-------------------------|----------|----|
| 1 | AZ-3387 | existing-feature overlap | `PACKBIN_CPP_HANDOFF` set to a path | compiled on every call as before | AZ-3387 AC-4 |
| 2 | AZ-3387 | partial failure | one of the new sources fails to compile | `run_lang cpp` returns non-zero, no stale binary runs | AZ-3387 AC-4 |
| 3 | AZ-3387 | invalid input | a malformed frame/ECC line | exit and message as at HEAD | AZ-3387 AC-3 |
| 4 | AZ-3388 | invalid input | unreadable workflow YAML | exit 2, same message | AZ-3388 AC-3 |
| 5 | AZ-3388 | boundaries | checker run by `python3 -I` from another directory | module found | AZ-3388 AC-4 |
| 6 | AZ-3388 | partial failure | a helper edited wrongly | a wiring test fails | AZ-3388 AC-5 |
| 7 | AZ-3389 | first use | key33 + `ad256` | `BadValue` in the 6 byte-string packages | AZ-3389 AC-3 |
| 8 | AZ-3389 | boundaries | id7 + `outshort` | `BadValue` | AZ-3389 AC-3 |
| 9 | AZ-3389 | existing-feature overlap | Rust/C++ drivers given a wrong-length value | print `BadValue` by construction, said in the README | AZ-3389 AC-3 |
| 10 | AZ-3389 | partial failure | a package answers `TooLong` first | ring fails; reported, row kept | AZ-3389 AC-6 |
| 11 | all | concurrent | three workers in one tree | disjoint paths; no git write by workers | plan |
