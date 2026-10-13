#!/usr/bin/env bash
# Upload step of the go-tag target (ADR-004), run by publish-upload.sh after every registry took its
# version. Go has no registry: the module github.com/zxsanny/packbin/go is fetched from the tag
# go/v<version>, which must sit at the commit of the tag v<version>. The build phase recorded that
# commit in $PACKBIN_OUT/artifacts/go-tag/tag.txt (publish-build.sh, checked by publish-check.py).
#
# 1. Ask the remote about the tag. At the same commit: nothing to push. At another commit: fail naming
#    both, because a Go tag never moves and is never deleted. Absent: push it (never forced).
# 2. Ask proxy.golang.org for the module at that version (`go mod download -json`: it fetches the
#    zip and verifies it against sum.golang.org, which `go list -m` does not), retrying for
#    $PACKBIN_GO_PROXY_WINDOW seconds (default 1800) every $PACKBIN_GO_PROXY_PAUSE seconds (default 30).
#    It runs on a re-run too, so a run that failed here is finished by running the tag again.
#
# Needs: PACKBIN_OUT, PACKBIN_VERSION; GITHUB_TOKEN for a github.com remote (git_push); go on PATH.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=publish-lib.sh
source "$here/publish-lib.sh"
# shellcheck source=publish-query.sh
source "$here/publish-query.sh"

version="${PACKBIN_VERSION:?PACKBIN_VERSION is required}"
version="${version#v}"
out="${PACKBIN_OUT:?PACKBIN_OUT is required}"
artifacts="$out/artifacts"
root="$(publish_root)"
url="$(go_tag_url)"
module="github.com/zxsanny/packbin/go"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

read -r tag commit < "$artifacts/go-tag/tag.txt"

# The commit the remote tag points at (an annotated tag is peeled), empty when the tag is absent.
remote_tag_commit() {
  local ref="refs/tags/$tag" sha
  sha="$(remote_sha "$url" "$ref^{}")" || query_fail go-tag "git ls-remote $url failed"
  if [ -z "$sha" ]; then
    sha="$(remote_sha "$url" "$ref")" || query_fail go-tag "git ls-remote $url failed"
  fi
  printf '%s\n' "$sha"
}

push_go_tag() {
  local remote
  remote="$(remote_tag_commit)" || exit 1
  if [ "$remote" = "$commit" ]; then
    echo "go tag $tag is already at $commit; not pushing"
    return 0
  fi
  if [ -n "$remote" ]; then
    echo "go tag $tag is at $remote, but v$version is at $commit: a Go tag never moves and is never" \
      "deleted; retract this version in go.mod of the next one" >&2
    return 1
  fi
  echo "push go tag $tag at $commit"
  git_push "$root" "$url" "$commit:refs/tags/$tag"
}

# Succeeds when proxy.golang.org downloads `<module> v<version>`: the JSON of `go mod download` names
# that Path and Version. GOPROXY has no fallback to the repository, GOFLAGS is replaced, and the
# variables that exclude a module from the proxy or from the checksum database are unset, so the answer
# is what a new user's `go get` would get.
proxy_check() {
  local window="${PACKBIN_GO_PROXY_WINDOW:-1800}" pause="${PACKBIN_GO_PROXY_PAUSE:-30}"
  local want="$module v$version" probe="$work/probe" deadline attempt=0 answer="" json="" code=0
  deadline=$((SECONDS + window))
  mkdir -p "$probe"
  printf 'module packbin-proxy-probe\n\ngo 1.26\n' > "$probe/go.mod"
  while :; do
    attempt=$((attempt + 1))
    answer="" code=0
    json="$(cd "$probe" && env -u GONOSUMDB -u GONOSUMCHECK -u GONOPROXY -u GOPRIVATE -u GOINSECURE -u GOSUMDB \
      GOPROXY=https://proxy.golang.org GOFLAGS=-mod=mod GOWORK=off \
      go mod download -json "$module@v$version" 2> "$probe/err")" || code=$?
    # A failed download prints its reason as the Error field of the JSON on stdout.
    answer="$(printf '%s' "$json" | python3 -I -c 'import json, sys
d = json.load(sys.stdin)
print(d["Error"] if d.get("Error") else "%s %s" % (d.get("Path", ""), d.get("Version", "")))' 2>> "$probe/err")" || answer=""
    if [ "$code" -ne 0 ] && [ "$answer" = "$want" ]; then
      answer="go exited $code"
    fi
    if [ "$answer" = "$want" ]; then
      echo "go proxy answers $answer (try $attempt)"
      return 0
    fi
    echo "go proxy try $attempt: ${answer:-no answer}; $(tail -n 1 "$probe/err")"
    if [ "$SECONDS" -ge "$deadline" ]; then
      break
    fi
    sleep "$pause"
  done
  echo "proxy.golang.org gave no answer for $module@v$version after $attempt tries in ${window}s;" \
    "the tag $tag stays at $commit; run the tag again to check again (a re-run only re-checks)" >&2
  return 1
}

push_go_tag
proxy_check
