#!/usr/bin/env bash
# Swift release scenarios (AZ-2523, ADR-005; AC-1 to AC-5). Sourced by publish-gate.test.sh after publish-go.test.sh
# (it defines fail, assert_eq, not_run, $root and $here; publish-go.test.sh gt_write_go), or run on its own:
# bash publish-swift.test.sh. publish-swift-gate.test.sh (sourced below) holds the gate, position, static, real-swift
# and mutation scenarios: the last proves every guard of both files against mutated copies of the scripts.
# Git runs for real on local repositories: a source repository (the release commit, tagged v0.1.9) and a bare one
# named packbin.git that stands for GitHub, whose pre-receive hook logs every push. Most scenarios use a `swift`
# stub that resolves for real through git (the pin is the commit the bare repository's tag names) and logs each
# call; sw_real_checks runs the real `swift package resolve` and `swift build` on that bare repository, which
# fetches swift-crypto and swift-asn1 from github.com (owner decision S-2), and is NOT RUN without swift.
# No Docker: the gate runs on a synthetic tree whose position scripts are stubs.

sw_standalone=0
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  root="$(cd "$here/../.." && pwd)"
  failures=0
  not_run=""
  sw_standalone=1
  fail() {
    echo "FAIL: $*" >&2
    failures=$((failures + 1))
  }
  assert_eq() {
    if [ "$1" != "$2" ]; then
      fail "$3: expected [$2] got [$1]"
    fi
  }
  # shellcheck source=publish-go.test.sh
  source "$here/publish-go.test.sh"
fi

SW_GOLDEN="4001000065cd1d00a3e1110100"
SW_WRONG="4001000065cd1d00a3e1110101"
SW_CREDENTIALS="NUGET_TOKEN NPM_TOKEN PYPI_TOKEN CARGO_REGISTRY_TOKEN MAVEN_CENTRAL_TOKEN MAVEN_GPG_PRIVATE_KEY PLATFORMIO_AUTH_TOKEN IDF_COMPONENT_API_TOKEN GITHUB_TOKEN ACTIONS_ID_TOKEN_REQUEST_URL ACTIONS_ID_TOKEN_REQUEST_TOKEN"
# The scripts under test; publish-swift-mutants.test.sh points it at a mutated copy.
sw_wf="$here"
# The real swift, found before any stub goes on PATH.
sw_real_swift="$(command -v swift || true)"

sw_git() {
  git -c user.name=test -c user.email=test@example.com -c commit.gpgsign=false -c init.defaultBranch=main "$@"
}

# Every ref of bare repository $1 with its object, one line.
sw_refs() {
  git --git-dir="$1" for-each-ref --format='%(refname)=%(objectname)' | paste -sd ' ' -
}

# A `swift` stub: logs `<args>|tags=<tags of the bare repository>`; `package ... resolve` fails the first
# $SW_RESOLVE_FAILS calls, else reads the URL and version of the consumer manifest (kept in $SW_SWIFT_LOG.manifest),
# looks up the tag v<version> in that repository with git and writes Package.resolved (location, version and
# revision replaceable by SW_PIN_LOCATION, SW_PIN_VERSION, SW_PIN_REVISION); `build` fails the first $SW_BUILD_FAILS
# calls and needs a main.swift that imports Packbin. Every call fails when a variable named in $SW_DENY_CREDENTIALS is set.
sw_write_swift() {
  cat > "$1/swift" <<'EOF'
#!/bin/bash
printf '%s|tags=%s\n' "$*" "$(git --git-dir="$SW_BARE" for-each-ref --format='%(refname:short)' refs/tags | paste -sd , -)" >> "$SW_SWIFT_LOG"
for var in ${SW_DENY_CREDENTIALS:-}; do
  if [ -n "${!var+set}" ]; then echo "error: $var is set in the environment of swift $1" >&2; exit 1; fi
done
if [ "${1:-}" = --version ]; then echo "Swift version 6.1.2 (stub)"; exit 0; fi
pkg="" prev=""
for arg in "$@"; do
  if [ "$prev" = --package-path ]; then pkg="$arg"; fi
  prev="$arg"
done
calls="$(grep -c "^$1 " "$SW_SWIFT_LOG")"
case "$1" in
  package)
    cp "$pkg/Package.swift" "$SW_SWIFT_LOG.manifest"
    if [ "$calls" -le "${SW_RESOLVE_FAILS:-0}" ]; then echo "error: Failed to clone repository" >&2; exit 1; fi
    url="$(sed -n 's/^ *\.package(url: "\(.*\)", exact: "[^"]*"),$/\1/p' "$pkg/Package.swift")"
    ver="$(sed -n 's/^ *\.package(url: ".*", exact: "\([^"]*\)"),$/\1/p' "$pkg/Package.swift")"
    rev="$(git --git-dir="$url" rev-parse --verify --quiet "refs/tags/v$ver^{commit}")" || { echo "error: no version $ver" >&2; exit 1; }
    printf '{"pins":[{"identity":"packbin","kind":"localSourceControl","location":"%s","state":{"revision":"%s","version":"%s"}}],"version":2}\n' \
      "${SW_PIN_LOCATION:-$url}" "${SW_PIN_REVISION:-$rev}" "${SW_PIN_VERSION:-$ver}" > "$pkg/Package.resolved"
    ;;
  build)
    if [ "$calls" -le "${SW_BUILD_FAILS:-0}" ]; then echo "error: build failed" >&2; exit 1; fi
    grep -qx 'import Packbin' "$pkg/Sources/consumer/main.swift" || { echo "error: no import Packbin" >&2; exit 1; }
    ;;
  *) exit 2 ;;
