#!/usr/bin/env bash
# Publish entry point: plans the targets, builds and checks every one (publish-build.sh), and only
# then uploads the built files (publish-upload.sh).
# PACKBIN_BUILD_ONLY=1 runs the build phase alone as a dry run: it needs no credential, unsets every
# one it finds, signs the Maven bundle with a throwaway key, writes nothing to any registry and
# exits 0. It is for CI tests and dry runs, never a way to publish.
# Exit codes: 0 done (or nothing to publish), 1 refused, a build or check failed, or an upload failed.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=publish-lib.sh
source "$here/publish-lib.sh"

if [ "${PACKBIN_PUBLISH:-}" != "1" ]; then
  echo "publish refused" >&2
  exit 1
fi

root="$(publish_root)"
version="${PACKBIN_VERSION:-0.1.0}"
version="${version#v}"
plan="${PACKBIN_PLAN:-$root/.github/workflows/out/publish-plan.txt}"
out="${PACKBIN_OUT:-$root/.github/workflows/out}"
build_only="${PACKBIN_BUILD_ONLY:-}"
mkdir -p "$out"
export SRC_ROOT="$root" PACKBIN_VERSION="$version" PACKBIN_OUT="$out"

if [ ! -s "$plan" ]; then
  echo "publishing 0 packages"
  exit 0
fi

if [ "$build_only" = "1" ]; then
  for var in "${PACKBIN_CREDENTIALS[@]}"; do
    unset "$var"
  done
fi

need() {
  local lang="$1" var="$2"
  if grep -qx "$lang" "$plan" && [ -z "${!var:-}" ]; then
    echo "$var is required before any registry write" >&2
    exit 1
  fi
}

require_tool() {
  if ! command -v "$1" >/dev/null; then
    echo "$1 is required before any registry write" >&2
    exit 1
  fi
}

# True when the target's credential is set, or in a build-only run, which plans every target.
credentialed() {
  [ "$build_only" = "1" ] || [ -n "${!1:-}" ]
}

if [ "$build_only" != "1" ]; then
  need csharp NUGET_TOKEN
  if grep -qx typescript "$plan" && [ -z "${NPM_TOKEN:-}" ] && [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
    echo "NPM_TOKEN is required before any registry write" >&2
    exit 1
  fi
  need java MAVEN_CENTRAL_TOKEN
  need java MAVEN_GPG_PRIVATE_KEY
fi

targets=()
for lang in "${PACKBIN_LANGS[@]}"; do
  if ! grep -qx "$lang" "$plan"; then
    continue
  fi
  case "$lang" in
    python)
      if credentialed PYPI_TOKEN || [ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
        targets+=(python)
      else
        echo "skip python"
      fi
      ;;
    rust)
      if credentialed CARGO_REGISTRY_TOKEN; then
        targets+=(rust)
      else
        echo "skip rust"
      fi
      ;;
    cpp)
      targets+=(vcpkg)
      if credentialed PLATFORMIO_AUTH_TOKEN; then
        targets+=(platformio)
      else
        echo "skip platformio"
      fi
      if credentialed IDF_COMPONENT_API_TOKEN; then
        targets+=(esp-idf)
      else
        echo "skip esp-idf component"
      fi
      if credentialed GITHUB_TOKEN || [ -n "${ARDUINO_REGISTRY_URL:-}" ]; then
        targets+=(arduino)
      else
        echo "skip arduino"
      fi
      ;;
    *) targets+=("$lang") ;;
  esac
done

if [ "${#targets[@]}" -eq 0 ]; then
  echo "publishing 0 packages"
  exit 0
fi

if [ "$build_only" != "1" ]; then
  for target in "${targets[@]}"; do
    case "$target" in
      csharp) require_tool dotnet ;;
      typescript) require_tool npm ;;
      python | platformio | esp-idf) require_tool python3 ;;
      rust) require_tool cargo ;;
      java) require_tool curl; require_tool gpg ;;
      vcpkg | arduino) require_tool git ;;
    esac
  done
fi

# The build sees no registry token. Only the signing key, which a real publish needs, passes through.
(
  for var in "${PACKBIN_CREDENTIALS[@]}"; do
    if [ "$var" != "MAVEN_GPG_PRIVATE_KEY" ]; then
      unset "$var"
    fi
  done
  exec bash "$here/publish-build.sh" "${targets[@]}"
)

if [ "$build_only" = "1" ]; then
  : > "$out/artifacts/dry-run"
  echo "build only: ${#targets[@]} target(s) built and checked, nothing uploaded"
  exit 0
fi

bash "$here/publish-upload.sh" "${targets[@]}"
