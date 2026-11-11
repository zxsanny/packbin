#!/usr/bin/env bash
# Sourced by publish-dart.test.sh (fail, assert_eq, not_run, copy_tree, $root, $here, $dt_wf): the Dart package prepared for
# real (AC-2). publish-build.sh runs in the dart image on a copy of the tree for a test tag v9.8.7; the real
# `dart pub publish --dry-run` runs on the prepared copy and uploads nothing (it reads pub.dev for the dependencies); a
# consumer with a path dependency on the prepared package resolves and prints the golden hex; publish-check.py is held
# to every rule against mutated copies of the prepared package.

# shellcheck disable=SC2154
# dp_dart <dir> <command...>: the dart image (the pinned tag, the Dart suite's image) with <dir> mounted at its own path, run as
# the caller, in <dir>/consumer. Needs the network for pub get.
dp_dart() {
  docker run --rm -i --user "$(id -u):$(id -g)" -e HOME="$1/home" -e PUB_CACHE="$1/pub-cache" -v "$1:$1" -w "$1/consumer" \
    "dart:$(bash "$dt_wf/tool-pin.sh" dart)" dart "${@:2}" < /dev/null
}

# dp_build <name> [VAR=value ...]: publish-build.sh pubdev for the test tag on $dp_tree; output in $dp_dir/<name>.out,
# the artifact in $dp_tree/.github/workflows/out/<name>/artifacts/pubdev, exit code in $dp_code.
dp_build() {
  local name="$1"
  shift
  set +e
  env SRC_ROOT="$dp_tree" PACKBIN_OUT="$dp_tree/.github/workflows/out/$name" PACKBIN_VERSION=v9.8.7 "$@" \
    bash "$dp_tree/.github/workflows/publish-build.sh" pubdev > "$dp_dir/$name.out" 2>&1 < /dev/null
  dp_code=$?
  set -e
  dp_art="$dp_tree/.github/workflows/out/$name/artifacts/pubdev"
}

# What the real dry run printed for the prepared package: the warnings it names (the list AZ-4148 must clear).
DP_WARNING_SAMPLE='Validating package...
Package validation found the following 2 potential issues:
* Please add a README.md file that describes your package.

* Please add a `CHANGELOG.md` to your package. See https://dart.dev/tools/pub/publishing#important-files.
The server may enforce additional checks.

Package has 2 warnings.
exit 65'
DP_ERROR_SAMPLE='Validating package...
Package validation found the following error:
* You must have a LICENSE file in the root directory.
  An open-source license helps ensure people can legally use your code.

Package validation found the following 2 potential issues:
* Please add a README.md file that describes your package.

* Please add a `CHANGELOG.md` to your package. See https://dart.dev/tools/pub/publishing#important-files.
Sorry, your package is missing a requirement and can'"'"'t be published yet.
For more information, see: https://dart.dev/tools/pub/cmd/pub-lish.
exit 65'

# dp_check <dir> <version> [VAR=value ...]: publish-check.py pubdev; its output is in $dp_out, its exit code in $dp_code.
dp_check() {
  local dir="$1" version="$2"
  shift 2
  set +e
  dp_out="$(env "$@" python3 "$dt_wf/publish-check.py" pubdev "$dir" "$version" 2>&1)"
  dp_code=$?
  set -e
}

# dp_refuses <label> <needle> <dir> <version> [VAR=value ...]: the check fails and its message holds <needle>.
dp_refuses() {
  local label="$1" needle="$2"
  shift 2
  dp_check "$@"
  if [ "$dp_code" -ne 1 ] || ! grep -qF -- "$needle" <<< "$dp_out"; then
    fail "AC-2 the check did not refuse [$label] with [$needle]: exit $dp_code, $dp_out"
  fi
}

# One mutated copy of the prepared package $dp_art at $dp_dir/mut, edited by command $1 (run inside the copy).
dp_mutant() {
  rm -rf "$dp_dir/mut"
  cp -R "$dp_art" "$dp_dir/mut"
  (cd "$dp_dir/mut" && eval "$1")
}