esac
EOF
  chmod +x "$1/swift"
}

# sw_setup: $sw_dir with a source repository (the Swift package, its position program, go/go.mod and go/LICENSE; one
# commit, tagged v0.1.9), the bare repository packbin.git holding that commit and tag (then a pre-receive hook that
# logs each push), the swift stub and the plan file.
sw_setup() {
  sw_dir="$(mktemp -d)"
  sw_src="$sw_dir/src"
  sw_bare="$sw_dir/packbin.git"
  sw_bin="$sw_dir/bin"
  sw_plan="$sw_dir/plan.txt"
  sw_pushes="$sw_dir/pushes.log"
  sw_log="$sw_dir/swift.log"
  sw_golog="$sw_dir/go.log"
  : > "$sw_pushes"
  : > "$sw_log"
  : > "$sw_golog"
  mkdir -p "$sw_bin" "$sw_src/go" "$sw_src/.github/workflows/drivers/handoff-swift/Sources/position"
  cp "$root/Package.swift" "$root/Package.resolved" "$root/LICENSE" "$sw_src/"
  tar -C "$root" --exclude .build --exclude .swiftpm -cf - swift | tar -C "$sw_src" -xf -
  cp "$root/.github/workflows/drivers/handoff-swift/Sources/position/main.swift" \
    "$sw_src/.github/workflows/drivers/handoff-swift/Sources/position/main.swift"
  cp "$root/go/go.mod" "$root/go/LICENSE" "$sw_src/go/"
  sw_git -C "$sw_src" init -q
  sw_git -C "$sw_src" add -A
  sw_git -C "$sw_src" commit -q -m "release commit"
  sw_git -C "$sw_src" tag v0.1.9
  git init -q --bare "$sw_bare"
  git -C "$sw_src" push -q "$sw_bare" HEAD:refs/heads/main refs/tags/v0.1.9 < /dev/null
  printf '#!/bin/sh\nwhile read old new ref; do echo "push $ref $new" >> "%s"; done\n' "$sw_pushes" > "$sw_bare/hooks/pre-receive"
  chmod +x "$sw_bare/hooks/pre-receive"
  sw_write_swift "$sw_bin"
  gt_write_go "$sw_bin"
  printf 'swift\n' > "$sw_plan"
  sw_head="$(git -C "$sw_src" rev-parse HEAD)"
  sw_refs0="$(sw_refs "$sw_bare")"
}

