---
title: "Before committing a change to a shape another script reads, git grep every reader and run each one"
applies_when: "changing an error kind, a suites matrix entry or a case list that other scripts or drivers read"
source: "loop 34 (missed report-row.test.sh), loop 39 (missed the Go, Swift and C++ ring drivers)"
---

Before committing a change to a shape another script reads (an error kind, a `suites` matrix entry, a case list), `git grep` every reader and run each one: loop 34 missed `report-row.test.sh` and loop 39 missed the Go, Swift and C++ ring drivers that map `TooLong` to `too_long` (both found by step 11, not before the commit).
