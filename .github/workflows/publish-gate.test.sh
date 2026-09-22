#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
expected="4001000065cd1d00a3e1110100"
failures=0

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
  for token in NPM_TOKEN NUGET_TOKEN PYPI_TOKEN CARGO_REGISTRY_TOKEN MAVEN_CENTRAL_TOKEN; do
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
  local inside="$root/.github/workflows/publish-inside.sh"
  for cmd in "dotnet nuget push" "npm publish" "twine upload" "cargo publish" "https://api.nuget.org" "https://central.sonatype.com"; do
    if ! grep -q "$cmd" "$inside" && ! grep -q "$cmd" "$registries"; then
      fail "missing publish command: $cmd"
    fi
  done
  if ! grep -q 'git -C "$reg" push' "$registries" && ! grep -q 'push "$url"' "$registries"; then
    fail "cpp publish does not git push"
  fi
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

  if grep -q 'MAVEN_GROUP_ID' "$here/publish-registries.sh" || grep -q 'MAVEN_GROUP_ID' "$here/publish-inside.sh"; then
    fail "Java publish still reads MAVEN_GROUP_ID"
  fi
  if ! grep -q '<groupId>packbin</groupId>' "$here/publish-inside.sh"; then
    fail "Java group id is not packbin"
  fi
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
  PACKBIN_PUBLISH=1 PACKBIN_DOCKER=0 PACKBIN_PLAN="$plan" PACKBIN_VERSION=0.1.0 \
    VCPKG_REGISTRY_URL="$bare" \
    bash "$here/publish-registries.sh"
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
    -cf - . | tar -C "$dest" -xf -
}

gate_checks() {
  local out plan
  out="$(mktemp -d)"
  PACKBIN_OUT="$out" bash "$here/publish-gate.sh" >"$out/log.txt"
  plan="$out/publish-plan.txt"
  local order
  order="$(paste -sd ' ' "$plan")"
  assert_eq "$order" "csharp typescript python rust cpp java" "AC-1 call list"
  local count
  count="$(grep -c '^pack ' "$out/log.txt" || true)"
  assert_eq "$count" "6" "AC-1 pack calls"
  while read -r _ lang hex; do
    assert_eq "$hex" "$expected" "AC-1 $lang hex"
  done < <(grep '^pack ' "$out/log.txt")
  assert_eq "$(grep '^mismatch ' "$out/log.txt" | awk '{print $2}')" "0" "AC-5 mismatch"

  local bad
  bad="$(mktemp -d)"
  copy_tree "$bad"
  printf '00\n' > "$bad/fixtures/golden.hex"
  local bad_out="$bad/.github/workflows/out"
  set +e
  SRC_ROOT="$bad" PACKBIN_OUT="$bad_out" bash "$bad/.github/workflows/publish-gate.sh" >"$bad/log.txt"
  local code=$?
  set -e
  if [ "$code" -eq 0 ]; then
    fail "AC-3 mismatch still published"
  fi
  if [ -s "$bad_out/publish-plan.txt" ]; then
    fail "AC-3 plan was not empty"
  fi
  local packed
  packed="$(grep '^pack csharp ' "$bad/log.txt" | awk '{print $3}')"
  assert_eq "$packed" "$expected" "AC-3 pack ignored the bad fixture"

  local missing
  missing="$(mktemp -d)"
  copy_tree "$missing"
  rm -rf "$missing/java"
  local miss_out="$missing/.github/workflows/out"
  SRC_ROOT="$missing" PACKBIN_OUT="$miss_out" bash "$missing/.github/workflows/publish-gate.sh" >"$missing/log.txt"
  if grep -qx java "$miss_out/publish-plan.txt"; then
    fail "AC-4 java was published"
  fi
  if ! grep -q '^absent java$' "$missing/log.txt"; then
    fail "AC-4 java was not absent"
  fi
  assert_eq "$(wc -l < "$miss_out/publish-plan.txt" | tr -d ' ')" "5" "AC-4 five languages"
}

static_checks
registry_checks
gate_checks

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "publish gate tests passed"
