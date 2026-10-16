#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
expected="4001000065cd1d00a3e1110100"
failures=0
# Checks that could not run here (a missing tool outside GitHub Actions): named in the last line, never counted as passed.
not_run=""

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

assert_eq() {
  if [ "$1" != "$2" ]; then
    fail "$3: expected [$2] got [$1]"
  fi
}

static_checks() {
  local test_yml="$root/.github/workflows/test.yml"
  local publish_yml="$root/.github/workflows/publish.yml"
  local registries="$root/.github/workflows/publish-registries.sh"
  for token in NPM_TOKEN NUGET_TOKEN PYPI_TOKEN CARGO_REGISTRY_TOKEN MAVEN_CENTRAL_TOKEN \
    MAVEN_GPG_PRIVATE_KEY PLATFORMIO_AUTH_TOKEN IDF_COMPONENT_API_TOKEN; do
    if grep -q "$token" "$test_yml"; then
      fail "test workflow contains $token"
    fi
  done
  if grep -q 'microsoft/vcpkg' "$registries" || grep -q 'gh pr' "$registries"; then
    fail "cpp publish is not a git push of this registry"
  fi
  local gate_line publish_line
  gate_line="$(grep -n 'publish-gate.sh' "$publish_yml" | head -n 1 | cut -d: -f1)"
  publish_line="$(grep -n 'publish-registries.sh' "$publish_yml" | head -n 1 | cut -d: -f1)"
  if [ -z "$gate_line" ] || [ -z "$publish_line" ] || [ "$gate_line" -ge "$publish_line" ]; then
    fail "registries run before the golden gate"
  fi
  bash "$here/publish-timing.selftest.sh" || fail "AZ-2563 publish-timing.selftest.sh failed"
}

registry_checks() {
  local tmp plan log bin
  tmp="$(mktemp -d)"
  plan="$tmp/plan.txt"
  log="$tmp/log.txt"
  bin="$tmp/bin"
  mkdir -p "$bin"
  cat > "$bin/dotnet" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$PACKBIN_PUBLISH_LOG"
exit 0
EOF
  cat > "$bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$PACKBIN_PUBLISH_LOG"
exit 0
EOF
  chmod +x "$bin/dotnet" "$bin/curl"

  printf 'csharp\n' > "$plan"
  set +e
  PACKBIN_PUBLISH=1 PACKBIN_DOCKER=0 PACKBIN_PLAN="$plan" PACKBIN_OUT="$tmp" \
    PACKBIN_PUBLISH_LOG="$log" PATH="$bin:$PATH" \
    bash "$here/publish-registries.sh" >"$tmp/out.txt" 2>"$tmp/err.txt"
  local code=$?
  set -e
  if [ "$code" -eq 0 ]; then
    fail "csharp publish ran without NUGET_TOKEN"
  fi
  if [ -s "$log" ]; then
    fail "a registry write ran before the token check"
  fi

  : > "$log"
  printf 'cpp\n' > "$plan"
  local bare="$tmp/vcpkg.git"
  git init --bare "$bare" >/dev/null
  env -u GITHUB_TOKEN -u PLATFORMIO_AUTH_TOKEN -u IDF_COMPONENT_API_TOKEN \
    PACKBIN_PUBLISH=1 PACKBIN_DOCKER=0 PACKBIN_PLAN="$plan" PACKBIN_VERSION=0.1.0 \
    PACKBIN_OUT="$tmp/cpp-out" VCPKG_REGISTRY_URL="$bare" \
    bash "$here/publish-registries.sh" | tee "$tmp/cpp.txt"
  for skipped in "platformio: PLATFORMIO_AUTH_TOKEN" "esp-idf: IDF_COMPONENT_API_TOKEN" "arduino: GITHUB_TOKEN"; do
    grep -qx "::warning::skipping optional target $skipped is not set" "$tmp/cpp.txt" \
      || fail "embedded publish without a token: $skipped"
  done

  local arduino="$tmp/arduino.git"
  git init --bare "$arduino" >/dev/null
  env -u GITHUB_TOKEN -u PLATFORMIO_AUTH_TOKEN -u IDF_COMPONENT_API_TOKEN \
    PACKBIN_PUBLISH=1 PACKBIN_PLAN="$plan" PACKBIN_VERSION=0.1.0 PACKBIN_OUT="$tmp/cpp-out2" \
    VCPKG_REGISTRY_URL="$bare" ARDUINO_REGISTRY_URL="$arduino" \
    bash "$here/publish-registries.sh"
  git --git-dir="$arduino" show arduino:library.properties | grep -qx 'version=0.1.0' \
    || fail "arduino library version"
  git --git-dir="$arduino" show arduino-0.1.0:src/packbin.h >/dev/null \
    || fail "arduino tag layout"
  git --git-dir="$bare" show vcpkg:ports/packbin/vcpkg.json | grep -q '"name": "packbin"' \
    || fail "vcpkg port name"
  git --git-dir="$bare" show vcpkg:ports/packbin/vcpkg.json | grep -q '"license": "MIT"' \
    || fail "vcpkg license"
  git --git-dir="$bare" rev-parse --verify vcpkg >/dev/null || fail "vcpkg ref missing"
}

