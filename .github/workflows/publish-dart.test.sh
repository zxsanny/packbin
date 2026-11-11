#!/usr/bin/env bash
# Dart release scenarios (AZ-4147, ADR-011; AC-1 to AC-6). Sourced by publish-gate.test.sh after publish-swift.test.sh
# (it defines fail, assert_eq, not_run, copy_tree, $root and $here), or run on its own: bash publish-dart.test.sh.
# This file holds the scenarios that need no Docker: the golden gate with a Dart mismatch (AC-1), a tree without Dart
# (AC-4), the plan and its precondition (AC-5), a version pub.dev already has (AC-3) and the upload step (AC-6), all on a
# synthetic tree of the publish scripts with PATH stubs for dart, curl and the other tools: every registry answer and every
# upload is a stub, so real uploads are 0. publish-dart-package.test.sh (sourced below) prepares the package for real in
# the dart image, runs the real `dart pub publish --dry-run` (which uploads nothing) and a path-dependency consumer.

dt_standalone=0
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  root="$(cd "$here/../.." && pwd)"
  failures=0
  not_run=""
  dt_standalone=1
  fail() {
    echo "FAIL: $*" >&2
    failures=$((failures + 1))
  }
  assert_eq() {
    if [ "$1" != "$2" ]; then
      fail "$3: expected [$2] got [$1]"
    fi
  }
  copy_tree() {
    mkdir -p "$1"
    tar -C "$root" --exclude .git --exclude test-results --exclude .github/workflows/out --exclude .build --exclude .swiftpm \
      --exclude rust/target --exclude .cache --exclude cpp/build --exclude .dart_tool -cf - . | tar -C "$1" -xf -
  }
fi

DT_GOLDEN="4001000065cd1d00a3e1110100"
DT_WRONG="4001000065cd1d00a3e1110101"
DT_CREDENTIALS="NUGET_TOKEN NPM_TOKEN PYPI_TOKEN CARGO_REGISTRY_TOKEN MAVEN_CENTRAL_TOKEN MAVEN_GPG_PRIVATE_KEY PLATFORMIO_AUTH_TOKEN IDF_COMPONENT_API_TOKEN GITHUB_TOKEN ACTIONS_ID_TOKEN_REQUEST_URL ACTIONS_ID_TOKEN_REQUEST_TOKEN PUB_TOKEN"
# The scripts under test; the mutation checks point it at a mutated copy.
dt_wf="$here"

# A JWT-shaped token whose exp is $1 seconds from now (negative: past). Not signed: the upload step reads only exp.
dt_jwt() {
  python3 -c '
import base64, json, sys, time
part = lambda d: base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b"=").decode()
print(part({"alg": "none"}) + "." + part({"exp": int(time.time()) + int(sys.argv[1])}) + ".sig")' "$1"
}

# The stubs. `dart` logs each call and its directory; `pub publish --dry-run` reports a clean package, `pub token list`
# says pub.dev is registered unless DT_NO_TOKEN is set, `pub publish --force` logs the version it finds (exit DT_PUBLISH_EXIT).
# `curl` answers only the pub.dev package document, from $DT_PUBDEV: absent (404), has (lists 9.8.7), other (lists 0.0.1),
# busy (503); it logs every call, and any other URL fails.
dt_write_stubs() {
  cat > "$1/dart" <<'EOF'
#!/bin/bash
printf 'dart %s|cwd=%s\n' "$*" "$PWD" >> "$DT_LOG"
case "$*" in
  "pub publish --dry-run") echo "Validating package..."; echo "Package has 0 warnings."; exit 0 ;;
  "pub token list")
    if [ -n "${DT_NO_TOKEN:-}" ]; then echo "You do not have any secret tokens for package repositories."; else echo "You have secret tokens for 1 package repositories:"; echo "https://pub.dev"; fi ;;
  "pub publish --force") printf 'published version=%s files=%s\n' "$(sed -n 's/^version: //p' pubspec.yaml)" "$(ls | paste -sd ' ' -)" >> "$DT_LOG"; exit "${DT_PUBLISH_EXIT:-0}" ;;
  *) echo "dart stub: unexpected $*" >&2; exit 2 ;;
