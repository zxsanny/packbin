#!/usr/bin/env bash
# Sourced by publish-swift.test.sh (sw_setup, sw_publish, sw_calls, sw_refs, sw_assert_untouched, $sw_wf): the Swift
# golden gate (AC-1, AC-4), the Swift position program (publish-position.sh swift), the static checks (AC-5 and the
# target table), the real `swift` consumer (AC-2, AC-3) and the mutation proof of every guard.

# sw_gate_tree <name> [path to remove ...]: a tree with a marker of every language and the gate scripts of $sw_wf beside
# a stub publish-position.sh that prints the golden hex, or $SW_SWIFT_HEX for swift. Prints the tree's path.
sw_gate_tree() {
  local tree="$sw_gates/$1" wf rel
  shift
  wf="$tree/.github/workflows"
  mkdir -p "$wf" "$tree/fixtures" "$tree/csharp" "$tree/typescript" "$tree/python" "$tree/rust" "$tree/cpp" "$tree/java" \
    "$tree/go" "$tree/swift/Sources/Packbin"
  cp "$sw_wf/publish-lib.sh" "$sw_wf/publish-gate.sh" "$wf/"
  printf '%s\n' "$SW_GOLDEN" > "$tree/fixtures/golden.hex"
  for rel in csharp/Packbin.csproj typescript/package.json python/pyproject.toml rust/Cargo.toml cpp/Makefile java/test.sh \
    go/go.mod Package.swift; do
    : > "$tree/$rel"
  done
  cat > "$wf/publish-position.sh" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  swift) printf '%s\n' "${SW_SWIFT_HEX:?}" ;;
  *) cat "$SRC_ROOT/fixtures/golden.hex" ;;
esac
EOF
  for rel in "$@"; do
    rm -rf "${tree:?}/$rel"
  done
  printf '%s\n' "$tree"
}

# sw_gate <tree> <name> <swift hex>: the gate on <tree>; output in $sw_dir/<name>.out, exit code in $sw_code.
sw_gate() {
  set +e
  SW_SWIFT_HEX="$3" SRC_ROOT="$1" PACKBIN_DOCKER=0 PACKBIN_OUT="$1/out" bash "$1/.github/workflows/publish-gate.sh" \
    > "$sw_dir/$2.out" 2>&1 < /dev/null
  sw_code=$?
  set -e
}

