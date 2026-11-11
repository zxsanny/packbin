#!/usr/bin/env bash
# Sourced by publish-dart.test.sh (dt_setup, dt_tree, dt_publish, dt_calls, dt_jwt, $dt_oidc, $dt_dir, $dt_log, $dt_bin, fail,
# assert_eq): the pub.dev OIDC token (AZ-4149 R8, R10; ADR-011). publish-pubdev.sh asks GitHub for the token right before
# its upload, so it cannot be stale; no other upload tool sees PUB_TOKEN and dart sees no other credential. Every network
# call and every upload is a stub; the token is never printed.
# shellcheck disable=SC2154

# The line number in $dt_log of the first line that matches grep pattern $1, empty when none does.
dt_first_line() {
  grep -n -m 1 -e "$1" "$dt_log" | cut -d: -f1 || true
}

# R8: the request shape, the order after the build phase, and a token that is never printed.
dt_token_request_checks() {
  local tree token dry oidc add publish
  dt_setup
  tree="$(dt_tree token)"
  token="$(dt_jwt 600)"
  dt_publish "$tree" mint "dart" "${dt_oidc[@]}" DT_MINT_JWT="$token" PUB_TOKEN=stale-early-token DT_PUBDEV=other
  assert_eq "$dt_code" "0" "R8 an upload with a minted token: $(tail -n 4 "$dt_dir/mint.out")"
  assert_eq "$(dt_calls '^curl .*oidc.example')" "1" "R8 one token request"
  grep -q '^curl .* https://oidc.example/req?x=1&audience=https%3A%2F%2Fpub.dev$' "$dt_log" \
    || fail "R8 the request is not the request URL plus the audience https://pub.dev: $(grep oidc.example "$dt_log")"
  grep -qxF 'curl-header Authorization: Bearer reqtok-123' "$dt_log" || fail "R8 the bearer header of the request token is missing: $(grep curl-header "$dt_log")"
  grep '^curl .*oidc.example' "$dt_log" | grep -qe '-X \|--data\|--request' && fail "R8 the token request is not a GET"
  grep '^curl ' "$dt_log" | grep -q 'reqtok-123' && fail "R8 the request token is on a command line"
  grep -qx 'token-add PUB_TOKEN set=yes' "$dt_log" || fail "R8 the token is not in the environment of dart pub token add"
  grep -qxF 'publish-env credentials=[] token-is-minted=yes' "$dt_log" \
    || fail "R8 dart pub publish does not see the minted token alone: $(grep '^publish-env' "$dt_log")"

  # The token is made after the build phase (the dry run is in it), registered, then used by the upload.
  dry="$(dt_first_line '^dart pub publish --dry-run')"
  oidc="$(dt_first_line '^curl .*oidc.example')"
  add="$(dt_first_line '^dart pub token add')"
  publish="$(dt_first_line '^dart pub publish --force')"
  if [ -z "$dry" ] || [ -z "$oidc" ] || [ -z "$add" ] || [ -z "$publish" ] || [ "$dry" -ge "$oidc" ] || [ "$oidc" -ge "$add" ] || [ "$add" -ge "$publish" ]; then
    fail "R8 the order is not build (dry run $dry), token request ($oidc), token add ($add), publish ($publish)"
  fi

  # Never printed: only the ::add-mask:: command carries it, in the output and in every logged call.
  grep -qx "::add-mask::$token" "$dt_dir/mint.out" || fail "R8 the token is not masked"
  grep -v '^::add-mask::' "$dt_dir/mint.out" | grep -qF "$token" && fail "R8 the token is printed: $(grep -F "$token" "$dt_dir/mint.out")"
  grep -qF "$token" "$dt_log" && fail "R8 the token is on a command line"
  grep -q 'stale-early-token' "$dt_log" "$dt_dir/mint.out" && fail "R8 the early PUB_TOKEN of setup-dart was used or printed"
  rm -rf "$dt_dir"
}

