#!/usr/bin/env bash
# Swift wiring check of the cross-language ring (AZ-2522 AC-3), the sibling of ring-wiring.test.sh (at its line
# cap): Swift joins every kind of language-pair.sh both ways with each member of that kind's ring, refuses the
# short element packets, packs the session, checks its position row through publish-position.sh (AZ-2523), and the
# driver package, ring-swift.sh, ring-toolchains.sh and the ring job of test.yml carry the Swift pieces. Every guard
# is then proven against a temp copy with one piece removed: the copy must be rejected, naming it. ring-swift.sh is
# also run against a temp tree with a stand-in `swift` (rebuild only when a source is newer; the version it prints).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

swift_kinds="user nested boolflag booltrue bitwhen roundflags roundwhen listgroup dictgroup listflags session"
# The members of each kind's ring (as language-pair.sh runs them), Go included.
swift_members() {
  case "$1" in
    roundflags | roundwhen) echo "csharp typescript rust java cpp go" ;;
    listgroup | dictgroup | listflags) echo "typescript python java csharp go" ;;
    *) echo "csharp typescript python rust java cpp go" ;;
  esac
}
swift_expected_lines() {
  local kind member
  for kind in $swift_kinds; do
    for member in $(swift_members "$kind"); do
      # C# only produces the round kinds (no public C# API reads an aligned round row yet).
      case "$kind$member" in roundflagscsharp | roundwhencsharp) ;; *) echo "handoff swift $member $kind \"\$${kind}_hex\"" ;; esac
      echo "handoff $member swift $kind \"\$${kind}_hex\""
    done
  done
}

# Prints the violations of the ring job of workflow $1 (RING_SWIFT against pin $2 and the compose file $3).
swift_job_violations() {
  ruby -ryaml - "$1" "$2" "$3" <<'RUBY'
workflow = YAML.safe_load(File.read(ARGV.fetch(0)))
pin = ARGV.fetch(1)
compose = YAML.safe_load(File.read(ARGV.fetch(2)))
errors = []
jobs = workflow["jobs"].is_a?(Hash) ? workflow["jobs"] : {}
steps_of = ->(job) { job.is_a?(Hash) && job["steps"].is_a?(Array) ? job["steps"] : [] }
code_lines = ->(step) { step["run"].to_s.lines.map(&:strip).reject { |l| l.empty? || l.start_with?("#") } }
ring = %r{\Abash \.github/workflows/language-pair\.sh\z}
name, job = jobs.find { |_, j| steps_of.call(j).any? { |s| code_lines.call(s).any? { |l| l.match?(ring) } } }
if job.nil?
  puts "test.yml has no job that runs .github/workflows/language-pair.sh"
  exit 1
end
steps = steps_of.call(job)
have = job["env"].is_a?(Hash) ? job["env"]["RING_SWIFT"].to_s : ""
image = compose.dig("services", "swift", "image").to_s
errors << "RING_SWIFT is '#{have}' in job #{name}, tool-pins.txt has swift==#{pin}" if have != pin
errors << "RING_SWIFT is '#{have}' in job #{name}, the swift suite image is '#{image}'" if image != "swift:#{have}"
at = ->(re) { steps.index { |s| code_lines.call(s).any? { |l| l.match?(re) } } }
ring_at = at.call(ring)
build_at = at.call(%r{\Abash \.github/workflows/ring-swift\.sh \S+\z})
errors << "job #{name} does not build the Swift drivers through ring-swift.sh before the ring" if build_at.nil? || build_at > ring_at
check_at = at.call(%r{\Abash \.github/workflows/ring-wiring-swift\.test\.sh\z})
if check_at.nil?
  errors << "job #{name} does not run ring-wiring-swift.test.sh"
elsif steps[check_at].key?("if") || steps[check_at].key?("continue-on-error")
  errors << "the ring-wiring-swift.test.sh step of job #{name} has an if or continue-on-error"
end
steps.each do |s|
  next unless s.key?("uses")
  errors << "#{s['uses']} in job #{name} is not pinned to a commit SHA" unless s["uses"].to_s.match?(/@[0-9a-f]{40}\z/)
end
errors.each { |e| puts e }
exit(errors.empty? ? 0 : 1)
RUBY
}

