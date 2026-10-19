#!/bin/sh
# packbin hostile-input probe, Go (AZ-2666, loop 41): compact text decoder and message ECC unpack.
#
# Usage: sh run.sh <packbin checkout> <work dir> <command> [args...]
#   <packbin checkout>  a checkout (or `git archive HEAD go fixtures` copy) holding go/ and fixtures/; read only
#   <work dir>          an empty directory outside the checkout; the probe module is assembled there
#   <command>           random <seed> <calls> | ecctime <calls> | textamp <one|list1m|list8m|controls|short>
#                       | edges | allocs | fuzz <FuzzTextLone|FuzzTextList|FuzzEccRepair|FuzzSession> <seconds>
# The probe module requires github.com/zxsanny/packbin/go and replaces it with <checkout>/go at run time.
# Go is not needed on the host; on a Mac without Go run it in the CI image, the checkout read-only:
#   docker run --rm -m 2g -v <checkout>:/src:ro -v <this dir>:/probe:ro -v <work dir>:/work \
#     -v packbin-gomod:/go/pkg/mod -v packbin-gocache:/root/.cache/go-build -w /work golang:1.27 \
#     sh /probe/run.sh /src /work edges
# Each command prints its figures, CPU seconds and peak RSS (VmHWM), and exits 1 when an invariant breaks.
set -eu
[ $# -ge 3 ] || { echo "usage: sh run.sh <checkout> <work dir> <command> [args]" >&2; exit 2; }
checkout=$(cd "$1" && pwd)
work=$2
shift 2
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$work/mod"
cp "$here"/*.go "$work/mod/"
cp "$checkout/go/go.sum" "$work/mod/go.sum"
cat > "$work/mod/go.mod" <<EOF
module packbinprobe

go 1.26.0

require github.com/zxsanny/packbin/go v0.0.0

replace github.com/zxsanny/packbin/go => $checkout/go
EOF
cd "$work/mod"
export GOTOOLCHAIN=local GOFLAGS=-mod=mod PACKBIN_CHECKOUT="$checkout"
go mod tidy </dev/null >/dev/null 2>&1 || go mod tidy </dev/null
if [ "$1" = fuzz ]; then
  target=$2
  seconds=$3
  # The fuzz corpus and the instrumented build stay in the work dir, not in a shared cache volume.
  export GOCACHE="$work/gocache"
  exec go test -run '^$' -fuzz "^${target}\$" -fuzztime "${seconds}s" -parallel "${FUZZ_PARALLEL:-4}" -v . </dev/null
fi
go build -o "$work/probe" . </dev/null
exec "$work/probe" "$checkout" "$@" </dev/null