copy_tree() {
  local dest="$1"
  mkdir -p "$dest"
  tar -C "$root" \
    --exclude .git \
    --exclude test-results \
    --exclude .github/workflows/out \
    --exclude .build --exclude .swiftpm \
    --exclude rust/target \
    --exclude .cache \
    --exclude cpp/build \
    -cf - . | tar -C "$dest" -xf -
}

gate_checks() {
  local out plan
  out="$(mktemp -d)"
  PACKBIN_OUT="$out" bash "$here/publish-gate.sh" >"$out/log.txt"
  plan="$out/publish-plan.txt"
  local order
  order="$(paste -sd ' ' "$plan")"
  assert_eq "$order" "csharp typescript python rust cpp java go swift" "AC-1 call list"
  local count
  count="$(grep -c '^pack ' "$out/log.txt" || true)"
  assert_eq "$count" "8" "AC-1 pack calls"
  while read -r _ lang hex; do
    assert_eq "$hex" "$expected" "AC-1 $lang hex"
  done < <(grep '^pack ' "$out/log.txt")
  assert_eq "$(grep '^mismatch ' "$out/log.txt" | awk '{print $2}')" "0" "AC-5 mismatch"

  # AC-3 (a bad fixture publishes nothing) and AC-4 (a missing language is absent, not published) run in
  # ro_gate_checks on a read-only tree: the same script and scenarios, so they are not run twice here.
}

manifest_checks() {
  grep -q 'PackageLicenseExpression>MIT' "$root/csharp/Packbin.csproj" || fail "csharp license"
  grep -q '"license": "MIT"' "$root/typescript/package.json" || fail "typescript license"
  grep -q 'text = "MIT"' "$root/python/pyproject.toml" || fail "python license"
  grep -q 'license = "MIT"' "$root/rust/Cargo.toml" || fail "rust license"
  grep -q '<name>MIT</name>' "$root/.github/workflows/publish-inside.sh" || fail "java license"
  grep -q 'PackageReadmeFile' "$root/csharp/Packbin.csproj" || fail "nuget readme"
  grep -q '"README.md"' "$root/typescript/package.json" || fail "npm readme"
  grep -q 'readme = "README.md"' "$root/rust/Cargo.toml" || fail "crates readme"
  grep -q 'typescript/README.md' "$root/.github/workflows/publish-inside.sh" || fail "npm readme copy"
  grep -q 'cp "$root/README.md" "$stage/README.md"' "$root/.github/workflows/publish-inside.sh" || fail "crates readme copy"
  grep -q 'readme = "README.md"' "$root/python/pyproject.toml" || fail "pypi readme"
  grep -q 'python/README.md' "$root/.github/workflows/publish-inside.sh" || fail "pypi readme copy"
  grep -q 'oidc/mint-token' "$root/.github/workflows/publish-upload.sh" || fail "pypi trusted publisher"
}