dp_check_mutants() {
  dp_mutant "sed -i.bak 's/^name: packbin/name: packbim/' package/pubspec.yaml && rm package/pubspec.yaml.bak"
  dp_refuses "another name" "not packbin" "$dp_dir/mut" 9.8.7
  dp_refuses "another version" "not 9.8.6" "$dp_art" 9.8.6
  dp_mutant "sed -i.bak '/^  sdk:/d' package/pubspec.yaml && rm package/pubspec.yaml.bak"
  dp_refuses "no sdk constraint" "environment: sdk" "$dp_dir/mut" 9.8.7
  dp_mutant "printf 'dependencies:\n  path: ^1.9.0\n' >> package/pubspec.yaml"
  dp_refuses "a runtime dependency" "runtime dependencies" "$dp_dir/mut" 9.8.7
  dp_mutant "rm package/LICENSE"
  dp_refuses "no license" "LICENSE is missing" "$dp_dir/mut" 9.8.7
  dp_mutant "printf 'Apache License\n' > package/LICENSE"
  dp_refuses "another license" "not the MIT license" "$dp_dir/mut" 9.8.7
  dp_mutant "rm package/lib/packbin.dart"
  dp_refuses "no library" "lib/packbin.dart is missing" "$dp_dir/mut" 9.8.7
  dp_mutant "mkdir package/.dart_tool"
  dp_refuses "a build leftover" ".dart_tool or pubspec.lock" "$dp_dir/mut" 9.8.7
  dp_mutant "ln -s /etc/hostname package/planted"
  dp_refuses "a symlink" "planted is a symlink" "$dp_dir/mut" 9.8.7
  dp_mutant "rm publish-dry-run.txt"
  dp_refuses "no dry run" "publish-dry-run.txt" "$dp_dir/mut" 9.8.7
  dp_mutant "printf '%s\n' 'Package has 0 warnings.' > publish-dry-run.txt"
  dp_refuses "a dry run without an exit line" "does not end in an exit line" "$dp_dir/mut" 9.8.7
  dp_mutant "printf '%s\n' 'boom' 'exit 1' > publish-dry-run.txt"
  dp_refuses "a dry run that failed with neither errors nor warnings" "dry-run reports errors" "$dp_dir/mut" 9.8.7
  dp_mutant true
  printf '%s\n' "$DP_ERROR_SAMPLE" > "$dp_dir/mut/publish-dry-run.txt"
  dp_refuses "a dry run with an error" "You must have a LICENSE file" "$dp_dir/mut" 9.8.7
  dp_mutant true
  printf '%s\n' "$DP_WARNING_SAMPLE" > "$dp_dir/mut/publish-dry-run.txt"
  dp_check "$dp_dir/mut" 9.8.7
  [ "$dp_code" -eq 0 ] && grep -q 'note: pubdev: dry run warning: Please add a README.md' <<< "$dp_out" || fail "AC-2 warnings only must pass and be listed: $dp_out"
  dp_refuses "warnings with PACKBIN_DART_STRICT=1" "PACKBIN_DART_STRICT=1" "$dp_dir/mut" 9.8.7 PACKBIN_DART_STRICT=1
  dp_mutant "printf '%s\n' '# Changelog' '## 9.8.6' > package/CHANGELOG.md; printf 'Package has 0 warnings.\nexit 0\n' > publish-dry-run.txt"
  dp_check "$dp_dir/mut" 9.8.7
  grep -q 'note: pubdev: CHANGELOG.md has no entry for 9.8.7' <<< "$dp_out" || fail "AC-2 a CHANGELOG without the version is not noted: $dp_out"
  dp_refuses "a CHANGELOG without the version with PACKBIN_DART_STRICT=1" "no entry for 9.8.7" "$dp_dir/mut" 9.8.7 PACKBIN_DART_STRICT=1
  dp_mutant "printf '%s\n' '# Changelog' '## 9.8.7' > package/CHANGELOG.md; printf 'Package has 0 warnings.\nexit 0\n' > publish-dry-run.txt"
  dp_check "$dp_dir/mut" 9.8.7 PACKBIN_DART_STRICT=1
  [ "$dp_code" -eq 0 ] && ! grep -q '^note' <<< "$dp_out" || fail "AC-2 a clean package with PACKBIN_DART_STRICT=1 must pass without a note: $dp_out"
}