# swift_violations: one line per missing Swift piece. Each file can be replaced by a copy: SW_SCRIPT, SW_KINDS,
# SW_MAIN, SW_PACKAGE, SW_RESOLVED, SW_TOOLS, SW_BUILD, SW_WORKFLOW, SW_PINS, SW_COMPOSE (defaults: the real files).
swift_violations() {
  local script="${SW_SCRIPT:-$here/language-pair.sh}" kinds="${SW_KINDS:-$here/drivers/handoff-swift/Sources/handoff-swift/Kinds.swift}"
  local main="${SW_MAIN:-$here/drivers/handoff-swift/Sources/handoff-swift/main.swift}"
  local package="${SW_PACKAGE:-$here/drivers/handoff-swift/Package.swift}" tools="${SW_TOOLS:-$here/ring-toolchains.sh}"
  local build="${SW_BUILD:-$here/ring-swift.sh}" workflow="${SW_WORKFLOW:-$here/test.yml}"
  local pins="${SW_PINS:-$here/tool-pins.txt}" compose="${SW_COMPOSE:-$here/../../docker-compose.test.yml}"
  local kind pin case_block short_loop
  swift_expected_lines > "$tmp/swift-expected.txt"
  grep -Fxv -f "$script" "$tmp/swift-expected.txt" | sed 's/^/no handoff line: /' || true
  case_block="$(awk '/^    swift[)]$/ { on = 1 } on { print } on && /^      ;;$/ { exit }' "$script")"
  if [ -z "$case_block" ]; then
    echo "run_lang has no swift case"
  else
    grep -qxF '      bash "$root/.github/workflows/ring-swift.sh" "$swift_ring" || return' <<< "$case_block" \
      || echo "the swift case of run_lang does not build through ring-swift.sh, returning on a failed build"
    grep -qxF '      "$swift_ring/release/handoff-swift" "$@"' <<< "$case_block" \
      || echo "the swift case of run_lang does not run the built handoff-swift"
  fi
  awk '/^for lang in /{ langs = $0 } index($0, "\"pack-session\"") { print langs }' "$script" | grep -Eq '[ ]swift[ ;]' \
    || echo "swift is not in the loop that checks pack-session"
  short_loop="$(awk '/^for kind in /{ loop = $0 } index($0, "if ! run_lang swift \"unpack-$kind-short\" \"${!short}\"; then") { print loop }' "$script")"
  if [ -z "$short_loop" ]; then
    echo "no loop refuses the short element packets with swift"
  else
    for kind in listgroup dictgroup listflags; do
      grep -Eq "[ ]$kind[ ;]" <<< "$short_loop" || echo "the swift short packet loop has no $kind"
    done
  fi
  awk '/^for lang in /{ langs = $0 } index($0, "publish-position.sh") { print langs }' "$script" | grep -Eq '[ ]swift[ ;]' \
    || echo "swift is not in the loop that checks the position row through publish-position.sh"
  for kind in ${swift_kinds% session}; do
    grep -qxF "    case \"$kind\":" "$kinds" || echo "the swift driver has no kind $kind"
  done
  for kind in listgroup dictgroup listflags; do
    grep '^let shortKinds: ' "$kinds" | grep -qF "\"$kind\"" || echo "the swift driver does not refuse the short $kind packet"
  done
  for kind in pack-session unpack-session; do
    grep -qxF "    case \"$kind\":" "$main" || echo "the swift driver has no $kind command"
  done
  grep -qxF '        .package(path: "../../../.."),' "$package" \
    || echo "the swift driver package does not depend on the root package by path"
  [ "$(grep -c '\.package(' "$package")" = 1 ] || echo "the swift driver package has a dependency other than the root package"
  cmp -s "${SW_RESOLVED:-$here/drivers/handoff-swift/Package.resolved}" "$here/../../Package.resolved" \
    || echo "the swift driver package pins other versions than the root Package.resolved"
  for kind in handoff-swift position; do
    grep -qxF "            name: \"$kind\"," "$package" || echo "the swift driver package has no $kind program"
  done
  grep -qF 'check swift "${RING_SWIFT:?}"' "$tools" || echo "ring-toolchains.sh does not check the Swift version"
  grep -qxF 'tag="${RING_SWIFT:-$(bash "$here/tool-pin.sh" swift)}"' "$build" \
    || echo "ring-swift.sh does not take the image tag from RING_SWIFT or the tool-pins.txt swift pin"
  grep -qF '"swift:$tag"' "$build" || echo "ring-swift.sh does not build in the swift:\$tag image"
  if ! pin="$(awk -F'==' '$1 == "swift" { print $2 }' "$pins")" || [ -z "$pin" ]; then
    echo "tool-pins.txt has no swift pin"
  fi
  swift_job_violations "$workflow" "$pin" "$compose" || true
}