esac
EOF
  cat > "$1/curl" <<'EOF'
#!/bin/bash
printf 'curl %s\n' "$*" >> "$DT_LOG"
out="" prev="" url=""
for a in "$@"; do
  if [ "$prev" = "-o" ]; then out="$a"; fi
  prev="$a"
  url="$a"
done
case "$url" in
  https://pub.dev/api/packages/packbin)
    case "${DT_PUBDEV:?}" in
      absent) printf 404 ;;
      busy) printf 503 ;;
      has) printf '{"name":"packbin","versions":[{"version":"0.1.0"},{"version":"9.8.7"}]}' > "$out"; printf 200 ;;
      other) printf '{"name":"packbin","versions":[{"version":"0.0.1"}]}' > "$out"; printf 200 ;;
    esac ;;
  *) echo "unexpected curl url: $url" >&2; exit 1 ;;
esac
EOF
  chmod +x "$1/dart" "$1/curl"
}

# dt_setup: $dt_dir with the stubs in bin/ and the log.
dt_setup() {
  dt_dir="$(mktemp -d)"
  dt_bin="$dt_dir/bin"
  dt_log="$dt_dir/calls.log"
  mkdir -p "$dt_bin"
  : > "$dt_log"
  dt_write_stubs "$dt_bin"
}

# dt_tree <name> [path to remove ...]: a tree with the publish scripts of $dt_wf, a marker of every language and a stub
# publish-position.sh that prints the golden hex, or $DT_DART_HEX for dart, and the real Dart package files the build
# needs (pubspec.yaml, lib, LICENSE). Prints the tree's path.
dt_tree() {
  local tree="$dt_dir/$1" wf rel f
  shift
  wf="$tree/.github/workflows"
  mkdir -p "$wf" "$tree/fixtures" "$tree/csharp" "$tree/typescript" "$tree/python" "$tree/rust" "$tree/cpp" "$tree/java" \
    "$tree/go" "$tree/swift" "$tree/dart"
  for f in "$dt_wf"/publish-*.sh "$dt_wf"/publish-*.py "$dt_wf/tool-pin.sh" "$dt_wf/tool-pins.txt"; do
    case "$f" in *.test.sh) continue ;; esac
    cp "$f" "$wf/"
  done
  printf '%s\n' "$DT_GOLDEN" > "$tree/fixtures/golden.hex"
  for rel in csharp/Packbin.csproj typescript/package.json python/pyproject.toml rust/Cargo.toml cpp/Makefile java/test.sh \
    go/go.mod Package.swift; do
    : > "$tree/$rel"
  done
  cp -R "$root/dart/pubspec.yaml" "$root/dart/LICENSE" "$root/dart/lib" "$tree/dart/"
  [ ! -f "$root/dart/CHANGELOG.md" ] || cp "$root/dart/CHANGELOG.md" "$tree/dart/"
  cp "$root/LICENSE" "$tree/LICENSE"
  cat > "$wf/publish-position.sh" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  dart) printf '%s\n' "${DT_DART_HEX:?}" ;;
  *) cat "$SRC_ROOT/fixtures/golden.hex" ;;
esac
EOF
  for rel in "$@"; do
    rm -rf "${tree:?}/$rel"
  done
  printf '%s\n' "$tree"
}

# dt_gate <tree> <name> <dart hex>: the gate on <tree>; output in $dt_dir/<name>.out, exit code in $dt_code.
dt_gate() {
  set +e
  DT_DART_HEX="$3" SRC_ROOT="$1" PACKBIN_DOCKER=0 PACKBIN_OUT="$1/out" bash "$1/.github/workflows/publish-gate.sh" \
    > "$dt_dir/$2.out" 2>&1 < /dev/null
  dt_code=$?
  set -e
}