crates_token_checks() {
  local publish_yml="$root/.github/workflows/publish.yml"
  local exchange_line publish_line revoke_line
  if grep -q 'crates-io-auth-action' "$publish_yml"; then
    fail "publish workflow still uses crates-io-auth-action"
  fi
  if grep -q 'continue-on-error' "$publish_yml"; then
    fail "publish workflow uses continue-on-error"
  fi
  exchange_line="$(grep -n 'crates-token.sh exchange' "$publish_yml" | head -n 1 | cut -d: -f1)"
  publish_line="$(grep -n 'publish-registries.sh' "$publish_yml" | head -n 1 | cut -d: -f1)"
  revoke_line="$(grep -n 'crates-token.sh revoke' "$publish_yml" | head -n 1 | cut -d: -f1)"
  if [ -z "$exchange_line" ] || [ -z "$publish_line" ] || [ -z "$revoke_line" ]; then
    fail "crates token steps are missing"
  elif [ "$exchange_line" -ge "$publish_line" ] || [ "$publish_line" -ge "$revoke_line" ]; then
    fail "crates token exchange, publish, and revoke are out of order"
  fi

  local tmp out code
  tmp="$(mktemp -d)"
  set +e
  env -u ACTIONS_ID_TOKEN_REQUEST_URL -u ACTIONS_ID_TOKEN_REQUEST_TOKEN \
    bash "$here/crates-token.sh" exchange >"$tmp/no-oidc.out" 2>"$tmp/no-oidc.err"
  code=$?
  set -e
  if [ "$code" -eq 0 ]; then
    fail "crates token exchange succeeded without an OIDC token"
  fi

  local bin count
  bin="$tmp/bin"
  count="$tmp/count"
  mkdir -p "$bin"
  cat > "$bin/curl" <<'EOF'
#!/bin/bash
nfile="${PACKBIN_CURL_COUNT:?}"
n=0
[ -f "$nfile" ] && n="$(cat "$nfile")"
n=$((n + 1))
printf '%s\n' "$n" > "$nfile"
mode="${PACKBIN_CURL_MODE:?}"
outfile=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "-o" ]; then
    outfile="$arg"
  fi
  prev="$arg"
done
case "$mode" in
  exchange-ok)
    if [ "$n" -eq 1 ]; then
      printf '%s\n' '{"value":"oidc-jwt"}'
      exit 0
    fi
    printf '%s\n' '{"token":"cio-secret"}' > "$outfile"
    printf '%s' "200"
    ;;
  exchange-denied)
    if [ "$n" -eq 1 ]; then
      printf '%s\n' '{"value":"oidc-jwt"}'
      exit 0
    fi
    printf '%s\n' '{"errors":[{"detail":"denied"}]}' > "$outfile"
    printf '%s' "403"
    ;;
  revoke-503)
    printf '%s' "503"
    ;;
  revoke-200)
    printf '%s' "200"
    ;;
esac
EOF
  chmod +x "$bin/curl"

  out="$tmp/exchange-out"
  : > "$count"
  GITHUB_OUTPUT="$out" PACKBIN_CURL_COUNT="$count" PACKBIN_CURL_MODE="exchange-ok" \
    ACTIONS_ID_TOKEN_REQUEST_URL="https://token.actions.githubusercontent.com/req?x=1" \
    ACTIONS_ID_TOKEN_REQUEST_TOKEN="request-token" \
    PATH="$bin:$PATH" \
    bash "$here/crates-token.sh" exchange >"$tmp/exchange.log"
  grep -q '^token=cio-secret$' "$out" || fail "crates token was not written"
  grep -q '^::add-mask::cio-secret$' "$tmp/exchange.log" || fail "crates token was not masked"
  if grep -v '^::add-mask::' "$tmp/exchange.log" | grep -q 'cio-secret'; then
    fail "crates token was printed"
  fi

  : > "$count"
  set +e
  GITHUB_OUTPUT="$tmp/denied-out" PACKBIN_CURL_COUNT="$count" PACKBIN_CURL_MODE="exchange-denied" \
    ACTIONS_ID_TOKEN_REQUEST_URL="https://token.actions.githubusercontent.com/req?x=1" \
    ACTIONS_ID_TOKEN_REQUEST_TOKEN="request-token" \
    PATH="$bin:$PATH" \
    bash "$here/crates-token.sh" exchange >"$tmp/denied.log" 2>"$tmp/denied.err"
  code=$?
  set -e
  if [ "$code" -eq 0 ]; then
    fail "denied crates token exchange succeeded"
  fi
  if [ -s "$tmp/denied-out" ]; then
    fail "denied crates token exchange wrote an output"
  fi

  : > "$count"
  CARGO_REGISTRY_TOKEN="cio-secret" PACKBIN_CRATES_REVOKE_PAUSE=0 \
    PACKBIN_CURL_COUNT="$count" PACKBIN_CURL_MODE="revoke-503" PATH="$bin:$PATH" \
    bash "$here/crates-token.sh" revoke >"$tmp/revoke503.log"
  assert_eq "$(grep -c 'revoke returned 503' "$tmp/revoke503.log")" "5" "crates revoke retries"
  grep -q 'revoke still unavailable' "$tmp/revoke503.log" || fail "crates revoke 503 failed the step"

  : > "$count"
  CARGO_REGISTRY_TOKEN="cio-secret" PACKBIN_CURL_COUNT="$count" PACKBIN_CURL_MODE="revoke-200" \
    PATH="$bin:$PATH" \
    bash "$here/crates-token.sh" revoke >"$tmp/revoke200.log"
  grep -q 'token revoked' "$tmp/revoke200.log" || fail "crates revoke 200"
}

