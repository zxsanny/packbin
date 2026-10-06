#!/usr/bin/env bash
set -euo pipefail

PACKBIN_LANGS=(csharp typescript python rust cpp java)

# The publish targets: name, the language whose presence plans it, and its tier. A required target
# with a missing credential fails the run before any write and a failed upload fails it; an
# optional target with a missing credential is skipped with a warning, and a failed upload of
# one that has its credential fails the run too. Uploads run required targets first.
PACKBIN_TARGETS=(
  "csharp csharp required"
  "typescript typescript required"
  "python python required"
  "rust rust required"
  "java java required"
  "vcpkg cpp required"
  "platformio cpp optional"
  "esp-idf cpp optional"
  "arduino cpp optional"
)

targets_of_lang() {
  local row name lang tier
  for row in "${PACKBIN_TARGETS[@]}"; do
    read -r name lang tier <<< "$row"
    if [ "$lang" = "$1" ]; then
      printf '%s\n' "$name"
    fi
  done
}

target_tier() {
  local row name lang tier
  for row in "${PACKBIN_TARGETS[@]}"; do
    read -r name lang tier <<< "$row"
    if [ "$name" = "$1" ]; then
      printf '%s\n' "$tier"
      return 0
    fi
  done
  echo "unknown target: $1" >&2
  return 1
}

# The credential variables a target needs, space separated. a|b means either one will do.
# A git registry on GitHub needs GITHUB_TOKEN; any other URL (the bare repositories of the tests) needs none.
target_credentials() {
  case "$1" in
    csharp) echo "NUGET_TOKEN" ;;
    typescript) echo "NPM_TOKEN|ACTIONS_ID_TOKEN_REQUEST_URL" ;;
    python) echo "PYPI_TOKEN|ACTIONS_ID_TOKEN_REQUEST_URL" ;;
    rust) echo "CARGO_REGISTRY_TOKEN" ;;
    java) echo "MAVEN_CENTRAL_TOKEN MAVEN_GPG_PRIVATE_KEY" ;;
    platformio) echo "PLATFORMIO_AUTH_TOKEN" ;;
    esp-idf) echo "IDF_COMPONENT_API_TOKEN" ;;
    vcpkg) if [[ "$(vcpkg_url)" == https://github.com/* ]]; then echo "GITHUB_TOKEN"; fi ;;
    arduino) if [[ "$(arduino_url)" == https://github.com/* ]]; then echo "GITHUB_TOKEN"; fi ;;
    *)
      echo "unknown target: $1" >&2
      return 1
      ;;
  esac
}

# The credentials of target $1 that are not set, as one line ("A or B" for alternatives). Empty when it has all.
missing_credentials() {
  local spec word var alternatives found missing=""
  spec="$(target_credentials "$1")"
  for word in $spec; do
    found=0
    IFS='|' read -r -a alternatives <<< "$word"
    for var in "${alternatives[@]}"; do
      if [ -n "${!var:-}" ]; then
        found=1
      fi
    done
    if [ "$found" = 0 ]; then
      missing="${missing:+$missing }${word//|/ or }"
    fi
  done
  printf '%s\n' "$missing"
}

# Every secret the publish scripts can read. The build phase runs without them (except the Maven
# signing key in a real publish) and a build-only run unsets all of them.
PACKBIN_CREDENTIALS=(
  NUGET_TOKEN NPM_TOKEN PYPI_TOKEN CARGO_REGISTRY_TOKEN MAVEN_CENTRAL_TOKEN MAVEN_GPG_PRIVATE_KEY
  PLATFORMIO_AUTH_TOKEN IDF_COMPONENT_API_TOKEN GITHUB_TOKEN
  ACTIONS_ID_TOKEN_REQUEST_URL ACTIONS_ID_TOKEN_REQUEST_TOKEN
)

publish_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s\n' "${SRC_ROOT:-$(cd "$here/../.." && pwd)}"
}

