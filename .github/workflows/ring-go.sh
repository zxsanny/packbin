#!/usr/bin/env bash
# Builds a Go driver of the ring: ring-go.sh <output binary> [package, default "." = the handoff driver;
# "./position" = the position program], both in .github/workflows/drivers/handoff-go.
#
# It rebuilds only when a non-test Go source, go.mod or go.sum of the package (go/) or the driver module is
# newer than the binary, so language-pair.sh can call it before every driver command (as the java case does).
#
# With `go` on PATH (the ring job: setup-go, RING_GO) it builds with it. Without (the owner's Mac has no Go),
# it builds in the golang:$RING_GO image (default 1.27, the go suite image) for the host OS and architecture,
# so the binary runs on the host. The container sees the repo and the output directory at the host paths;
# the named volumes keep the module and build caches between runs.
set -euo pipefail

out="${1:?output binary}"
pkg="${2:-.}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
driver="$root/.github/workflows/drivers/handoff-go"

if [ -x "$out" ] && [ -z "$(find "$root/go" "$driver" \( -name '*.go' -o -name go.mod -o -name go.sum \) \
  ! -name '*_test.go' -newer "$out" -print -quit)" ]; then
  exit 0
fi

mkdir -p "$(dirname "$out")"
if command -v go > /dev/null; then
  CGO_ENABLED=0 go build -C "$driver" -o "$out" "$pkg"
  exit 0
fi

case "$(uname -s)" in
  Darwin) goos=darwin ;;
  Linux) goos=linux ;;
  *) echo "ring-go.sh: no go on PATH and no GOOS for $(uname -s)" >&2; exit 1 ;;
esac
case "$(uname -m)" in
  arm64 | aarch64) goarch=arm64 ;;
  x86_64 | amd64) goarch=amd64 ;;
  *) echo "ring-go.sh: no go on PATH and no GOARCH for $(uname -m)" >&2; exit 1 ;;
esac
outdir="$(cd "$(dirname "$out")" && pwd)"
mounts=(-v "$root:$root")
case "$outdir" in
  "$root" | "$root"/*) ;;
  *) mounts+=(-v "$outdir:$outdir") ;;
esac
docker run --rm -i "${mounts[@]}" -v packbin-gomod:/go/pkg/mod -v packbin-gocache:/root/.cache/go-build \
  -e CGO_ENABLED=0 -e GOOS="$goos" -e GOARCH="$goarch" -w "$driver" \
  "golang:${RING_GO:-1.27}" go build -o "$outdir/$(basename "$out")" "$pkg" < /dev/null