# shellcheck source=publish-workflow.test.sh
source "$here/publish-workflow.test.sh"
# shellcheck source=publish-npm.test.sh
source "$here/publish-npm.test.sh"
# shellcheck source=publish-vcpkg.test.sh
source "$here/publish-vcpkg.test.sh"

if [ "${1:-}" = "--npm" ]; then
  npm_dist_checks
  bash "$here/publish-position.test.sh" || fail "AZ-2238 AC-1 AC-2 publish-position.test.sh failed"
  if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
  fi
  echo "npm dist checks passed"
  exit 0
fi

if [ "${1:-}" = "--crates" ]; then
  crates_token_checks
  if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
  fi
  echo "crates token checks passed"
  exit 0
fi

if [ "${1:-}" = "--vcpkg" ]; then
  vcpkg_checks
  if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
  fi
  if [ -n "$not_run" ]; then
    echo "vcpkg port checks: no failures, NOT RUN: $not_run"
  else
    echo "vcpkg port checks passed"
  fi
  exit 0
fi

# shellcheck source=publish-phases.test.sh
source "$here/publish-phases.test.sh"
# shellcheck source=publish-rerun.test.sh
source "$here/publish-rerun.test.sh"
# shellcheck source=publish-pins.test.sh
source "$here/publish-pins.test.sh"
# shellcheck source=publish-readonly.test.sh
source "$here/publish-readonly.test.sh"
# shellcheck source=publish-go.test.sh
source "$here/publish-go.test.sh"
# shellcheck source=publish-swift.test.sh
source "$here/publish-swift.test.sh"
# shellcheck source=publish-timing.test.sh
source "$here/publish-timing.test.sh"

# The 14 check groups, in run order. CI runs them as three jobs (test.yml, publish-gate-*), each with --groups <a,b,..>
# naming its share (AZ-2600); no argument runs all of them, as the Mac does. publish-jobs.test.sh reads this list, so a
# group that no CI job runs, or two jobs run, is refused there.
gate_groups="static crates-token registry vcpkg gate go swift manifest npm position workflow pins phases readonly"
selected=" $gate_groups "
if [ "${1:-}" = "--groups" ]; then
  wanted="${2:-}"
  if [ -z "$wanted" ]; then
    echo "usage: publish-gate.test.sh [--groups a,b,..] ($gate_groups)" >&2
    exit 2
  fi
  selected=" ${wanted//,/ } "
  for name in $selected; do
    case " $gate_groups " in
      *" $name "*) ;;
      *)
        echo "publish-gate.test.sh: unknown group '$name' (groups: $gate_groups)" >&2
        exit 2
        ;;
    esac
  done
fi

echo "publish-gate: groups$selected"

# group <name> <function>: runs one group through `timed` when it is selected.
group() {
  case "$selected" in
    *" $1 "*) timed "$1" "$2" ;;
  esac
}

group static static_checks
group crates-token crates_token_checks
group registry registry_checks
group vcpkg vcpkg_checks
group gate gate_checks
group go go_checks
group swift swift_checks
group manifest manifest_checks
group npm npm_dist_checks
group position position_checks
group workflow workflow_checks
group pins pins_checks
group phases phase_checks
group readonly readonly_checks
timed_total

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
# A run with a check that did not run must not read like a pass (smoke scripts grep for the phrase).
if [ -n "$not_run" ]; then
  echo "publish gate: no failures, NOT RUN: $not_run"
else
  echo "publish gate tests passed"
fi