# expect_rejected <label> <variable=copy>: the copy differs from the real file and the check names what it lacks.
expect_rejected() {
  local label="$1" var="${2%%=*}" copy="${2#*=}" real out
  case "$var" in
    SW_SCRIPT) real="$here/language-pair.sh" ;;
    SW_KINDS) real="$here/drivers/handoff-swift/Sources/handoff-swift/Kinds.swift" ;;
    SW_MAIN) real="$here/drivers/handoff-swift/Sources/handoff-swift/main.swift" ;;
    SW_PACKAGE) real="$here/drivers/handoff-swift/Package.swift" ;;
    SW_RESOLVED) real="$here/drivers/handoff-swift/Package.resolved" ;;
    SW_TOOLS) real="$here/ring-toolchains.sh" ;;
    SW_BUILD) real="$here/ring-swift.sh" ;;
    SW_WORKFLOW) real="$here/test.yml" ;;
    SW_PINS) real="$here/tool-pins.txt" ;;
    SW_COMPOSE) real="$here/../../docker-compose.test.yml" ;;
  esac
  if cmp -s "$real" "$copy"; then
    fail "temp copy is unchanged: $label"
    return
  fi
  out="$(export "$var=$copy"; swift_violations)"
  if [ -z "$out" ]; then
    fail "the Swift ring check passed a copy without: $label"
  else
    echo "rejects: $label ($out)"
  fi
}

# mutate <file> <copy> <sed program>: the copy is <file> edited by sed.
mutate() { sed "$3" "$1" > "$2"; }

# insert_after <file> <copy> <line regex> <new lines>: the copy has <new lines> (awk escapes) after each match.
insert_after() { awk -v re="$3" -v add="$4" '{ print } $0 ~ re { print add }' "$1" > "$2"; }