# AC-1: a wrong Swift byte publishes nothing, tags nothing and runs no Swift check; a matching one plans swift last.
# AC-4: a tree without Package.swift or without swift/ says `absent swift`, plans the other seven, and the Go tag of a
# plan without swift is pushed with no Swift check. A plan of go and swift pushes the Go tag before the check runs.
sw_gate_checks() {
  local tree missing out code
  sw_setup
  sw_gates="$sw_dir/gates"
  tree="$(sw_gate_tree bad)"
  sw_gate "$tree" bad "$SW_WRONG"
  [ "$sw_code" -ne 0 ] || fail "AC-1 a Swift mismatch passed the gate"
  grep -qx "pack swift $SW_WRONG" "$sw_dir/bad.out" && grep -qx 'mismatch 1' "$sw_dir/bad.out" \
    && grep -qx 'publishing 0 packages' "$sw_dir/bad.out" || fail "AC-1 gate lines: $(cat "$sw_dir/bad.out")"
  [ ! -s "$tree/out/publish-plan.txt" ] || fail "AC-1 the plan is not empty after a Swift mismatch"
  grep -q '^publish ' "$sw_dir/bad.out" && fail "AC-1 a publish line after a Swift mismatch"
  sw_publish afterbad PACKBIN_PLAN="$tree/out/publish-plan.txt"
  assert_eq "$sw_code" "0" "AC-1 publish with the empty plan"
  grep -qx 'publishing 0 packages' "$sw_dir/afterbad.out" || fail "AC-1 publish with the empty plan: $(cat "$sw_dir/afterbad.out")"
  assert_eq "$(sw_calls package)/$(grep -c '^mod download ' "$sw_golog")" "0/0" "AC-1 Swift checks and Go proxy asks"
  sw_assert_untouched "AC-1 Swift mismatch"

  tree="$(sw_gate_tree good)"
  sw_gate "$tree" good "$SW_GOLDEN"
  assert_eq "$sw_code" "0" "AC-1 a matching Swift failed the gate: $(tail -n 3 "$sw_dir/good.out")"
  assert_eq "$(paste -sd ' ' "$tree/out/publish-plan.txt")" "csharp typescript python rust cpp java go swift" "AC-1 plan with Swift"
  assert_eq "$(grep -c '^pack ' "$sw_dir/good.out")/$(grep -cx 'publish swift' "$sw_dir/good.out")" "8/1" "AC-1 pack and publish lines"

  for missing in Package.swift swift; do
    tree="$(sw_gate_tree "no-$missing" "$missing")"
    sw_gate "$tree" "no-$missing" "$SW_WRONG"
    assert_eq "$sw_code" "0" "AC-4 the gate without $missing: $(tail -n 3 "$sw_dir/no-$missing.out")"
    grep -qx 'absent swift' "$sw_dir/no-$missing.out" || fail "AC-4 no 'absent swift' line without $missing"
    assert_eq "$(paste -sd ' ' "$tree/out/publish-plan.txt")" "csharp typescript python rust cpp java go" "AC-4 plan without $missing"
    assert_eq "$(grep -c '^pack ' "$sw_dir/no-$missing.out")/$(grep '^mismatch ' "$sw_dir/no-$missing.out")" "7/mismatch 0" "AC-4 without $missing"
    out="$(env SRC_ROOT="$tree" bash "$sw_wf/publish-position.sh" swift 2>&1 < /dev/null)" && code=0 || code=$?
    assert_eq "$code/$out" "2/absent swift" "AC-4 publish-position.sh swift without $missing"
  done
  printf 'go\n' > "$sw_plan"
  sw_publish goonly
  assert_eq "$sw_code" "0" "AC-4 the Go tag without Swift: $(tail -n 3 "$sw_dir/goonly.out")"
  assert_eq "$(git --git-dir="$sw_bare" rev-parse 'refs/tags/go/v0.1.9^{commit}' 2>&1)" "$sw_head" "AC-4 the Go tag"
  assert_eq "$(sw_calls package)" "0" "AC-4 Swift checks without Swift"
  grep -q 'swift-check' "$sw_dir/goonly.out" && fail "AC-4 swift-check planned without swift: $(cat "$sw_dir/goonly.out")"
  rm -rf "$sw_dir"

  sw_setup
  printf 'go\nswift\n' > "$sw_plan"
  sw_publish both
  assert_eq "$sw_code" "0" "AC-2 go and swift: $(tail -n 3 "$sw_dir/both.out")"
  assert_eq "$(grep '^upload ' "$sw_dir/both.out" | paste -sd ' ' -)" "upload go-tag upload swift-check" "AC-2 upload order"
  assert_eq "$(grep '^package ' "$sw_log" | sed 's/.*|//')" "tags=go/v0.1.9,v0.1.9" "AC-2 the Go tag is there when Swift resolves"
  assert_eq "$(cat "$sw_pushes")" "push refs/tags/go/v0.1.9 $sw_head" "AC-2 the one push is the Go tag"
  rm -rf "$sw_dir"
}

# A stand-in `swift` for ring-swift.sh: logs each call and writes the two programs into the --scratch-path of a build;
# position prints the golden hex.
sw_write_ring_swift() {
  local pin
  pin="$(bash "$sw_wf/tool-pin.sh" swift)"
  # On Linux ring-swift.sh uses the swift on PATH only when --version names the pinned Swift; otherwise it builds in
  # the swift:<pin> image (a runner carries another Swift), so the stand-in answers --version with the pin.
  cat > "$1/swift" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = --version ]; then
  echo "Swift version $pin (stub)"
  exit 0
fi
EOF
  cat >> "$1/swift" <<'EOF'
echo "swift $*" >> "$SW_RING_LOG"
prev=""
for arg in "$@"; do
  if [ "$prev" = --scratch-path ]; then
    mkdir -p "$arg/release"
    printf '#!/bin/sh\necho 4001000065cd1d00a3e1110100\n' > "$arg/release/position"
    printf '#!/bin/sh\n' > "$arg/release/handoff-swift"
    chmod +x "$arg/release/position" "$arg/release/handoff-swift"
  fi
  prev="$arg"
done
EOF
  chmod +x "$1/swift"
}

