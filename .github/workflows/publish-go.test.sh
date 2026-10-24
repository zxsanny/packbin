#!/usr/bin/env bash
# Go release scenarios (AZ-2450, ADR-004; AC-1 to AC-4). Sourced by publish-gate.test.sh, which defines
# fail, assert_eq, $root and $here, or run on its own: bash publish-go.test.sh.
# Hermetic: no network, no Docker, no real tag. Git runs for real on local repositories (a source repository
# and a bare one that stands for GitHub); `go` is a PATH stub that logs each call and answers from the
# environment; the golden gate runs on a synthetic tree whose position scripts are stubs, so only the gate's
# own logic (the byte sum, the plan, the absent language) is under test. The real Go position program runs
# in the `go` container through the full publish-gate.test.sh.

go_standalone=0
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  root="$(cd "$here/../.." && pwd)"
  failures=0
  go_standalone=1
  fail() {
    echo "FAIL: $*" >&2
    failures=$((failures + 1))
  }
  assert_eq() {
    if [ "$1" != "$2" ]; then
      fail "$3: expected [$2] got [$1]"
    fi
  }
fi

GT_GOLDEN="4001000065cd1d00a3e1110100"
GT_WRONG="4001000065cd1d00a3e1110101"
GT_CREDENTIALS="NUGET_TOKEN NPM_TOKEN PYPI_TOKEN CARGO_REGISTRY_TOKEN MAVEN_CENTRAL_TOKEN MAVEN_GPG_PRIVATE_KEY PLATFORMIO_AUTH_TOKEN IDF_COMPONENT_API_TOKEN GITHUB_TOKEN ACTIONS_ID_TOKEN_REQUEST_URL ACTIONS_ID_TOKEN_REQUEST_TOKEN"

gt_git() {
  git -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false -c init.defaultBranch=main "$@"
}

# The tags of bare repository $1, one line.
gt_tags() {
  git --git-dir="$1" for-each-ref --format='%(refname:short)' refs/tags | paste -sd ' ' -
}

# A fake `go` on PATH: logs `mod download -json <module>@<version>|GOPROXY|GOFLAGS|GONOSUMDB|directory|go.mod
# there|tags on the remote at that moment`, fails the first $GT_GO_FAILS calls like a proxy that has not seen the
# tag yet (JSON with an Error field, exit 1), then prints the JSON of `go mod download`: Path and Version of the
# request, or $GT_GO_ANSWER ("path version") when set.
gt_write_go() {
  cat > "$1/go" <<'EOF'
#!/bin/bash
printf '%s|GOPROXY=%s|GOFLAGS=%s|GONOSUMDB=%s|dir=%s|gomod=%s|remote=%s\n' "$*" "${GOPROXY:-}" "${GOFLAGS:-}" \
  "${GONOSUMDB-unset}" "$(basename "$PWD")" "$([ -f go.mod ] && echo yes || echo no)" \
  "$(git --git-dir="$GT_BARE" for-each-ref --format='%(refname:short)' refs/tags | paste -sd , -)" >> "$GT_GO_LOG"
calls="$(grep -c '^mod download ' "$GT_GO_LOG")"
sleep "${GT_GO_DELAY:-0}"
spec="${@: -1}"
path="${spec%@*}"
version="${spec#*@}"
if [ -n "${GT_GO_ANSWER:-}" ]; then
  path="${GT_GO_ANSWER% *}"
  version="${GT_GO_ANSWER#* }"
fi
if [ "$calls" -le "${GT_GO_FAILS:-0}" ]; then
  printf '{\n\t"Path": "%s",\n\t"Version": "%s",\n\t"Error": "module not found"\n}\n' "$path" "$version"
  echo "go: module not found" >&2
  exit 1
fi
printf '{\n\t"Path": "%s",\n\t"Version": "%s",\n\t"Info": "/cache/%s.info",\n\t"Sum": "h1:x"\n}\n' "$path" "$version" "$version"
EOF
  chmod +x "$1/go"
}