swift_wiring_checks() {
  local out line n=0 kind script="$here/language-pair.sh" driver="$here/drivers/handoff-swift"
  out="$(swift_violations)"
  if [ -n "$out" ]; then fail "swift ring: $out"; return; fi
  echo "accepts: the real files"
  # Every one of the Swift handoff lines, removed alone, is named.
  while IFS= read -r line; do
    n=$((n + 1))
    grep -Fxv -- "$line" "$script" > "$tmp/no-swift-line.sh"
    if ! SW_SCRIPT="$tmp/no-swift-line.sh" swift_violations | grep -qxF "no handoff line: $line"; then
      fail "removing [$line] was not named by the Swift ring check"
    fi
  done < "$tmp/swift-expected.txt"
  echo "rejects: each of the $n Swift handoff lines removed alone"
  mutate "$script" "$tmp/s1.sh" 's/^    swift[)]$/    swiftx)/'
  expect_rejected "the swift case of run_lang" SW_SCRIPT="$tmp/s1.sh"
  mutate "$script" "$tmp/s2.sh" 's/"$swift_ring" || return$/"$swift_ring"/'
  expect_rejected "the || return of the Swift build in run_lang" SW_SCRIPT="$tmp/s2.sh"
  mutate "$script" "$tmp/s3.sh" 's/"$swift_ring\/release\/handoff-swift" "$@"/"$swift_ring\/release\/position" "$@"/'
  expect_rejected "the handoff-swift binary in run_lang" SW_SCRIPT="$tmp/s3.sh"
  mutate "$script" "$tmp/s4.sh" 's/^\(for lang in .*\) swift go; do$/\1 go; do/'
  expect_rejected "swift in the pack-session loop" SW_SCRIPT="$tmp/s4.sh"
  for kind in listgroup dictgroup listflags; do
    mutate "$script" "$tmp/s5-$kind.sh" "s/^\\(for kind in .*\\)$kind\\(.*; do\\)$/\\1\\2/"
    expect_rejected "$kind in the swift short packet loop" SW_SCRIPT="$tmp/s5-$kind.sh"
  done
  mutate "$script" "$tmp/s6.sh" 's/^  if ! run_lang swift "unpack-$kind-short"/  if ! run_lang go "unpack-$kind-short"/'
  expect_rejected "the swift short packet refusal" SW_SCRIPT="$tmp/s6.sh"
  # The position loop reads like the pack-session loop, so only the loop above the publish-position.sh line loses swift.
  awk '{ lines[NR] = $0 } /^for lang in /{ n = NR } index($0, "publish-position.sh") { at = n }
    END { sub(/ swift go; do$/, " go; do", lines[at]); for (i = 1; i <= NR; i++) print lines[i] }' "$script" > "$tmp/s7.sh"
  expect_rejected "swift in the publish-position loop" SW_SCRIPT="$tmp/s7.sh"
  for kind in ${swift_kinds% session}; do
    mutate "$driver/Sources/handoff-swift/Kinds.swift" "$tmp/k-$kind.swift" "s/^    case \"$kind\":$/    case \"x$kind\":/"
    expect_rejected "the $kind kind of the swift driver" SW_KINDS="$tmp/k-$kind.swift"
  done
  for kind in listgroup dictgroup listflags; do
    mutate "$driver/Sources/handoff-swift/Kinds.swift" "$tmp/short-$kind.swift" "/^let shortKinds: /s/\"$kind\"/\"x\"/"
    expect_rejected "the short $kind refusal of the swift driver" SW_KINDS="$tmp/short-$kind.swift"
  done
  for kind in pack-session unpack-session; do
    mutate "$driver/Sources/handoff-swift/main.swift" "$tmp/m-$kind.swift" "s/^    case \"$kind\":$/    case \"x$kind\":/"
    expect_rejected "the $kind command of the swift driver" SW_MAIN="$tmp/m-$kind.swift"
  done
  mutate "$driver/Package.swift" "$tmp/p1.swift" 's#\.package(path: "../../../.."),#.package(url: "https://github.com/zxsanny/packbin", from: "0.2.2"),#'
  expect_rejected "the root package by path" SW_PACKAGE="$tmp/p1.swift"
  insert_after "$driver/Package.swift" "$tmp/p2.swift" '^        [.]package[(]path: ' \
    '        .package(url: "https://github.com/apple/swift-crypto.git", exact: "4.3.1"),'
  expect_rejected "a second dependency of the driver package" SW_PACKAGE="$tmp/p2.swift"
  mutate "$driver/Package.swift" "$tmp/p3.swift" 's/name: "position",/name: "where",/'
  expect_rejected "the position program" SW_PACKAGE="$tmp/p3.swift"
  mutate "$driver/Package.resolved" "$tmp/r1.json" 's/"version" : "1.7.3"/"version" : "1.6.0"/'
  expect_rejected "a driver pin that differs from the root package" SW_RESOLVED="$tmp/r1.json"
  mutate "$here/ring-toolchains.sh" "$tmp/t1.sh" '/^check swift /d'
  expect_rejected "the Swift version check" SW_TOOLS="$tmp/t1.sh"
  mutate "$here/ring-swift.sh" "$tmp/b1.sh" 's/^tag=.*/tag=6/'
  expect_rejected "the image tag from RING_SWIFT or the pin" SW_BUILD="$tmp/b1.sh"
  mutate "$here/ring-swift.sh" "$tmp/b2.sh" 's/"swift:$tag"/"swift:latest"/g'
  expect_rejected "the swift:\$tag image" SW_BUILD="$tmp/b2.sh"
  mutate "$here/test.yml" "$tmp/w1.yml" 's/^      RING_SWIFT: "6\.3\.3"$/      RING_SWIFT: "6.3.4"/'
  expect_rejected "RING_SWIFT bumped alone" SW_WORKFLOW="$tmp/w1.yml"
  mutate "$here/test.yml" "$tmp/w2.yml" '/^      RING_SWIFT: /d'
  expect_rejected "RING_SWIFT removed" SW_WORKFLOW="$tmp/w2.yml"
  mutate "$here/tool-pins.txt" "$tmp/pins.txt" 's/^swift==6\.3\.3$/swift==6.3.4/'
  expect_rejected "the tool-pins.txt swift pin bumped alone" SW_PINS="$tmp/pins.txt"
  mutate "$here/../../docker-compose.test.yml" "$tmp/compose.yml" 's/image: swift:6\.3\.3$/image: swift:6.3.4/'
  expect_rejected "the swift suite image bumped alone" SW_COMPOSE="$tmp/compose.yml"
  mutate "$here/test.yml" "$tmp/w3.yml" '/^          bash \.github\/workflows\/ring-swift\.sh /d'
  expect_rejected "the Swift driver build step line" SW_WORKFLOW="$tmp/w3.yml"
  mutate "$here/test.yml" "$tmp/w4.yml" '/^      - name: Swift ring wiring$/,/ring-wiring-swift\.test\.sh$/d'
  expect_rejected "the Swift ring wiring step" SW_WORKFLOW="$tmp/w4.yml"
  insert_after "$here/test.yml" "$tmp/w5.yml" '^      - name: Swift ring wiring$' "        if: github.ref == 'refs/heads/main'"
  expect_rejected "an if on the Swift ring wiring step" SW_WORKFLOW="$tmp/w5.yml"
  mutate "$here/test.yml" "$tmp/w6.yml" 's#\(actions/setup-go@\)[0-9a-f]\{40\}.*#\1v7.0.0#'
  expect_rejected "a uses: of the ring job pinned to a tag" SW_WORKFLOW="$tmp/w6.yml"
}

