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

if [ ! -s "$plan" ] && [ "${PACKBIN_MAVEN_BUNDLE_ONLY:-}" != "1" ]; then
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

if [ "${PACKBIN_MAVEN_BUNDLE_ONLY:-}" != "1" ]; then
  need csharp NUGET_TOKEN
  if grep -qx typescript "$plan" && [ -z "${NPM_TOKEN:-}" ] && [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
    echo "NPM_TOKEN is required before any registry write" >&2
    exit 1
  fi
  need java MAVEN_CENTRAL_TOKEN
  need java MAVEN_GPG_PRIVATE_KEY
fi

skip_unset() {
  local lang="$1" var="$2"
  if grep -qx "$lang" "$plan" && [ -z "${!var:-}" ]; then
    echo "skip $lang"
    grep -vx "$lang" "$plan" > "$plan.skip"
    mv "$plan.skip" "$plan"
  fi
}

if [ "${PACKBIN_MAVEN_BUNDLE_ONLY:-}" != "1" ]; then
  if grep -qx python "$plan" && [ -z "${PYPI_TOKEN:-}" ] && [ -z "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
    echo "skip python"
    grep -vx python "$plan" > "$plan.skip"
    mv "$plan.skip" "$plan"
  fi
  skip_unset rust CARGO_REGISTRY_TOKEN
fi

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

publish_pypi_oidc() {
  local work oidc jwt body code token
  work="$(mktemp -d)"
  cp -a "$root/python/." "$work/python"
  rm -f "$work/python/README.md"
  cp "$root/README.md" "$work/python/README.md"
  python3 -c '
import re, sys
from pathlib import Path
path, version = Path(sys.argv[1]), sys.argv[2]
text = path.read_text()
path.write_text(re.sub(r"(?m)^version = \".*\"$", f"version = \"{version}\"", text, count=1))
' "$work/python/pyproject.toml" "$version"
  python3 -m venv "$work/venv"
  "$work/venv/bin/pip" install --quiet build twine
  "$work/venv/bin/python" -m build "$work/python" --outdir "$work/pypi"
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
  echo "::add-mask::${token}"
  "$work/venv/bin/twine" upload --non-interactive -u __token__ -p "$token" "$work/pypi"/*
}

publish_npm_oidc() {
  local work
  work="$(mktemp -d)"
  cp -a "$root/typescript/." "$work/typescript"
  cp "$root/README.md" "$work/typescript/README.md"
  rm -rf "$work/typescript/node_modules"
  (
    cd "$work/typescript"
    npm version "$version" --no-git-tag-version --allow-same-version
    npm publish --access public
  )
}

prepare_maven_bundle() {
  local src="$out/maven" ring file
  if [ ! -d "$src" ]; then
    echo "maven bundle directory is missing" >&2
    exit 1
  fi
  if [ -z "${MAVEN_GPG_PRIVATE_KEY:-}" ]; then
    echo "MAVEN_GPG_PRIVATE_KEY is required before any registry write" >&2
    exit 1
  fi
  ring="$(mktemp -d)"
  chmod 700 "$ring"
  GNUPGHOME="$ring" gpg --batch --import <<EOF
${MAVEN_GPG_PRIVATE_KEY}
EOF
  while IFS= read -r -d '' file; do
    case "$file" in
      *.pom|*.jar)
        GNUPGHOME="$ring" gpg --batch --yes --pinentry-mode loopback \
          --detach-sign --armor --output "$file.asc" "$file"
        python3 - "$file" <<'PY'
import hashlib, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = path.read_bytes()
for name in ("md5", "sha1"):
    path.with_name(path.name + "." + name).write_text(hashlib.new(name, data).hexdigest() + "\n")
PY
        ;;
    esac
  done < <(find "$src" -type f -print0)
  python3 - "$src" "$out/maven-bundle.zip" <<'PY'
import sys, zipfile
from pathlib import Path
src, dest = Path(sys.argv[1]), Path(sys.argv[2])
with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
    for path in sorted(src.rglob("*")):
        if path.is_file():
            bundle.write(path, path.relative_to(src).as_posix())
PY
}

publish_java_upload() {
  local id state attempt
  prepare_maven_bundle
  id="$(curl --fail --silent --show-error \
    -H "Authorization: Bearer ${MAVEN_CENTRAL_TOKEN}" \
    -F "bundle=@${out}/maven-bundle.zip" \
    "https://central.sonatype.com/api/v1/publisher/upload?publishingType=AUTOMATIC")"
  id="$(printf '%s' "$id" | tr -d '[:space:]')"
  for attempt in $(seq 1 90); do
    state="$(curl --fail --silent --show-error -X POST \
      -H "Authorization: Bearer ${MAVEN_CENTRAL_TOKEN}" \
      "https://central.sonatype.com/api/v1/publisher/status?id=${id}")"
    printf '%s\n' "$state"
    case "$state" in
      *'"deploymentState":"PUBLISHED"'*) return 0 ;;
      *'"deploymentState":"FAILED"'*) exit 1 ;;
    esac
    sleep 15
  done
  echo "maven central deployment did not finish" >&2
  exit 1
}

if [ "${PACKBIN_MAVEN_BUNDLE_ONLY:-}" = "1" ]; then
  prepare_maven_bundle
  exit 0
fi

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
    python)
      if [ -z "${PYPI_TOKEN:-}" ] && [ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
        publish_pypi_oidc
      else
        run_inside python
      fi
      ;;
    *) run_inside "$lang" ;;
  esac
done
