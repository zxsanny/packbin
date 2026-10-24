#!/usr/bin/env bash
# Two-phase publish scenarios (AZ-2096). Sourced by publish-gate.test.sh, which defines fail,
# assert_eq, copy_tree, $root and $here. Builds run in the real toolchain containers on a copy
# of the tree; registry tools are PATH stubs that log to $PACKBIN_PUBLISH_LOG, and the vcpkg and
# Arduino registries are bare git repositories whose hook logs each push.
#
# Every log line starts with the number of `build ok` lines in build.log at the moment the tool
# ran, so "no upload before every build" is a check on that first field.
#
# This file holds the harness (stubs, ph_setup, ph_publish, ph_bares), the static checks, the success
# scenarios and the two group functions, phase_checks and phase_rerun_checks; publish-phases-failures.test.sh
# (sourced before them) holds the failure scenarios: a failing build, fabricated bad artifacts and real-pipeline check
# violations.

PH_TARGETS="csharp typescript python rust vcpkg platformio esp-idf arduino java"
PH_CREDENTIALS="NUGET_TOKEN NPM_TOKEN PYPI_TOKEN CARGO_REGISTRY_TOKEN MAVEN_CENTRAL_TOKEN MAVEN_GPG_PRIVATE_KEY PLATFORMIO_AUTH_TOKEN IDF_COMPONENT_API_TOKEN GITHUB_TOKEN ACTIONS_ID_TOKEN_REQUEST_URL ACTIONS_ID_TOKEN_REQUEST_TOKEN"

ph_write_stub() {
  local name="$1" body="$2"
  {
    cat <<'EOF'
#!/bin/sh
built=0
if [ -f "$PACKBIN_OUT/artifacts/build.log" ]; then built="$(grep -c '^build ok ' "$PACKBIN_OUT/artifacts/build.log")"; fi
record() { printf '%s %s %s\n' "$built" "$(basename "$0")" "$*" >> "$PACKBIN_PUBLISH_LOG"; }
has() { [ -f "${PACKBIN_SCENARIO:-}" ] && grep -qx "$1" "$PACKBIN_SCENARIO"; }
fail_if_asked() { if has "fail $(basename "$0")"; then echo "stub: forced failure" >&2; exit 1; fi; }
EOF
    printf '%s\n' "$body"
  } > "$ph_bin/$name"
  chmod +x "$ph_bin/$name"
}