# write_fake_swift <bin dir>: a stand-in `swift` that logs each call, prints a Linux version line for
# --version and writes the two binaries into the --scratch-path of a build when they are missing (a real build
# with nothing to compile leaves them as they were).
write_fake_swift() {
  cat > "$1/swift" <<'FAKE'
#!/usr/bin/env bash
echo "swift $*" >> "$FAKE_SWIFT_LOG"
if [ "${1:-}" = --version ]; then echo "Swift version ${FAKE_SWIFT_VERSION:?} (swift-${FAKE_SWIFT_VERSION}-RELEASE)"; exit 0; fi
while [ $# -gt 0 ]; do
  if [ "$1" = --scratch-path ] && [ ! -e "$2/release/position" ]; then mkdir -p "$2/release"; printf '#!/bin/sh\n' | tee "$2/release/handoff-swift" > "$2/release/position"; chmod +x "$2/release/"*; fi
  shift
done
FAKE
  chmod +x "$1/swift"
}

# write_fake_docker <bin dir>: a stand-in `docker` that logs each call, prints the pinned Swift for `swift --version`
# and writes the two binaries into the --scratch-path of a build (the image build of ring-swift.sh).
write_fake_docker() {
  cat > "$1/docker" <<'FAKE'
#!/usr/bin/env bash
echo "docker $*" >> "$FAKE_SWIFT_LOG"
case " $* " in *" --version "*) echo "Swift version ${FAKE_DOCKER_SWIFT:?} (swift-${FAKE_DOCKER_SWIFT}-RELEASE)"; exit 0 ;; esac
while [ $# -gt 0 ]; do
  if [ "$1" = --scratch-path ] && [ ! -e "$2/release/position" ]; then mkdir -p "$2/release"; printf '#!/bin/sh\n' | tee "$2/release/handoff-swift" > "$2/release/position"; chmod +x "$2/release/"*; fi
  shift
done
FAKE
  chmod +x "$1/docker"
}

# ring-swift.sh against a temp tree: it builds once, skips while no source is newer, rebuilds after a source
# changes (once, though the binaries keep their time), and prints the version of the Swift on PATH. On a Linux host
# (a stand-in `uname`) with a Swift other than the pin it builds in the swift:<pin> image and reports the image's
# version; with the pinned Swift it uses it.
ring_swift_checks() {
  local tree="$tmp/tree" bin="$tmp/fake-bin" log="$tmp/fake-swift.log" builds version pin
  pin="$(bash "$here/tool-pin.sh" swift)"
  export FAKE_SWIFT_VERSION="$pin"
  mkdir -p "$tree/.github/workflows/drivers/handoff-swift" "$tree/swift/Sources/Packbin" "$bin"
  cp "$here/ring-swift.sh" "$here/tool-pin.sh" "$here/tool-pins.txt" "$tree/.github/workflows/"
  : > "$tree/Package.swift"; : > "$tree/Package.resolved"; : > "$tree/swift/Sources/Packbin/A.swift"
  : > "$tree/.github/workflows/drivers/handoff-swift/Package.swift"
  write_fake_swift "$bin"
  find "$tree" -type f -exec touch -t 200001010000 {} +
  : > "$log"
  for _ in 1 2; do
    PATH="$bin:$PATH" FAKE_SWIFT_LOG="$log" bash "$tree/.github/workflows/ring-swift.sh" "$tmp/scratch" < /dev/null
  done
  builds="$(grep -c '^swift build -c release ' "$log" || true)"
  if [ "$builds" = 1 ]; then echo "builds once: two calls, one swift build"; else fail "two calls ran $builds swift builds"; fi
  # The last build was long ago (its output aged), and a source changed after it.
  find "$tmp/scratch" -exec touch -t 200101010000 {} +
  touch -t 200201010000 "$tree/swift/Sources/Packbin/A.swift"
  PATH="$bin:$PATH" FAKE_SWIFT_LOG="$log" bash "$tree/.github/workflows/ring-swift.sh" "$tmp/scratch" < /dev/null
  builds="$(grep -c '^swift build -c release ' "$log" || true)"
  if [ "$builds" = 2 ]; then echo "rebuilds: a newer package source"; else fail "a newer source gave $builds builds, expected 2"; fi
  PATH="$bin:$PATH" FAKE_SWIFT_LOG="$log" bash "$tree/.github/workflows/ring-swift.sh" "$tmp/scratch" < /dev/null
  builds="$(grep -c '^swift build -c release ' "$log" || true)"
  if [ "$builds" = 2 ]; then echo "builds once more only: the binaries of a no-op build stay old"; else fail "a call after the rebuild built again ($builds builds)"; fi
  grep -q -- "--scratch-path $tmp/scratch" "$log" || fail "the build did not use the scratch dir: $(cat "$log")"
  version="$(PATH="$bin:$PATH" FAKE_SWIFT_LOG="$log" bash "$tree/.github/workflows/ring-swift.sh" --version < /dev/null)"
  if [ "$version" = "$pin" ]; then echo "prints the version: $version"; else fail "--version printed [$version], expected $pin"; fi
  ring_swift_linux_checks "$tree" "$pin"
}

# A Linux host (stand-in uname) whose Swift is newer than the pin, as ubuntu-latest is: the drivers are built in
# the swift:<pin> image, not with that Swift, and --version reports the image's.
ring_swift_linux_checks() {
  local tree="$1" pin="$2" lbin="$tmp/linux-bin" log="$tmp/linux-swift.log" version scratch="$tmp/linux-scratch"
  mkdir -p "$lbin"
  printf '#!/bin/sh\n[ "$1" = -s ] && echo Linux || exec /usr/bin/uname "$@"\n' > "$lbin/uname"; chmod +x "$lbin/uname"
  write_fake_swift "$lbin"; write_fake_docker "$lbin"
  : > "$log"
  version="$(PATH="$lbin:$PATH" FAKE_SWIFT_VERSION=6.4 FAKE_DOCKER_SWIFT="$pin" FAKE_SWIFT_LOG="$log" \
    bash "$tree/.github/workflows/ring-swift.sh" --version < /dev/null)"
  if [ "$version" = "$pin" ]; then echo "linux host, another Swift: --version reports the image's $version"; else fail "linux --version printed [$version], expected the image's $pin"; fi
  PATH="$lbin:$PATH" FAKE_SWIFT_VERSION=6.4 FAKE_DOCKER_SWIFT="$pin" FAKE_SWIFT_LOG="$log" \
    bash "$tree/.github/workflows/ring-swift.sh" "$scratch" < /dev/null
  if grep -q "^docker run .* swift:$pin swift build -c release --static-swift-stdlib" "$log" && ! grep -q '^swift build' "$log"; then
    echo "linux host, another Swift: the drivers build in the swift:$pin image"
  else
    fail "a Linux host with Swift 6.4 did not build in the image: $(cat "$log")"
  fi
  : > "$log"; rm -rf "$scratch"
  version="$(PATH="$lbin:$PATH" FAKE_SWIFT_VERSION="$pin" FAKE_SWIFT_LOG="$log" bash "$tree/.github/workflows/ring-swift.sh" --version < /dev/null)"
  PATH="$lbin:$PATH" FAKE_SWIFT_VERSION="$pin" FAKE_SWIFT_LOG="$log" bash "$tree/.github/workflows/ring-swift.sh" "$scratch" < /dev/null
  if [ "$version" = "$pin" ] && grep -q '^swift build -c release ' "$log" && ! grep -q '^docker' "$log"; then
    echo "linux host, the pinned Swift: it builds the drivers"
  else
    fail "a Linux host with the pinned Swift did not use it: version [$version] $(cat "$log")"
  fi
}

if ! command -v ruby > /dev/null; then
  fail "ruby is required to parse the workflow YAML"
else
  swift_wiring_checks
fi
ring_swift_checks

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)" >&2
  exit 1
fi
echo "swift ring wiring checks passed"
