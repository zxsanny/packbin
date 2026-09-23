#!/usr/bin/env bash
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
mkdir -p "$out"

if [ ! -s "$plan" ]; then
  echo "publishing 0 packages"
  exit 0
fi

need() {
  local lang="$1" var="$2"
  if grep -qx "$lang" "$plan" && [ -z "${!var:-}" ]; then
    echo "$var is required before any registry write" >&2
    exit 1
  fi
}

need csharp NUGET_TOKEN
if grep -qx typescript "$plan" && [ -z "${NPM_TOKEN:-}" ] && [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
  echo "NPM_TOKEN is required before any registry write" >&2
  exit 1
fi
need java MAVEN_CENTRAL_TOKEN

skip_unset() {
  local lang="$1" var="$2"
  if grep -qx "$lang" "$plan" && [ -z "${!var:-}" ]; then
    echo "skip $lang"
    grep -vx "$lang" "$plan" > "$plan.skip"
    mv "$plan.skip" "$plan"
  fi
}

skip_unset python PYPI_TOKEN
skip_unset rust CARGO_REGISTRY_TOKEN

run_inside() {
  local lang="$1"
  if [ "${PACKBIN_DOCKER:-1}" = "0" ]; then
    PACKBIN_VERSION="$version" PACKBIN_OUT="$out" SRC_ROOT="$root" \
      bash "$here/publish-inside.sh" "$lang"
    return
  fi
  docker compose -f "$root/docker-compose.test.yml" --project-directory "$root" \
    -p packbin-publish run -T --rm --no-deps \
    -e SRC_ROOT=/src \
    -e PACKBIN_VERSION="$version" \
    -e PACKBIN_OUT=/src/.github/workflows/out \
    -e NUGET_TOKEN \
    -e NPM_TOKEN \
    -e PYPI_TOKEN \
    -e CARGO_REGISTRY_TOKEN \
    "$lang" "exec /src/.github/workflows/publish-inside.sh $lang"
}

stage_vcpkg_port() {
  local reg="$1"
  mkdir -p "$reg/ports/packbin/include" "$reg/ports/packbin/src" "$reg/versions/p-"
  rm -rf "$reg/ports/packbin/include/packbin"
  cp -R "$root/cpp/include/packbin" "$reg/ports/packbin/include/packbin"
  cp "$root/cpp/src/"*.cpp "$reg/ports/packbin/src/"
  cat > "$reg/ports/packbin/vcpkg.json" <<EOF
{
  "name": "packbin",
  "version": "$version",
  "description": "Pack and unpack a caller-owned field list",
  "license": "MIT",
  "homepage": "https://github.com/zxsanny/packbin"
}
EOF
  cat > "$reg/ports/packbin/portfile.cmake" <<'EOF'
set(SRC "${CURRENT_PORT_DIR}")
file(INSTALL "${SRC}/include/packbin" DESTINATION "${CURRENT_PACKAGES_DIR}/include")
file(INSTALL "${SRC}/src/" DESTINATION "${CURRENT_PACKAGES_DIR}/share/packbin/src")
file(WRITE "${CURRENT_PACKAGES_DIR}/share/packbin/copyright" "MIT\n")
EOF
}

record_vcpkg_version() {
  python3 - "$1" "$2" "$3" <<'PY'
import json, sys
from pathlib import Path
reg, version, tree = sys.argv[1:]
root = Path(reg)
baseline_path = root / "versions" / "baseline.json"
port_path = root / "versions" / "p-" / "packbin.json"
baseline = json.loads(baseline_path.read_text()) if baseline_path.exists() else {"default": {}}
baseline.setdefault("default", {})["packbin"] = {"baseline": version, "port-version": 0}
baseline_path.parent.mkdir(parents=True, exist_ok=True)
baseline_path.write_text(json.dumps(baseline, indent=2) + "\n")
history = json.loads(port_path.read_text()) if port_path.exists() else {"versions": []}
versions = [item for item in history.get("versions", []) if item.get("version") != version]
versions.insert(0, {"git-tree": tree, "port-version": 0, "version": version})
port_path.write_text(json.dumps({"versions": versions}, indent=2) + "\n")
PY
}

push_vcpkg() {
  local reg="$1" url="$2" ask
  if [ -n "${GITHUB_TOKEN:-}" ] && [[ "$url" == https://github.com/* ]]; then
    ask="$(mktemp)"
    cat > "$ask" <<'EOF'
#!/bin/sh
case "$1" in
  *sername*) printf '%s' "x-access-token" ;;
  *) printf '%s' "$GITHUB_TOKEN" ;;
esac
EOF
    chmod +x "$ask"
    GIT_ASKPASS="$ask" GIT_TERMINAL_PROMPT=0 git -C "$reg" -c credential.helper= \
      push "$url" HEAD:refs/heads/vcpkg
    return
  fi
  git -C "$reg" push "$url" HEAD:refs/heads/vcpkg
}

publish_cpp() {
  local work reg url tree
  work="$(mktemp -d)"
  reg="$work/reg"
  url="${VCPKG_REGISTRY_URL:-https://github.com/zxsanny/packbin.git}"
  if git ls-remote --heads "$url" vcpkg | grep -q .; then
    git clone --branch vcpkg --single-branch "$url" "$reg"
  else
    mkdir -p "$reg"
    git -C "$reg" init -b vcpkg
  fi
  git -C "$reg" config user.email "packbin@users.noreply.github.com"
  git -C "$reg" config user.name "packbin"
  stage_vcpkg_port "$reg"
  git -C "$reg" add ports/packbin
  if ! git -C "$reg" diff --cached --quiet; then
    git -C "$reg" commit -m "port packbin $version"
  fi
  tree="$(git -C "$reg" rev-parse "HEAD:ports/packbin")"
  record_vcpkg_version "$reg" "$version" "$tree"
  git -C "$reg" add versions
  if ! git -C "$reg" diff --cached --quiet; then
    git -C "$reg" commit -m "version packbin $version"
  fi
  push_vcpkg "$reg" "$url"
}

publish_npm_oidc() {
  local work
  work="$(mktemp -d)"
  cp -a "$root/typescript/." "$work/typescript"
  rm -rf "$work/typescript/node_modules"
  npm version "$version" --no-git-tag-version --allow-same-version --prefix "$work/typescript"
  npm publish --access public --prefix "$work/typescript"
}

publish_java_upload() {
  curl --fail --silent --show-error \
    -H "Authorization: Bearer ${MAVEN_CENTRAL_TOKEN}" \
    -F "bundle=@${out}/maven-bundle.zip" \
    https://central.sonatype.com/api/v1/publisher/upload
}

for lang in "${PACKBIN_LANGS[@]}"; do
  if ! grep -qx "$lang" "$plan"; then
    continue
  fi
  case "$lang" in
    typescript)
      if [ -z "${NPM_TOKEN:-}" ] && [ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
        publish_npm_oidc
      else
        run_inside typescript
      fi
      ;;
    cpp) publish_cpp ;;
    java)
      run_inside java
      publish_java_upload
      ;;
    *) run_inside "$lang" ;;
  esac
done