# sw_pos_tree <dir>: the Swift package and the scripts publish-position.sh swift needs, read-only like the gate's /src.
sw_pos_tree() {
  mkdir -p "$1/.github/workflows/drivers" "$1/swift/Sources/Packbin"
  cp "$root/Package.swift" "$root/Package.resolved" "$1/"
  : > "$1/swift/Sources/Packbin/A.swift"
  cp "$sw_wf/publish-lib.sh" "$sw_wf/publish-position.sh" "$sw_wf/ring-swift.sh" "$sw_wf/tool-pin.sh" "$sw_wf/tool-pins.txt" \
    "$1/.github/workflows/"
  tar -C "$here/drivers" --exclude .build --exclude .swiftpm -cf - handoff-swift | tar -C "$1/.github/workflows/drivers" -xf -
  chmod -R a-w "$1"
}

# publish-position.sh swift prints only the hex. A root named packbin (the ring's checkout) builds in the ring's scratch
# dir; a root of another name (the gate's /src) or a SRC_ROOT apart from the scripts builds on a copy in a directory
# named packbin (SwiftPM names the path dependency of the driver package after it) and removes it; the tree never changes.
sw_position_checks() {
  local dir bin log out before pkg
  dir="$(mktemp -d)"
  bin="$dir/bin"
  log="$dir/ring.log"
  mkdir -p "$bin"
  sw_write_ring_swift "$bin"
  sw_pos_tree "$dir/src"
  sw_pos_tree "$dir/packbin"
  sw_pos_tree "$dir/other/packbin"
  before="$(find "$dir/src" "$dir/packbin" "$dir/other" -exec ls -ld {} + | sort)"
  : > "$log"
  out="$(PATH="$bin:$PATH" SW_RING_LOG="$log" PACKBIN_SWIFT_RING="$dir/ring" bash "$dir/src/.github/workflows/publish-position.sh" swift 2> "$dir/src.err" < /dev/null)" \
    || fail "position: the /src-like tree failed: $(tail -n 3 "$dir/src.err")"
  assert_eq "$out" "$SW_GOLDEN" "position: stdout of the /src-like tree"
  pkg="$(sed -n 's/^swift build -c release --package-path \([^ ]*\) --scratch-path \([^ ]*\)$/\1 \2/p' "$log")"
  case "$pkg" in
    */packbin/.github/workflows/drivers/handoff-swift" "*/build) ;;
    *) fail "position: the /src-like tree did not build a copy named packbin in its own scratch: $(cat "$log")" ;;
  esac
  case "$pkg" in "$dir"/*) fail "position: the /src-like tree built in place: $pkg" ;; esac
  [ ! -e "${pkg%% *}" ] || fail "position: the copy was left behind: ${pkg%% *}"

  : > "$log"
  out="$(PATH="$bin:$PATH" SW_RING_LOG="$log" PACKBIN_SWIFT_RING="$dir/ring" bash "$dir/packbin/.github/workflows/publish-position.sh" swift 2> "$dir/packbin.err" < /dev/null)" \
    || fail "position: the packbin tree failed: $(tail -n 3 "$dir/packbin.err")"
  assert_eq "$out" "$SW_GOLDEN" "position: stdout of the packbin tree"
  assert_eq "$(sed -n 's/^swift build -c release //p' "$log")" \
    "--package-path $dir/packbin/.github/workflows/drivers/handoff-swift --scratch-path $dir/ring" "position: the packbin tree builds in the ring's scratch"

  : > "$log"
  out="$(PATH="$bin:$PATH" SW_RING_LOG="$log" SRC_ROOT="$dir/other/packbin" PACKBIN_SWIFT_RING="$dir/ring" bash "$dir/packbin/.github/workflows/publish-position.sh" swift 2> "$dir/other.err" < /dev/null)" \
    || fail "position: SRC_ROOT apart from the scripts failed: $(tail -n 3 "$dir/other.err")"
  case "$(cat "$log")" in
    *"--package-path $dir/"*) fail "position: SRC_ROOT apart from the scripts built the scripts' tree: $(cat "$log")" ;;
    *"/packbin/.github/workflows/drivers/handoff-swift --scratch-path "*/build) ;;
    *) fail "position: SRC_ROOT apart from the scripts: $(cat "$log")" ;;
  esac
  assert_eq "$out" "$SW_GOLDEN" "position: stdout with SRC_ROOT apart from the scripts"
  assert_eq "$(find "$dir/src" "$dir/packbin" "$dir/other" -exec ls -ld {} + | sort)" "$before" "position: the read-only trees"
  chmod -R u+w "$dir"
  rm -rf "$dir"
}