# gt_setup: $gt_dir with a source repository (go/go.mod, go/LICENSE, one commit), an empty bare repository whose
# pre-receive hook logs each push, the go stub, and the plan file.
gt_setup() {
  gt_dir="$(mktemp -d)"
  gt_src="$gt_dir/src"
  gt_bare="$gt_dir/remote.git"
  gt_bin="$gt_dir/bin"
  gt_plan="$gt_dir/plan.txt"
  gt_pushes="$gt_dir/pushes.log"
  gt_golog="$gt_dir/go.log"
  : > "$gt_pushes"
  : > "$gt_golog"
  mkdir -p "$gt_bin" "$gt_src/go"
  cp "$root/go/go.mod" "$gt_src/go/go.mod"
  cp "$root/go/LICENSE" "$gt_src/go/LICENSE"
  gt_git -C "$gt_src" init -q
  gt_git -C "$gt_src" add -A
  gt_git -C "$gt_src" commit -q -m "release commit"
  git init -q --bare "$gt_bare"
  printf '#!/bin/sh\nwhile read old new ref; do echo "push $ref $new" >> "%s"; done\n' "$gt_pushes" > "$gt_bare/hooks/pre-receive"
  chmod +x "$gt_bare/hooks/pre-receive"
  gt_write_go "$gt_bin"
  printf 'go\n' > "$gt_plan"
  gt_head="$(git -C "$gt_src" rev-parse HEAD)"
}

# gt_publish <name> [VAR=value ...]: publish-registries.sh on the plan with the go stub; output in $gt_dir/<name>.out,
# exit code in $gt_code. No registry credential is set; the remote is a local path, so the Go tag needs none.
gt_publish() {
  local name="$1" unset_args=() var
  shift
  for var in $GT_CREDENTIALS; do
    unset_args+=(-u "$var")
  done
  set +e
  env "${unset_args[@]}" PACKBIN_PUBLISH=1 PACKBIN_DOCKER=0 SRC_ROOT="$gt_src" PACKBIN_PLAN="$gt_plan" \
    PACKBIN_OUT="$gt_dir/out-$name" PACKBIN_VERSION=v0.1.9 GO_TAG_REGISTRY_URL="$gt_bare" PACKBIN_QUERY_PAUSE=0 \
    PACKBIN_GO_PROXY_PAUSE=0 PACKBIN_GO_PROXY_WINDOW=0 PACKBIN_GO_PROXY_SETTLE=0 PACKBIN_GO_TAG_PAUSE=0 GONOSUMDB=bogus \
    GT_BARE="$gt_bare" GT_GO_LOG="$gt_golog" PATH="$gt_bin:$PATH" "$@" \
    bash "$here/publish-registries.sh" > "$gt_dir/$name.out" 2>&1
  gt_code=$?
  set -e
}

# gt_window: a proxy window that holds several asks on this host: 3 s plus four times the slowest of three asks of the
# stub (whole seconds), so a loaded host or a GT_GO_DELAY stub cannot end the window after the first ask.
gt_window() {
  local slowest=0 start
  for _ in 1 2 3; do
    start=$SECONDS
    GT_BARE="$gt_bare" GT_GO_LOG="$gt_dir/probe.log" GT_GO_FAILS=999 PATH="$gt_bin:$PATH" \
      go mod download -json "probe@v0.0.0" > /dev/null 2>&1 || true
    [ $((SECONDS - start)) -le "$slowest" ] || slowest=$((SECONDS - start))
  done
  echo $((3 + 4 * slowest))
}

gt_go_calls() {
  grep -c '^mod download ' "$gt_golog" || true
}

gt_pushed() {
  wc -l < "$gt_pushes" | tr -d ' '
}

