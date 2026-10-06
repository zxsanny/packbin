#!/usr/bin/env bash
# CXX for the ring job: runs g++ from the gcc:$RING_GCC image, the compiler of the cpp suite
# (docker-compose.test.yml), because the runner has no GCC 16 release package. Arguments pass through
# unchanged. -static is added so the host can run what the image links: a Debian glibc binary does not
# always run on the runner's glibc.
#
# The container sees the repo, the working directory and /tmp at the same paths as the host, so every
# path language-pair.sh and publish-position.sh pass (-I, sources, -o /tmp/...) is valid inside it. It
# runs as the caller, so the files it writes belong to the runner user.
set -euo pipefail

image="gcc:${RING_GCC:?RING_GCC (the gcc image tag) is not set}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

mounts=(-v /tmp:/tmp)
dirs=("$root")
[ "$PWD" = "$root" ] || dirs+=("$PWD")
for dir in "${dirs[@]}"; do
  case "$dir" in
    /tmp | /tmp/*) ;;
    *) mounts+=(-v "$dir:$dir") ;;
  esac
done

exec docker run --rm -i --user "$(id -u):$(id -g)" "${mounts[@]}" -w "$PWD" "$image" g++ "$@" -static
