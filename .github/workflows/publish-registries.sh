#!/usr/bin/env bash
# Publish entry point: plans the targets from the declared table in publish-lib.sh (a required target
# without its credential stops the run before any write, an optional one is skipped with a warning),
# builds and checks every one (publish-build.sh), and only then uploads what is not yet published
# (publish-upload.sh). Re-running a tag finishes whatever an earlier run left out.
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

require_tool() {
  if ! command -v "$1" >/dev/null; then
    echo "$1 is required before any registry write" >&2
    exit 1
  fi
}

# An optional target without its credential is skipped, visibly: a GitHub annotation and a line in the job summary.
skip_optional() {
  local message="skipping optional target $1: $2 is not set"
  echo "::warning::$message"
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    printf -- '- %s\n' "$message" >> "$GITHUB_STEP_SUMMARY"
  fi
}

# Plans the targets of every language in the plan. A build-only run plans them all. Otherwise a required
# target without its credential stops the run, all of them named, before anything is built or written.
targets=()
refused=()
for lang in "${PACKBIN_LANGS[@]}"; do
  if ! grep -qx "$lang" "$plan"; then
    continue
  fi
  for target in $(targets_of_lang "$lang"); do
    lacking=""
    if [ "$build_only" != "1" ]; then
      lacking="$(missing_credentials "$target")"
    fi
    if [ -z "$lacking" ]; then
      targets+=("$target")
    elif [ "$(target_tier "$target")" = "required" ]; then
      refused+=("$target is required and lacks: $lacking")
    else
      skip_optional "$target" "$lacking"
    fi
  done
done

if [ "${#refused[@]}" -gt 0 ]; then
  printf '%s\n' "${refused[@]}" >&2
  echo "${#refused[@]} required target(s) lack a credential; nothing was built or written" >&2
  exit 1
fi

if [ "${#targets[@]}" -eq 0 ]; then
  echo "publishing 0 packages"
  exit 0
fi

if [ "$build_only" != "1" ]; then
  require_tool curl
  require_tool python3
  for target in "${targets[@]}"; do
    case "$target" in
      csharp) require_tool dotnet ;;
      typescript) require_tool npm ;;
      rust) require_tool cargo ;;
      java) require_tool gpg ;;
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