# AC-2: the tag lands once, at the commit of the checkout, then the proxy is asked; a dry run pushes nothing.
gt_tag_checks() {
  gt_setup
  gt_publish dry PACKBIN_BUILD_ONLY=1
  assert_eq "$gt_code" "0" "AC-2 dry run exit code"
  grep -qx 'build ok go-tag' "$gt_dir/dry.out" || fail "AC-2 dry run did not build go-tag: $(tail -n 3 "$gt_dir/dry.out")"
  grep -qx "go/v0.1.9 $gt_head" "$gt_dir/out-dry/artifacts/go-tag/tag.txt" || fail "AC-2 tag.txt: $(cat "$gt_dir/out-dry/artifacts/go-tag/tag.txt")"
  assert_eq "$(gt_tags "$gt_bare")" "" "AC-2 dry run pushed a tag"
  assert_eq "$(gt_pushed)" "0" "AC-2 dry run pushes"
  assert_eq "$(gt_go_calls)" "0" "AC-2 dry run asked the proxy"

  gt_publish first
  assert_eq "$gt_code" "0" "AC-2 first publish exit code: $(tail -n 4 "$gt_dir/first.out")"
  assert_eq "$(gt_tags "$gt_bare")" "go/v0.1.9" "AC-2 tags on the remote"
  assert_eq "$(git --git-dir="$gt_bare" rev-parse 'refs/tags/go/v0.1.9^{commit}')" "$gt_head" "AC-2 tag commit"
  assert_eq "$(gt_pushed)" "1" "AC-2 pushes"
  assert_eq "$(cat "$gt_pushes")" "push refs/tags/go/v0.1.9 $gt_head" "AC-2 pushed ref"
  assert_eq "$(gt_go_calls)" "1" "AC-2 proxy asks"
  # The module path and version, the proxy without a fallback, a temp module dir, and the tag already on the remote.
  assert_eq "$(sed -n 1p "$gt_golog")" \
    "mod download -json github.com/zxsanny/packbin/go@v0.1.9|GOPROXY=https://proxy.golang.org|GOFLAGS=-mod=mod|GONOSUMDB=unset|dir=probe|gomod=yes|remote=go/v0.1.9" \
    "AC-2 go list call"
  grep -q '^go proxy answers github.com/zxsanny/packbin/go v0.1.9' "$gt_dir/first.out" || fail "AC-2 no proxy answer line: $(cat "$gt_dir/first.out")"
  grep -q '^build ok go-tag$' "$gt_dir/first.out" && grep -q '^check ok: go-tag$' "$gt_dir/first.out" || fail "AC-2 build or check line missing"
  if git -C "$gt_src" tag -l | grep -q .; then
    fail "AC-2 the source repository got a tag: $(git -C "$gt_src" tag -l)"
  fi

  # The proxy needs a few tries: three asks, one push, the tag stays.
  rm -rf "$gt_dir/remote.git" && git init -q --bare "$gt_bare" && : > "$gt_pushes" && : > "$gt_golog"
  printf '#!/bin/sh\nwhile read old new ref; do echo "push $ref $new" >> "%s"; done\n' "$gt_pushes" > "$gt_bare/hooks/pre-receive"
  chmod +x "$gt_bare/hooks/pre-receive"
  gt_publish retry GT_GO_FAILS=2 PACKBIN_GO_PROXY_WINDOW=60
  assert_eq "$gt_code" "0" "AC-2 retrying proxy exit code: $(tail -n 4 "$gt_dir/retry.out")"
  assert_eq "$(gt_go_calls)" "3" "AC-2 proxy asks before the answer"
  assert_eq "$(gt_pushed)" "1" "AC-2 retrying proxy pushes"
  rm -rf "$gt_dir"
}

# AC-3 and GO-16: a re-run finds the tag at the same commit and pushes nothing; at another commit it fails naming
# both; a proxy that never answers fails with the tag in place, and the next run only re-checks.
gt_rerun_checks() {
  local other
  gt_setup
  gt_publish first
  assert_eq "$gt_code" "0" "AC-3 first publish exit code"
  gt_publish same
  assert_eq "$gt_code" "0" "AC-3 same-commit re-run exit code: $(tail -n 4 "$gt_dir/same.out")"
  grep -q "^go tag go/v0.1.9 is already at $gt_head; not pushing" "$gt_dir/same.out" || fail "AC-3 no 'already at' line: $(cat "$gt_dir/same.out")"
  assert_eq "$(gt_pushed)" "1" "AC-3 re-run pushes"
  assert_eq "$(gt_go_calls)" "2" "AC-3 the re-run re-checks the proxy"
  assert_eq "$(gt_tags "$gt_bare")" "go/v0.1.9" "AC-3 tags after the re-run"

  gt_git -C "$gt_src" commit -q --allow-empty -m "another commit"
  other="$(git -C "$gt_src" rev-parse HEAD)"
  gt_publish moved
  [ "$gt_code" -ne 0 ] || fail "AC-3 a tag at another commit passed"
  grep -q "go tag go/v0.1.9 is at $gt_head, but v0.1.9 is at $other" "$gt_dir/moved.out" || fail "AC-3 the message does not name both commits: $(cat "$gt_dir/moved.out")"
  assert_eq "$(git --git-dir="$gt_bare" rev-parse 'refs/tags/go/v0.1.9^{commit}')" "$gt_head" "AC-3 the tag moved"
  assert_eq "$(gt_pushed)" "1" "AC-3 a push after the mismatch"
  assert_eq "$(gt_go_calls)" "2" "AC-3 the proxy was asked after the mismatch"
  rm -rf "$gt_dir"

  gt_setup
  gt_publish never GT_GO_FAILS=999 PACKBIN_GO_PROXY_WINDOW="$(gt_window)"
  [ "$gt_code" -ne 0 ] || fail "AC-3 a proxy that never answers passed"
  [ "$(gt_go_calls)" -ge 2 ] || fail "AC-3 the proxy was asked once only: $(gt_go_calls)"
  grep -q 'the tag go/v0.1.9 stays' "$gt_dir/never.out" && grep -q 're-run only re-checks' "$gt_dir/never.out" \
    || fail "AC-3 the failure does not say the tag stays: $(tail -n 3 "$gt_dir/never.out")"
  assert_eq "$(gt_tags "$gt_bare")" "go/v0.1.9" "AC-3 the tag after a proxy failure"
  : > "$gt_golog"
  gt_publish after
  assert_eq "$gt_code" "0" "AC-3 re-run after a proxy failure: $(tail -n 3 "$gt_dir/after.out")"
  assert_eq "$(gt_pushed)" "1" "AC-3 re-run after a proxy failure pushed"
  assert_eq "$(gt_go_calls)" "1" "AC-3 re-run after a proxy failure re-checks once"
  rm -rf "$gt_dir"
}

