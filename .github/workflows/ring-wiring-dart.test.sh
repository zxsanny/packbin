#!/usr/bin/env bash
# Dart wiring check of the cross-language ring (AZ-4146 AC-1, AC-2, AC-5, AC-6), the sibling of ring-wiring-swift.test.sh:
# language-pair.sh is run against a recording runner (no toolchain), so the pairs Dart joins are read from what it does,
# not from its text: every kind both ways with each member of that kind's ring, the three short refusals and the position
# row. The driver package, ring-lib.sh, ring-dart.sh, ring-toolchains.sh, the ECC, frame and prepare scripts and the ring
# job of test.yml (ring-wiring-dart-check.py) carry the Dart pieces. Every guard is proven against a temp copy with one
# piece removed: the copy must be rejected, naming it. ring-dart.sh is also run against a temp tree with stand-in `dart`
# and `docker` commands (it builds only when a source is newer; the version it prints; the image build of a Linux host).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../.." && pwd)"
# shellcheck source=ring-wiring-lib.sh
source "$here/ring-wiring-lib.sh" # tmp, failures, fail
driver="$here/drivers/handoff-dart"
position_hex="4001000065cd1d00a3e1110100"
reader_failed="the workflow checker could not run, status"
dart_kinds="user nested boolflag booltrue bitwhen roundflags roundwhen listgroup dictgroup listflags"

# The members of each kind's ring (as language-pair.sh runs them) besides Dart; C# only produces the round kinds.
members() {
  case "$1" in
    roundflags | roundwhen) echo "csharp typescript rust java cpp go swift" ;;
    listgroup | dictgroup | listflags) echo "typescript python java csharp go swift" ;;
    *) echo "csharp typescript python rust java cpp go swift" ;;
  esac
}

hex_of() { sed -n "s/^$1=\"\\([0-9a-f]*\\)\"\$/\\1/p" "$here/language-pair.sh"; }

# expected_events: what Dart must do in the ring, one event a line, sorted.
expected_events() {
  local kind member hex
  for kind in $dart_kinds; do
    hex="$(hex_of "${kind}_hex")"
    for member in $(members "$kind"); do
      case "$kind$member" in roundflagscsharp | roundwhencsharp) ;; *) echo "handoff dart $member $kind $hex" ;; esac
      echo "handoff $member dart $kind $hex"
    done
  done
  for kind in listgroup dictgroup listflags; do echo "run_lang dart unpack-$kind-short $(hex_of "${kind}_short_hex")"; done
  echo "position dart"
}

# actual_events <language-pair.sh copy>: the Dart events of a run of the copy against a recording runner and publish-position.sh.
actual_events() {
  local t="$tmp/run-$((++runs))" log
  log="$t/events"
  mkdir -p "$t/.github/workflows"
  cp "$1" "$t/.github/workflows/language-pair.sh"
  cat > "$t/.github/workflows/ring-lib.sh" <<'LIB'
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
run_lang() { echo "run_lang $*" >> "$root/events"; }
handoff() { echo "handoff $*" >> "$root/events"; }
LIB
  printf '#!/bin/sh\necho "position $1" >> "%s"\necho %s\n' "$log" "$position_hex" > "$t/.github/workflows/publish-position.sh"
  : > "$log"
  if ! bash "$t/.github/workflows/language-pair.sh" > "$t/out" 2>&1 < /dev/null; then
    echo "language-pair.sh failed: $(head -n 3 "$t/out")"
    return
  fi
  grep -E '^handoff dart |^handoff [a-z]+ dart |^run_lang dart |^position dart$' "$log" | sort
}

# ring_violations <language-pair.sh copy>: the difference between the expected Dart events and the copy's.
ring_violations() {
  local actual
  expected_events | sort > "$tmp/expected.txt"
  actual="$(actual_events "$1")"
  printf '%s\n' "$actual" | diff "$tmp/expected.txt" - | grep '^[<>]' | sed 's/^< /missing: /; s/^> /unexpected: /' || true
}

# expect_ring_rejected <label> <copy>: the copy differs from the real script and the difference is named.
expect_ring_rejected() {
  local label="$1" copy="$2" out
  if cmp -s "$here/language-pair.sh" "$copy"; then fail "temp copy is unchanged: $label"; return; fi
  out="$(ring_violations "$copy")"
  if [ -z "$out" ]; then fail "the Dart ring check passed a copy without: $label"; else echo "rejects: $label ($(head -n 1 <<< "$out"))"; fi
}

