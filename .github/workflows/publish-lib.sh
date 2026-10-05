#!/usr/bin/env bash
set -euo pipefail

PACKBIN_LANGS=(csharp typescript python rust cpp java)

publish_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s\n' "${SRC_ROOT:-$(cd "$here/../.." && pwd)}"
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

# Pushes HEAD of the repository at $1 to branch $3 (and tag $4 when given) of remote URL $2.
# With GITHUB_TOKEN set and a github.com URL, the token answers the credential prompt.
push_branch() {
  local reg="$1" url="$2" branch="$3" tag="${4:-}" ask
  local refs=("HEAD:refs/heads/$branch")
  if [ -n "$tag" ]; then
    git -C "$reg" tag -f "$tag"
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
      push "$url" "${refs[@]}"
    return
  fi
  git -C "$reg" push "$url" "${refs[@]}"
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