# AZ-2600: the proxy gets its first request only after the pushed tag shows on an anonymous ls-remote and the settle
# pause (a first request that finds no tag is cached as "not found" for about 30 minutes: 19 minutes on go/v0.3.0). A
# `git` wrapper hides the tag from ls-remote $GT_HIDE_FILE times after the first push; the proxy stub logs each call.
gt_visibility_checks() {
  local real_git hide started
  real_git="$(command -v git)"
  gt_setup
  hide="$gt_dir/hide"
  cat > "$gt_bin/git" <<'EOF'
#!/bin/bash
if [ "$1" = ls-remote ] && [ -n "${GT_HIDE_FILE:-}" ] && [ -s "$GT_PUSHES" ]; then
  n="$(cat "$GT_HIDE_FILE")"
  if [ "$n" -gt 0 ]; then echo $((n - 1)) > "$GT_HIDE_FILE"; exit 0; fi
fi
exec "$GT_REAL_GIT" "$@"
EOF
  chmod +x "$gt_bin/git"
  echo 4 > "$hide"
  started=$SECONDS
  gt_publish lag GT_REAL_GIT="$real_git" GT_HIDE_FILE="$hide" GT_PUSHES="$gt_pushes" PACKBIN_GO_TAG_WINDOW=60 PACKBIN_GO_PROXY_SETTLE=6
  [ $((SECONDS - started)) -ge 6 ] || fail "AZ-2600 the settle pause of 6 s did not happen: the run took $((SECONDS - started)) s"
  assert_eq "$gt_code" "0" "AZ-2600 a tag that shows late: $(tail -n 4 "$gt_dir/lag.out")"
  assert_eq "$(cat "$hide")" "0" "AZ-2600 the hidden answers were not all asked for"
  grep -q '^go tag go/v0.1.9 is not visible on .* yet (try 1)$' "$gt_dir/lag.out" || fail "AZ-2600 no 'not visible' line: $(cat "$gt_dir/lag.out")"
  grep -q '^go tag go/v0.1.9 is not visible on .* yet (try 2)$' "$gt_dir/lag.out" || fail "AZ-2600 no second 'not visible' line"
  if grep -q 'not visible on .* yet (try 3)$' "$gt_dir/lag.out"; then fail "AZ-2600 a third wait for a tag that showed"; fi
  grep -q '^go tag go/v0.1.9 is visible; waiting 6s before the first proxy request$' "$gt_dir/lag.out" || fail "AZ-2600 no settle line"
  [ "$(grep -n 'waiting 6s' "$gt_dir/lag.out" | cut -d: -f1)" -lt "$(grep -n '^go proxy answers' "$gt_dir/lag.out" | cut -d: -f1)" ] \
    || fail "AZ-2600 the proxy answered before the settle pause"
  assert_eq "$(gt_go_calls)" "1" "AZ-2600 proxy asks after a late tag"
  rm -rf "$gt_dir"

  # A tag that never shows: the run fails before any proxy request, the tag stays, and the message says so.
  gt_setup
  cat > "$gt_bin/git" <<'EOF'
#!/bin/bash
if [ "$1" = ls-remote ] && [ -s "$GT_PUSHES" ]; then exit 0; fi
exec "$GT_REAL_GIT" "$@"
EOF
  chmod +x "$gt_bin/git"
  gt_publish never GT_REAL_GIT="$real_git" GT_PUSHES="$gt_pushes" PACKBIN_GO_TAG_WINDOW=0
  [ "$gt_code" -ne 0 ] || fail "AZ-2600 a tag that never shows passed"
  grep -q 'was pushed but did not show on .* within 0s; the proxy was not asked' "$gt_dir/never.out" || fail "AZ-2600 no 'did not show' message: $(tail -n 3 "$gt_dir/never.out")"
  assert_eq "$(gt_go_calls)" "0" "AZ-2600 the proxy was asked for a tag that did not show"
  assert_eq "$(gt_tags "$gt_bare")" "go/v0.1.9" "AZ-2600 the tag after a visibility failure"

  # An ls-remote that fails after the push is a failed query, named as such; it is not a tag that does not show.
  printf '#!/bin/bash\nif [ "$1" = ls-remote ] && [ -s "$GT_PUSHES" ]; then echo "fatal: unable to access" >&2; exit 128; fi\nexec "$GT_REAL_GIT" "$@"\n' > "$gt_bin/git"
  git --git-dir="$gt_bare" tag -d go/v0.1.9 > /dev/null
  : > "$gt_pushes"
  gt_publish lsfail GT_REAL_GIT="$real_git" GT_PUSHES="$gt_pushes" PACKBIN_GO_TAG_WINDOW=0 PACKBIN_QUERY_ATTEMPTS=1
  [ "$gt_code" -ne 0 ] || fail "AZ-2600 a failing ls-remote after the push passed"
  grep -q 'cannot tell whether go-tag 0.1.9 is published: git ls-remote .* failed' "$gt_dir/lsfail.out" || fail "AZ-2600 no query failure message: $(tail -n 3 "$gt_dir/lsfail.out")"
  if grep -q 'did not show' "$gt_dir/lsfail.out"; then fail "AZ-2600 a failed ls-remote was reported as a tag that did not show"; fi

  # A re-run finds the tag there: no visibility wait, no settle pause, the proxy is asked at once.
  rm -f "$gt_bin/git"
  gt_publish rerun PACKBIN_GO_PROXY_SETTLE=1
  assert_eq "$gt_code" "0" "AZ-2600 re-run: $(tail -n 3 "$gt_dir/rerun.out")"
  if grep -q 'not visible\|waiting' "$gt_dir/rerun.out"; then fail "AZ-2600 a re-run waited for a tag that was already there: $(cat "$gt_dir/rerun.out")"; fi
  assert_eq "$(gt_go_calls)" "1" "AZ-2600 re-run proxy asks"
  rm -rf "$gt_dir"
}

