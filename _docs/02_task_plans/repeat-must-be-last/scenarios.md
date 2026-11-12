# Scenarios — repeat-must-be-last

Source of rows: `intake` (the handoff of AZ-4206, loop 112: the probe findings and the owner's decision). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | a scheme author puts a byte-writing field after a repeat at the top level | confirmed | the scheme is refused when it is built; the text names the repeat and the field and says to use `times` | AZ-4210 AC-1 (R1); AC-1 of AZ-4211 to AZ-4219 | intake |
| S2 | the field stands after a `when`, a `flags`, a group or a nested row that holds the repeat | confirmed | refused the same way | AZ-4210 AC-1 (R2 to R4); AC-1 of AZ-4211 to AZ-4219 | intake |
| S3 | a second repeat follows a repeat | confirmed | refused the same way | AZ-4210 AC-1 (R5); AC-1 of AZ-4211 to AZ-4219 | intake |
| S4 | the field after the repeat sits under a `when` that cannot be taken together with the repeat's `when` | confirmed | refused all the same | AZ-4210 AC-1 (R6); AC-1 of AZ-4211 to AZ-4219 | intake |
| S5 | a repeat sits inside a list or dict element | confirmed | refused when the scheme is built; a package whose element cannot be a row keeps its refusal of the row | AZ-4210 AC-1 (R7, R8); AC-1 of AZ-4211 to AZ-4217; AZ-4218 AC-1; AZ-4219 AC-5 | intake |
| S6 | a repeat sits inside a `repeat` or `times` round (Java, C++) | confirmed | refused when the scheme is built; a `times` inside a round keeps building | AZ-4210 AC-1 (R9); AZ-4214 AC-5; AZ-4219 AC-5 | intake |
| S7 | the repeat is the last thing read | confirmed | builds; the packet is unchanged | AZ-4210 AC-2 (K1 to K3); AC-2 of AZ-4211 to AZ-4219 | intake |
| S8 | a field after the repeat cannot write a byte | confirmed | builds | contract K5; AC-2 of AZ-4211 to AZ-4219 | intake |
| S9 | a `times` is followed by fields or sits inside an element | confirmed | unchanged | AZ-4210 AC-2 (K4); AC-2 of AZ-4211 to AZ-4219 | intake |
| S10 | an existing packet, fixture, golden vector or ring handoff | confirmed | 0 bytes differ | AZ-4210 AC-3; AC-4 of AZ-4211 to AZ-4219 | intake |
| S11 | a package's own test or README example uses a refused scheme | confirmed | rewritten with `times` or turned into a test of the refusal; the README names the change for an upgrade | AZ-4210 AC-4; AC-4 of AZ-4211 to AZ-4219 | intake |
| S12 | the check runs on a device | confirmed | the embedded rows pass; a pin above the budget goes to the owner | AZ-4218 AC-5; AZ-4219 AC-6 | intake |

One scenario of the shared rule is owned by the shared task (the case in `fixtures/hostile/cases.txt` and the contract) and realised by the same criterion of every package task; the AC column names both.

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| 1 | schemes that read back only for some rows stop building | owner, 2026-11-12: refuse at build | yes |
| 2 | a pack-only sender loses the scheme | owner, 2026-11-12: accepted | yes |
| 3 | Java and C++ build a repeat inside a round today | agent default: refuse at build (the owner can overrule it) | yes (open, Low) |
| 4 | the check adds code on a device | agent default: pins follow the measurement inside 256 B of flash and 64 B of stack | yes |
| 5 | the shared cases and the nine loaders must land together | the shared task first, one total test run | yes |

## Not walked

- A reader of packets written by a scheme that no longer builds (an old sender in the field): out of the feature; the contract's Non-Goals say how such bytes are read (`times`, or by hand).
- Schemes outside this repository (Archangel uses the C# package): not measured; the owner checks them before the upgrade.
- The relaxation for two `when`s that cannot both be taken: offered to the owner and not taken; a later task if a real scheme needs it.