# mutate <file> <copy> <sed program>: the copy is <file> edited by sed.
mutate() { sed "$3" "$1" > "$2"; }

ring_checks() {
  local out n
  out="$(ring_violations "$here/language-pair.sh")"
  if [ -n "$out" ]; then fail "dart ring: $out"; return; fi
  n="$(expected_events | wc -l | tr -d ' ')"
  echo "accepts: the real language-pair.sh ($n Dart events)"
  local lp="$here/language-pair.sh"
  mutate "$lp" "$tmp/l1.sh" 's/^    \*) members="csharp typescript python rust java cpp go swift" ;;$/    *) members="csharp typescript python rust java cpp go" ;;/'
  expect_ring_rejected "swift in the member list of the plain kinds" "$tmp/l1.sh"
  mutate "$lp" "$tmp/l2.sh" 's/^    handoff "$member" dart "$kind" "${!hex}"$/    :/'
  expect_ring_rejected "the lines with dart as the consumer" "$tmp/l2.sh"
  mutate "$lp" "$tmp/l3.sh" 's/\*) handoff dart "$member" "$kind" "${!hex}" ;; esac/*) ;; esac/'
  expect_ring_rejected "the lines with dart as the producer" "$tmp/l3.sh"
  mutate "$lp" "$tmp/l4.sh" 's/roundflagscsharp | roundwhencsharp) ;;/roundflagscsharpx) ;;/'
  expect_ring_rejected "C# left out of the producers of the round kinds, as it is not" "$tmp/l4.sh"
  mutate "$lp" "$tmp/l5.sh" 's/run_lang dart "unpack-/run_lang swift "unpack-/'
  expect_ring_rejected "the Dart short packet refusal" "$tmp/l5.sh"
  mutate "$lp" "$tmp/l6.sh" '/^# Dart refuses/,/^done$/s/ dictgroup listflags; do$/ dictgroup; do/'
  expect_ring_rejected "listflags in the Dart short packet loop" "$tmp/l6.sh"
  mutate "$lp" "$tmp/l7.sh" 's/ swift go dart; do$/ swift go; do/'
  expect_ring_rejected "dart in the publish-position loop" "$tmp/l7.sh"
  mutate "$lp" "$tmp/l8.sh" 's/ roundwhen listgroup dictgroup listflags; do$/ roundwhen listgroup dictgroup; do/'
  expect_ring_rejected "the listflags kind of the Dart handoff loop" "$tmp/l8.sh"
  mutate "$lp" "$tmp/l9.sh" 's/\*) handoff dart "$member" "$kind" "${!hex}" ;; esac/*) handoff dart "$member" "$kind" "$position_hex" ;; esac/'
  expect_ring_rejected "the hex of the producer lines" "$tmp/l9.sh"
}