# The build phase refuses before any write: a license that is not MIT, a module path that is not ours, a local
# tag v0.1.9 at another commit, a checkout without .git; a github.com remote without a token is refused up front.
gt_refusal_checks() {
  local other
  gt_setup
  printf 'Apache License\nVersion 2.0\n' > "$gt_src/go/LICENSE"
  gt_publish license
  [ "$gt_code" -ne 0 ] || fail "AC-4 a Go license that is not MIT passed"
  grep -q 'check failed: go-tag: LICENSE is not the MIT license text' "$gt_dir/license.out" || fail "license message: $(cat "$gt_dir/license.out")"
  cp "$root/go/LICENSE" "$gt_src/go/LICENSE"

  sed 's|^module .*|module example.com/other|' "$root/go/go.mod" > "$gt_src/go/go.mod"
  gt_publish module
  [ "$gt_code" -ne 0 ] || fail "AC-4 a wrong module path passed"
  grep -q 'check failed: go-tag: go.mod does not declare module github.com/zxsanny/packbin/go' "$gt_dir/module.out" || fail "module message: $(cat "$gt_dir/module.out")"
  cp "$root/go/go.mod" "$gt_src/go/go.mod"

  gt_git -C "$gt_src" tag v0.1.9
  gt_git -C "$gt_src" commit -q --allow-empty -m "after the tag"
  other="$(git -C "$gt_src" rev-parse HEAD)"
  gt_publish localtag
  [ "$gt_code" -ne 0 ] || fail "AC-3 a local tag at another commit passed"
  grep -q "tag v0.1.9 is at $gt_head, but the checkout is at $other" "$gt_dir/localtag.out" || fail "local tag message: $(cat "$gt_dir/localtag.out")"
  gt_git -C "$gt_src" tag -d v0.1.9 > /dev/null

  mv "$gt_src/.git" "$gt_dir/dot-git"
  gt_publish nogit
  [ "$gt_code" -ne 0 ] || fail "a checkout without .git passed"
  grep -q 'go-tag needs a git checkout' "$gt_dir/nogit.out" || fail "nogit message: $(cat "$gt_dir/nogit.out")"
  mv "$gt_dir/dot-git" "$gt_src/.git"

  gt_publish github GO_TAG_REGISTRY_URL=https://github.com/zxsanny/packbin.git
  [ "$gt_code" -ne 0 ] || fail "a github.com remote without GITHUB_TOKEN passed"
  grep -q 'go-tag is required and lacks: GITHUB_TOKEN' "$gt_dir/github.out" || fail "token message: $(cat "$gt_dir/github.out")"
  assert_eq "$(gt_go_calls)" "0" "no proxy ask after the refusals"
  assert_eq "$(gt_pushed)" "0" "pushes after the refusals"
  assert_eq "$(gt_tags "$gt_bare")" "" "tags after the refusals"
  [ ! -e "$gt_dir/out-github/artifacts" ] || fail "a build started without GITHUB_TOKEN"
  rm -rf "$gt_dir"
}