# dt_publish <tree> <name> <plan words> [VAR=value ...]: publish-registries.sh of <tree> on a plan of the given languages
# with the stubs on PATH and no credential but the ones given; output in $dt_dir/<name>.out, exit code in $dt_code.
dt_publish() {
  local tree="$1" name="$2" plan="$3" unset_args=() var
  shift 3
  for var in $DT_CREDENTIALS; do
    unset_args+=(-u "$var")
  done
  printf '%s\n' $plan > "$dt_dir/$name.plan"
  set +e
  env "${unset_args[@]}" PACKBIN_PUBLISH=1 PACKBIN_DOCKER=0 SRC_ROOT="$tree" PACKBIN_PLAN="$dt_dir/$name.plan" \
    PACKBIN_OUT="$dt_dir/out-$name" PACKBIN_VERSION=v9.8.7 PACKBIN_QUERY_PAUSE=0 DT_LOG="$dt_log" DT_PUBDEV=other \
    PATH="$dt_bin:$PATH" "$@" bash "$tree/.github/workflows/publish-registries.sh" > "$dt_dir/$name.out" 2>&1 < /dev/null
  dt_code=$?
  set -e
}

# The dart and curl calls so far that match grep pattern $1, counted.
dt_calls() {
  grep -c -e "$1" "$dt_log" || true
}

# AC-1: a Dart byte that is not golden publishes nothing, for all nine languages, and the run names Dart. AC-4: a tree
# without dart/pubspec.yaml says `absent dart`, plans the other eight, and no pubdev target is planned for them.
dt_gate_checks() {
  local tree out
  dt_setup
  tree="$(dt_tree bad)"
  dt_gate "$tree" bad "$DT_WRONG"
  [ "$dt_code" -ne 0 ] || fail "AC-1 a Dart mismatch passed the gate"
  grep -qx "pack dart $DT_WRONG" "$dt_dir/bad.out" && grep -qx 'mismatch 1' "$dt_dir/bad.out" \
    && grep -qx 'publishing 0 packages' "$dt_dir/bad.out" || fail "AC-1 gate lines: $(cat "$dt_dir/bad.out")"
  grep -qx 'golden mismatch in: dart' "$dt_dir/bad.out" || fail "AC-1 the run does not name Dart: $(cat "$dt_dir/bad.out")"
  assert_eq "$(grep -c '^pack ' "$dt_dir/bad.out")" "9" "AC-1 pack lines (nine languages)"
  grep -q '^publish ' "$dt_dir/bad.out" && fail "AC-1 a publish line after a Dart mismatch"
  [ ! -s "$tree/out/publish-plan.txt" ] || fail "AC-1 the plan is not empty after a Dart mismatch"
  dt_publish "$tree" afterbad "" PACKBIN_PLAN="$tree/out/publish-plan.txt"
  assert_eq "$dt_code" "0" "AC-1 publish with the empty plan"
  grep -qx 'publishing 0 packages' "$dt_dir/afterbad.out" || fail "AC-1 publish with the empty plan: $(cat "$dt_dir/afterbad.out")"
  assert_eq "$(wc -c < "$dt_log" | tr -d ' ')" "0" "AC-1 calls to dart or a registry after the mismatch"

  tree="$(dt_tree good)"
  dt_gate "$tree" good "$DT_GOLDEN"
  assert_eq "$dt_code" "0" "AC-1 a golden Dart failed the gate: $(tail -n 3 "$dt_dir/good.out")"
  assert_eq "$(paste -sd ' ' "$tree/out/publish-plan.txt")" "csharp typescript python rust cpp java go swift dart" "AC-1 plan with Dart"

  tree="$(dt_tree nodart dart/pubspec.yaml)"
  dt_gate "$tree" nodart "$DT_WRONG"
  assert_eq "$dt_code" "0" "AC-4 the gate without dart/pubspec.yaml: $(tail -n 3 "$dt_dir/nodart.out")"
  grep -qx 'absent dart' "$dt_dir/nodart.out" || fail "AC-4 no 'absent dart' line"
  assert_eq "$(paste -sd ' ' "$tree/out/publish-plan.txt")" "csharp typescript python rust cpp java go swift" "AC-4 plan without Dart"
  assert_eq "$(grep -c '^pack ' "$dt_dir/nodart.out")" "8" "AC-4 pack lines"
  out="$(env SRC_ROOT="$tree" bash "$dt_wf/publish-position.sh" dart 2>&1 < /dev/null)" && out="ran: $out" || true
  assert_eq "$out" "absent dart" "AC-4 publish-position.sh dart without a Dart tree"
  rm -rf "$dt_dir"
}

