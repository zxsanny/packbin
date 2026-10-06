#!/usr/bin/env bash
# Build phase. Builds every target given on the command line, checks each artifact with
# publish-check.py and records `build ok <target>` in $PACKBIN_OUT/artifacts/build.log.
# This script holds no upload or push command; publish-upload.sh runs only after it exits 0.
# Exit codes: 0 every target built and checked, 1 a build or a check failed, 2 usage.
# Usage: publish-build.sh <target>...   (csharp typescript python rust vcpkg platformio esp-idf arduino java)
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
  local lang="$1" rel
  if [ "${PACKBIN_DOCKER:-1}" = "0" ]; then
    bash "$here/publish-inside.sh" "$lang"
    return
  fi
  if [[ "$out" != "$root"/* ]]; then
    echo "PACKBIN_OUT must be inside $root when the build runs in containers" >&2
    return 1
  fi
  rel="${out#"$root"/}"
  docker compose -f "$root/docker-compose.test.yml" --project-directory "$root" \
    -p packbin-publish run -T --rm --no-deps \
    -e SRC_ROOT=/src \
    -e PACKBIN_VERSION="$version" \
    -e PACKBIN_OUT="/src/$rel" \
    "$lang" "exec /src/.github/workflows/publish-inside.sh $lang"
  chmod -R a+rwX "$artifacts/$lang"
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
    *)
      echo "unknown target: $target" >&2
      exit 1
      ;;
  esac
  python3 "$here/publish-check.py" "$target" "$artifacts/$target" "$version"
  printf 'build ok %s\n' "$target" | tee -a "$artifacts/build.log"
done
