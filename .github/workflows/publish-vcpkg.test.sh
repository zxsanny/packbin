#!/usr/bin/env bash
# vcpkg port checks (AZ-2098, AZ-2232, AZ-2240). Sourced by publish-gate.test.sh, which defines fail, assert_eq,
# $root and $here, and reports $not_run in its last line; `bash publish-gate.test.sh --vcpkg` runs only these.
# The port is staged into a local bare git registry by the real publish-registries.sh, a consumer
# project installs it through the vcpkg toolchain from that registry, builds, links and runs it.
# vcpkg is the one on GitHub-hosted Ubuntu runners ($VCPKG_INSTALLATION_ROOT), or $VCPKG_ROOT, or the
# one on PATH. Without vcpkg or cmake a run on GitHub Actions fails; anywhere else it prints
# `<check> NOT RUN` and the gate says so in its last line: a check that did not run is not a pass.
# PACKBIN_CXX_SYSROOT (macOS only, see _docs/AGENT_GOTCHAS.md) adds the sysroot flags to the cmake builds
# and writes an overlay triplet for the vcpkg consumer into the temp dir; unset, nothing of it exists.

# shellcheck disable=SC2154
# AZ-2232: 0.9.0, not 0.1.0. An installed 0.1.0 is older than every other 0.x minor, so a request for another
# minor would fail for that reason alone and could not show that the version rule is "same minor".
vcpkg_version="0.9.0"

# A missing tool fails the gate on GitHub Actions and is a visible NOT RUN anywhere else.
vcpkg_tool_missing() {
  local check="$1" tool="$2"
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    fail "AZ-2098 $check: no $tool"
  else
    echo "$check NOT RUN: no $tool"
    not_run="${not_run:+$not_run, }$check"
  fi
}