# static_violations: one line per missing Dart piece outside the rows. Each file can be replaced by a copy: DT_LIB, DT_KINDS,
# DT_PACKAGE, DT_TOOLS, DT_BUILD, DT_ECC, DT_FRAME, DT_FRAME_DRIVERS, DT_PREPARE, DT_POSITION, DT_ECC_TEST, DT_FRAME_TEST,
# DT_README (defaults: the real files).
static_violations() {
  local lib="${DT_LIB:-$here/ring-lib.sh}" kinds="${DT_KINDS:-$driver/lib/kinds.dart}" package="${DT_PACKAGE:-$driver/pubspec.yaml}"
  local tools="${DT_TOOLS:-$here/ring-toolchains.sh}" build="${DT_BUILD:-$here/ring-dart.sh}" kind case_block f
  case_block="$(awk '/^    dart[)]$/ { on = 1 } on { print } on && /^      ;;$/ { exit }' "$lib")"
  if [ -z "$case_block" ]; then
    echo "run_lang has no dart case"
  else
    grep -qxF '      bash "$root/.github/workflows/ring-dart.sh" "$dart_ring" || return' <<< "$case_block" \
      || echo "the dart case of run_lang does not build through ring-dart.sh, returning on a failed build"
    grep -qxF '      "$dart_ring/handoff-dart" "$@"' <<< "$case_block" || echo "the dart case of run_lang does not run the built handoff-dart"
  fi
  for kind in $dart_kinds; do
    grep -qxF "    case '$kind':" "$kinds" || echo "the dart driver has no kind $kind"
  done
  for kind in listgroup dictgroup listflags; do
    grep '^const shortKinds = ' "$kinds" | grep -qF "'$kind'" || echo "the dart driver does not refuse the short $kind packet"
  done
  grep -qxF '    path: ../../../../dart' "$package" || echo "the dart driver package does not depend on dart/ by path"
  [ "$(grep -c 'path:' "$package")" = 1 ] || echo "the dart driver package has a dependency other than dart/"
  grep -qF 'check dart "${RING_DART:?}"' "$tools" || echo "ring-toolchains.sh does not check the Dart version"
  grep -qxF 'tag="${RING_DART:-$(bash "$here/tool-pin.sh" dart)}"' "$build" \
    || echo "ring-dart.sh does not take the image tag from RING_DART or the tool-pins.txt dart pin"
  grep -qF '"dart:$tag"' "$build" || echo "ring-dart.sh does not build in the dart:\$tag image"
  grep -qxF 'if [ -n "${PACKBIN_DART_CACHE:-}" ]; then echo "ring-dart: cache $PACKBIN_DART_CACHE" >&2; fi' "$build" \
    || echo "ring-dart.sh does not say the cache state when CI keeps its output"
  for f in "${DT_ECC:-$here/ring-ecc.sh}" "${DT_FRAME:-$here/ring-frame.sh}" "${DT_FRAME_DRIVERS:-$here/ring-frame-drivers.test.sh}"; do
    grep -qF ' go swift dart}"' "$f" || echo "$(basename "$f") does not run dart in its default language list"
  done
  grep -qF 'task dart bash "$here/ring-dart.sh" "${PACKBIN_DART_RING:-/tmp/packbin-ring-dart}" &' "${DT_PREPARE:-$here/ring-prepare.sh}" \
    || echo "ring-prepare.sh build does not build the Dart drivers"
  awk '/^  dart[)]$/ { on = 1 } on && /ring-dart\.sh/ { found = 1 } END { exit !found }' "${DT_POSITION:-$here/publish-position.sh}" \
    || echo "publish-position.sh has no dart case that builds through ring-dart.sh"
  grep -qF 'FAKE_LIE=dart:protect' "${DT_ECC_TEST:-$here/ring-ecc.test.sh}" || echo "ring-ecc.test.sh has no Dart liar"
  grep -qF 'FAKE_LIE=dart:seal' "${DT_FRAME_TEST:-$here/ring-frame.test.sh}" || echo "ring-frame.test.sh has no Dart liar"
  grep -qF '"Dart": (' "${DT_README:-$root/scripts/frame/readme-examples.sh}" || echo "readme-examples.sh has no Dart entry"
}