# AC-4 and AC-5: the targets planned for a plan with and without dart (a build-only run with the build and upload scripts
# replaced by loggers), and a run that lacks PUB_TOKEN (a required target without its credential) or finds no package on
# pub.dev: it fails before anything is built or sent, with no call to dart and no write to pub.dev.
dt_plan_checks() {
  local tree wf
  dt_setup
  tree="$(dt_tree plan)"
  wf="$tree/.github/workflows"
  printf '#!/usr/bin/env bash\necho "planned build: $*" >> "$DT_LOG"\n' > "$wf/publish-build.sh"
  printf '#!/usr/bin/env bash\necho "planned upload: $*" >> "$DT_LOG"\n' > "$wf/publish-upload.sh"

  dt_publish "$tree" nodart "csharp rust" PACKBIN_BUILD_ONLY=1
  assert_eq "$dt_code" "0" "AC-4 a plan without dart: $(tail -n 3 "$dt_dir/nodart.out")"
  assert_eq "$(grep '^planned build' "$dt_log")" "planned build: csharp rust" "AC-4 targets without dart"
  : > "$dt_log"
  dt_publish "$tree" withdart "csharp rust dart" PACKBIN_BUILD_ONLY=1
  assert_eq "$(grep '^planned build' "$dt_log")" "planned build: csharp rust pubdev" "AC-4 targets with dart: the others are unchanged"
  assert_eq "$(bash -c 'source "$1"; target_tier pubdev; targets_of_lang dart' _ "$wf/publish-lib.sh" | paste -sd ' ' -)" "required pubdev" "pubdev target table"

  : > "$dt_log"
  dt_publish "$tree" nopermission "dart"
  assert_eq "$dt_code" "1" "AC-5 a run without PUB_TOKEN"
  grep -qx 'pubdev is required and lacks: PUB_TOKEN' "$dt_dir/nopermission.out" || fail "AC-5 the refusal does not name pubdev and PUB_TOKEN: $(cat "$dt_dir/nopermission.out")"
  grep -q 'nothing was built or written' "$dt_dir/nopermission.out" || fail "AC-5 the refusal does not say that nothing was written: $(cat "$dt_dir/nopermission.out")"
  assert_eq "$(wc -c < "$dt_log" | tr -d ' ')" "0" "AC-5 calls made after a refusal for the missing permission"
  [ ! -e "$dt_dir/out-nopermission/artifacts" ] || fail "AC-5 something was built after the refusal"

  : > "$dt_log"
  dt_publish "$tree" nopackage "dart" PUB_TOKEN="$(dt_jwt 600)" DT_PUBDEV=absent
  assert_eq "$dt_code" "1" "AC-5 a pub.dev without the package"
  grep -q "pub.dev has no package packbin" "$dt_dir/nopackage.out" || fail "AC-5 no first-publish message: $(cat "$dt_dir/nopackage.out")"
  assert_eq "$(dt_calls '^planned')/$(dt_calls '^dart ')/$(dt_calls '^curl .* -X ')" "0/0/0" "AC-5 builds, dart calls and writes after a missing package"
  dt_publish "$tree" busy "dart" PUB_TOKEN="$(dt_jwt 600)" DT_PUBDEV=busy
  assert_eq "$dt_code" "1" "AC-5 a pub.dev that cannot be asked"
  grep -q "cannot tell whether pubdev 9.8.7 is published" "$dt_dir/busy.out" || fail "AC-5 an unknown answer was not reported: $(cat "$dt_dir/busy.out")"
  assert_eq "$(dt_calls '^planned')" "0" "AC-5 builds after a pub.dev that cannot be asked"
  rm -rf "$dt_dir"
}

