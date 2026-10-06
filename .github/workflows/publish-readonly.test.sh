#!/usr/bin/env bash
# Read-only repo mount checks (AZ-2215, F13). Sourced by publish-gate.test.sh, which defines fail,
# assert_eq, copy_tree, $root and $here, and by publish-phases.test.sh (ph_setup, ph_publish, ph_bares).
# The publish containers mount the repo read-only (docker-compose.publish.yml) and write only their
# own artifacts/<lang> folder. The probes really attempt the writes in the real toolchain containers;
# reading the configuration alone proves nothing. What only Linux shows (root-owned output, the
# runner's Compose) is proven by the first CI run, and the ownership assertion says so here.

# shellcheck disable=SC2154,SC2016
RO_SERVICES="csharp typescript python rust cpp java"
RO_BUILD_LANGS="csharp typescript python rust java"
RO_OVERRIDE="docker-compose.publish.yml"
RO_OPS=7

# Prints "kind path mode sha256" for every file and directory under $1 except .github/workflows/out.
ro_manifest() {
  python3 - "$1" <<'PY'
import hashlib, os, sys
base = sys.argv[1]
skip = os.path.join(base, ".github", "workflows", "out")
rows = []
for here, dirs, files in os.walk(base):
    if here == skip:
        dirs[:] = []
        continue
    for name in dirs:
        path = os.path.join(here, name)
        if path != skip:
            rows.append(f"d {os.path.relpath(path, base)} {os.stat(path).st_mode & 0o7777:o}")
    for name in files:
        path = os.path.join(here, name)
        digest = hashlib.sha256(open(path, "rb").read()).hexdigest() if os.path.isfile(path) else "-"
        rows.append(f"f {os.path.relpath(path, base)} {os.lstat(path).st_mode & 0o7777:o} {digest}")
print("\n".join(sorted(rows)))
PY
}

# Asserts two manifests ($2 before, $3 after) are equal and names the first differences if not.
ro_assert_same() {
  if [ "$2" != "$3" ]; then
    fail "$1: $(diff <(printf '%s\n' "$2") <(printf '%s\n' "$3") | head -n 6 | paste -sd '|' -)"
  fi
}

# The names directly inside directory $1, sorted, on one line.
ro_names() {
  find "$1" -mindepth 1 -maxdepth 1 -exec basename {} \; | sort | paste -sd ' ' -
}

# A copy of the tree for one scenario, without what a developer machine adds (and CI never has).
ro_tree() {
  copy_tree "$1"
  rm -rf "$1/typescript/node_modules" "$1/csharp/bin" "$1/csharp/obj"
}

# Prints the problems of the merged compose configuration ($1 = override file, $2 = project directory)
# and exits non-zero when there are any. A failure of the tools themselves exits 2 with no "problem" lines.
ro_config_errors() {
  local json
  json="$(mktemp)"
  docker compose -f "$2/docker-compose.test.yml" -f "$1" --project-directory "$2" config --format json > "$json"
  python3 - "$json" "$2" "$RO_SERVICES" <<'PY'
import json, sys
config = json.load(open(sys.argv[1]))
project = sys.argv[2]
errors = []
for name in sys.argv[3].split():
    binds = {}
    tmpfs = []
    for volume in config["services"][name].get("volumes", []):
        if volume["type"] == "bind":
            binds[volume["target"]] = volume
        elif volume["type"] == "tmpfs":
            tmpfs.append(volume["target"])
        else:
            errors.append("problem: %s: unexpected %s volume at %s" % (name, volume["type"], volume["target"]))
    src = binds.get("/src")
    if src is None or src["source"] != project or not src.get("read_only"):
        errors.append("problem: %s: /src is not a read-only bind of the repo" % name)
    for target, volume in binds.items():
        if not volume.get("read_only"):
            errors.append("problem: %s: bind %s at %s is writable" % (name, volume["source"], target))
    if "/test-results" not in tmpfs:
        errors.append("problem: %s: /test-results is not a tmpfs" % name)
print("\n".join(errors))
sys.exit(1 if errors else 0)
PY
  local code=$?
  rm -f "$json"
  return "$code"
}