# expect_static_rejected <label> <variable=copy>: the copy differs from the real file and the check names what it lacks.
expect_static_rejected() {
  local label="$1" out
  out="$(export "${2%%=*}=${2#*=}"; static_violations)"
  if [ -z "$out" ]; then fail "the Dart check passed a copy without: $label"; else echo "rejects: $label ($(head -n 1 <<< "$out"))"; fi
}

# changed <file> <copy> <sed program>: writes the copy and fails the test when sed changed nothing.
changed() {
  mutate "$1" "$2" "$3"
  if cmp -s "$1" "$2"; then fail "temp copy is unchanged: $3"; fi
}

static_checks() {
  local out kind
  out="$(static_violations)"
  if [ -n "$out" ]; then fail "dart pieces: $out"; return; fi
  echo "accepts: the real files"
  changed "$here/ring-lib.sh" "$tmp/s1.sh" 's/^    dart)$/    dartx)/'
  expect_static_rejected "the dart case of run_lang" DT_LIB="$tmp/s1.sh"
  changed "$here/ring-lib.sh" "$tmp/s2.sh" 's/"$dart_ring" || return$/"$dart_ring"/'
  expect_static_rejected "the || return of the Dart build in run_lang" DT_LIB="$tmp/s2.sh"
  changed "$here/ring-lib.sh" "$tmp/s3.sh" 's/"$dart_ring\/handoff-dart" "$@"/"$dart_ring\/position" "$@"/'
  expect_static_rejected "the handoff-dart binary in run_lang" DT_LIB="$tmp/s3.sh"
  for kind in $dart_kinds; do
    changed "$driver/lib/kinds.dart" "$tmp/k-$kind.dart" "s/^    case '$kind':\$/    case 'x$kind':/"
    expect_static_rejected "the $kind kind of the dart driver" DT_KINDS="$tmp/k-$kind.dart"
  done
  for kind in listgroup dictgroup listflags; do
    changed "$driver/lib/kinds.dart" "$tmp/short-$kind.dart" "/^const shortKinds = /s/'$kind'/'x'/"
    expect_static_rejected "the short $kind refusal of the dart driver" DT_KINDS="$tmp/short-$kind.dart"
  done
  changed "$driver/pubspec.yaml" "$tmp/p1.yaml" 's#path: ../../../../dart#hosted: pub.dev#'
  expect_static_rejected "the package by path" DT_PACKAGE="$tmp/p1.yaml"
  { cat "$driver/pubspec.yaml"; printf '  lints:\n    path: ../lints\n'; } > "$tmp/p2.yaml"
  expect_static_rejected "a second dependency of the driver package" DT_PACKAGE="$tmp/p2.yaml"
  changed "$here/ring-toolchains.sh" "$tmp/t1.sh" '/^check dart /d'
  expect_static_rejected "the Dart version check" DT_TOOLS="$tmp/t1.sh"
  changed "$here/ring-dart.sh" "$tmp/b1.sh" 's/^tag=.*/tag=3/'
  expect_static_rejected "the image tag from RING_DART or the pin" DT_BUILD="$tmp/b1.sh"
  changed "$here/ring-dart.sh" "$tmp/b2.sh" 's/"dart:$tag"/"dart:latest"/g'
  expect_static_rejected "the dart:\$tag image" DT_BUILD="$tmp/b2.sh"
  changed "$here/ring-dart.sh" "$tmp/b3.sh" '/echo "ring-dart: cache/d'
  expect_static_rejected "the cache state line of ring-dart.sh" DT_BUILD="$tmp/b3.sh"
  changed "$here/ring-ecc.sh" "$tmp/e1.sh" 's/ go swift dart}"/ go swift}"/'
  expect_static_rejected "dart in the ECC ring languages" DT_ECC="$tmp/e1.sh"
  changed "$here/ring-frame.sh" "$tmp/f1.sh" 's/ go swift dart}"/ go swift}"/'
  expect_static_rejected "dart in the frame ring languages" DT_FRAME="$tmp/f1.sh"
  changed "$here/ring-frame-drivers.test.sh" "$tmp/f2.sh" 's/ go swift dart}"/ go swift}"/'
  expect_static_rejected "dart in the frame driver test languages" DT_FRAME_DRIVERS="$tmp/f2.sh"
  changed "$here/ring-prepare.sh" "$tmp/r1.sh" '/^    task dart /d'
  expect_static_rejected "the Dart build of ring-prepare.sh" DT_PREPARE="$tmp/r1.sh"
  changed "$here/publish-position.sh" "$tmp/pp.sh" 's/^  dart)$/  dartx)/'
  expect_static_rejected "the dart case of publish-position.sh" DT_POSITION="$tmp/pp.sh"
  changed "$here/ring-ecc.test.sh" "$tmp/et.sh" 's/FAKE_LIE=dart:protect/FAKE_LIE=java:protect/'
  expect_static_rejected "the Dart liar of the ECC ring self-test" DT_ECC_TEST="$tmp/et.sh"
  changed "$here/ring-frame.test.sh" "$tmp/ft.sh" 's/FAKE_LIE=dart:seal/FAKE_LIE=java:seal/'
  expect_static_rejected "the Dart liar of the frame ring self-test" DT_FRAME_TEST="$tmp/ft.sh"
  changed "$root/scripts/frame/readme-examples.sh" "$tmp/re.sh" 's/"Dart": (/"Dartx": (/'
  expect_static_rejected "the Dart entry of readme-examples.sh" DT_README="$tmp/re.sh"
}

# workflow_violations <test.yml> <dart pin> <compose>: the violations of the ring job of a workflow file.
workflow_violations() {
  local status=0
  python3 -I "$here/ring-wiring-dart-check.py" "$1" "$2" "$3" || status=$?
  if [ "$status" -gt 1 ]; then echo "$reader_failed $status"; fi
}

# expect_workflow_rejected <label> <test.yml copy> [<pin> [<compose copy>]]
expect_workflow_rejected() {
  local label="$1" copy="$2" pin="${3:-3.13.7}" compose="${4:-$root/docker-compose.test.yml}" out
  out="$(workflow_violations "$copy" "$pin" "$compose")"
  if [ -z "$out" ]; then
    fail "the Dart workflow check passed a copy without: $label"
  elif grep -qF "$reader_failed" <<< "$out"; then
    fail "the Dart workflow check did not run on the copy without: $label ($out)"
  else
    echo "rejects: $label ($(head -n 1 <<< "$out"))"
  fi
}

workflow_checks() {
  local out pin test_yml="$here/test.yml"
  pin="$(bash "$here/tool-pin.sh" dart)"
  out="$(workflow_violations "$test_yml" "$pin" "$root/docker-compose.test.yml")"
  if [ -n "$out" ]; then fail "test.yml: $out"; return; fi
  echo "accepts: test.yml, RING_DART $pin equal to the tool pin and the suite image"
  changed "$test_yml" "$tmp/w1.yml" 's/^      RING_DART: "3.13.7"$/      RING_DART: "3.13.8"/'
  expect_workflow_rejected "RING_DART bumped alone" "$tmp/w1.yml"
  changed "$test_yml" "$tmp/w2.yml" '/^      RING_DART: /d'
  expect_workflow_rejected "RING_DART removed" "$tmp/w2.yml"
  expect_workflow_rejected "the tool-pins.txt dart pin bumped alone" "$test_yml" 3.13.8
  changed "$root/docker-compose.test.yml" "$tmp/c1.yml" 's/image: dart:3\.13\.7$/image: dart:3.13.8/'
  expect_workflow_rejected "the dart suite image bumped alone" "$test_yml" "$pin" "$tmp/c1.yml"
  changed "$test_yml" "$tmp/w3.yml" "s#'dart/pubspec.yaml', ##"
  expect_workflow_rejected "the package pubspec.yaml in the Dart cache key" "$tmp/w3.yml"
  changed "$test_yml" "$tmp/w4.yml" "s#'.github/workflows/drivers/handoff-dart/pubspec.yaml', ##"
  expect_workflow_rejected "the driver pubspec.yaml in the Dart cache key" "$tmp/w4.yml"
  changed "$test_yml" "$tmp/w5.yml" "s#, '.github/workflows/ring-dart.sh')#)#"
  expect_workflow_rejected "ring-dart.sh in the Dart cache key" "$tmp/w5.yml"
  changed "$test_yml" "$tmp/w6.yml" 's/key: dart-v1-ring-${{ env.RING_DART }}-/key: dart-v1-ring-/'
  expect_workflow_rejected "the dart image tag in the Dart cache key" "$tmp/w6.yml"
  awk '{ print } /^          key: dart-v1-ring-/ { print "          restore-keys: dart-v1-ring-" }' "$test_yml" > "$tmp/w7.yml"
  expect_workflow_rejected "a prefix restore of the Dart cache" "$tmp/w7.yml"
  awk '/^      - name: Dart driver build cache$/ { on = 1 } on && /^        if: / { on = 0; next } { print }' "$test_yml" > "$tmp/w8.yml"
  expect_workflow_rejected "the tag run left out of the Dart cache" "$tmp/w8.yml"
  changed "$test_yml" "$tmp/w9.yml" 's#^          path: /tmp/packbin-ring-dart$#          path: /tmp/other#'
  expect_workflow_rejected "the Dart cache on another dir" "$tmp/w9.yml"
  changed "$test_yml" "$tmp/w10.yml" '/^          PACKBIN_DART_CACHE: /d'
  expect_workflow_rejected "the cache state of the build step" "$tmp/w10.yml"
  changed "$test_yml" "$tmp/w11.yml" 's/ "dart:$RING_DART"$//'
  expect_workflow_rejected "the dart image left out of the start line" "$tmp/w11.yml"
  changed "$test_yml" "$tmp/w12.yml" '/^      - name: Dart ring wiring$/,/ring-wiring-dart\.test\.sh$/d'
  expect_workflow_rejected "the Dart ring wiring step of scaffold" "$tmp/w12.yml"
  awk '{ print } /^      - name: Dart ring wiring$/ { print "        if: github.ref == '"'refs/heads/main'"'" }' "$test_yml" > "$tmp/w13.yml"
  expect_workflow_rejected "an if on the Dart ring wiring step" "$tmp/w13.yml"
  awk '{ print } /^          bash \.github\/workflows\/ring-prepare\.sh wait / { print "          bash .github/workflows/ring-wiring-dart.test.sh" }' "$test_yml" > "$tmp/w14.yml"
  expect_workflow_rejected "the Dart ring wiring check back in the ring job" "$tmp/w14.yml"
}

# write_fake_dart <bin dir>: a stand-in `dart` that logs each call, prints a version line for --version and writes an
# executable to the -o path of `compile exe`.
write_fake_dart() {
  cat > "$1/dart" <<'FAKE'
#!/usr/bin/env bash
echo "dart $* @ $PWD" >> "$FAKE_DART_LOG"
if [ "${1:-}" = --version ]; then echo "Dart SDK version: ${FAKE_DART_VERSION:?} (stable) (Tue Sep 29 2026) on \"linux_x64\""; exit 0; fi
while [ $# -gt 0 ]; do
  if [ "$1" = -o ]; then printf '#!/bin/sh\n' > "$2"; chmod +x "$2"; fi
  shift
done
FAKE
  chmod +x "$1/dart"
}

# write_fake_docker <bin dir>: a stand-in `docker` that logs each call and prints the pinned Dart for `dart --version`.
write_fake_docker() {
  cat > "$1/docker" <<'FAKE'
#!/usr/bin/env bash
echo "docker $*" >> "$FAKE_DART_LOG"
case " $* " in *" --version "*) echo "Dart SDK version: ${FAKE_DOCKER_DART:?} (stable)"; exit 0 ;; esac
FAKE
  chmod +x "$1/docker"
}

# ring-dart.sh against a temp tree: it builds once on a copy of the sources inside the scratch dir (the tree itself gets no
# .dart_tool), skips while no source is newer, rebuilds after a source changes, and prints the version of the Dart on PATH.
# On a Linux host (a stand-in `uname`) with another Dart than the pin it builds in the dart:<pin> image and reports the
# image's version; with the pinned Dart it uses it.
ring_dart_checks() {
  local tree="$tmp/tree" bin="$tmp/fake-bin" log="$tmp/fake-dart.log" builds version pin out
  pin="$(bash "$here/tool-pin.sh" dart)"
  export FAKE_DART_VERSION="$pin"
  mkdir -p "$tree/.github/workflows/drivers/handoff-dart/bin" "$tree/dart/lib" "$bin"
  cp "$here/ring-dart.sh" "$here/tool-pin.sh" "$here/tool-pins.txt" "$tree/.github/workflows/"
  : > "$tree/dart/pubspec.yaml"; : > "$tree/dart/lib/a.dart"
  : > "$tree/.github/workflows/drivers/handoff-dart/pubspec.yaml"; : > "$tree/.github/workflows/drivers/handoff-dart/bin/handoff_dart.dart"
  write_fake_dart "$bin"
  find "$tree" -type f -exec touch -t 200001010000 {} +
  : > "$log"
  for _ in 1 2; do
    PATH="$bin:$PATH" FAKE_DART_LOG="$log" bash "$tree/.github/workflows/ring-dart.sh" "$tmp/scratch" < /dev/null
  done
  builds="$(grep -c '^dart pub get' "$log" || true)"
  if [ "$builds" = 1 ]; then echo "builds once: two calls, one dart pub get"; else fail "two calls ran $builds builds"; fi
  [ "$(grep -c '^dart compile exe ' "$log")" = 2 ] || fail "a build did not compile the handoff driver and the position program: $(cat "$log")"
  [ -x "$tmp/scratch/handoff-dart" ] && [ -x "$tmp/scratch/position" ] || fail "the build left no handoff-dart and position in the scratch dir"
  if [ -e "$tree/dart/.dart_tool" ] || [ -e "$tree/.github/workflows/drivers/handoff-dart/.dart_tool" ]; then
    fail "the build wrote into the repository tree"
  fi
  grep -q "^dart pub get @ $tmp/scratch/src/.github/workflows/drivers/handoff-dart" "$log" \
    || fail "the build did not run on the copy in the scratch dir: $(cat "$log")"
  # The last build was long ago, and a source changed after it.
  find "$tmp/scratch" -exec touch -t 200101010000 {} +
  touch -t 200201010000 "$tree/dart/lib/a.dart"
  PATH="$bin:$PATH" FAKE_DART_LOG="$log" bash "$tree/.github/workflows/ring-dart.sh" "$tmp/scratch" < /dev/null
  builds="$(grep -c '^dart pub get' "$log" || true)"
  if [ "$builds" = 2 ]; then echo "rebuilds: a newer package source"; else fail "a newer source gave $builds builds, expected 2"; fi
  PATH="$bin:$PATH" FAKE_DART_LOG="$log" bash "$tree/.github/workflows/ring-dart.sh" "$tmp/scratch" < /dev/null
  builds="$(grep -c '^dart pub get' "$log" || true)"
  if [ "$builds" = 2 ]; then echo "builds once more only"; else fail "a call after the rebuild built again ($builds builds)"; fi
  version="$(PATH="$bin:$PATH" FAKE_DART_LOG="$log" bash "$tree/.github/workflows/ring-dart.sh" --version < /dev/null)"
  if [ "$version" = "$pin" ]; then echo "prints the version: $version"; else fail "--version printed [$version], expected $pin"; fi
  ring_dart_linux_checks "$tree" "$pin"
}

# A Linux host (stand-in uname) whose Dart is another than the pin: the drivers are built in the dart:<pin> image, and
# --version reports the image's; with the pinned Dart it builds with that Dart.
ring_dart_linux_checks() {
  local tree="$1" pin="$2" lbin="$tmp/linux-bin" log="$tmp/linux-dart.log" version scratch="$tmp/linux-scratch" out
  mkdir -p "$lbin"
  printf '#!/bin/sh\n[ "$1" = -s ] && echo Linux || exec /usr/bin/uname "$@"\n' > "$lbin/uname"; chmod +x "$lbin/uname"
  write_fake_dart "$lbin"; write_fake_docker "$lbin"
  : > "$log"
  version="$(PATH="$lbin:$PATH" FAKE_DART_VERSION=3.99.0 FAKE_DOCKER_DART="$pin" FAKE_DART_LOG="$log" \
    bash "$tree/.github/workflows/ring-dart.sh" --version < /dev/null)"
  if [ "$version" = "$pin" ]; then echo "linux host, another Dart: --version reports the image's $version"; else fail "linux --version printed [$version], expected the image's $pin"; fi
  out="$(PATH="$lbin:$PATH" FAKE_DART_VERSION=3.99.0 FAKE_DOCKER_DART="$pin" FAKE_DART_LOG="$log" PACKBIN_DART_CACHE=hit \
    bash "$tree/.github/workflows/ring-dart.sh" "$scratch" 2>&1 < /dev/null)"
  if grep -q "^docker run --rm -i --user $(id -u):$(id -g) .* dart:$pin bash -c " "$log" && ! grep -q '^dart pub' "$log" \
    && grep -qx 'ring-dart: cache hit' <<< "$out"; then
    echo "linux host, another Dart: the drivers build in the dart:$pin image, the cache state said"
  else
    fail "a Linux host with Dart 3.99.0 did not build in the image or did not say its cache state: $(cat "$log") $out"
  fi
  : > "$log"; rm -rf "$scratch"
  PATH="$lbin:$PATH" FAKE_DART_VERSION="$pin" FAKE_DART_LOG="$log" bash "$tree/.github/workflows/ring-dart.sh" "$scratch" < /dev/null
  if grep -q '^dart pub get' "$log" && ! grep -q '^docker' "$log"; then
    echo "linux host, the pinned Dart: it builds the drivers"
  else
    fail "a Linux host with the pinned Dart did not use it: $(cat "$log")"
  fi
}

runs=0
ring_checks
static_checks
workflow_checks
ring_dart_checks

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "dart ring wiring checks passed"