# A stub that logs only the registry write (and answers `extra_case`, a shell case branch) and hands every
# other call to the real tool, the next executable of that name on PATH after the stub directory.
ph_write_spy() {
  local name="$1" write_pattern="$2" extra_case="${3:-}"
  ph_write_stub "$name" "case \"\$*\" in
  $extra_case
  *\"$write_pattern\"*) record \"\$@\"; fail_if_asked; exit 0 ;;
esac
real=\"\"
IFS=:
for dir in \$PATH; do
  if [ \"\$dir\" != \"$ph_bin\" ] && [ -x \"\$dir/$name\" ]; then real=\"\$dir/$name\"; break; fi
done
unset IFS
exec \"\$real\" \"\$@\""
}

# Registry queries answer from the scenario file (publish-rerun.test.sh describes its lines); the Central
# upload and status calls answer as a successful deployment unless the scenario says otherwise.
ph_write_curl_stub() {
  ph_write_stub curl 'record "$@"
out=""; url=""; prev=""
for a in "$@"; do
  if [ "$prev" = "-o" ]; then out="$a"; fi
  prev="$a"
  url="$a"
done
query() {
  if has "503 $1"; then printf 503; exit 0; fi
  if has "503-once $1" && [ ! -e "$PACKBIN_SCENARIO.$1.seen" ]; then : > "$PACKBIN_SCENARIO.$1.seen"; printf 503; exit 0; fi
  if has "published $1"; then printf "%s" "$2" > "$out"; printf 200; else printf 404; fi
  exit 0
}
pypi_files() {
  files=""
  for f in "$PACKBIN_OUT"/artifacts/python/*; do
    n="$(basename "$f")"
    if has "partial python" && [ "${n%.whl}" = "$n" ]; then continue; fi
    files="$files{\"filename\":\"$n\"},"
  done
  printf "{\"urls\":[%s]}" "${files%,}"
}
case "$url" in
  *publisher/status*)
    if has maven-exists; then
      printf "%s\n" "{\"deploymentState\":\"FAILED\",\"errors\":{\"pkg:maven/io.github.zxsanny/packbin@0.1.9\":[\"Component with package url: pkg:maven/io.github.zxsanny/packbin@0.1.9 already exists\"]}}"
    else
      printf "%s\n" "{\"deploymentState\":\"PUBLISHED\"}"
    fi ;;
  *publisher/upload*) printf "%s\n" "deployment-1" ;;
  *publisher/published*) query java "{\"published\":true}" ;;
  *api.nuget.org/v3-flatcontainer*) query csharp "{\"versions\":[\"0.1.9\"]}" ;;
  *registry.npmjs.org*) query typescript "{}" ;;
  *pypi.org/pypi*) query python "$(pypi_files)" ;;
  *crates.io/api*) query rust "{}" ;;
  *api.registry.platformio.org*) query platformio "{\"versions\":[{\"name\":\"0.1.9\"}]}" ;;
  *components.espressif.com*) query esp-idf "{\"versions\":[{\"version\":\"0.1.9\"}]}" ;;
  *) printf "%s\n" "unexpected curl url: $url" >&2; exit 1 ;;
esac'
}

ph_setup() {
  ph_dir="$(mktemp -d)"
  ph_scenario="$ph_dir/scenario.txt"
  : > "$ph_scenario"
  ph_bin="$ph_dir/bin"
  ph_tree="$ph_dir/tree"
  ph_plan="$ph_dir/plan.txt"
  mkdir -p "$ph_bin"
  copy_tree "$ph_tree"
  printf 'csharp\ntypescript\npython\nrust\ncpp\njava\n' > "$ph_plan"
  python3 -m venv "$ph_dir/tools/venv"
  "$ph_dir/tools/venv/bin/pip" install --quiet --only-binary=:all: "platformio==$(bash "$here/tool-pin.sh" platformio)" "idf-component-manager==$(bash "$here/tool-pin.sh" idf-component-manager)"
  for tool in dotnet npm twine cargo; do
    ph_write_stub "$tool" 'record "$@"
fail_if_asked'
  done
  ph_write_curl_stub
  ph_write_spy pio "pkg publish" '"account show"*) record "$@"; printf "%s\n" "{\"profile\":{\"username\":\"zxsanny\"}}"; exit 0 ;;'
  ph_write_spy compote "component upload"
  if ! command -v gpg >/dev/null; then
    cat > "$ph_bin/gpg" <<'EOF'
#!/usr/bin/env bash
exec docker run --rm -i -u "$(id -u):$(id -g)" --tmpfs "/run/user/$(id -u):mode=700,uid=$(id -u),gid=$(id -g)" \
  -e GNUPGHOME -v "$GNUPGHOME:$GNUPGHOME" -v "$PACKBIN_OUT:$PACKBIN_OUT" -w "$PWD" python:3.14 gpg "$@"
EOF
    chmod +x "$ph_bin/gpg"
  fi
  local ring="$ph_dir/ring"
  mkdir -m 700 "$ring"
  PATH="$ph_bin:$PATH" GNUPGHOME="$ring" PACKBIN_OUT="$ph_dir" gpg --batch --pinentry-mode loopback \
    --passphrase '' --quick-generate-key "packbin-test" rsa3072 sign 0
  ph_key="$(PATH="$ph_bin:$PATH" GNUPGHOME="$ring" PACKBIN_OUT="$ph_dir" gpg --armor --export-secret-keys)"
}

# Two empty bare repositories whose pre-receive hook logs the push.
ph_bares() {
  local name="$1" repo
  ph_vcpkg="$ph_dir/$name-vcpkg.git"
  ph_arduino="$ph_dir/$name-arduino.git"
  for repo in "$ph_vcpkg" "$ph_arduino"; do
    git init --bare "$repo" >/dev/null
    cat > "$repo/hooks/pre-receive" <<'EOF'
#!/bin/sh
built="$(grep -c '^build ok ' "$PACKBIN_OUT/artifacts/build.log")"
printf '%s git-push %s\n' "$built" "$(basename "$(pwd)")" >> "$PACKBIN_PUBLISH_LOG"
EOF
    chmod +x "$repo/hooks/pre-receive"
  done
}

# ph_publish <name> <extra PATH dir or -> [VAR=value ...]
# Runs publish-registries.sh against the tree copy with no credentials but those given.
# Leaves the exit code in ph_code, merged output in $ph_dir/<name>.out, the tool log in <name>.log.
ph_publish() {
  local name="$1" front="$2" unset_args="" var
  shift 2
  for var in $PH_CREDENTIALS; do
    unset_args="$unset_args -u $var"
  done
  ph_out="$ph_tree/.github/workflows/out/$name"
  ph_log="$ph_dir/$name.log"
  : > "$ph_log"
  [ "$front" = "-" ] && front="$ph_bin"
  set +e
  # shellcheck disable=SC2086
  env $unset_args \
    PACKBIN_PUBLISH=1 PACKBIN_PLAN="$ph_plan" PACKBIN_VERSION=v0.1.9 SRC_ROOT="$ph_tree" \
    PACKBIN_OUT="$ph_out" PACKBIN_TOOLS="$ph_dir/tools" PACKBIN_PUBLISH_LOG="$ph_log" \
    PACKBIN_SCENARIO="$ph_scenario" PACKBIN_QUERY_PAUSE=0 \
    VCPKG_REGISTRY_URL="$ph_vcpkg" ARDUINO_REGISTRY_URL="$ph_arduino" \
    PATH="$front:$ph_bin:$PATH:$ph_dir/tools/venv/bin" "$@" \
    bash "$here/publish-registries.sh" > "$ph_dir/$name.out" 2>&1
  ph_code=$?
  set -e
}

# ph_quote <file>: the last 25 lines of a run's output for a failure message. A tool's own error (a pip install in
# the build container) comes before `build failed: <target>`, so 3 lines hid it in loop 65.
ph_quote() {
  tail -n 25 "$1"
}

ph_no_refs() {
  local label="$1" repo
  for repo in "$ph_vcpkg" "$ph_arduino"; do
    if [ -n "$(git --git-dir="$repo" for-each-ref)" ]; then
      fail "$label: $(basename "$repo") has refs"
    fi
  done
}

ph_creds=()
ph_set_credentials() {
  ph_creds=(NUGET_TOKEN=n NPM_TOKEN=n PYPI_TOKEN=p CARGO_REGISTRY_TOKEN=c MAVEN_CENTRAL_TOKEN=m
    PLATFORMIO_AUTH_TOKEN=pio IDF_COMPONENT_API_TOKEN=idf "MAVEN_GPG_PRIVATE_KEY=$ph_key")
}

ph_static_checks() {
  local upload_words='nuget push|npm publish|twine upload|cargo publish|pkg publish|component upload|push_branch|git .*push|sonatype|api.nuget.org|pypi.org'
  local build_files="publish-build.sh publish-inside.sh publish-sign.sh publish-embedded.sh publish-check.py"
  local publish_scripts="$here/publish-registries.sh $here/publish-build.sh $here/publish-upload.sh $here/publish-inside.sh $here/publish-sign.sh $here/publish-embedded.sh $here/publish-lib.sh"
  local file
  for file in $build_files; do
    if grep -Eq "$upload_words" "$here/$file"; then
      fail "AZ-2096 AC-3 $file holds an upload command"
    fi
  done
  if grep -Eq 'dotnet pack|npm pack|python3? -m build|cargo package|zipfile|javac|pkg pack|component pack|gpg' "$here/publish-upload.sh"; then
    fail "AZ-2096 AC-5 publish-upload.sh builds or signs"
  fi
  grep -q 'PACKBIN_HOST_UID' "$here/publish-build.sh" || fail "AZ-2096 build containers are not told the host user"
  grep -q 'chown -R' "$here/publish-inside.sh" || fail "AZ-2096 build containers do not hand the artifacts to the host user"
  ! grep -q 'chmod -R a+rwX' "$here/publish-build.sh" || fail "AZ-2096 the host chmods root-owned artifacts (a Linux runner cannot)"
  if grep -Eq 'microsoft/vcpkg|gh pr' $publish_scripts; then
    fail "cpp publish is not a git push of this registry"
  fi
  for cmd in "dotnet nuget push" "npm publish" "twine upload" "cargo publish --no-verify" "pkg publish" \
    "component upload --archive" "https://api.nuget.org" "https://central.sonatype.com" "publishingType=AUTOMATIC" \
    "oidc/mint-token" 'push_branch "$artifacts/vcpkg/reg"'; do
    grep -qF -- "$cmd" "$here/publish-upload.sh" || fail "publish-upload.sh lacks: $cmd"
  done
  grep -q 'git -C "$reg" push' "$here/publish-lib.sh" || fail "cpp publish does not git push"
  if grep -q 'MAVEN_GROUP_ID' $publish_scripts; then
    fail "Java publish still reads MAVEN_GROUP_ID"
  fi
  grep -q '<groupId>io.github.zxsanny</groupId>' "$here/publish-inside.sh" || fail "Java group id is not io.github.zxsanny"
  if grep -q 'maven-bundle.zip" -C' "$here/publish-inside.sh"; then
    fail "maven bundle is a jar archive"
  fi
  local quote_in
  quote_in="$(mktemp)"
  { seq 1 29; echo 'ERROR: stub pip failed'; seq 31 39; echo 'build failed: python'; } > "$quote_in"
  ph_quote "$quote_in" | grep -qx 'ERROR: stub pip failed' || fail "loop 66 AC-4 ph_quote hides a tool error 10 lines before the failure line"
  rm -f "$quote_in"
  if grep -q 'tail -n 3' "$here/publish-phases-failures.test.sh"; then
    fail "loop 66 AC-4 a failure message in publish-phases-failures.test.sh quotes 3 lines"
  fi
}

# AC-3: a build-only run with no credential builds and checks every target and writes nothing.
ph_build_only() {
  ph_bares build-only
  ph_publish build-only - PACKBIN_BUILD_ONLY=1
  assert_eq "$ph_code" "0" "AZ-2096 AC-3 build-only exit code"
  [ ! -s "$ph_log" ] || fail "AZ-2096 AC-3 a registry command ran in build-only mode: $(head -n 3 "$ph_log")"
  ph_no_refs "AZ-2096 AC-3"
  local target
  for target in $PH_TARGETS; do
    [ -n "$(ls -A "$ph_out/artifacts/$target")" ] || fail "AZ-2096 AC-3 no artifact for $target"
    grep -qx "build ok $target" "$ph_out/artifacts/build.log" || fail "AZ-2096 AC-3 no build ok for $target"
    grep -qx "check ok: $target" "$ph_dir/build-only.out" || fail "AZ-2096 AC-3 no check ok for $target"
  done
  grep -q '^upload ' "$ph_dir/build-only.out" && fail "AZ-2096 AC-3 build-only printed an upload"
  [ -e "$ph_out/artifacts/dry-run" ] || fail "AZ-2096 AC-3 build-only left no dry-run marker"
  python3 - "$ph_out/artifacts/java/maven-bundle.zip" <<'PY' || fail "maven bundle layout"
import sys, zipfile
names = zipfile.ZipFile(sys.argv[1]).namelist()
base = "io/github/zxsanny/packbin/0.1.9/packbin-0.1.9"
for part in (".pom", ".jar", "-sources.jar", "-javadoc.jar"):
    for suffix in ("", ".asc", ".md5", ".sha1"):
        if base + part + suffix not in names:
            raise SystemExit(f"missing {base + part + suffix}")
if any(name == "META-INF" or name.startswith("META-INF/") for name in names):
    raise SystemExit("bundle contains META-INF")
PY
  if env PACKBIN_PUBLISH=1 PACKBIN_BUILD_ONLY=1 PACKBIN_OUT="$ph_out" PACKBIN_VERSION=v0.1.9 \
    bash "$here/publish-upload.sh" $PH_TARGETS >"$ph_dir/dry-upload.out" 2>&1; then
    fail "AZ-2096 AC-3 the upload phase accepted build-only artifacts"
  fi
}

# AC-1 and AC-5: a full publish. No registry command before every target built; uploads send the
# built files and the host registry tools run no pack or build.
ph_full_publish() {
  local tool line
  ph_bares full
  ph_set_credentials
  ph_publish full - "${ph_creds[@]}"
  assert_eq "$ph_code" "0" "AZ-2096 AC-1 full publish exit code"
  assert_eq "$(grep -c '^build ok ' "$ph_dir/full.out")" "9" "AZ-2096 AC-1 build ok lines"
  [ -s "$ph_log" ] || fail "AZ-2096 AC-1 no registry command ran"
  if awk '$1 != 9 { bad = 1 } END { exit !bad }' "$ph_log"; then
    fail "AZ-2096 AC-1 a registry command ran before all 9 targets built: $(awk '$1 != 9' "$ph_log" | head -n 3)"
  fi
  local last_build first_upload
  last_build="$(grep -n '^build ok ' "$ph_dir/full.out" | tail -n 1 | cut -d: -f1)"
  first_upload="$(grep -n '^upload ' "$ph_dir/full.out" | head -n 1 | cut -d: -f1)"
  if [ -z "$last_build" ] || [ -z "$first_upload" ] || [ "$last_build" -ge "$first_upload" ]; then
    fail "AZ-2096 AC-1 an upload line precedes the last build ok line"
  fi
  for line in '^[0-9]+ dotnet nuget push ' '^[0-9]+ npm publish ' '^[0-9]+ twine upload ' '^[0-9]+ cargo publish ' \
    '^[0-9]+ curl .*publisher/upload' '^[0-9]+ pio pkg publish ' '^[0-9]+ compote component upload ' \
    '^[0-9]+ git-push full-vcpkg.git$' '^[0-9]+ git-push full-arduino.git$'; do
    grep -Eq "$line" "$ph_log" || fail "AZ-2096 AC-1 no registry command logged: $line"
  done
  for tool in dotnet npm twine cargo; do
    if awk -v t="$tool" '$2 == t' "$ph_log" | grep -Eq ' (pack|build|package) '; then
      fail "AZ-2096 AC-5 $tool packed again during upload"
    fi
  done
  assert_eq "$(awk '$2 == "dotnet"' "$ph_log" | grep -c ' nuget push ')" "1" "AZ-2096 AC-5 dotnet calls"
  assert_eq "$(awk '$2 == "cargo"' "$ph_log" | grep -c ' publish --no-verify ')" "1" "AZ-2096 AC-5 cargo calls"
  local artifacts="$ph_out/artifacts"
  grep -qF "nuget push $artifacts/csharp/Packbin.0.1.9.nupkg" "$ph_log" || fail "AZ-2096 AC-5 nupkg path"
  grep -qF "publish $artifacts/typescript/packbin-0.1.9.tgz" "$ph_log" || fail "AZ-2096 AC-5 npm tarball path"
  grep -qF "$artifacts/python/packbin-0.1.9-py3-none-any.whl $artifacts/python/packbin-0.1.9.tar.gz" "$ph_log" \
    || fail "AZ-2096 AC-5 python files"
  grep -qF -- "--manifest-path $artifacts/rust/stage/Cargo.toml" "$ph_log" || fail "AZ-2096 AC-5 cargo staged directory"
  grep -qF "bundle=@$artifacts/java/maven-bundle.zip" "$ph_log" || fail "AZ-2096 AC-5 maven bundle path"
  grep -qF "pkg publish $artifacts/platformio/packbin-0.1.9.tar.gz" "$ph_log" || fail "AZ-2096 AC-5 platformio archive"
  grep -qF -- "--archive $artifacts/esp-idf/packbin_0.1.9.tgz" "$ph_log" || fail "AZ-2096 AC-5 esp-idf archive"
  git --git-dir="$ph_vcpkg" show vcpkg:ports/packbin/vcpkg.json | grep -q '"version": "0.1.9"' || fail "AZ-2096 AC-5 vcpkg push"
  git --git-dir="$ph_arduino" show arduino-0.1.9:library.properties | grep -qx 'version=0.1.9' || fail "AZ-2096 AC-5 arduino push"
}

# AC-6: an empty plan (the golden gate failed) builds and uploads nothing.
ph_empty_plan() {
  : > "$ph_plan"
  ph_bares empty
  ph_publish empty - "NUGET_TOKEN=n"
  assert_eq "$ph_code" "0" "AZ-2096 AC-6 empty plan exit code"
  grep -qx 'publishing 0 packages' "$ph_dir/empty.out" || fail "AZ-2096 AC-6 empty plan did not say so"
  [ ! -e "$ph_out/artifacts" ] || fail "AZ-2096 AC-6 an empty plan built something"
  [ ! -s "$ph_log" ] || fail "AZ-2096 AC-6 an empty plan ran a registry command"
  printf 'csharp\ntypescript\npython\nrust\ncpp\njava\n' > "$ph_plan"
}

# shellcheck source=publish-phases-failures.test.sh
source "$here/publish-phases-failures.test.sh"

ph_cleanup() {
  if ! rm -rf "$ph_dir"; then
    echo "note: could not remove $ph_dir (files written by a build container)"
  fi
}

# The two phase gate groups (AZ-2625) each pay their own ph_setup and run in separate CI jobs. The cut is by the measured
# seconds of a Mac run (ph_rerun_checks 128 s; the other scenarios 128 s together, setup 15 s each). `phases`: the
# two-phase publish scenarios of AZ-2096, the static checks, the fabricated artifacts, an empty plan, a build-only run,
# a full publish, the failure injection and the pipeline violations.
phase_checks() {
  ph_static_checks
  ph_setup
  ph_fabricated_checks
  ph_empty_plan
  ph_build_only
  ph_full_publish
  ph_failure_injection
  ph_pipeline_violations
  ph_cleanup
}

# `phases-rerun`: the re-run and registry-policy scenarios of publish-rerun.test.sh (AZ-2097).
phase_rerun_checks() {
  ph_setup
  ph_rerun_checks
  ph_cleanup
}
