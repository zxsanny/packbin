#!/usr/bin/env bash
# Go probe of AZ-4206 (see ../README.md). Builds a copy of this module in a temporary directory against
# the go/ package of this checkout and runs it; nothing is written into the repository. It uses the go
# on PATH when there is one, else Docker with the image and the two cache volumes of the project
# (docker-compose.test.yml).
# stdout: the probe lines. stderr: every build message.
# Exit 0 when the probe ran (whatever it found), non-zero when the build or the run failed.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../../.." && pwd)"

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

copy="$out/probe"
mkdir "$copy"
# The checksums of the package's own dependencies: the copy needs them and go adds nothing.
cp "$here/go.mod" "$here/main.go" "$root/go/go.sum" "$copy/"

if command -v go >/dev/null; then
  cd "$copy"
  go mod edit -replace "github.com/zxsanny/packbin/go=$root/go"
  GOFLAGS=-mod=mod go run . </dev/null
else
  docker run --rm \
    -v "$root":/src:ro \
    -v "$copy":/probe \
    -v packbin-gomod:/go/pkg/mod \
    -v packbin-gocache:/root/.cache/go-build \
    -w /probe \
    -e GOFLAGS=-mod=mod \
    golang:1.27 go run . </dev/null
fi