dart_package_checks() {
  local tag out
  if ! command -v docker > /dev/null || ! docker info > /dev/null 2>&1; then
    not_run="${not_run:+$not_run; }dart package build (no Docker)"
    return
  fi
  dp_dir="$(mktemp -d)"
  dp_tree="$dp_dir/tree"
  mkdir -p "$dp_dir/home" "$dp_dir/pub-cache" "$dp_dir/consumer"
  copy_tree "$dp_tree"
  rm -rf "$dp_tree/dart/.dart_tool" "$dp_tree/dart/pubspec.lock"

  # AC-2: the real package of the tree.
  dp_build pkg
  assert_eq "$dp_code" "0" "AC-2 the build of the Dart package: $(tail -n 8 "$dp_dir/pkg.out")"
  grep -qx 'build ok pubdev' "$dp_dir/pkg.out" && grep -qx 'check ok: pubdev' "$dp_dir/pkg.out" || fail "AC-2 build lines: $(tail -n 5 "$dp_dir/pkg.out")"
  assert_eq "$(grep -c '^version: 9.8.7$' "$dp_art/package/pubspec.yaml")" "1" "AC-2 pubspec version"
  assert_eq "$(sed -n 's/^name: //p' "$dp_art/package/pubspec.yaml")" "packbin" "AC-2 pubspec name"
  assert_eq "$(tail -n 1 "$dp_art/publish-dry-run.txt" | sed 's/^exit 0$/exit 0 or 65/; s/^exit 65$/exit 0 or 65/')" "exit 0 or 65" "AC-2 dry run exit code"
  grep -q 'found the following error' "$dp_art/publish-dry-run.txt" && fail "AC-2 the dry run reports errors: $(sed -n '/^Validating/,$p' "$dp_art/publish-dry-run.txt")"
  echo "dart dry run of the prepared package (0 errors): $(grep -E '^Package has [0-9]+ warnings?\.' "$dp_art/publish-dry-run.txt" || echo 'Package has 0 warnings.')"
  grep '^note: pubdev: ' "$dp_dir/pkg.out" | sed 's/^/  AZ-4148 must clear: /' || true
  [ ! -e "$dp_tree/dart/.dart_tool" ] || fail "AC-2 the build wrote into the tree (read-only mount)"
  grep -q 'publish --dry-run' "$dp_dir/pkg.out" && ! grep -q 'publish --force' "$dp_dir/pkg.out" || fail "AC-6 the build phase ran something other than a dry run"

  # AC-2: a consumer with a path dependency on the prepared package resolves with 0 runtime dependencies, prints the golden hex.
  mkdir -p "$dp_dir/consumer/bin"
  printf 'name: consumer\nenvironment:\n  sdk: ^3.13.0\ndependencies:\n  packbin:\n    path: %s\n' "$dp_art/package" > "$dp_dir/consumer/pubspec.yaml"
  cat > "$dp_dir/consumer/bin/main.dart" <<'DART'
import 'package:packbin/packbin.dart';

void main() {
  final s = scheme(0x40, [u16(0, 'sid'), i32(1, 'lat'), i32(2, 'lon'), u8(3, 'profile'), flags(4, [u16(4, 'heading'), u8(5, 'speed'), i16(6, 'altitude')])]);
  final raw = pack(s, {'sid': 1, 'lat': 500000000, 'lon': 300000000, 'profile': 1});
  print(raw.map((b) => b.toRadixString(16).padLeft(2, '0')).join());
}
DART
  out="$(dp_dart "$dp_dir" pub get 2>&1)" || fail "AC-2 the consumer did not resolve: $out"
  assert_eq "$(awk '/^packages:/ { in_packages = 1; next } /^[a-z]/ { in_packages = 0 } in_packages && /^  [a-z0-9_]+:$/ { n++ } END { print n + 0 }' "$dp_dir/consumer/pubspec.lock")" "1" "AC-2 packages the consumer resolves (packbin alone)"
  out="$(dp_dart "$dp_dir" run bin/main.dart 2>&1)" || fail "AC-2 the consumer did not run: $out"
  assert_eq "$out" "$DT_GOLDEN" "AC-2 the consumer prints the golden hex"
  echo "dart consumer (path dependency on the prepared package): 1 package resolved, prints $out"

  dp_check_mutants

  # PACKBIN_DART_STRICT=1: refuses the package of a tree without README.md and CHANGELOG.md, passes one that has them with an entry
  # for the tag; the real dry run reports 0 warnings (the switch AZ-4148 turns on).
  rm -rf "$dp_tree/dart/README.md" "$dp_tree/dart/CHANGELOG.md" "$dp_tree/dart/example"
  dp_build bare PACKBIN_DART_STRICT=1
  assert_eq "$dp_code" "1" "AC-2 strict mode on a package without README.md and CHANGELOG.md"
  grep -q 'PACKBIN_DART_STRICT=1 and the package is not clean: CHANGELOG.md is absent' "$dp_dir/bare.out" || fail "AC-2 strict refusal: $(tail -n 3 "$dp_dir/bare.out")"
  printf '# packbin\n\nCompact binary packing.\n' > "$dp_tree/dart/README.md"
  printf '## 9.8.7\n\n- Test release.\n' > "$dp_tree/dart/CHANGELOG.md"
  mkdir -p "$dp_tree/dart/example"
  printf 'void main() {}\n' > "$dp_tree/dart/example/example.dart"
  dp_build clean PACKBIN_DART_STRICT=1
  assert_eq "$dp_code" "0" "AC-2 strict mode on a clean package: $(tail -n 8 "$dp_dir/clean.out")"
  grep -qx 'Package has 0 warnings.' "$dp_art/publish-dry-run.txt" && grep -qx 'exit 0' "$dp_art/publish-dry-run.txt" || fail "AC-2 the dry run of the clean package is not 0 errors and 0 warnings: $(sed -n '/^Validating/,$p' "$dp_art/publish-dry-run.txt")"
  echo "dart strict mode: refuses the bare package, passes the clean one (dry run: $(grep -E '^Package has' "$dp_art/publish-dry-run.txt"))"
  grep -q '^note' "$dp_dir/clean.out" && fail "AC-2 a clean package has notes: $(grep '^note' "$dp_dir/clean.out")"
  tag="$(bash "$dt_wf/tool-pin.sh" dart)"
  rm -rf "$dp_dir" || echo "note: could not remove $dp_dir (files written by the dart image, pin $tag)"
}