# The command a container runs to try to change /src. Writes one `ro-probe` line per attempt.
ro_write_probe() {
  cat > "$1" <<'EOF'
#!/usr/bin/env bash
# Not a build: it only attempts writes and reports each result. An attempt may fail, so no -e.
set -uo pipefail
lang="${1:?language}"
attempt() {
  local label="$1" msg
  shift
  if msg="$("$@" 2>&1)"; then
    echo "ro-probe WROTE $label"
  else
    echo "ro-probe denied $label: $msg"
  fi
}
attempt append-upload bash -c 'echo x >> /src/.github/workflows/publish-upload.sh'
attempt append-lib bash -c 'echo x >> /src/.github/workflows/publish-lib.sh'
attempt git-config bash -c 'echo x >> /src/.git/config'
attempt cargo-config bash -c 'mkdir -p /src/.cargo && echo x > /src/.cargo/config.toml'
attempt new-file bash -c "echo x > /src/$lang/new-file"
attempt chmod chmod 600 /src/README.md
attempt delete rm /src/README.md
EOF
  chmod +x "$1"
}

# Asserts a probe output ($2) shows every attempt refused as read-only and none that wrote.
ro_assert_denied() {
  local label="$1" out="$2"
  if grep -q '^ro-probe WROTE' <<< "$out"; then
    fail "$label: a write into /src succeeded: $(grep '^ro-probe WROTE' <<< "$out" | head -n 3)"
  fi
  assert_eq "$(grep -c '^ro-probe denied .*Read-only file system' <<< "$out" || true)" "$RO_OPS" "$label read-only refusals"
}

# ro_probe_direct <tree> <lib file> <lang>: the probe through publish_container of <lib file> (the gate's call shape).
ro_probe_direct() {
  SRC_ROOT="$1" bash -c 'source "$1"; shift; publish_container "$@"' _ "$2" \
    -e SRC_ROOT=/src "$3" "exec /src/.github/workflows/ro-probe.sh $3" 2>&1
}

