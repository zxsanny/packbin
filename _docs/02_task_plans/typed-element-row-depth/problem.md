---
loop: 128
branch: dev
---

# Loop 128 — A typed list or dict of rows counts two levels in C# (D20)

Intake: the owner's answer to D20 on 2026-11-14 ("Yes, two levels"), hygiene entry 2 of loop 126/127. C# counted the element-row group of a typed `list(row)` as 0 levels, so a typed list of rows was one level while the map form `list(group(...))`, Java, Go, TypeScript, Python, Dart, Swift and C++ count two. After this loop it is two in every form: `SchemeOrder.LevelsOf` counts every group, the 256-level typed list and dict tests use 128 typed levels, a D20 test pins 128 builds and 129 is refused, and `scheme-depth.md` 1.0.3 states the rule. Not in this loop: the other eight packages (unchanged), the wire format.
