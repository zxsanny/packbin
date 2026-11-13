---
title: "Go is not installed on this Mac: run it only in golang:1.27"
applies_when: "running Go format, vet or tests, writing a test-script regex on go test output, or building the Go ring driver"
source: "loop 24 (Go package; the bullet names no loop, taken from git history)"
---

Go is not installed on this Mac: run it only in `golang:1.27`, about 30 s; the two named volumes keep the module and build caches:

```
docker run --rm -v "$PWD":/src -v packbin-gomod:/go/pkg/mod -v packbin-gocache:/root/.cache/go-build -w /src/go golang:1.27 sh -c 'gofmt -l . && go vet ./... && go test -race -count=1 ./...'
```

- A test-script regex on `go test` output must allow a tab (`ok<TAB>pkg`).
- The 1 s AC-10 bound is asserted without `-race` only.
- The ring builds the Go driver for the host with `ring-go.sh` (cross-compiled in the container).

This cached-volume run is not the compose `go` stage: see [go-stage-needs-network.md](go-stage-needs-network.md).