# Prints the root of a bootstrapped vcpkg and returns 0, or returns 1 when there is none.
vcpkg_root() {
  local candidate tool
  tool="$(command -v vcpkg || true)"
  if [ -n "$tool" ]; then
    tool="$(python3 -c 'import os, sys; print(os.path.dirname(os.path.realpath(sys.argv[1])))' "$tool")"
  fi
  for candidate in "${VCPKG_ROOT:-}" "${VCPKG_INSTALLATION_ROOT:-}" "$tool"; do
    if [ -n "$candidate" ] && [ -x "$candidate/vcpkg" ] && [ -f "$candidate/scripts/buildsystems/vcpkg.cmake" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# vcpkg_run <log> <command>...: the output goes to the log, and to stderr when the command fails.
vcpkg_run() {
  local log="$1"
  shift
  if ! "$@" >"$log" 2>&1; then
    cat "$log" >&2
    return 1
  fi
}

# PACKBIN_CXX_SYSROOT is the macOS SDK path that this host's compiler needs to find the C++ headers (the
# recipe of language-pair.sh and publish-position.sh). Prints the compile flags for it; prints nothing when it is unset,
# as on the CI runner.
vcpkg_sysroot_flags() {
  local sdk="${PACKBIN_CXX_SYSROOT:-}"
  if [ -n "$sdk" ]; then
    printf '%s\n' "-isysroot $sdk -I$sdk/usr/include/c++/v1"
  fi
}

# With PACKBIN_CXX_SYSROOT set, writes an overlay triplet into directory $2: the default macOS triplet of vcpkg
# root $1 plus the sysroot flags (vcpkg ignores CXXFLAGS), and prints the directory. Prints nothing when it is unset.
vcpkg_sysroot_triplets() {
  local vroot="$1" dir="$2" sdk="${PACKBIN_CXX_SYSROOT:-}" triplet="x64-osx"
  if [ -z "$sdk" ]; then
    return 0
  fi
  if [ "$(uname -m)" = "arm64" ]; then
    triplet="arm64-osx"
  fi
  if [ ! -f "$vroot/triplets/$triplet.cmake" ]; then
    echo "PACKBIN_CXX_SYSROOT is set but $vroot has no triplet $triplet" >&2
    return 1
  fi
  mkdir -p "$dir"
  {
    cat "$vroot/triplets/$triplet.cmake"
    printf 'set(VCPKG_C_FLAGS "-isysroot %s")\n' "$sdk"
    printf 'set(VCPKG_CXX_FLAGS "%s")\n' "$(vcpkg_sysroot_flags)"
  } > "$dir/$triplet.cmake"
  printf '%s\n' "$dir"
}

# One real publish-registries.sh run that builds the vcpkg port and pushes it to bare repository $1.
# $2 is a scratch directory, $3 names the run. The optional targets lack their token and are skipped.
vcpkg_stage_registry() {
  local bare="$1" dir="$2" name="$3"
  printf 'cpp\n' > "$dir/plan.txt"
  env -u GITHUB_TOKEN -u PLATFORMIO_AUTH_TOKEN -u IDF_COMPONENT_API_TOKEN -u GITHUB_STEP_SUMMARY \
    PACKBIN_PUBLISH=1 PACKBIN_DOCKER=0 PACKBIN_PLAN="$dir/plan.txt" PACKBIN_VERSION="$vcpkg_version" \
    PACKBIN_OUT="$dir/out-$name" VCPKG_REGISTRY_URL="$bare" \
    bash "$here/publish-registries.sh" >"$dir/stage-$name.log" 2>&1 || {
    cat "$dir/stage-$name.log" >&2
    return 1
  }
}

# AC-4: the port that the registry holds, read back with git, and its versions files.
vcpkg_port_checks() {
  local bare="$1" file portfile
  for file in CMakeLists.txt LICENSE portfile.cmake vcpkg.json include/packbin/packbin.hpp \
    src/core/pack.cpp src/os_random.cpp; do
    git --git-dir="$bare" cat-file -e "vcpkg:ports/packbin/$file" || fail "AZ-2098 AC-4 the port lacks $file"
  done
  cmp -s <(git --git-dir="$bare" show vcpkg:ports/packbin/LICENSE) "$root/LICENSE" \
    || fail "AZ-2098 AC-4 the port LICENSE is not the repository LICENSE"
  cmp -s <(git --git-dir="$bare" show vcpkg:ports/packbin/CMakeLists.txt) "$root/cpp/CMakeLists.txt" \
    || fail "AZ-2098 AC-4 the port CMakeLists.txt is not cpp/CMakeLists.txt"
  portfile="$(git --git-dir="$bare" show vcpkg:ports/packbin/portfile.cmake)"
  for file in vcpkg_cmake_configure vcpkg_cmake_install vcpkg_cmake_config_fixup vcpkg_install_copyright; do
    grep -q "^$file(" <<<"$portfile" || fail "AZ-2098 AC-4 the portfile does not call $file"
  done
  python3 - "$bare" "$vcpkg_version" <<'PY' || fail "AZ-2098 AC-4 port metadata"
import json, subprocess, sys

bare, version = sys.argv[1:]


def show(path):
    out = subprocess.run(["git", "--git-dir", bare, "show", f"vcpkg:{path}"], capture_output=True, text=True, check=True)
    return out.stdout


errors = []
manifest = json.loads(show("ports/packbin/vcpkg.json"))
hosts = {d["name"]: d.get("host") for d in manifest.get("dependencies", []) if isinstance(d, dict)}
for key, want in (("name", "packbin"), ("version", version), ("license", "MIT"), ("supports", "linux | osx")):
    if manifest.get(key) != want:
        errors.append(f"vcpkg.json {key} is {manifest.get(key)!r}, not {want!r}")
if hosts != {"vcpkg-cmake": True, "vcpkg-cmake-config": True}:
    errors.append(f"vcpkg.json host dependencies are {hosts}")
tree = subprocess.run(["git", "--git-dir", bare, "rev-parse", "vcpkg:ports/packbin"], capture_output=True, text=True, check=True).stdout.strip()
entry = json.loads(show("versions/p-/packbin.json"))["versions"][0]
if entry != {"git-tree": tree, "port-version": 0, "version": version}:
    errors.append(f"versions/p-/packbin.json newest entry {entry} is not git-tree {tree}")
baseline = json.loads(show("versions/baseline.json"))["default"]["packbin"]
if baseline != {"baseline": version, "port-version": 0}:
    errors.append(f"versions/baseline.json packbin is {baseline}")
for error in errors:
    print(error)
sys.exit(1 if errors else 0)
PY
}

# AC-3: add_subdirectory(<repo>/cpp packbin) builds with both target names, and both programs print the golden bytes.
vcpkg_subdirectory_check() {
  local tmp="$1" app want name flags cmake_flags=()
  app="$tmp/subdirectory"
  flags="$(vcpkg_sysroot_flags)"
  if [ -n "$flags" ]; then
    cmake_flags+=("-DCMAKE_CXX_FLAGS=$flags")
  fi
  if ! command -v cmake >/dev/null; then
    vcpkg_tool_missing "add_subdirectory check" "cmake"
    return 0
  fi
  mkdir -p "$app"
  cp "$here/drivers/position.cpp" "$app/main.cpp"
  cat > "$app/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.16)
project(packbin_subdirectory LANGUAGES CXX)
add_subdirectory("$root/cpp" packbin)
add_executable(by_name main.cpp)
target_link_libraries(by_name PRIVATE packbin)
add_executable(by_alias main.cpp)
target_link_libraries(by_alias PRIVATE packbin::packbin)
install(FILES main.cpp DESTINATION share/subdirectory)
EOF
  if ! vcpkg_run "$app/build.log" cmake -S "$app" -B "$app/build" ${cmake_flags[@]+"${cmake_flags[@]}"}; then
    fail "AZ-2098 AC-3 configure of add_subdirectory(cpp)"
    return 0
  fi
  if ! vcpkg_run "$app/build.log" cmake --build "$app/build"; then
    fail "AZ-2098 AC-3 build with the targets packbin and packbin::packbin"
    return 0
  fi
  want="$(tr -d '[:space:]' < "$root/fixtures/golden.hex")"
  for name in by_name by_alias; do
    assert_eq "$("$app/build/$name" | tr -d '[:space:]')" "$want" "AZ-2098 AC-3 $name stdout"
  done
  # packbin installs itself only as the top-level project: a parent's install holds the parent's files only.
  if ! vcpkg_run "$app/install.log" cmake --install "$app/build" --prefix "$app/prefix"; then
    fail "AZ-2098 AC-3 cmake --install of the parent project"
    return 0
  fi
  [ -f "$app/prefix/share/subdirectory/main.cpp" ] || fail "AZ-2098 AC-3 the parent's own file was not installed"
  for name in lib/libpackbin.a lib/cmake/packbin include/packbin; do
    if [ -e "$app/prefix/$name" ]; then
      fail "AZ-2098 AC-3 the parent's install holds $name"
    fi
  done
}

# Writes the vcpkg.json and vcpkg-configuration.json of directory $1: a project that depends on packbin from
# bare registry $2. vcpkg needs a baseline for the default registry once another registry is configured; the
# checkout of vcpkg root $3 is its own baseline. Returns 1 when that root has no git checkout.
vcpkg_manifest_project() {
  local app="$1" bare="$2" vroot="$3" builtin
  if [ ! -e "$vroot/.git" ] || ! builtin="$(git -C "$vroot" rev-parse HEAD)" || [ -z "$builtin" ]; then
    return 1
  fi
  mkdir -p "$app"
  cat > "$app/vcpkg.json" <<'EOF'
{
  "name": "packbin-consumer",
  "version": "0.0.0",
  "dependencies": ["packbin"]
}
EOF
  cat > "$app/vcpkg-configuration.json" <<EOF
{
  "default-registry": {
    "kind": "builtin",
    "baseline": "$builtin"
  },
  "registries": [
    {
      "kind": "git",
      "repository": "$bare",
      "reference": "vcpkg",
      "baseline": "$(git --git-dir="$bare" rev-parse vcpkg)",
      "packages": ["packbin"]
    }
  ]
}
EOF
}

# vcpkg_configure <log> <vroot> <tmp> <overlay triplets> <app> [cmake option]...: configures manifest project <app>
# through the vcpkg toolchain, with a binary cache and a registries cache of their own under <tmp>.
vcpkg_configure() {
  local log="$1" vroot="$2" tmp="$3" overlay="$4" app="$5"
  shift 5
  vcpkg_run "$log" env VCPKG_DISABLE_METRICS=1 VCPKG_ROOT="$vroot" \
    VCPKG_DEFAULT_BINARY_CACHE="$tmp/binary-cache" X_VCPKG_REGISTRIES_CACHE="$tmp/registries-cache" \
    ${overlay:+"VCPKG_OVERLAY_TRIPLETS=$overlay"} \
    cmake -S "$app" -B "$app/build" -DCMAKE_TOOLCHAIN_FILE="$vroot/scripts/buildsystems/vcpkg.cmake" "$@"
}

# AZ-2232 AC-2: vcpkg refuses the port on a triplet that does not match `linux | osx`, and plans it on one that does.
# `--dry-run` makes the plan and checks the platform expression without building: a triplet of another system
# (x64-linux on a Mac) is accepted without a compiler for it, and a port without `supports` shows up as planned.
vcpkg_supports_check() {
  local bare="$1" tmp="$2" vroot app out status
  if ! vroot="$(vcpkg_root)"; then
    vcpkg_tool_missing "vcpkg supports check" "vcpkg tool"
    return 0
  fi
  app="$tmp/supports"
  mkdir -p "$tmp/registries-cache"
  if ! vcpkg_manifest_project "$app" "$bare" "$vroot"; then
    fail "AZ-2232 AC-2 vcpkg root has no git checkout: no builtin baseline ($vroot)"
    return 0
  fi
  status=0
  out="$(cd "$app" && env VCPKG_DISABLE_METRICS=1 VCPKG_ROOT="$vroot" X_VCPKG_REGISTRIES_CACHE="$tmp/registries-cache" \
    "$vroot/vcpkg" install --dry-run --triplet x64-windows 2>&1)" || status=$?
  if [ "$status" -ne 1 ] || ! grep -qF "packbin is only supported on 'linux | osx', which does not match x64-windows." <<< "$out"; then
    fail "AZ-2232 AC-2 vcpkg did not refuse the port on x64-windows (exit $status): $out"
  fi
  status=0
  out="$(cd "$app" && env VCPKG_DISABLE_METRICS=1 VCPKG_ROOT="$vroot" X_VCPKG_REGISTRIES_CACHE="$tmp/registries-cache" \
    "$vroot/vcpkg" install --dry-run --triplet x64-linux 2>&1)" || status=$?
  if [ "$status" -ne 0 ] || grep -qF 'only supported' <<< "$out" || ! grep -qF "packbin:x64-linux@$vcpkg_version" <<< "$out"; then
    fail "AZ-2232 AC-2 vcpkg did not plan the port on x64-linux (exit $status): $out"
  fi
}

# AZ-2232 AC-4: the version rule of the installed packbin-config-version.cmake, without vcpkg. cpp/ is built once, then
# installed under three versions (a reconfigure with another -DPACKBIN_VERSION rewrites only the version file, so the
# next build is a no-op), and an empty project asks find_package for each request. A row is
# `installed|requests that find it|requests that do not`.
vcpkg_version_rule_check() {
  local tmp="$1" dir row installed found refused request flags cmake_flags=()
  if ! command -v cmake >/dev/null; then
    vcpkg_tool_missing "version rule check" "cmake"
    return 0
  fi
  dir="$tmp/rule"
  flags="$(vcpkg_sysroot_flags)"
  if [ -n "$flags" ]; then
    cmake_flags+=("-DCMAKE_CXX_FLAGS=$flags")
  fi
  mkdir -p "$dir/consumer"
  cat > "$dir/consumer/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(packbin_rule LANGUAGES NONE)
find_package(packbin ${REQUEST} CONFIG)
if(packbin_FOUND)
  message(STATUS "packbin found")
else()
  message(STATUS "packbin not found")
endif()
EOF
  for row in "0.9.0|0.9 0.9.0|0.1 0.2 0.10 0.1.0 0.9.1 0 1.0" "0.10.2|0.10|0.1 0.2 0.9 0.9.0 1.0" "1.4.0|1.0 1.2 1.4|1.5 2.0 0.9"; do
    IFS='|' read -r installed found refused <<< "$row"
    if ! vcpkg_run "$dir/build.log" cmake -S "$root/cpp" -B "$dir/build" -DPACKBIN_VERSION="$installed" ${cmake_flags[@]+"${cmake_flags[@]}"} \
      || ! vcpkg_run "$dir/build.log" cmake --build "$dir/build" \
      || ! vcpkg_run "$dir/build.log" cmake --install "$dir/build" --prefix "$dir/prefix-$installed"; then
      fail "AZ-2232 AC-4 cpp/ did not configure, build and install at version $installed"
      return 0
    fi
    # shellcheck disable=SC2086
    for request in $found $refused; do
      if ! vcpkg_run "$dir/find-$installed-$request.log" cmake -S "$dir/consumer" -B "$dir/find-$installed-$request" \
        -DREQUEST="$request" -DCMAKE_PREFIX_PATH="$dir/prefix-$installed"; then
        fail "AZ-2232 AC-4 find_package(packbin $request) did not configure against $installed"
        continue
      fi
      if [[ " $found " == *" $request "* ]]; then
        grep -qF 'packbin found' "$dir/find-$installed-$request.log" \
          || fail "AZ-2232 AC-4 installed $installed: a request for $request was refused"
      else
        grep -qF 'packbin not found' "$dir/find-$installed-$request.log" \
          || fail "AZ-2232 AC-4 installed $installed: a request for $request was satisfied"
      fi
    done
  done
}

# AC-1, AC-2 and the installed copyright of AC-4: a consumer installs packbin from bare registry $1 through
# the vcpkg toolchain, with find_package(packbin CONFIG REQUIRED) and packbin::packbin. $2 is a scratch dir.
vcpkg_consumer_check() {
  local bare="$1" tmp="$2" vroot app log copyright="" got want flags overlay dir cmake_flags=()
  if ! vroot="$(vcpkg_root)"; then
    vcpkg_tool_missing "vcpkg consumer check" "vcpkg tool"
    return 0
  fi
  if ! command -v cmake >/dev/null; then
    vcpkg_tool_missing "vcpkg consumer check" "cmake"
    return 0
  fi
  app="$tmp/consumer"
  log="$app/vcpkg-consumer.log"
  mkdir -p "$app" "$tmp/binary-cache" "$tmp/registries-cache"
  if ! vcpkg_manifest_project "$app" "$bare" "$vroot"; then
    fail "AZ-2098 AC-1 vcpkg root has no git checkout: no builtin baseline ($vroot)"
    return 0
  fi
  cp "$here/drivers/position.cpp" "$app/main.cpp"
  # The version in find_package fails the check when the port installs no packbin-config-version.cmake.
  cat > "$app/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.16)
project(packbin_consumer LANGUAGES CXX)
find_package(packbin ${vcpkg_version%.*} CONFIG REQUIRED)
add_executable(consumer main.cpp)
target_link_libraries(consumer PRIVATE packbin::packbin)
EOF
  "$vroot/vcpkg" version | sed -n 1p
  # A binary cache and a registries cache of their own, and no old build tree (its logs are read on a failure):
  # the port is built from this registry every time.
  rm -rf "$vroot/buildtrees/packbin"
  flags="$(vcpkg_sysroot_flags)"
  overlay="$(vcpkg_sysroot_triplets "$vroot" "$tmp/triplets")" || {
    fail "AZ-2098 AC-1 no overlay triplet for PACKBIN_CXX_SYSROOT"
    return 0
  }
  if [ -n "$flags" ]; then
    cmake_flags+=("-DCMAKE_CXX_FLAGS=$flags")
    overlay="$overlay${VCPKG_OVERLAY_TRIPLETS:+:$VCPKG_OVERLAY_TRIPLETS}"
  fi
  if ! vcpkg_configure "$log" "$vroot" "$tmp" "$overlay" "$app" ${cmake_flags[@]+"${cmake_flags[@]}"}; then
    tail -n 60 "$vroot"/buildtrees/packbin/*.log >&2 || true
    fail "AZ-2098 AC-1 the consumer did not install packbin and configure through the port"
    return 0
  fi
  if ! vcpkg_run "$log" cmake --build "$app/build"; then
    fail "AZ-2098 AC-1 the consumer did not build and link against packbin::packbin"
    return 0
  fi
  if ! got="$("$app/build/consumer")"; then
    fail "AZ-2098 AC-2 the consumer exited with an error"
    return 0
  fi
  want="$(tr -d '[:space:]' < "$root/fixtures/golden.hex")"
  assert_eq "$(printf '%s' "$got" | tr -d '[:space:]')" "$want" "AZ-2098 AC-2 consumer stdout"
  for dir in "$app"/build/vcpkg_installed/*/debug/include; do
    if [ -e "$dir" ]; then
      fail "AZ-2098 AC-4 the installed tree holds debug/include"
    fi
  done
  for copyright in "$app"/build/vcpkg_installed/*/share/packbin/copyright; do :; done
  if [ ! -f "$copyright" ] || ! cmp -s "$copyright" "$root/LICENSE"; then
    fail "AZ-2098 AC-4 share/packbin/copyright is not the repository LICENSE"
  fi
  # AZ-2232 AC-3: the installed 0.9.0 answers a request for 0.9 (above) and not one for another 0.x minor. The
  # second project of the same manifest takes the port from the binary cache of the first.
  app="$tmp/consumer-minor"
  vcpkg_manifest_project "$app" "$bare" "$vroot"
  cat > "$app/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.16)
project(packbin_other_minor LANGUAGES NONE)
find_package(packbin 0.2 CONFIG)
if(packbin_FOUND)
  message(STATUS "packbin 0.2 found")
else()
  message(STATUS "packbin 0.2 not found")
endif()
EOF
  if ! vcpkg_configure "$app/vcpkg-consumer.log" "$vroot" "$tmp" "$overlay" "$app" ${cmake_flags[@]+"${cmake_flags[@]}"}; then
    fail "AZ-2232 AC-3 the second project did not configure"
  elif ! grep -qF 'packbin 0.2 not found' "$app/vcpkg-consumer.log"; then
    fail "AZ-2232 AC-3 a request for another 0.x minor was satisfied by the installed port"
  fi
}

# AZ-2240: the tag-time guard (publish-check.py vcpkg) on the real staged port, the artifact directory $1 that
# vcpkg_stage_registry left, and on mutants of its working tree (copies in scratch directory $2). The real port must
# pass; each mutant must fail with exactly the message that names the missing part.
vcpkg_guard_checks() {
  python3 - "$here/publish-check.py" "$1" "$2/guard" "$vcpkg_version" <<'PY' || fail "AZ-2240 the vcpkg guard did not behave as expected"
import json, shutil, subprocess, sys
from pathlib import Path

check, artifact, work, version = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4]
cmake = "CMakeLists.txt is missing or does not build the packbin library"
licence = "LICENSE is missing or is not the MIT license text"
host = "vcpkg.json lacks the host dependency "


def manifest(change):
    def mutate(port):
        data = json.loads((port / "vcpkg.json").read_text())
        change(data)
        (port / "vcpkg.json").write_text(json.dumps(data, indent=2))
    return mutate


def without(name):
    return manifest(lambda data: data.update(dependencies=[d for d in data["dependencies"] if d["name"] != name]))


def host_off(data):
    for entry in data["dependencies"]:
        entry["host"] = False


cases = [
    ("control", lambda port: None, None),
    ("no CMakeLists.txt", lambda port: (port / "CMakeLists.txt").unlink(), cmake),
    ("CMakeLists.txt is a comment", lambda port: (port / "CMakeLists.txt").write_text("# no library\n"), cmake),
    ("no LICENSE", lambda port: (port / "LICENSE").unlink(), licence),
    ("empty LICENSE", lambda port: (port / "LICENSE").write_text(""), licence),
    ("no vcpkg-cmake", without("vcpkg-cmake"), host + "vcpkg-cmake"),
    ("no vcpkg-cmake-config", without("vcpkg-cmake-config"), host + "vcpkg-cmake-config"),
    ("no dependencies", manifest(lambda data: data.pop("dependencies")), host + "vcpkg-cmake"),
    ("both host entries off", manifest(host_off), host + "vcpkg-cmake"),
]
errors = 0
for name, mutate, wanted in cases:
    copy = work / name.replace(" ", "-")
    shutil.copytree(artifact, copy, symlinks=True)
    mutate(copy / "reg" / "ports" / "packbin")
    result = subprocess.run([sys.executable, check, "vcpkg", str(copy), f"v{version}"], capture_output=True, text=True)
    want = (0, "check ok: vcpkg") if wanted is None else (1, f"check failed: vcpkg: {wanted}")
    got = (result.returncode, (result.stdout if wanted is None else result.stderr).strip())
    if got != want:
        errors += 1
        print(f"{name}: expected {want}, got {got}")
shutil.rmtree(work)
sys.exit(1 if errors else 0)
PY
}

vcpkg_checks() {
  local bare before
  vcpkg_tmp="$(mktemp -d)"
  trap 'rm -rf "$vcpkg_tmp"' EXIT
  bare="$vcpkg_tmp/vcpkg.git"
  git -c init.defaultBranch=vcpkg init --bare "$bare" >/dev/null
  if ! vcpkg_stage_registry "$bare" "$vcpkg_tmp" first; then
    fail "AZ-2098 the port was not staged into the bare registry"
    return 0
  fi
  before="$(git --git-dir="$bare" rev-list --count vcpkg)"
  if ! vcpkg_stage_registry "$bare" "$vcpkg_tmp" again; then
    fail "AZ-2098 AC-5 the second stage of the same version failed"
    return 0
  fi
  assert_eq "$(git --git-dir="$bare" rev-list --count vcpkg)" "$before" "AZ-2098 AC-5 commits after re-staging the same version"
  vcpkg_port_checks "$bare"
  vcpkg_guard_checks "$vcpkg_tmp/out-first/artifacts/vcpkg" "$vcpkg_tmp"
  vcpkg_subdirectory_check "$vcpkg_tmp"
  vcpkg_version_rule_check "$vcpkg_tmp"
  vcpkg_supports_check "$bare" "$vcpkg_tmp"
  vcpkg_consumer_check "$bare" "$vcpkg_tmp"
}
