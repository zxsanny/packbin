---
title: "A packer writes the canonical quiet NaN itself; a NaN is not one bit pattern"
applies_when: "packing a float NaN, or trusting a bytes test that passed on the Mac"
source: "loop 99 (Dart ByteData.setFloat32)"
---

A NaN is not one bit pattern: `ByteData.setFloat32(nan)` wrote `7fc00000` on arm64 and `ffc00000` on x86 (loop 99): any packer writes the canonical quiet NaN itself, and a bytes test passing on the Mac says nothing about the x86 CI runner.