# AC-5: the manifest, the license and ADR-005; the swift-check row of the target table; the check passes the real files.
sw_static_checks() {
  local dir out adr script
  [ "$(sed -n 1p "$root/Package.swift")" = "// swift-tools-version: 6.0" ] || fail "AC-5 Package.swift tools version"
  grep -qF 'platforms: [.iOS(.v15), .macOS(.v12)],' "$root/Package.swift" || fail "AC-5 Package.swift platforms"
  [ "$(sed -n 1p "$root/LICENSE")" = "MIT License" ] && grep -q 'Permission is hereby granted, free of charge' "$root/LICENSE" \
    || fail "AC-5 the root LICENSE is not MIT"
  out="$(grep -rhoE 'SPDX-License-Identifier: *[^ ]+' "$root/Package.swift" "$root/LICENSE" "$root/swift" | grep -vx 'SPDX-License-Identifier: *MIT' || true)"
  assert_eq "$out" "" "AC-5 non-MIT license identifiers"
  dir="$(mktemp -d)"
  printf 'v0.1.9 %s\n' "$(printf '%040d' 0)" > "$dir/tag.txt"
  cp "$root/Package.swift" "$root/LICENSE" "$dir/"
  cp "$here/drivers/handoff-swift/Sources/position/main.swift" "$dir/main.swift"
  out="$(python3 "$sw_wf/publish-check.py" swift-check "$dir" 0.1.9 2>&1)" || fail "AC-5 the check refuses the real files: $out"
  rm -rf "$dir"
  adr="$(find "$root/_docs/02_document/adr" -name '005_*.md' | sed -n 1p)"
  if [ -z "$adr" ]; then
    fail "AC-5 no ADR-005"
  else
    for out in '- **Status**: Accepted' '.package(url: "https://github.com/zxsanny/packbin", from: "X.Y.Z")' \
      'publishes 0 packages' 'There is no Swift tag' 'Tags never move' 'publish-swift.sh'; do
      grep -qF -- "$out" "$adr" || fail "AC-5 ADR-005 does not state: $out"
    done
    grep -q '^| 005 | .* | Accepted | 2026-10-14 |' "$root/_docs/02_document/adr/README.md" || fail "AC-5 the ADR index has no 005 row"
  fi
  script='source "$1"
printf "%s|%s|%s|%s|%s\n" "$(targets_of_lang swift)" "$(target_tier swift-check)" "$(missing_credentials swift-check)" \
  "${PACKBIN_LANGS[*]}" "$(printf "%s\n" "${PACKBIN_TARGETS[@]}" | sed -n "\$p")"'
  out="$(env -u SWIFT_PACKAGE_URL -u GITHUB_TOKEN bash -c "$script" _ "$sw_wf/publish-lib.sh")"
  assert_eq "$out" "swift-check|final||csharp typescript python rust cpp java go swift|swift-check swift final" "swift-check table"
  out="$(env -u SWIFT_PACKAGE_URL bash -c 'source "$1"; swift_package_url' _ "$sw_wf/publish-lib.sh")"
  assert_eq "$out" "https://github.com/zxsanny/packbin" "the default Swift package URL"
  grep -q 'ADR-005' "$sw_wf/publish-lib.sh" || fail "publish-lib.sh does not cite ADR-005"
}

# AC-2, AC-3 with the real toolchain: the consumer resolves the tag of the local bare repository and builds Packbin; a
# re-run passes the same way; a tag at another commit fails naming both. The refs never change.
sw_real_checks() {
  local other
  if [ -z "$sw_real_swift" ]; then
    not_run="${not_run:+$not_run, }swift consumer resolve (no swift on PATH)"
    echo "NOT RUN: the real swift consumer resolve (no swift on PATH)"
    return 0
  fi
  sw_setup
  rm "$sw_bin/swift"
  for other in real-first real-again; do
    sw_publish "$other"
    assert_eq "$sw_code" "0" "AC-2 real swift $other: $(tail -n 5 "$sw_dir/$other.out")"
    grep -qx "swift consumer resolves $sw_bare 0.1.9 at $sw_head and builds Packbin (try 1)" "$sw_dir/$other.out" \
      && echo "real swift $other: $(grep '^swift consumer resolves' "$sw_dir/$other.out")" || fail "AC-2 real swift $other: no pass line"
  done
  sw_git -C "$sw_src" tag -d v0.1.9 > /dev/null
  sw_git -C "$sw_src" commit -q --allow-empty -m "another commit"
  other="$(git -C "$sw_src" rev-parse HEAD)"
  sw_publish real-moved
  sw_git -C "$sw_src" tag v0.1.9 "$sw_head"
  [ "$sw_code" -ne 0 ] || fail "AC-3 real swift: a tag at another commit passed"
  grep -qF "swift package $sw_bare resolves 0.1.9 to [0.1.9 $sw_head], but v0.1.9 is at $other" "$sw_dir/real-moved.out" \
    && echo "real swift real-moved: $(grep '^swift package ' "$sw_dir/real-moved.out")" || fail "AC-3 real swift moved: $(tail -n 3 "$sw_dir/real-moved.out")"
  sw_assert_untouched "AC-3 real swift"
  rm -rf "$sw_dir"
}

