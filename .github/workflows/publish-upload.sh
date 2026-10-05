#!/usr/bin/env bash
# Upload phase. Transmits the files publish-build.sh built and checked; it builds nothing and
# refuses to start unless build.log holds `build ok` for every target given. Registry tools run
# on the host. Cargo is the one tool that archives again: `cargo publish --no-verify` re-archives
# the staged directory that the build phase already compiled and checked.
# Usage: publish-upload.sh <target>...
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=publish-lib.sh
source "$here/publish-lib.sh"

if [ "$#" -eq 0 ]; then
  echo "usage: publish-upload.sh <target>..." >&2
  exit 2
fi

version="${PACKBIN_VERSION:-0.1.0}"
version="${version#v}"
out="${PACKBIN_OUT:?PACKBIN_OUT is required}"
artifacts="$out/artifacts"
export PACKBIN_OUT="$out"

for target in "$@"; do
  if ! grep -qx "build ok $target" "$artifacts/build.log"; then
    echo "no build ok for $target; refusing to upload" >&2
    exit 1
  fi
done
if [ -e "$artifacts/dry-run" ]; then
  echo "artifacts come from a build-only run; refusing to upload" >&2
  exit 1
fi

# OIDC exchange for PyPI: prints a short-lived upload token.
pypi_oidc_token() {
  local oidc jwt body code token
  if [ -z "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:-}" ]; then
    echo "id-token permission is required" >&2
    exit 1
  fi
  oidc="$(curl -sS \
    -H "Authorization: bearer ${ACTIONS_ID_TOKEN_REQUEST_TOKEN}" \
    -H "User-Agent: packbin-publish" \
    "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=pypi")"
  jwt="$(printf '%s' "$oidc" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("value") or "")')"
  if [ -z "$jwt" ]; then
    echo "GitHub did not return an OIDC token" >&2
    exit 1
  fi
  body="$(mktemp)"
  code="$(curl -sS -o "$body" -w '%{http_code}' -X POST "https://pypi.org/_/oidc/mint-token" \
    -H "Content-Type: application/json" \
    -H "User-Agent: packbin-publish" \
    --data-binary "{\"token\":\"${jwt}\"}")"
  if [ "$code" -lt 200 ] || [ "$code" -ge 300 ]; then
    echo "PyPI token request failed: ${code}" >&2
    rm -f "$body"
    exit 1
  fi
  token="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("token") or "")' <"$body")"
  rm -f "$body"
  if [ -z "$token" ]; then
    echo "PyPI token response had no token" >&2
    exit 1
  fi
  printf '%s\n' "$token"
}

upload_npm() {
  local tarball="$artifacts/typescript/packbin-$version.tgz" npmrc
  if [ -z "${NPM_TOKEN:-}" ] && [ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
    npm publish "$tarball" --access public
    return
  fi
  npmrc="$(mktemp)"
  printf '//registry.npmjs.org/:_authToken=%s\n' "$NPM_TOKEN" > "$npmrc"
  npm publish "$tarball" --userconfig "$npmrc" --access public || {
    rm -f "$npmrc"
    return 1
  }
  rm -f "$npmrc"
}

upload_pypi() {
  local token="${PYPI_TOKEN:-}"
  if [ -z "$token" ]; then
    token="$(pypi_oidc_token)"
    echo "::add-mask::${token}"
  fi
  twine upload --non-interactive -u __token__ -p "$token" "$artifacts/python"/*
}

upload_maven() {
  local id state attempt
  id="$(curl --fail --silent --show-error \
    -H "Authorization: Bearer ${MAVEN_CENTRAL_TOKEN}" \
    -F "bundle=@${artifacts}/java/maven-bundle.zip" \
    "https://central.sonatype.com/api/v1/publisher/upload?publishingType=AUTOMATIC")"
  id="$(printf '%s' "$id" | tr -d '[:space:]')"
  for attempt in $(seq 1 90); do
    state="$(curl --fail --silent --show-error -X POST \
      -H "Authorization: Bearer ${MAVEN_CENTRAL_TOKEN}" \
      "https://central.sonatype.com/api/v1/publisher/status?id=${id}")"
    printf '%s\n' "$state"
    case "$state" in
      *'"deploymentState":"PUBLISHED"'*) return 0 ;;
      *'"deploymentState":"FAILED"'*) return 1 ;;
    esac
    sleep 15
  done
  echo "maven central deployment did not finish" >&2
  return 1
}

# Tools that are not on the runner come from pip, before the first byte leaves.
prepare_tools() {
  local target
  for target in "$@"; do
    case "$target" in
      python) ensure_tool twine twine ;;
      platformio) ensure_tool pio platformio ;;
      esp-idf) ensure_tool compote idf-component-manager ;;
    esac
  done
}

prepare_tools "$@"

for target in "$@"; do
  echo "upload $target"
  case "$target" in
    csharp)
      dotnet nuget push "$artifacts/csharp/Packbin.$version.nupkg" \
        --api-key "$NUGET_TOKEN" \
        --source https://api.nuget.org/v3/index.json \
        --skip-duplicate
      ;;
    typescript) upload_npm ;;
    python) upload_pypi ;;
    rust)
      cargo publish --no-verify --allow-dirty --token "$CARGO_REGISTRY_TOKEN" \
        --manifest-path "$artifacts/rust/stage/Cargo.toml"
      ;;
    java) upload_maven ;;
    vcpkg) push_branch "$artifacts/vcpkg/reg" "$(vcpkg_url)" vcpkg ;;
    platformio)
      pio pkg publish "$artifacts/platformio/packbin-$version.tar.gz" --type library --no-interactive
      ;;
    esp-idf)
      compote component upload --archive "$artifacts/esp-idf/packbin_$version.tgz" \
        --namespace zxsanny --name packbin
      ;;
    arduino) push_branch "$artifacts/arduino/reg" "$(arduino_url)" arduino "arduino-$version" ;;
    *)
      echo "unknown target: $target" >&2
      exit 1
      ;;
  esac
done