# sw_publish <name> [VAR=value ...]: publish-registries.sh of $sw_wf on the plan with the stubs on PATH; output in
# $sw_dir/<name>.out, exit code in $sw_code. No registry credential is set; both remotes are the bare repository.
sw_publish() {
  local name="$1" unset_args=() var
  shift
  for var in $SW_CREDENTIALS; do
    unset_args+=(-u "$var")
  done
  set +e
  env "${unset_args[@]}" PACKBIN_PUBLISH=1 PACKBIN_DOCKER=0 SRC_ROOT="$sw_src" PACKBIN_PLAN="$sw_plan" \
    PACKBIN_OUT="$sw_dir/out-$name" PACKBIN_VERSION=v0.1.9 SWIFT_PACKAGE_URL="$sw_bare" GO_TAG_REGISTRY_URL="$sw_bare" \
    PACKBIN_QUERY_PAUSE=0 PACKBIN_SWIFT_PAUSE=0 PACKBIN_SWIFT_WINDOW=0 PACKBIN_GO_PROXY_PAUSE=0 PACKBIN_GO_PROXY_WINDOW=0 PACKBIN_GO_PROXY_SETTLE=0 PACKBIN_GO_TAG_PAUSE=0 \
    SW_BARE="$sw_bare" SW_SWIFT_LOG="$sw_log" GT_BARE="$sw_bare" GT_GO_LOG="$sw_golog" PATH="$sw_bin:$PATH" "$@" \
    bash "$sw_wf/publish-registries.sh" > "$sw_dir/$name.out" 2>&1 < /dev/null
  sw_code=$?
  set -e
}

sw_calls() {
  grep -c "^$1 " "$sw_log" || true
}

# The bare repository's refs are the ones sw_setup pushed, and no push reached it ($1 names the moment).
sw_assert_untouched() {
  assert_eq "$(sw_refs "$sw_bare")" "$sw_refs0" "$1: refs of the bare repository"
  assert_eq "$(wc -l < "$sw_pushes" | tr -d ' ')" "0" "$1: pushes to the bare repository"
  assert_eq "$(git -C "$sw_src" tag -l | paste -sd ' ' -)" "v0.1.9" "$1: tags of the source repository"
}

# AC-2: a dry run builds and checks the target and runs no swift; a publish resolves the tag in a fresh consumer and
# builds it; a resolve or build that fails is retried, and one that never works fails the step with no tag written.
sw_check_checks() {
  local first
  sw_setup
  sw_publish dry PACKBIN_BUILD_ONLY=1
  assert_eq "$sw_code" "0" "AC-2 dry run exit code: $(tail -n 3 "$sw_dir/dry.out")"
  grep -qx 'build ok swift-check' "$sw_dir/dry.out" && grep -qx 'check ok: swift-check' "$sw_dir/dry.out" \
    || fail "AC-2 dry run did not build and check swift-check: $(tail -n 3 "$sw_dir/dry.out")"
  assert_eq "$(cat "$sw_dir/out-dry/artifacts/swift-check/tag.txt" 2>&1)" "v0.1.9 $sw_head" "AC-2 tag.txt"
  assert_eq "$(sw_calls package)" "0" "AC-2 dry run resolves"
  sw_assert_untouched "AC-2 dry run"

  sw_publish first
  assert_eq "$sw_code" "0" "AC-2 publish exit code: $(tail -n 4 "$sw_dir/first.out")"
  grep -qx 'upload swift-check' "$sw_dir/first.out" || fail "AC-2 the swift check did not run in the upload phase"
  grep -qx "swift consumer resolves $sw_bare 0.1.9 at $sw_head and builds Packbin (try 1)" "$sw_dir/first.out" \
    || fail "AC-2 no pass line: $(tail -n 3 "$sw_dir/first.out")"
  assert_eq "$(sw_calls package)/$(sw_calls build)" "1/1" "AC-2 resolve and build calls"
  first="$(grep '^package ' "$sw_log" | sed -n 1p)"
  case "$first" in
    "package --package-path "*"/consumer --scratch-path "*"/try-1/build --cache-path "*"/try-1/cache --config-path "*"/try-1/config --security-path "*"/try-1/security resolve|tags=v0.1.9") ;;
    *) fail "AC-2 the resolve does not run in a fresh consumer state: $first" ;;
  esac
  assert_eq "$(grep '^build ' "$sw_log" | cut -d'|' -f1)" "build $(sed 's/^package //; s/ resolve|.*$//' <<< "$first")" \
    "AC-2 the build uses the resolve's consumer state"
  grep -qx '// swift-tools-version: 6.0' "$sw_log.manifest" || fail "AC-2 consumer tools version"
  grep -qxF "        .package(url: \"$sw_bare\", exact: \"0.1.9\")," "$sw_log.manifest" || fail "AC-2 consumer dependency: $(grep package "$sw_log.manifest")"
  grep -qF '.product(name: "Packbin", package: "packbin")' "$sw_log.manifest" || fail "AC-2 consumer product"
  sw_assert_untouched "AC-2 publish"
  rm -rf "$sw_dir"

  sw_setup
  sw_publish retry SW_RESOLVE_FAILS=2 SW_BUILD_FAILS=1 PACKBIN_SWIFT_WINDOW=60
  assert_eq "$sw_code" "0" "AC-2 retry exit code: $(tail -n 4 "$sw_dir/retry.out")"
  assert_eq "$(sw_calls package)/$(sw_calls build)" "4/2" "AC-2 resolves and builds until both work"
  grep -q '^swift check try 1: swift package resolve failed; error: Failed to clone repository' "$sw_dir/retry.out" \
    && grep -q '^swift check try 3: swift build failed; error: build failed' "$sw_dir/retry.out" || fail "AC-2 retry lines: $(cat "$sw_dir/retry.out")"
  grep -q 'builds Packbin (try 4)$' "$sw_dir/retry.out" || fail "AC-2 no pass on try 4"
  : > "$sw_log"
  sw_publish never SW_RESOLVE_FAILS=999 PACKBIN_SWIFT_WINDOW=2
  [ "$sw_code" -ne 0 ] || fail "AC-2 a resolve that never works passed"
  [ "$(sw_calls package)" -ge 2 ] || fail "AC-2 the resolve was tried once only"
  grep -q 'did not resolve and build after [0-9]* tries in 2s; no tag was created, moved or deleted' "$sw_dir/never.out" \
    || fail "AC-2 the failure line: $(tail -n 2 "$sw_dir/never.out")"
  sw_assert_untouched "AC-2 failed check"
  rm -rf "$sw_dir"
}