# AC-3 and AC-6: the real build (on the host, the dart stub answering the dry run) and the real upload scripts. A version
# pub.dev already has is reported and not uploaded, and the run succeeds. A version it lacks runs `dart pub publish
# --force` once, in a copy outside the tree, on the package with version 9.8.7. A token that expired, one that is not a
# JWT, or one setup-dart did not register stops the run before `pub publish`.
dt_upload_checks() {
  local tree token published
  dt_setup
  tree="$(dt_tree upload)"
  token="$(dt_jwt 600)"

  dt_publish "$tree" has "dart" PUB_TOKEN="$token" DT_PUBDEV=has
  assert_eq "$dt_code" "0" "AC-3 a version pub.dev has: $(tail -n 4 "$dt_dir/has.out")"
  grep -qx 'already published pubdev 9.8.7' "$dt_dir/has.out" || fail "AC-3 not reported as already published: $(cat "$dt_dir/has.out")"
  assert_eq "$(dt_calls 'pub publish --force')" "0" "AC-3 an upload attempt for a version pub.dev has"
  grep -q '^upload pubdev' "$dt_dir/has.out" && fail "AC-3 an upload line for a version pub.dev has"
  assert_eq "$(grep -c '^curl .*-X \|^curl .*--data\|^curl .* -T ' "$dt_log" || true)" "0" "AC-6 writes to pub.dev through curl"

  : > "$dt_log"
  dt_publish "$tree" fresh "dart" PUB_TOKEN="$token" DT_PUBDEV=other
  assert_eq "$dt_code" "0" "AC-6 an upload through the stub: $(tail -n 4 "$dt_dir/fresh.out")"
  grep -qx 'upload pubdev' "$dt_dir/fresh.out" || fail "AC-6 no upload line: $(cat "$dt_dir/fresh.out")"
  assert_eq "$(dt_calls '^dart pub publish --force')" "1" "AC-6 publish calls"
  assert_eq "$(dt_calls '^dart pub token list')" "1" "AC-6 the registered-token check"
  published="$(grep '^published version=' "$dt_log")"
  assert_eq "${published%% files=*}" "published version=9.8.7" "AC-2 the published package carries the tag version"
  case "$(grep '^dart pub publish --force' "$dt_log")" in
    *"cwd=$dt_dir"*) fail "AC-6 pub publish ran inside the tree: $(grep '^dart pub publish --force' "$dt_log")" ;;
  esac
  grep -q '^check ok: pubdev' "$dt_dir/fresh.out" || fail "AC-2 the prepared package was not checked: $(cat "$dt_dir/fresh.out")"
  assert_eq "$(grep -c -- '--dry-run' "$dt_log")" "1" "AC-2 one dry run in the build phase"

  : > "$dt_log"
  dt_publish "$tree" expired "dart" PUB_TOKEN="$(dt_jwt -5)" DT_PUBDEV=other
  assert_eq "$dt_code" "1" "AC-6 an expired token"
  grep -q 'expired .* run the tag again' "$dt_dir/expired.out" || fail "AC-6 an expired token is not explained: $(tail -n 3 "$dt_dir/expired.out")"
  assert_eq "$(dt_calls 'pub publish --force')" "0" "AC-6 an upload with an expired token"
  dt_publish "$tree" notjwt "dart" PUB_TOKEN="not-a-jwt" DT_PUBDEV=other
  assert_eq "$dt_code" "1" "AC-6 a token that is not a JWT"
  grep -q 'cannot read the OIDC token' "$dt_dir/notjwt.out" || fail "AC-6 a bad token is not explained: $(tail -n 3 "$dt_dir/notjwt.out")"
  dt_publish "$tree" unregistered "dart" PUB_TOKEN="$token" DT_PUBDEV=other DT_NO_TOKEN=1
  assert_eq "$dt_code" "1" "AC-6 a token setup-dart did not register"
  grep -q 'did not register a token for https://pub.dev' "$dt_dir/unregistered.out" || fail "AC-6 an unregistered token is not explained: $(tail -n 3 "$dt_dir/unregistered.out")"
  dt_publish "$tree" refused "dart" PUB_TOKEN="$token" DT_PUBDEV=other DT_PUBLISH_EXIT=65
  [ "$dt_code" -ne 0 ] || fail "AC-6 a publish that pub.dev refuses did not fail the run"
  rm -rf "$dt_dir"
}

