---
title: "While a v* tag publish runs, never ask proxy.golang.org about go/vX.Y.Z yourself"
applies_when: "watching a v* tag publish run"
source: "v0.4.0 publish, 2026-10-31"
---

While a `v*` tag publish runs, never ask `proxy.golang.org` about `go/vX.Y.Z` yourself (v0.4.0, 2026-10-31): a request before the tag exists is cached as "not found", and the workflow's own check (try 57, about 29 minutes) was answered only then; watch the run and the registries (npm, PyPI, crates.io, NuGet, Maven) and read the Go result from the job log.