# AC-3, SW-16: a re-run resolves the same commit and passes; a tag at another commit than the run's fails at once naming
# both (nothing built); a pin of another version or location fails too; the build phase refuses a local tag at another
# commit and a checkout without .git. Refs never change.
sw_rerun_checks() {
  local other
  sw_setup
  sw_publish first
  sw_publish same
  assert_eq "$sw_code" "0" "AC-3 re-run exit code: $(tail -n 3 "$sw_dir/same.out")"
  grep -qx "swift consumer resolves $sw_bare 0.1.9 at $sw_head and builds Packbin (try 1)" "$sw_dir/same.out" || fail "AC-3 re-run line"
  assert_eq "$(sw_calls package)/$(sw_calls build)" "2/2" "AC-3 the re-run checks again"
  sw_assert_untouched "AC-3 re-run"

  sw_git -C "$sw_src" commit -q --allow-empty -m "another commit"
  other="$(git -C "$sw_src" rev-parse HEAD)"
  sw_git -C "$sw_src" tag -d v0.1.9 > /dev/null
  sw_publish moved
  sw_git -C "$sw_src" tag v0.1.9 "$sw_head"
  [ "$sw_code" -ne 0 ] || fail "AC-3 a tag at another commit passed"
  grep -qF "swift package $sw_bare resolves 0.1.9 to [0.1.9 $sw_head], but v0.1.9 is at $other" "$sw_dir/moved.out" \
    || fail "AC-3 the message does not name both commits: $(tail -n 2 "$sw_dir/moved.out")"
  assert_eq "$(sw_calls package)/$(sw_calls build)" "3/2" "AC-3 calls after a tag at another commit"
  sw_assert_untouched "AC-3 tag at another commit"
  rm -rf "$sw_dir"

  sw_setup
  sw_publish version SW_PIN_VERSION=0.1.8
  [ "$sw_code" -ne 0 ] || fail "AC-3 a pin of another version passed"
  grep -qF "resolves 0.1.9 to [0.1.8 $sw_head]" "$sw_dir/version.out" || fail "AC-3 version message: $(tail -n 2 "$sw_dir/version.out")"
  sw_publish location SW_PIN_LOCATION=/elsewhere/packbin.git
  [ "$sw_code" -ne 0 ] || fail "AC-3 a pin of another location passed"
  grep -qF "resolves 0.1.9 to [no pin]" "$sw_dir/location.out" || fail "AC-3 location message: $(tail -n 2 "$sw_dir/location.out")"
  assert_eq "$(sw_calls build)" "0" "AC-3 builds after a wrong pin"

  sw_git -C "$sw_src" commit -q --allow-empty -m "after the tag"
  other="$(git -C "$sw_src" rev-parse HEAD)"
  sw_publish localtag
  [ "$sw_code" -ne 0 ] || fail "AC-3 a local tag at another commit passed"
  grep -qF "tag v0.1.9 is at $sw_head, but the checkout is at $other" "$sw_dir/localtag.out" || fail "AC-3 local tag message"
  mv "$sw_src/.git" "$sw_dir/dot-git"
  sw_publish nogit
  mv "$sw_dir/dot-git" "$sw_src/.git"
  [ "$sw_code" -ne 0 ] || fail "AC-3 a checkout without .git passed"
  grep -q 'swift-check needs a git checkout of the tag' "$sw_dir/nogit.out" || fail "AC-3 nogit message: $(tail -n 2 "$sw_dir/nogit.out")"
  assert_eq "$(sw_calls package)" "2" "AC-3 resolves after the build refusals"
  sw_assert_untouched "AC-3 refusals"
  rm -rf "$sw_dir"
}