# F45: only a version the Go proxy can serve for this module path (canonical semver, major 0 or 1) is built; a
# refused version is stopped by the build check before any push or proxy call. A proxy that answers another
# version fails the check.
gt_version_checks() {
  local bad ok
  gt_setup
  for bad in v2.0.0 v1.2 v01.2.3 v1.0.0+meta v1.2.3-; do
    gt_publish "ver-$bad" PACKBIN_VERSION="$bad"
    [ "$gt_code" -ne 0 ] || fail "F45 version $bad passed"
    grep -q "check failed: go-tag: version ${bad#v} is not one the Go proxy serves" "$gt_dir/ver-$bad.out" \
      || fail "F45 version $bad message: $(tail -n 3 "$gt_dir/ver-$bad.out")"
    assert_eq "$(gt_go_calls)" "0" "F45 proxy asks after version $bad"
    assert_eq "$(gt_pushed)" "0" "F45 pushes after version $bad"
    assert_eq "$(gt_tags "$gt_bare")" "" "F45 tags after version $bad"
  done
  for ok in v0.2.3 v1.0.0-rc.1; do
    gt_publish "ver-$ok" PACKBIN_VERSION="$ok"
    assert_eq "$gt_code" "0" "F45 version $ok: $(tail -n 3 "$gt_dir/ver-$ok.out")"
    assert_eq "$(git --git-dir="$gt_bare" rev-parse "refs/tags/go/$ok^{commit}")" "$gt_head" "F45 tag go/$ok"
  done
  rm -rf "$gt_dir"

  gt_setup
  gt_publish otherversion GT_GO_ANSWER="github.com/zxsanny/packbin/go v0.1.8"
  [ "$gt_code" -ne 0 ] || fail "F45 a proxy answer for another version passed"
  [ "$(gt_go_calls)" -ge 1 ] || fail "F45 the proxy was not asked"
  grep -q 'go proxy try 1: github.com/zxsanny/packbin/go v0.1.8' "$gt_dir/otherversion.out" || fail "F45 the wrong answer is not shown: $(tail -n 3 "$gt_dir/otherversion.out")"
  gt_publish otherpath GT_GO_ANSWER="example.com/other v0.1.9"
  [ "$gt_code" -ne 0 ] || fail "F45 a proxy answer for another module passed"
  rm -rf "$gt_dir"
}

