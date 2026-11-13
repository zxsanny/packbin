---
title: "Commit the auditor's fuzz corpora and drivers under fixtures/hostile/fuzz/, never leave them in a scratchpad"
applies_when: "auditing or changing unpack, and building fuzz corpora, per-language drivers or amplification probes"
source: "loop 11 (recommended, ignored), repeated in loop 13"
---

The auditor's fuzz corpora, per-language drivers, `cmp.py` and amplification probes live in a session scratchpad. Commit them under `fixtures/hostile/fuzz/` or the next unpack-changing loop rebuilds them from an old temp dir (recommended in loop 11, ignored, repeated in loop 13).