# sw_refused <name> <expected message> [VAR=value ...]: the publish fails before any swift call, with the message.
sw_refused() {
  local name="$1" want="$2"
  shift 2
  : > "$sw_log"
  sw_publish "$name" "$@"
  [ "$sw_code" -ne 0 ] || fail "AC-5 $name passed"
  grep -qF -- "$want" "$sw_dir/$name.out" || fail "AC-5 $name message: $(tail -n 2 "$sw_dir/$name.out")"
  assert_eq "$(sw_calls package)" "0" "AC-5 $name resolves"
}

# sw_edit <file> <old> <new>: replaces the first <old> in <file> (fixed strings); fails the test if absent.
sw_edit() {
  python3 -I -c 'import sys; p, old, new = sys.argv[1:4]; s = open(p).read(); assert old in s, old; open(p, "w").write(s.replace(old, new, 1))' "$@"
}

# AC-5 and the build check: a manifest, license, version or consumer the check refuses stops the run before the resolve;
# so do a URL that cannot be a Swift string and a host without swift.
sw_refusal_checks() {
  local bad old new want n=0 tools dir cmd ok
  sw_setup
  cp "$sw_src/Package.swift" "$sw_dir/Package.swift"
  for bad in "// swift-tools-version: 6.0|// swift-tools-version: 5.9|Package.swift does not declare swift-tools-version: 6.0" \
    ".macOS(.v12)|.macOS(.v13)|Package.swift does not declare iOS 15 and macOS 12" \
    ".iOS(.v15)|.iOS(.v16)|Package.swift does not declare iOS 15 and macOS 12" \
    '.library(name: "Packbin"|.library(name: "PackbinKit"|Package.swift has no library product Packbin' \
    "import PackageDescription|import PackageDescription // SPDX-License-Identifier: Apache-2.0|a license identifier that is not MIT: Apache-2.0"; do
    IFS='|' read -r old new want <<< "$bad"
    n=$((n + 1))
    sw_edit "$sw_src/Package.swift" "$old" "$new"
    sw_git -C "$sw_src" commit -q -am "bad manifest $n"
    sw_git -C "$sw_src" tag -f v0.1.9 > /dev/null
    sw_refused "manifest-$n" "check failed: swift-check: $want"
    cp "$sw_dir/Package.swift" "$sw_src/Package.swift"
  done
  sw_git -C "$sw_src" commit -q -am "good manifest"
  sw_git -C "$sw_src" tag -f v0.1.9 > /dev/null
  printf 'Apache License\nVersion 2.0\n' > "$sw_src/LICENSE"
  sw_git -C "$sw_src" commit -q -am "bad license"
  sw_git -C "$sw_src" tag -f v0.1.9 > /dev/null
  sw_refused license "check failed: swift-check: LICENSE is not the MIT license text"
  cp "$root/LICENSE" "$sw_src/LICENSE"
  sw_edit "$sw_src/.github/workflows/drivers/handoff-swift/Sources/position/main.swift" "import Packbin" "import Foundation"
  sw_git -C "$sw_src" commit -q -am "consumer without Packbin"
  sw_git -C "$sw_src" tag -f v0.1.9 > /dev/null
  sw_refused consumer "check failed: swift-check: the consumer main.swift does not import Packbin"
  sw_edit "$sw_src/.github/workflows/drivers/handoff-swift/Sources/position/main.swift" "import Foundation" "import Packbin"
  sw_git -C "$sw_src" commit -q -am "good again"
  sw_git -C "$sw_src" tag -f v0.1.9 > /dev/null
  for bad in v1.2 v01.2.3 v1.2.3- v1.2.3+; do
    sw_refused "ver-$bad" "check failed: swift-check: version ${bad#v} is not a semantic version SwiftPM resolves" PACKBIN_VERSION="$bad"
  done
  sw_refused quote 'holds a quote, a backslash or a line break' SWIFT_PACKAGE_URL="$sw_bare\"x"
  # A PATH with the tools the publish scripts call, and no swift.
  tools="$sw_dir/no-swift"
  mkdir -p "$tools"
  for cmd in bash env git python3 mkdir rm cat grep sed tail head tr wc cp mktemp dirname basename paste sort tee chmod \
    ls id uname awk find touch mv sleep seq cut cmp curl; do
    dir="$(command -v "$cmd")" && ln -s "$dir" "$tools/$cmd"
  done
  sw_publish noswift PATH="$tools"
  [ "$sw_code" -ne 0 ] || fail "AC-5 a host without swift passed"
  grep -qx 'swift is required before any registry write' "$sw_dir/noswift.out" || fail "AC-5 noswift message: $(tail -n 2 "$sw_dir/noswift.out")"
  [ ! -e "$sw_dir/out-noswift/artifacts" ] || fail "AC-5 a build started without swift"
  sw_assert_untouched "AC-5 refusals"
  for ok in v1.0.0-rc.1 v0.2.3 v2.0.0+build.5; do
    sw_publish "ok-$ok" PACKBIN_BUILD_ONLY=1 PACKBIN_VERSION="$ok"
    assert_eq "$sw_code" "0" "AC-5 version $ok: $(tail -n 2 "$sw_dir/ok-$ok.out")"
  done
  rm -rf "$sw_dir"
}

