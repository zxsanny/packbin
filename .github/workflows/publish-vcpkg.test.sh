#!/usr/bin/env bash
# vcpkg port checks (AZ-2098). Sourced by publish-gate.test.sh, which defines fail, assert_eq, $root and
# $here, and reports $not_run in its last line; `bash publish-gate.test.sh --vcpkg` runs only these.
# The port is staged into a local bare git registry by the real publish-registries.sh, a consumer
# project installs it through the vcpkg toolchain from that registry, builds, links and runs it.
# vcpkg is the one on GitHub-hosted Ubuntu runners ($VCPKG_INSTALLATION_ROOT), or $VCPKG_ROOT, or the
# one on PATH. Without vcpkg or cmake a run on GitHub Actions fails; anywhere else it prints
# `<check> NOT RUN` and the gate says so in its last line: a check that did not run is not a pass.
# PACKBIN_CXX_SYSROOT (macOS only, see _docs/AGENT_GOTCHAS.md) adds the sysroot flags to the cmake builds
# and writes an overlay triplet for the vcpkg consumer into the temp dir; unset, nothing of it exists.

# shellcheck disable=SC2154
vcpkg_version="0.1.0"

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
for key, want in (("name", "packbin"), ("version", version), ("license", "MIT")):
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

# AC-1, AC-2 and the installed copyright of AC-4: a consumer installs packbin from bare registry $1 through
# the vcpkg toolchain, with find_package(packbin CONFIG REQUIRED) and packbin::packbin. $2 is a scratch dir.
vcpkg_consumer_check() {
  local bare="$1" tmp="$2" vroot app log copyright="" got want flags overlay builtin dir cmake_flags=()
  if ! vroot="$(vcpkg_root)"; then
    vcpkg_tool_missing "vcpkg consumer check" "vcpkg tool"
    return 0
  fi
  if ! command -v cmake >/dev/null; then
    vcpkg_tool_missing "vcpkg consumer check" "cmake"
    return 0
  fi
  # vcpkg needs a baseline for the default registry once another registry is configured; the checkout of
  # this vcpkg is its own baseline.
  if [ ! -e "$vroot/.git" ] || ! builtin="$(git -C "$vroot" rev-parse HEAD)" || [ -z "$builtin" ]; then
    fail "AZ-2098 AC-1 vcpkg root has no git checkout: no builtin baseline ($vroot)"
    return 0
  fi
  app="$tmp/consumer"
  log="$app/vcpkg-consumer.log"
  mkdir -p "$app" "$tmp/binary-cache" "$tmp/registries-cache"
  cp "$here/drivers/position.cpp" "$app/main.cpp"
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
  if ! vcpkg_run "$log" env VCPKG_DISABLE_METRICS=1 VCPKG_ROOT="$vroot" \
    VCPKG_DEFAULT_BINARY_CACHE="$tmp/binary-cache" X_VCPKG_REGISTRIES_CACHE="$tmp/registries-cache" \
    ${overlay:+"VCPKG_OVERLAY_TRIPLETS=$overlay"} \
    cmake -S "$app" -B "$app/build" -DCMAKE_TOOLCHAIN_FILE="$vroot/scripts/buildsystems/vcpkg.cmake" \
    ${cmake_flags[@]+"${cmake_flags[@]}"}; then
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
  vcpkg_subdirectory_check "$vcpkg_tmp"
  vcpkg_consumer_check "$bare" "$vcpkg_tmp"
}