# The one way the publish run starts a container (build phase and golden gate): the repo is mounted
# read-only by docker-compose.publish.yml, merged over the base file. Arguments go to `compose run`:
# options, then the service and its command. Never add a `run -v` for /src: Compose ignores it
# for a target the service already mounts.
publish_container() {
  local root
  root="$(publish_root)"
  docker compose -f "$root/docker-compose.test.yml" -f "$root/docker-compose.publish.yml" \
    --project-directory "$root" -p packbin-publish run -T --rm --no-deps "$@"
}

language_present() {
  local root="$1" lang="$2"
  case "$lang" in
    csharp)
      compgen -G "$root/csharp/*.csproj" >/dev/null
      ;;
    typescript) [ -f "$root/typescript/package.json" ] ;;
    python) [ -f "$root/python/pyproject.toml" ] ;;
    rust) [ -f "$root/rust/Cargo.toml" ] ;;
    cpp) [ -f "$root/cpp/Makefile" ] ;;
    java) [ -f "$root/java/test.sh" ] ;;
    *) return 1 ;;
  esac
}

vcpkg_url() {
  printf '%s\n' "${VCPKG_REGISTRY_URL:-https://github.com/zxsanny/packbin.git}"
}

arduino_url() {
  printf '%s\n' "${ARDUINO_REGISTRY_URL:-https://github.com/zxsanny/packbin.git}"
}

# Installs pip packages $2... into venv $1 at the exact versions of tool-pins.txt, wheels only.
# A package with no pin fails before pip runs.
pip_install_pinned() {
  local venv="$1" pkg pin specs=()
  shift
  for pkg in "$@"; do
    pin="$(bash "$(dirname "${BASH_SOURCE[0]}")/tool-pin.sh" "$pkg")" || return 1
    specs+=("$pkg==$pin")
  done
  "$venv/bin/pip" install --quiet --only-binary=:all: "${specs[@]}"
}

# Puts command $1 on PATH. A tool already on PATH wins; otherwise pip package $2 goes into a venv
# under $PACKBIN_TOOLS (default $PACKBIN_OUT/tools), which is appended to PATH.
ensure_tool() {
  local cmd="$1" pkg="$2" venv
  if command -v "$cmd" >/dev/null; then
    return 0
  fi
  venv="${PACKBIN_TOOLS:-${PACKBIN_OUT:?PACKBIN_OUT is required}/tools}/venv"
  if [ ! -x "$venv/bin/python" ]; then
    python3 -m venv "$venv"
  fi
  pip_install_pinned "$venv" "$pkg"
  PATH="$PATH:$venv/bin"
  export PATH
}

# Pushes HEAD of the repository at $1 to branch $3 (and the existing tag $4 when given) of remote URL $2,
# all or nothing: a tag that already points elsewhere is refused and the branch stays where it was.
# With GITHUB_TOKEN set and a github.com URL, the token answers the credential prompt.
push_branch() {
  local reg="$1" url="$2" branch="$3" tag="${4:-}" ask code=0
  local refs=("HEAD:refs/heads/$branch")
  if [ -n "$tag" ]; then
    refs+=("refs/tags/$tag")
  fi
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
      push --atomic "$url" "${refs[@]}" || code=$?
    rm -f "$ask"
    return "$code"
  fi
  git -C "$reg" push --atomic "$url" "${refs[@]}"
}

fixture_hex() {
  tr -d '[:space:]' < "$1"
}

byte_mismatch() {
  python3 -c '
import sys
a, b = sys.argv[1], sys.argv[2]
ab, bb = bytes.fromhex(a), bytes.fromhex(b)
n = max(len(ab), len(bb))
bad = 0
for i in range(n):
    left = ab[i] if i < len(ab) else None
    right = bb[i] if i < len(bb) else None
    if left != right:
        bad += 1
print(bad)
' "$1" "$2"
}
