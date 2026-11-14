#!/usr/bin/env bash
# Go probe of AZ-4291 (scheme depth; see main.go). Builds a copy of this module in a temporary directory against
# the go/ package of this checkout; nothing is written into the repository. It uses the go on PATH when there is
# one, else one Docker container (image and cache volumes of the project, docker-compose.test.yml) that builds the
# program and runs every case in it. Each shape and depth runs in its own process through ../case.sh with a 60 s
# limit, so Go's fatal stack overflow or a hang is one line. A Go program ignores SIGALRM, the signal case.sh's
# limit uses, so the program runs under `timeout 55` as well: a hang is then `crashed: exit 124`.
# stdout: one line per case. stderr: build messages. Exit 0 when the probe ran, non-zero when the build failed.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../../.." && pwd)"

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

copy="$out/probe"
mkdir "$copy"
# The checksums of the package's own dependencies: the copy needs them and go adds nothing.
cp "$here/go.mod" "$here/main.go" "$root/go/go.sum" "$copy/"

# Run inside the build environment: build once, then one process per case.
cases='cd "$PROBE" && go build -o "$PROBE/depthprobe" . >&2 </dev/null || exit 1
for shape in when group; do
  for depth in 1000 5000 50000; do
    bash "$CASE" go "$shape-$depth" 60 timeout 55 "$PROBE/depthprobe" "$shape" "$depth"
  done
done'

if command -v go >/dev/null; then
  cd "$copy"
  go mod edit -replace "github.com/zxsanny/packbin/go=$root/go"
  GOFLAGS=-mod=mod CASE="$here/../case.sh" PROBE="$copy" bash -c "$cases" </dev/null
else
  docker run --rm \
    -v "$root":/src:ro \
    -v "$copy":/probe \
    -v "$here/..":/depth:ro \
    -v packbin-gomod:/go/pkg/mod \
    -v packbin-gocache:/root/.cache/go-build \
    -e GOFLAGS=-mod=mod \
    -e CASE=/depth/case.sh \
    -e PROBE=/probe \
    golang:1.27 bash -c "$cases" </dev/null
fi