# The target table: go-tag follows the go language, needs GITHUB_TOKEN only for a github.com remote, and is the
# one final target.
gt_table_checks() {
  local script out
  script='source "$1"
printf "%s|%s|%s|%s\n" "$(targets_of_lang go)" "$(target_tier go-tag)" "$(missing_credentials go-tag)" "${PACKBIN_LANGS[*]}"'
  out="$(env -u GO_TAG_REGISTRY_URL -u GITHUB_TOKEN bash -c "$script" _ "$here/publish-lib.sh")"
  assert_eq "$out" "go-tag|final|GITHUB_TOKEN|csharp typescript python rust cpp java go swift" "go-tag table with the default remote"
  out="$(env GO_TAG_REGISTRY_URL=/srv/go.git bash -c "$script" _ "$here/publish-lib.sh")"
  assert_eq "$out" "go-tag|final||csharp typescript python rust cpp java go swift" "go-tag table with a local remote"
  out="$(env GITHUB_TOKEN=g bash -c "$script" _ "$here/publish-lib.sh")"
  assert_eq "$out" "go-tag|final||csharp typescript python rust cpp java go swift" "go-tag table with GITHUB_TOKEN"
  grep -qx 'for tier in required optional final; do' "$here/publish-upload.sh" || fail "the upload loop does not run the final tier last"
  grep -q 'ADR-004' "$here/publish-lib.sh" || fail "publish-lib.sh does not cite ADR-004"
}

# gt_gate_tree <name> [language to leave out]: a tree with a marker file of every language and the real gate scripts
# beside a stub publish-position.sh that prints the golden hex, or $GT_GO_HEX for go. Prints the tree's path.
gt_gate_tree() {
  local tree="$gt_gates/$1" wf lang
  wf="$tree/.github/workflows"
  mkdir -p "$wf" "$tree/fixtures" "$tree/csharp" "$tree/typescript" "$tree/python" "$tree/rust" "$tree/cpp" "$tree/java" "$tree/go"
  cp "$here/publish-lib.sh" "$here/publish-gate.sh" "$wf/"
  printf '%s\n' "$GT_GOLDEN" > "$tree/fixtures/golden.hex"
  : > "$tree/csharp/Packbin.csproj"
  : > "$tree/typescript/package.json"
  : > "$tree/python/pyproject.toml"
  : > "$tree/rust/Cargo.toml"
  : > "$tree/cpp/Makefile"
  : > "$tree/java/test.sh"
  : > "$tree/go/go.mod"
  cat > "$wf/publish-position.sh" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  go) printf '%s\n' "${GT_GO_HEX:?}" ;;
  *) cat "$SRC_ROOT/fixtures/golden.hex" ;;
esac
EOF
  if [ -n "${2:-}" ]; then
    lang="$2"
    rm -rf "${tree:?}/$lang"
  fi
  printf '%s\n' "$tree"
}