# AC-7: the merged configuration, the single call site, and the negative proofs of the checks themselves.
ro_static_checks() {
  local out tmp scripts line count file
  tmp="$(mktemp -d)"
  [ -f "$root/$RO_OVERRIDE" ] || fail "AZ-2215 AC-7 $RO_OVERRIDE is missing"
  if ! out="$(ro_config_errors "$root/$RO_OVERRIDE" "$root")"; then
    fail "AZ-2215 AC-7 merged configuration: $out"
  fi
  if ro_config_errors "$root/docker-compose.test.yml" "$root" > "$tmp/base.out"; then
    fail "AZ-2215 AC-7 the config check passed the base file alone"
  fi
  sed 's|- \./:/src:ro|- ./:/src|' "$root/$RO_OVERRIDE" > "$tmp/writable.yml"
  cmp -s "$root/$RO_OVERRIDE" "$tmp/writable.yml" && fail "AZ-2215 AC-7 temp override is unchanged"
  if ro_config_errors "$tmp/writable.yml" "$root" > "$tmp/writable.out"; then
    fail "AZ-2215 AC-7 the config check passed a writable /src"
  else
    grep -q '^problem: ' "$tmp/writable.out" || fail "AZ-2215 AC-7 the config check failed without naming a problem: $(cat "$tmp/writable.out")"
    echo "config check rejects a writable /src: $(head -n 1 "$tmp/writable.out")"
  fi
  awk '/^  java:$/ { skip = 1; next } !skip { print }' "$root/$RO_OVERRIDE" > "$tmp/no-java.yml"
  if ro_config_errors "$tmp/no-java.yml" "$root" > "$tmp/no-java.out"; then
    fail "AZ-2215 AC-7 the config check passed an override without the java service"
  else
    grep -q '^problem: ' "$tmp/no-java.out" || fail "AZ-2215 AC-7 the config check failed without naming a problem: $(cat "$tmp/no-java.out")"
    echo "config check rejects a missing service: $(head -n 1 "$tmp/no-java.out")"
  fi

  scripts="$(find "$here" -maxdepth 1 -name 'publish-*.sh' ! -name '*.test.sh' | sort)"
  count=0
  for file in $scripts; do
    while IFS= read -r line; do
      case "$line" in
        '#'* | [[:space:]]'#'*) continue ;;
      esac
      count=$((count + 1))
      [ "$(basename "$file")" = "publish-lib.sh" ] || fail "AZ-2215 AC-7 $(basename "$file") starts a container: $line"
    done < <(grep -E 'docker( |-compose)' "$file" || true)
  done
  assert_eq "$count" "1" "AZ-2215 AC-7 docker call sites in the publish scripts"
  grep -q 'publish_container' "$here/publish-build.sh" || fail "AZ-2215 AC-7 publish-build.sh does not use publish_container"
  grep -q 'publish_container' "$here/publish-gate.sh" || fail "AZ-2215 AC-7 publish-gate.sh does not use publish_container"
  grep -q -- '-f "\$root/docker-compose.publish.yml"' "$here/publish-lib.sh" || fail "AZ-2215 AC-7 publish_container drops the override file"
  if grep -n 'PACKBIN_DOCKER' "$here"/*.yml; then
    fail "AZ-2215 AC-7 a workflow sets PACKBIN_DOCKER"
  fi
  if grep -nE -- '-v [^ ]*:/src' "$here"/publish-*.sh | grep -v '\.test\.sh:'; then
    fail "AZ-2215 AC-7 a publish script mounts something over /src with -v (Compose ignores it)"
  fi
  rm -rf "$tmp"
}

# Hands a tree that a container wrote into as root back to the host user, so the host can delete it.
# Docker Desktop maps ownership and never needs this; a Linux runner does (loop 15: the negative proof
# below leaves root-owned files and `rm -rf` failed on the runner). The typescript service image is
# already pulled by the suites that run before this test.
ro_reclaim() {
  docker run --rm -v "$1:/w" --entrypoint chown node:24 -R "$(id -u):$(id -g)" /w
}

# AC-1 and AC-7: every service refuses every write through the shared function and through the build
# script; the same probe through a copy of the function without the override writes (negative proof).
ro_probe_checks() {
  local tree lang out before after
  tree="$(mktemp -d)"
  ro_tree "$tree"
  mkdir "$tree/.git"
  printf '[core]\n' > "$tree/.git/config"
  ro_write_probe "$tree/.github/workflows/ro-probe.sh"
  before="$(ro_manifest "$tree")"
  for lang in $RO_SERVICES; do
    out="$(ro_probe_direct "$tree" "$here/publish-lib.sh" "$lang")" || fail "AZ-2215 AC-1 probe container for $lang failed: $out"
    ro_assert_denied "AZ-2215 AC-1 $lang (publish_container)" "$out"
  done
  after="$(ro_manifest "$tree")"
  ro_assert_same "AZ-2215 AC-1 tree manifest after the six direct probes" "$before" "$after"

  cp "$tree/.github/workflows/ro-probe.sh" "$tree/.github/workflows/publish-inside.sh"
  before="$(ro_manifest "$tree")"
  for lang in $RO_BUILD_LANGS; do
    set +e
    out="$(SRC_ROOT="$tree" PACKBIN_OUT="$tree/.github/workflows/out/probe-$lang" PACKBIN_VERSION=0.1.9 PACKBIN_BUILD_ONLY=1 \
      bash "$tree/.github/workflows/publish-build.sh" "$lang" 2>&1)"
    set -e
    ro_assert_denied "AZ-2215 AC-1 $lang (publish-build.sh)" "$out"
  done
  after="$(ro_manifest "$tree")"
  ro_assert_same "AZ-2215 AC-1 tree manifest after the five build probes" "$before" "$after"

  sed 's| -f "\$root/docker-compose.publish.yml"||' "$here/publish-lib.sh" > "$tree/lib-without-override.sh"
  cmp -s "$here/publish-lib.sh" "$tree/lib-without-override.sh" && fail "AZ-2215 AC-7 temp lib is unchanged"
  out="$(ro_probe_direct "$tree" "$tree/lib-without-override.sh" csharp)" || fail "AZ-2215 AC-7 mutated probe container failed: $out"
  if grep -q '^ro-probe WROTE' <<< "$out"; then
    echo "probe fails without the override: $(grep -c '^ro-probe WROTE' <<< "$out") of $RO_OPS attempts wrote into /src"
  else
    fail "AZ-2215 AC-7 the probe did not notice a missing override: $out"
  fi
  ro_reclaim "$tree"
  rm -rf "$tree"
}

# AC-2 and AC-4: csharp builds for real (stale bin and obj in the copy), then a typescript container probes
# what it can reach. The csharp folder is hashed by the host at each check.
ro_out_checks() {
  local tree out log before after logs
  tree="$(mktemp -d)"
  logs="$(mktemp -d)"
  ro_tree "$tree"
  mkdir -p "$tree/csharp/bin" "$tree/csharp/obj"
  printf 'stale\n' > "$tree/csharp/bin/stale.txt"
  printf 'stale\n' > "$tree/csharp/obj/stale.txt"
  ro_write_probe "$tree/.github/workflows/ro-probe.sh"
  cp "$tree/.github/workflows/publish-inside.sh" "$tree/.github/workflows/publish-inside.real.sh"
  cp "$tree/.github/workflows/publish-check.py" "$tree/.github/workflows/publish-check.real.py"
  cat > "$tree/.github/workflows/publish-inside.sh" <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$1" = csharp ]; then
  PACKBIN_WORK=/tmp/ro-work bash "$here/publish-inside.real.sh" csharp || exit $?
  find /tmp/ro-work/tree/csharp -name stale.txt > "$PACKBIN_OUT/artifacts/csharp/stale-found.txt"
  chown "$PACKBIN_HOST_UID:$PACKBIN_HOST_GID" "$PACKBIN_OUT/artifacts/csharp/stale-found.txt"
  exit 0
fi
echo "ro-out listing: $(ls /out/artifacts | paste -sd ' ' -)"
echo own > "/out/artifacts/$1/own.txt"
if msg="$(bash -c 'echo x > /out/artifacts/csharp/x' 2>&1)"; then echo "ro-out WROTE csharp"; else echo "ro-out csharp refused: $msg"; fi
echo y > /test-results/y
echo "ro-out test-results: $(grep -c ' /test-results tmpfs ' /proc/mounts) tmpfs mount"
EOF
  cat > "$tree/.github/workflows/publish-check.py" <<'EOF'
#!/usr/bin/env python3
import hashlib, os, runpy, sys
from pathlib import Path
out = Path(os.environ["PACKBIN_OUT"])
digest = hashlib.sha256()
for path in sorted((out / "artifacts" / "csharp").rglob("*")):
    if path.is_file():
        digest.update(path.name.encode() + path.read_bytes())
with open(out / "csharp-hash.log", "a") as log:
    log.write(f"{sys.argv[1]} {digest.hexdigest()}\n")
real = str(Path(__file__).with_name("publish-check.real.py"))
sys.argv[0] = real
runpy.run_path(real, run_name="__main__")
EOF
  chmod +x "$tree/.github/workflows/publish-inside.sh"
  out="$tree/.github/workflows/out/two"
  log="$logs/two.log"
  before="$(ro_manifest "$tree")"
  set +e
  SRC_ROOT="$tree" PACKBIN_OUT="$out" PACKBIN_VERSION=0.1.9 PACKBIN_BUILD_ONLY=1 \
    bash "$tree/.github/workflows/publish-build.sh" csharp typescript > "$log" 2>&1
  set -e
  grep -qx 'build ok csharp' "$out/artifacts/build.log" || fail "AZ-2215 AC-4 csharp did not build: $(tail -n 5 "$log")"
  [ -f "$out/artifacts/csharp/Packbin.0.1.9.nupkg" ] || fail "AZ-2215 AC-4 no nupkg"
  assert_eq "$(wc -c < "$out/artifacts/csharp/stale-found.txt" | tr -d ' ')" "0" "AZ-2215 AC-4 stale bin/obj files carried into the build copy"
  after="$(ro_manifest "$tree")"
  ro_assert_same "AZ-2215 AC-4 tree manifest after the csharp build" "$before" "$after"
  grep -qx 'ro-out listing: typescript' "$log" || fail "AZ-2215 AC-2 the typescript container sees more than its own folder: $(grep 'ro-out listing' "$log")"
  grep -q '^ro-out csharp refused: .*No such file or directory' "$log" || fail "AZ-2215 AC-2 csharp artifact folder is reachable: $(grep 'ro-out' "$log")"
  grep -qx 'ro-out test-results: 1 tmpfs mount' "$log" || fail "AZ-2215 AC-2 /test-results is not a tmpfs"
  [ -f "$out/artifacts/typescript/own.txt" ] || fail "AZ-2215 AC-2 the own artifacts folder write did not reach the host"
  if [ -d "$tree/test-results" ] && [ -n "$(ls -A "$tree/test-results")" ]; then
    fail "AZ-2215 AC-2 host test-results is not empty: $(ls -A "$tree/test-results")"
  fi
  assert_eq "$(wc -l < "$out/csharp-hash.log" | tr -d ' ')" "2" "AZ-2215 AC-2 csharp hash records"
  assert_eq "$(awk 'NR == 1 { print $2 } NR == 2 { print $2 }' "$out/csharp-hash.log" | sort -u | wc -l | tr -d ' ')" "1" \
    "AZ-2215 AC-2 csharp artifact SHA-256 differs after the typescript container ran"
  rm -rf "$tree" "$logs"
}

# AC-8: with PACKBIN_DOCKER=0 (the host path) csharp still builds its nupkg and leaves no bin or obj.
ro_host_path_check() {
  local tree out before after logs
  if ! command -v dotnet >/dev/null; then
    echo "note: AZ-2215 AC-8 host-path csharp build not run: no dotnet on this host"
    return
  fi
  tree="$(mktemp -d)"
  logs="$(mktemp -d)"
  ro_tree "$tree"
  out="$tree/.github/workflows/out/host"
  before="$(ro_manifest "$tree")"
  SRC_ROOT="$tree" PACKBIN_DOCKER=0 PACKBIN_OUT="$out" PACKBIN_VERSION=0.1.9 \
    bash "$tree/.github/workflows/publish-build.sh" csharp > "$logs/host.log" 2>&1 || fail "AZ-2215 AC-8 host-path csharp build failed: $(tail -n 5 "$logs/host.log")"
  [ -f "$out/artifacts/csharp/Packbin.0.1.9.nupkg" ] || fail "AZ-2215 AC-8 host-path build made no nupkg"
  after="$(ro_manifest "$tree")"
  ro_assert_same "AZ-2215 AC-8 host-path build changed the tree (bin or obj)" "$before" "$after"
  rm -rf "$tree" "$logs"
}

# AC-5: the gate under the read-only mount, with no node_modules (npm ci runs in the container copy), prints the golden
# bytes in all six languages and changes nothing outside out/; the bad-fixture and missing-java copies behave as before.
ro_gate_checks() {
  local tree out before after count logs
  tree="$(mktemp -d)"
  logs="$(mktemp -d)"
  ro_tree "$tree"
  out="$tree/.github/workflows/out/gate"
  before="$(ro_manifest "$tree")"
  SRC_ROOT="$tree" PACKBIN_OUT="$out" bash "$tree/.github/workflows/publish-gate.sh" > "$logs/gate.log" 2> "$logs/gate.err" \
    || fail "AZ-2215 AC-5 the gate failed: $(tail -n 5 "$logs/gate.err")"
  count="$(grep -c "^pack [a-z]* $expected\$" "$logs/gate.log" || true)"
  assert_eq "$count" "6" "AZ-2215 AC-5 golden pack lines"
  assert_eq "$(grep '^mismatch ' "$logs/gate.log")" "mismatch 0" "AZ-2215 AC-5 mismatch"
  assert_eq "$(paste -sd ' ' "$out/publish-plan.txt")" "csharp typescript python rust cpp java" "AZ-2215 AC-5 plan"
  grep -q 'added [0-9]* package' "$logs/gate.err" || fail "AZ-2215 AC-5 npm ci did not run in the container copy: $(tail -n 5 "$logs/gate.err")"
  after="$(ro_manifest "$tree")"
  ro_assert_same "AZ-2215 AC-5 tree manifest after the gate" "$before" "$after"

  printf '00\n' > "$tree/fixtures/golden.hex"
  before="$(ro_manifest "$tree")"
  if SRC_ROOT="$tree" PACKBIN_OUT="$tree/.github/workflows/out/bad" bash "$tree/.github/workflows/publish-gate.sh" > "$logs/bad.log" 2> "$logs/bad.err"; then
    fail "AZ-2215 AC-5 a bad fixture passed the gate"
  fi
  [ ! -s "$tree/.github/workflows/out/bad/publish-plan.txt" ] || fail "AZ-2215 AC-5 the bad fixture left a plan"
  after="$(ro_manifest "$tree")"
  ro_assert_same "AZ-2215 AC-5 tree manifest after the bad-fixture gate" "$before" "$after"

  printf '4001000065cd1d00a3e1110100\n' > "$tree/fixtures/golden.hex"
  rm -rf "$tree/java"
  before="$(ro_manifest "$tree")"
  SRC_ROOT="$tree" PACKBIN_OUT="$tree/.github/workflows/out/nojava" bash "$tree/.github/workflows/publish-gate.sh" > "$logs/nojava.log" 2> "$logs/nojava.err" \
    || fail "AZ-2215 AC-5 the gate without java failed: $(tail -n 5 "$logs/nojava.err")"
  assert_eq "$(wc -l < "$tree/.github/workflows/out/nojava/publish-plan.txt" | tr -d ' ')" "5" "AZ-2215 AC-5 five languages without java"
  after="$(ro_manifest "$tree")"
  ro_assert_same "AZ-2215 AC-5 tree manifest after the missing-java gate" "$before" "$after"
  rm -rf "$tree" "$logs"
}

# AC-3, AC-6 and AC-8: a full build-only run (every container, the host embedded targets, signing) on a tree with a
# manifest. Needs ph_setup's tools; the manifest must be the same afterwards, and the artifacts must be the same files.
ro_full_run_check() {
  local before after target v=0.1.9 artifacts file owner
  ph_setup
  rm -rf "$ph_tree/typescript/node_modules"
  before="$(ro_manifest "$ph_tree")"
  ph_bares ro-full
  ph_publish ro-full - PACKBIN_BUILD_ONLY=1
  assert_eq "$ph_code" "0" "AZ-2215 AC-3 full build-only exit code"
  artifacts="$ph_out/artifacts"
  assert_eq "$(grep -c '^build ok ' "$ph_dir/ro-full.out")" "9" "AZ-2215 AC-3 build ok lines"
  assert_eq "$(grep -c '^check ok: ' "$ph_dir/ro-full.out")" "9" "AZ-2215 AC-3 check ok lines"
  for file in "csharp/Packbin.$v.nupkg" "typescript/packbin-$v.tgz" "python/packbin-$v-py3-none-any.whl" \
    "python/packbin-$v.tar.gz" "rust/packbin-$v.crate" rust/stage/Cargo.toml java/maven-bundle.zip vcpkg/reg \
    "platformio/packbin-$v.tar.gz" "esp-idf/packbin_$v.tgz" arduino/reg; do
    [ -e "$artifacts/$file" ] || fail "AZ-2215 AC-3 missing artifact $file"
  done
  assert_eq "$(ro_names "$artifacts/csharp")" "Packbin.$v.nupkg" "AZ-2215 AC-3 csharp folder"
  assert_eq "$(ro_names "$artifacts/typescript")" "packbin-$v.tgz" "AZ-2215 AC-3 typescript folder"
  assert_eq "$(ro_names "$artifacts/python")" "packbin-$v-py3-none-any.whl packbin-$v.tar.gz" "AZ-2215 AC-3 python folder"
  assert_eq "$(ro_names "$artifacts/java")" "maven-bundle.zip" "AZ-2215 AC-3 java folder"
  assert_eq "$(ro_names "$artifacts/rust")" "packbin-$v.crate stage" "AZ-2215 AC-3 rust folder"
  after="$(ro_manifest "$ph_tree")"
  ro_assert_same "AZ-2215 AC-6 tree manifest after the full build-only run" "$before" "$after"
  if [ "$(uname -s)" = "Linux" ]; then
    for target in csharp typescript python rust java; do
      owner="$(find "$artifacts/$target" ! -user "$(id -un)" | head -n 1)"
      [ -z "$owner" ] || fail "AZ-2215 AC-8 $owner is not owned by the host user"
    done
  else
    echo "note: AZ-2215 AC-8 artifact ownership is not observable on Docker Desktop; the CI scaffold job is its proof"
  fi
  if ! rm -rf "$ph_dir"; then
    echo "note: could not remove $ph_dir (files written by a build container)"
  fi
}

# A symlink in the tree of a container-built target is refused before any other check, for each of the five.
ro_symlink_check() {
  local dir out target
  dir="$(mktemp -d)"
  for target in csharp typescript python rust java; do
    mkdir -p "$dir/$target"
    out="$(python3 "$here/publish-check.py" "$target" "$dir/$target" 0.1.9 2>&1)" && fail "AZ-2215 $target: an empty tree passed the check"
    case "$out" in *"is a symlink"*) fail "AZ-2215 $target: the control tree was refused as a symlink: $out" ;; esac
    ln -s /etc/hostname "$dir/$target/planted"
    out="$(python3 "$here/publish-check.py" "$target" "$dir/$target" 0.1.9 2>&1)" && fail "AZ-2215 $target: a tree with a symlink passed the check"
    case "$out" in *"planted is a symlink"*) ;; *) fail "AZ-2215 $target: the symlink was not the reason: $out" ;; esac
  done
  rm -rf "$dir"
}

readonly_checks() {
  ro_symlink_check
  ro_static_checks
  ro_probe_checks
  ro_out_checks
  ro_host_path_check
  ro_gate_checks
  ro_full_run_check
}
