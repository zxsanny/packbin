#!/usr/bin/env bash
# Build phase. Builds every target given on the command line, checks each artifact with
# publish-check.py and records `build ok <target>` in $PACKBIN_OUT/artifacts/build.log.
# This script holds no upload or push command; publish-upload.sh runs only after it exits 0.
# Exit codes: 0 every target built and checked, 1 a build or a check failed, 2 usage.
# Usage: publish-build.sh <target>...   (csharp typescript python rust vcpkg platformio esp-idf arduino java go-tag)
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=publish-lib.sh
source "$here/publish-lib.sh"

if [ "$#" -eq 0 ]; then
  echo "usage: publish-build.sh <target>..." >&2
  exit 2
fi

root="$(publish_root)"
version="${PACKBIN_VERSION:-0.1.0}"
version="${version#v}"
out="${PACKBIN_OUT:?PACKBIN_OUT is required}"
artifacts="$out/artifacts"
export SRC_ROOT="$root" PACKBIN_VERSION="$version" PACKBIN_OUT="$out"

current=""
trap 'code=$?; if [ "$code" -ne 0 ]; then echo "build failed: ${current:-setup}" >&2; fi' EXIT

rm -rf "$artifacts"
mkdir -p "$artifacts"
: > "$artifacts/build.log"
# A build-only run marks its artifacts before building, so even a failed run can never be uploaded.
if [ "${PACKBIN_BUILD_ONLY:-}" = "1" ]; then
  : > "$artifacts/dry-run"
fi

# Language packages build in their toolchain image; the artifact lands in $artifacts/<lang>.
run_inside() {
  local lang="$1" mount
  if [ "${PACKBIN_DOCKER:-1}" = "0" ]; then
    bash "$here/publish-inside.sh" "$lang"
    return
  fi
  # The repo is read-only in the container; its own artifacts folder is the one writable host path.
  # The host made it (mkdir below), so Docker does not create it as root.
  mount="$(cd "$artifacts/$lang" && pwd)"
  publish_container \
    -v "$mount:/out/artifacts/$lang" \
    -e SRC_ROOT=/src \
    -e PACKBIN_VERSION="$version" \
    -e PACKBIN_OUT=/out \
    -e PACKBIN_HOST_UID="$(id -u)" \
    -e PACKBIN_HOST_GID="$(id -g)" \
    "$lang" "exec /src/.github/workflows/publish-inside.sh $lang"
}

# The Go module has no archive: its release is the tag go/v<version> at the commit of the checkout (ADR-004).
# This records what the upload phase will tag, so publish-check.py can check it before any write: the
# tag line, the module file and the license. It stops when the checkout is not a git work tree, or
# when the tag v<version> exists locally at another commit than HEAD.
prepare_go_tag() {
  local dest="$1" commit tagged
  if [ ! -e "$root/.git" ]; then
    echo "go-tag needs a git checkout of the tag: $root has no .git" >&2
    return 1
  fi
  commit="$(git -C "$root" rev-parse --verify "HEAD^{commit}")"
  if tagged="$(git -C "$root" rev-parse --verify --quiet "refs/tags/v$version^{commit}")" && [ "$tagged" != "$commit" ]; then
    echo "tag v$version is at $tagged, but the checkout is at $commit" >&2
    return 1
  fi
  printf 'go/v%s %s\n' "$version" "$commit" > "$dest/tag.txt"
  cp "$root/go/go.mod" "$dest/go.mod"
  cp "$root/go/LICENSE" "$dest/LICENSE"
}

for target in "$@"; do
  current="$target"
  mkdir -p "$artifacts/$target"
  case "$target" in
    csharp|typescript|python|rust)
      run_inside "$target"
      ;;
    java)
      run_inside java
      bash "$here/publish-sign.sh" "$artifacts/java"
      ;;
    vcpkg|platformio|esp-idf|arduino)
      bash "$here/publish-embedded.sh" "$target"
      ;;
    go-tag)
      prepare_go_tag "$artifacts/go-tag"
      ;;
    *)
      echo "unknown target: $target" >&2
      exit 1
      ;;
  esac
  python3 "$here/publish-check.py" "$target" "$artifacts/$target" "$version"
  printf 'build ok %s\n' "$target" | tee -a "$artifacts/build.log"
done