# shellcheck source=publish-swift-gate.test.sh
source "$here/publish-swift-gate.test.sh"

# sw_real_checks (the real swift fetches and builds, about two minutes) shares nothing with the stub scenarios and the
# mutants (own mktemp directories, no stdin), so it runs beside them in a subshell; its failure count and its
# NOT RUN note come back through a status file.
# shellcheck disable=SC2030,SC2031  # the subshell keeps its own counters on purpose; sw_real_join adds them
sw_real_beside() {
  local real_dir real_failures real_not_run
  real_dir="$(mktemp -d)"
  (
    failures=0
    not_run=""
    sw_real_checks
    printf '%s\n%s\n' "$failures" "$not_run" > "$real_dir/status"
  ) > "$real_dir/out" 2> "$real_dir/err" < /dev/null &
  sw_real_pid=$!
  sw_real_dir="$real_dir"
}

# shellcheck disable=SC2030,SC2031  # failures and not_run here are the parent shell's
sw_real_join() {
  local real_failures real_not_run real_rc=0
  wait "$sw_real_pid" || real_rc=$?
  cat "$sw_real_dir/out"
  cat "$sw_real_dir/err" >&2
  if [ -s "$sw_real_dir/status" ]; then
    { read -r real_failures; read -r real_not_run; } < "$sw_real_dir/status"
    failures=$((failures + real_failures))
    if [ -n "$real_not_run" ]; then
      not_run="${not_run:+$not_run, }$real_not_run"
    fi
    [ "$real_rc" -eq 0 ] || fail "sw_real_checks exited $real_rc after it reported"
  else
    fail "sw_real_checks stopped before it finished (exit $real_rc)"
  fi
  rm -rf "$sw_real_dir"
}

swift_checks() {
  sw_real_beside
  sw_check_checks
  sw_rerun_checks
  sw_refusal_checks
  sw_gate_checks
  sw_position_checks
  sw_static_checks
  sw_credential_checks
  sw_mutant_checks
  sw_real_join
}

if [ "$sw_standalone" = 1 ]; then
  swift_checks
  if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
  fi
  if [ -n "$not_run" ]; then
    echo "swift release checks: no failures, NOT RUN: $not_run"
  else
    echo "swift release checks passed"
  fi
fi