# AC-6 and the official mechanism, read from the files: `pub publish` without --dry-run appears only in
# publish-pubdev.sh (with --force, run after setup-dart); publish.yml keeps its permissions, pins setup-dart by commit
# and runs it after the golden gate and before the registries; no script stores or creates a token of pub.dev.
dt_static_checks() {
  local f line yml="$dt_wf/publish.yml" setup gate registries
  for f in "$dt_wf"/publish*.sh "$dt_wf"/publish*.py "$dt_wf"/publish*.yml; do
    case "$f" in *.test.sh | */publish-pubdev.sh) continue ;; esac
    while IFS= read -r line; do
      case "$line" in *--dry-run*) ;; *) fail "AC-6 $(basename "$f") has a pub publish without --dry-run: $line" ;; esac
    done < <(grep -E '(^|[[:space:];&(])dart pub publish' "$f" | grep -vE '^[[:space:]]*#' || true)
  done
  grep -q 'dart pub publish --force' "$dt_wf/publish-pubdev.sh" || fail "AC-6 publish-pubdev.sh does not run dart pub publish --force"
  for f in "$dt_wf"/publish*.sh "$dt_wf"/publish*.py "$yml"; do
    case "$f" in *.test.sh) continue ;; esac
    if grep -vE '^[[:space:]]*#' "$f" | grep -qE 'pub token add|PUB_TOKEN=|credentials\.json'; then
      fail "AC-6 $(basename "$f") stores or creates a pub.dev token"
    fi
  done
  grep -qE '^[[:space:]]+- uses: dart-lang/setup-dart@[0-9a-f]{40} # v[0-9.]+$' "$yml" || fail "AC-2 setup-dart is not pinned by a commit with its tag"
  setup="$(grep -n 'dart-lang/setup-dart@' "$yml" | head -n 1 | cut -d: -f1)"
  gate="$(grep -n 'publish-gate.sh' "$yml" | head -n 1 | cut -d: -f1)"
  registries="$(grep -n 'publish-registries.sh' "$yml" | head -n 1 | cut -d: -f1)"
  if [ -z "$setup" ] || [ "$setup" -le "$gate" ] || [ "$setup" -ge "$registries" ]; then
    fail "AC-2 setup-dart does not run between the golden gate and the registries"
  fi
  ! grep -q 'environment:' "$yml" || fail "AC-2 the publish job names an environment (ADR-011: it would change the OIDC claims of every registry)"
}

dart_checks() {
  dt_static_checks
  dt_gate_checks
  dt_plan_checks
  dt_upload_checks
  dart_package_checks
}

# shellcheck source=publish-dart-package.test.sh
source "$here/publish-dart-package.test.sh"

if [ "$dt_standalone" = 1 ]; then
  dart_checks
  if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)" >&2
    exit 1
  fi
  if [ -n "$not_run" ]; then
    echo "dart release tests: no failures, NOT RUN: $not_run"
  else
    echo "dart release tests passed"
  fi
fi