# AC-1 and AC-4 on the gate: a wrong Go byte publishes nothing and tags nothing; a good Go byte plans go last; a tree
# without go/ says `absent go` and plans the other six.
gt_gate_checks() {
  local tree out code
  gt_setup
  gt_gates="$gt_dir/gates"

  tree="$(gt_gate_tree bad)"
  set +e
  GT_GO_HEX="$GT_WRONG" SRC_ROOT="$tree" PACKBIN_DOCKER=0 PACKBIN_OUT="$tree/out" bash "$tree/.github/workflows/publish-gate.sh" > "$gt_dir/bad.out" 2>&1
  code=$?
  set -e
  [ "$code" -ne 0 ] || fail "AC-1 a Go mismatch passed the gate"
  grep -qx "pack go $GT_WRONG" "$gt_dir/bad.out" || fail "AC-1 the Go bytes are not printed: $(cat "$gt_dir/bad.out")"
  grep -qx 'mismatch 1' "$gt_dir/bad.out" || fail "AC-1 the mismatch is not counted: $(cat "$gt_dir/bad.out")"
  grep -qx 'publishing 0 packages' "$gt_dir/bad.out" || fail "AC-1 no 'publishing 0 packages' line"
  [ ! -s "$tree/out/publish-plan.txt" ] || fail "AC-1 the plan is not empty after a Go mismatch"
  if grep -q '^publish ' "$gt_dir/bad.out"; then
    fail "AC-1 a publish line after a Go mismatch"
  fi
  # The registry step with the empty plan of the failed gate: nothing built, nothing pushed, no Go tag.
  gt_publish afterbad PACKBIN_PLAN="$tree/out/publish-plan.txt"
  assert_eq "$gt_code" "0" "AC-1 publish with the empty plan"
  grep -qx 'publishing 0 packages' "$gt_dir/afterbad.out" || fail "AC-1 publish with the empty plan: $(cat "$gt_dir/afterbad.out")"
  assert_eq "$(gt_tags "$gt_bare")" "" "AC-1 Go tags after a Go mismatch"
  assert_eq "$(gt_pushed)" "0" "AC-1 pushes after a Go mismatch"

  tree="$(gt_gate_tree good)"
  GT_GO_HEX="$GT_GOLDEN" SRC_ROOT="$tree" PACKBIN_DOCKER=0 PACKBIN_OUT="$tree/out" bash "$tree/.github/workflows/publish-gate.sh" > "$gt_dir/good.out" 2>&1 \
    || fail "AC-1 a matching Go failed the gate: $(cat "$gt_dir/good.out")"
  assert_eq "$(paste -sd ' ' "$tree/out/publish-plan.txt")" "csharp typescript python rust cpp java go" "AC-1 plan with Go"
  grep -qx 'publish go' "$gt_dir/good.out" || fail "AC-1 no 'publish go' line"
  assert_eq "$(grep -c '^pack ' "$gt_dir/good.out")" "7" "AC-1 pack lines"

  tree="$(gt_gate_tree nogo go)"
  GT_GO_HEX="$GT_WRONG" SRC_ROOT="$tree" PACKBIN_DOCKER=0 PACKBIN_OUT="$tree/out" bash "$tree/.github/workflows/publish-gate.sh" > "$gt_dir/nogo.out" 2>&1 \
    || fail "AC-4 a tree without go/ failed the gate: $(cat "$gt_dir/nogo.out")"
  grep -qx 'absent go' "$gt_dir/nogo.out" || fail "AC-4 no 'absent go' line"
  assert_eq "$(paste -sd ' ' "$tree/out/publish-plan.txt")" "csharp typescript python rust cpp java" "AC-4 plan without Go"
  assert_eq "$(grep -c '^pack ' "$gt_dir/nogo.out")" "6" "AC-4 pack lines"
  assert_eq "$(grep '^mismatch ' "$gt_dir/nogo.out")" "mismatch 0" "AC-4 mismatch"
  out="$(env SRC_ROOT="$tree" bash "$here/publish-position.sh" go 2>&1)" && code=0 || code=$?
  assert_eq "$code" "2" "AC-4 publish-position.sh go exit code"
  assert_eq "$out" "absent go" "AC-4 publish-position.sh go message"
  # A plan without go builds and uploads no go-tag: the target is planned from the plan alone.
  printf 'csharp\n' > "$gt_plan"
  gt_publish nogo-publish
  [ "$gt_code" -ne 0 ] || fail "AC-4 the csharp plan passed without NUGET_TOKEN"
  grep -q 'go-tag' "$gt_dir/nogo-publish.out" && fail "AC-4 go-tag was planned for a plan without go: $(cat "$gt_dir/nogo-publish.out")"
  assert_eq "$(gt_tags "$gt_bare")" "" "AC-4 Go tags without go/"
  rm -rf "$gt_dir"
}

# The Go build of the ring and gate programs (ring-go.sh, run by publish-position.sh go): `go build` needs -C as
# its FIRST flag, and -buildvcs=false in every form (CI run 38422313279: git refuses the runner-owned checkout in
# the container; CI run 38431216035: `-buildvcs=false -C` is "invalid value for flag -C" with a host go).
gt_build_flag_checks() {
  local script="$here/ring-go.sh" line
  while IFS= read -r line; do
    case "$line" in
      *"go build -C "*"-buildvcs=false"* | *"go build -buildvcs=false -o"*) ;;
      *) fail "ring-go.sh: a go build line has no -buildvcs=false, or a flag before -C: $line" ;;
    esac
    case "$line" in
      *"go build -buildvcs=false -C"*) fail "ring-go.sh: -C is not the first flag of go build: $line" ;;
    esac
  done < <(grep -E '(^|[ ])go build ' "$script" | grep -v '^[[:space:]]*#')
  [ "$(grep -cE '(^|[ ])go build ' "$script")" -ge 2 ] || fail "ring-go.sh: the host and container go build lines are not both there"
}

go_checks() {
  gt_build_flag_checks
  gt_tag_checks
  gt_rerun_checks
  gt_visibility_checks
  gt_refusal_checks
  gt_version_checks
  gt_table_checks
  gt_gate_checks
}

if [ "$go_standalone" = 1 ]; then
  go_checks
  if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
  fi
  echo "go release checks passed"
fi