# R8: a token request that fails, or answers without a token, uploads nothing and says to run the tag again; a token that
# expired or is not a JWT is refused likewise (publish-dart.test.sh dt_upload_checks).
dt_token_failure_checks() {
  local tree mode
  dt_setup
  tree="$(dt_tree failing)"
  for mode in down unreachable empty; do
    : > "$dt_log"
    dt_publish "$tree" "oidc-$mode" "dart" "${dt_oidc[@]}" DT_OIDC="$mode" DT_MINT_JWT="$(dt_jwt 600)" DT_PUBDEV=other
    [ "$dt_code" -ne 0 ] || fail "R8 a token request that answers [$mode] did not fail the run"
    grep -q 'nothing was uploaded; run the tag again' "$dt_dir/oidc-$mode.out" \
      || fail "R8 [$mode] is not explained: $(tail -n 3 "$dt_dir/oidc-$mode.out")"
    assert_eq "$(dt_calls 'pub publish --force')/$(dt_calls 'pub token add')" "0/0" "R8 an upload or a registration after [$mode]"
  done
  grep -q 'GitHub answered 503' "$dt_dir/oidc-down.out" || fail "R8 the status of a failing request is not named: $(tail -n 3 "$dt_dir/oidc-down.out")"
  rm -rf "$dt_dir"
}

# R10: publish-upload.sh on a csharp and a pubdev target with every secret and the early PUB_TOKEN in its environment.
# The csharp tool (the dotnet stub) never sees PUB_TOKEN; the dart stub sees the token that was minted for it and no
# credential of another registry (not even the OIDC request variables); the token is requested after the csharp upload.
dt_token_scope_checks() {
  local tree token art words
  dt_setup
  tree="$(dt_tree scope)"
  token="$(dt_jwt 600)"
  dt_publish "$tree" built "dart" "${dt_oidc[@]}" DT_MINT_JWT="$token" DT_PUBDEV=other
  assert_eq "$dt_code" "0" "R10 the build for the scope check: $(tail -n 3 "$dt_dir/built.out")"
  art="$dt_dir/out-built/artifacts"
  mkdir -p "$art/csharp"
  : > "$art/csharp/Packbin.9.8.7.nupkg"
  echo 'build ok csharp' >> "$art/build.log"
  : > "$dt_log"
  set +e
  env PACKBIN_DOCKER=0 SRC_ROOT="$tree" PACKBIN_OUT="$dt_dir/out-built" PACKBIN_VERSION=v9.8.7 PACKBIN_QUERY_PAUSE=0 \
    DT_LOG="$dt_log" DT_PUBDEV=other PATH="$dt_bin:$PATH" NUGET_TOKEN=n-secret GITHUB_TOKEN=g-secret MAVEN_CENTRAL_TOKEN=m-secret \
    PUB_TOKEN=stale-early-token "${dt_oidc[@]}" DT_MINT_JWT="$token" \
    bash "$tree/.github/workflows/publish-upload.sh" csharp pubdev > "$dt_dir/scope.out" 2>&1 < /dev/null
  dt_code=$?
  set -e
  assert_eq "$dt_code" "0" "R10 the upload of csharp and pubdev: $(tail -n 4 "$dt_dir/scope.out")"
  assert_eq "$(dt_calls '^dotnet nuget push')/$(dt_calls '^dart pub publish --force')" "1/1" "R10 both uploads ran"
  words=" $(grep '^dotnet-env' "$dt_log" | sed 's/^dotnet-env credentials=\[\(.*\)\]$/\1/') "
  case "$words" in *" PUB_TOKEN "*) fail "R10 the csharp upload tool sees PUB_TOKEN" ;; esac
  case "$words" in *" NUGET_TOKEN "*) ;; *) fail "R10 the csharp upload tool lost its own credential: [$words]" ;; esac
  grep -qxF 'publish-env credentials=[] token-is-minted=yes' "$dt_log" \
    || fail "R10 dart pub publish sees a credential of another registry or not the minted token: $(grep '^publish-env' "$dt_log")"
  [ "$(dt_first_line '^dotnet nuget push')" -lt "$(dt_first_line '^curl .*oidc.example')" ] || fail "R8 the token was requested before the csharp upload"
  grep -qF "$token" "$dt_log" && fail "R8 the token is on a command line"
  grep -v '^::add-mask::' "$dt_dir/scope.out" | grep -qF "$token" && fail "R8 the token is printed by the upload phase"
  rm -rf "$dt_dir"
}

dart_token_checks() {
  dt_token_request_checks
  dt_token_failure_checks
  dt_token_scope_checks
}