# F48 (loop 26 audit): SwiftPM runs the manifests of the dependencies as code, so the consumer check sees no credential.
# Every credential is set in the publish environment and the swift stub fails a call that any of them reaches.
sw_credential_checks() {
  local var set_args=()
  sw_setup
  for var in $SW_CREDENTIALS; do
    set_args+=("$var=secret-$var")
  done
  sw_publish creds "${set_args[@]}" SW_DENY_CREDENTIALS="$SW_CREDENTIALS"
  assert_eq "$sw_code" "0" "F48 publish with every credential set: $(tail -n 3 "$sw_dir/creds.out" | paste -sd " " -)"
  assert_eq "$(grep -c '^--version|' "$sw_log")/$(sw_calls package)/$(sw_calls build)" "1/1/1" "F48 swift calls with no credential"
  grep -qx "swift consumer resolves $sw_bare 0.1.9 at $sw_head and builds Packbin (try 1)" "$sw_dir/creds.out" \
    || fail "F48 no pass line: $(tail -n 3 "$sw_dir/creds.out")"
  sw_assert_untouched "F48"
  rm -rf "$sw_dir"
}

# sw_mutant <label> <scenario> <file> <old> <new> [anchor]: a copy of the scripts whose <file> has the first <old> after
# <anchor> replaced by <new>; <scenario> run against it must report a failure.
sw_mutant() {
  local label="$1" scenario="$2" file="$3" copy log
  sw_mutants=$((sw_mutants + 1))
  copy="$sw_mut/m$sw_mutants"
  log="$copy.log"
  mkdir -p "$copy"
  cp "$here"/publish-*.sh "$here"/publish-*.py "$here/ring-swift.sh" "$here/tool-pin.sh" "$here/tool-pins.txt" "$copy/"
  rm -f "$copy"/*.test.sh
  if ! python3 -I -c 'import sys
src, dst, old, new, anchor = sys.argv[1:6]
s = open(src).read()
at = s.find(old, s.find(anchor) if anchor else 0)
sys.exit(3) if at < 0 or (anchor and s.find(anchor) < 0) else open(dst, "w").write(s[:at] + new + s[at + len(old):])' \
    "$here/$file" "$copy/$file" "$4" "$5" "${6:-}"; then
    fail "mutant [$label]: its text is not in $file"
    return 0
  fi
  (
    failures=0
    sw_wf="$copy"
    "$scenario"
  ) > "$log" 2>&1 < /dev/null || true
  if grep -q '^FAIL: ' "$log"; then
    echo "rejects: $label ($(grep -m 1 '^FAIL: ' "$log" | cut -c 7-140))"
  else
    fail "the swift checks passed a copy with: $label"
  fi
}

sw_mutant_checks() {
  local check='@target("swift-check")'
  sw_mutants=0
  sw_mut="$(mktemp -d)"
  sw_mutant "no pin check" sw_rerun_checks publish-swift.sh 'if [ "$pin" != "$version $commit" ]; then' 'if false; then'
  sw_mutant "a pin of any location" sw_rerun_checks publish-swift.sh 'if p.get("location") == sys.argv[2]' 'if True'
  sw_mutant "no retry" sw_check_checks publish-swift.sh 'if [ "$SECONDS" -ge "$deadline" ]; then' 'if true; then'
  sw_mutant "no consumer build" sw_check_checks publish-swift.sh 'if swift build "${opts[@]}"' 'if true || swift build "${opts[@]}"'
  sw_mutant "a shared SwiftPM cache" sw_check_checks publish-swift.sh ' --cache-path "$state/cache"' ''
  sw_mutant "from: in place of exact:" sw_check_checks publish-swift.sh 'exact: "$version"' 'from: "$version"'
  sw_mutant "no string literal guard" sw_refusal_checks publish-swift.sh 'case "$url$version" in' 'case "" in'
  sw_mutant "a tag written by the check" sw_check_checks publish-swift.sh $'swift --version < /dev/null\n' \
    $'swift --version < /dev/null\ngit --git-dir="$url" update-ref "refs/tags/swift/v$version" "$commit"\n'
  sw_mutant "no tools-version check" sw_refusal_checks publish-check.py 'need(manifest.startswith(' 'need(True or manifest.startswith(' "$check"
  sw_mutant "no platforms check" sw_refusal_checks publish-check.py 'need(re.search(r"platforms:' 'need(True or re.search(r"platforms:' "$check"
  sw_mutant "no library check" sw_refusal_checks publish-check.py $'need(re.search(r\'\\.library' $'need(True or re.search(r\'\\.library' "$check"
  sw_mutant "no license check" sw_refusal_checks publish-check.py 'need(licence.startswith(' 'need(True or licence.startswith(' "$check"
  sw_mutant "no SPDX check" sw_refusal_checks publish-check.py 'need(not others,' 'need(True,' "$check"
  sw_mutant "no version check" sw_refusal_checks publish-check.py 'need(SEMVER.fullmatch(version) is not None,' 'need(True,' "$check"
  sw_mutant "no consumer import check" sw_refusal_checks publish-check.py 'need(re.search(r"(?m)^import Packbin$"' 'need(True or re.search(r"(?m)^import Packbin$"' "$check"
  sw_mutant "a bad tag line from the build" sw_rerun_checks publish-build.sh $'printf \'v%s %s\\n\' "$version"' $'printf \'x%s %s\\n\' "$version"'
  sw_mutant "no local tag refusal" sw_rerun_checks publish-build.sh '&& [ "$tagged" != "$commit" ]; then' '&& false; then'
  sw_mutant "swift present without swift/" sw_gate_checks publish-lib.sh '[ -f "$root/Package.swift" ] && [ -d "$root/swift" ]' '[ -f "$root/Package.swift" ]'
  sw_mutant "swift out of PACKBIN_LANGS" sw_gate_checks publish-lib.sh 'java go swift)' 'java go)'
  sw_mutant "no swift-check target" sw_check_checks publish-lib.sh $'  "swift-check swift final"\n' ''
  sw_mutant "swift-check not final" sw_gate_checks publish-lib.sh '"swift-check swift final"' '"swift-check swift required"'
  sw_mutant "no swift tool check" sw_refusal_checks publish-registries.sh $'      swift-check) require_tool swift ;;\n' ''
  sw_mutant "no swift upload branch" sw_check_checks publish-upload.sh 'swift-check) PACKBIN_VERSION="$version" bash "$here/publish-swift.sh" ;;' 'swift-check) ;;'
  sw_mutant "swift-check read as published" sw_rerun_checks publish-query.sh 'swift-check) return 1 ;;' 'swift-check) return 0 ;;'
  sw_mutant "no swift position case" sw_position_checks publish-position.sh $'  swift)\n' $'  swiftx)\n'
  sw_mutant "no copy for a root of another name" sw_position_checks publish-position.sh \
    'if [ "$(basename "$root")" != packbin ] || [ "$root" != "$(cd "$here/../.." && pwd)" ]; then' 'if false; then'
  sw_mutant "no copy for a SRC_ROOT apart" sw_position_checks publish-position.sh \
    ' || [ "$root" != "$(cd "$here/../.." && pwd)" ]; then' '; then'
  sw_mutant "credentials reach the swift check" sw_credential_checks publish-swift.sh $'\nunset_credentials\n' $'\n'
  sw_mutant "GITHUB_TOKEN out of the credentials" sw_credential_checks publish-lib.sh ' GITHUB_TOKEN' '' 'PACKBIN_CREDENTIALS=('
  sw_mutant "the OIDC request token kept" sw_credential_checks publish-lib.sh ' ACTIONS_ID_TOKEN_REQUEST_TOKEN' '' 'PACKBIN_CREDENTIALS=('
  echo "rejects: $sw_mutants mutants"
  chmod -R u+w "$sw_mut"
  rm -rf "$sw_mut"
}
