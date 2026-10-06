#!/usr/bin/env bash
# Pin checks (AZ-2214, F12): every action is a commit SHA and every tool the publish and test scripts
# install has an exact version from tool-pins.txt. Sourced by publish-gate.test.sh, which defines
# fail, assert_eq, copy_tree, $root and $here. Each rule is also run against a violating temp copy.

# shellcheck disable=SC2154,SC2016
PINS_NAMES="npm twine platformio idf-component-manager build setuptools pytest"

# Prints the violations of every workflow file in directory $1 (non-zero exit when there are any):
# a non-local `uses:` that is not owner/repo@<40 lowercase hex>, a pinned one without a `# <tag>`
# comment, one action with two SHAs across the files, and a literal `npm@<digit>` in a run step.
pins_check_actions() {
  ruby -ryaml - "$1" <<'RUBY'
dir = ARGV.fetch(0)
files = Dir.glob(File.join(dir, "*.{yml,yaml}")).sort
errors = []
errors << "#{dir}: no workflow files" if files.empty?
pinned = /\A[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+(\/[^@\s]+)?@[0-9a-f]{40}\z/
shas = Hash.new { |h, k| h[k] = Hash.new { |g, s| g[s] = [] } }
count = 0
files.each do |path|
  name = File.basename(path)
  text = File.read(path)
  workflow = YAML.safe_load(text)
  jobs = workflow.is_a?(Hash) && workflow["jobs"].is_a?(Hash) ? workflow["jobs"].values : []
  steps = jobs.flat_map { |job| job["steps"].is_a?(Array) ? job["steps"] : [] }
  (jobs + steps).each do |node|
    ref = node["uses"]
    next if ref.nil? || ref.start_with?("./")
    count += 1
    errors << "#{name}: uses '#{ref}' is not owner/repo@<40 lowercase hex commit>" unless ref.match?(pinned)
  end
  steps.each do |step|
    literal = step["run"].to_s[/npm@\d\S*/]
    errors << "#{name}: run step installs npm at the literal version '#{literal}'" if literal
  end
  text.each_line.with_index(1) do |line, number|
    match = line.match(/^\s*(?:-\s+)?uses:\s*(\S+)(.*)$/)
    next if match.nil?
    ref = match[1].delete("\"'")
    next unless ref.match?(pinned)
    errors << "#{name}:#{number}: uses '#{ref}' has no tag comment (# <tag>)" unless match[2].match?(/\A\s+#\s*\S/)
    action, sha = ref.split("@")
    shas[action][sha] << name
  end
end
shas.each do |action, by_sha|
  errors << "action #{action} has #{by_sha.size} different SHAs: #{by_sha.keys.join(', ')}" if by_sha.size > 1
end
errors.each { |e| puts e }
puts "ok: #{count} non-local uses, #{shas.size} actions, #{files.size} files" if errors.empty?
exit(errors.empty? ? 0 : 1)
RUBY
}

# Prints the violations of pins file $1 (non-zero exit when there are any): exactly one name==digits.dots
# line for each of PINS_NAMES, nothing else.
pins_file_errors() {
  awk -v want="$PINS_NAMES" '
    BEGIN { n = split(want, w, " "); for (i = 1; i <= n; i++) need[w[i]] = 0 }
    /^[[:space:]]*(#|$)/ { next }
    $0 !~ /^[a-z0-9-]+==[0-9]+(\.[0-9]+)*$/ { print "malformed line: " $0; bad = 1; next }
    { split($0, p, "=="); if (p[1] in need) need[p[1]]++; else { print "unexpected tool: " p[1]; bad = 1 } }
    END { for (t in need) if (need[t] != 1) { print "pin count for " t ": " need[t]; bad = 1 } exit bad }
  ' "$1"
}

# pins_mutate <source file> <dest file> <sed expression>: writes the edited copy and fails when nothing changed.
pins_mutate() {
  sed -e "$3" "$1" > "$2"
  if cmp -s "$1" "$2"; then
    fail "AZ-2214 temp copy is unchanged: $(basename "$2") with $3"
  fi
}

pins_expect_reject() {
  local label="$1" dir="$2" out needle
  shift 2
  if out="$(pins_check_actions "$dir" 2>&1)"; then
    fail "AZ-2214 AC-2 the actions check passed a violating copy: $label"
    return
  fi
  for needle in "$@"; do
    if ! grep -qF -- "$needle" <<< "$out"; then
      fail "AZ-2214 AC-2 $label: the message does not name [$needle]: $out"
    fi
  done
  echo "actions check rejects: $label ($(head -n 1 <<< "$out"))"
}

pins_action_checks() {
  local tmp="$1" out checkout_sha upper dir
  local nuget_ref setup_ref seen
  if ! out="$(pins_check_actions "$here")"; then
    fail "AZ-2214 AC-1 workflow actions: $out"
  fi
  echo "$out"
  seen="$(sed -n 's/^ok: \([0-9]*\) non-local.*/\1/p' <<< "$out")"
  if [[ ! "$seen" =~ ^[0-9]+$ ]] || [ "$seen" -lt 5 ]; then
    fail "AZ-2214 AC-1 fewer than five non-local uses were seen: $out"
  fi
  grep -qF 'uses: ./.github/workflows/test.yml' "$here/publish.yml" || fail "AZ-2214 AC-1 the local call went missing"

  checkout_sha="$(awk -F'actions/checkout@' 'NF > 1 { print substr($2, 1, 40); exit }' "$here/test.yml")"
  upper="$(printf '%s' "$checkout_sha" | tr 'a-f' 'A-F')"
  nuget_ref="$(awk -F'NuGet/login@' 'NF > 1 { print substr($2, 1, 40); exit }' "$here/publish.yml")"
  setup_ref="$(awk -F'actions/setup-node@' 'NF > 1 { print substr($2, 1, 40); exit }' "$here/publish.yml")"
  assert_eq "${#checkout_sha}" "40" "AZ-2214 checkout SHA length"

  dir="$tmp/v7"
  mkdir -p "$dir"; cp "$here"/*.yml "$dir/"
  pins_mutate "$here/publish.yml" "$dir/publish.yml" "s|actions/checkout@$checkout_sha # v7.0.1|actions/checkout@v7|"
  pins_expect_reject "checkout@v7" "$dir" "publish.yml" "actions/checkout@v7"

  dir="$tmp/v1"
  mkdir -p "$dir"; cp "$here"/*.yml "$dir/"
  pins_mutate "$here/publish.yml" "$dir/publish.yml" "s|NuGet/login@$nuget_ref # v1.2.0|NuGet/login@v1|"
  pins_expect_reject "NuGet/login@v1" "$dir" "publish.yml" "NuGet/login@v1"

  dir="$tmp/main"
  mkdir -p "$dir"; cp "$here"/*.yml "$dir/"
  pins_mutate "$here/publish.yml" "$dir/publish.yml" "s|actions/setup-node@$setup_ref # v7.0.0|actions/setup-node@main|"
  pins_expect_reject "setup-node@main" "$dir" "publish.yml" "actions/setup-node@main"

  dir="$tmp/hex7"
  mkdir -p "$dir"; cp "$here"/*.yml "$dir/"
  pins_mutate "$here/test.yml" "$dir/test.yml" "s|actions/checkout@$checkout_sha|actions/checkout@${checkout_sha:0:7}|"
  pins_expect_reject "7-hex abbreviation" "$dir" "test.yml" "actions/checkout@${checkout_sha:0:7}"

  dir="$tmp/hex39"
  mkdir -p "$dir"; cp "$here"/*.yml "$dir/"
  pins_mutate "$here/test.yml" "$dir/test.yml" "s|actions/checkout@$checkout_sha|actions/checkout@${checkout_sha:0:39}|"
  pins_expect_reject "39-hex string" "$dir" "test.yml" "actions/checkout@${checkout_sha:0:39}"

  dir="$tmp/upper"
  mkdir -p "$dir"; cp "$here"/*.yml "$dir/"
  pins_mutate "$here/test.yml" "$dir/test.yml" "s|actions/checkout@$checkout_sha|actions/checkout@$upper|"
  pins_expect_reject "upper-case SHA" "$dir" "test.yml" "actions/checkout@$upper"

  dir="$tmp/docker"
  mkdir -p "$dir"; cp "$here"/*.yml "$dir/"
  pins_mutate "$here/test.yml" "$dir/test.yml" "s|actions/checkout@$checkout_sha # v7.0.1|docker://alpine:3|"
  pins_expect_reject "docker:// reference" "$dir" "test.yml" "docker://alpine:3"

  dir="$tmp/newstep"
  mkdir -p "$dir"; cp "$here"/*.yml "$dir/"
  { cat "$here/test.yml"; printf '      - uses: actions/foo@v1\n'; } > "$dir/test.yml"
  pins_expect_reject "a new step uses actions/foo@v1" "$dir" "test.yml" "actions/foo@v1"

  dir="$tmp/nocomment"
  mkdir -p "$dir"; cp "$here"/*.yml "$dir/"
  pins_mutate "$here/publish.yml" "$dir/publish.yml" "s|\(actions/checkout@$checkout_sha\) # v7.0.1|\1|"
  pins_expect_reject "a SHA without its tag comment" "$dir" "publish.yml" "actions/checkout@$checkout_sha" "tag comment"

  dir="$tmp/twoshas"
  mkdir -p "$dir"; cp "$here"/*.yml "$dir/"
  pins_mutate "$here/test.yml" "$dir/test.yml" "s|actions/checkout@$checkout_sha|actions/checkout@0123456789abcdef0123456789abcdef01234567|"
  pins_expect_reject "two SHAs for one action" "$dir" "actions/checkout" "different SHAs"

  dir="$tmp/newfile"
  mkdir -p "$dir"; cp "$here"/*.yml "$dir/"
  printf 'name: extra\non: push\njobs:\n  extra:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v7\n' > "$dir/extra.yml"
  pins_expect_reject "a new workflow file with a tag" "$dir" "extra.yml" "actions/checkout@v7"

  dir="$tmp/jobuses"
  mkdir -p "$dir"; cp "$here"/*.yml "$dir/"
  pins_mutate "$here/publish.yml" "$dir/publish.yml" "s|uses: ./.github/workflows/test.yml|uses: octo/reusable/.github/workflows/x.yml@v1|"
  pins_expect_reject "a job-level uses on a tag" "$dir" "publish.yml" "octo/reusable/.github/workflows/x.yml@v1"

  dir="$tmp/npm"
  mkdir -p "$dir"; cp "$here"/*.yml "$dir/"
  pins_mutate "$here/publish.yml" "$dir/publish.yml" 's|npm install -g "npm@$(bash .github/workflows/tool-pin.sh npm)"|npm install -g npm@11|'
  pins_expect_reject "a literal npm version" "$dir" "publish.yml" "npm@11"
}

pins_file_checks() {
  local tmp="$1" out dir name version
  if ! out="$(pins_file_errors "$here/tool-pins.txt")"; then
    fail "AZ-2214 AC-3 pins file: $out"
  fi
  for name in $PINS_NAMES; do
    version="$(bash "$here/tool-pin.sh" "$name")" || fail "AZ-2214 AC-3 the reader has no pin for $name"
    assert_eq "$(grep -c "^$name==$version\$" "$here/tool-pins.txt")" "1" "AZ-2214 AC-3 line for $name"
  done
  if out="$(bash "$here/tool-pin.sh" nosuchtool 2>&1)"; then
    fail "AZ-2214 AC-3 the reader answered for a tool that is not pinned: $out"
  else
    echo "reader rejects nosuchtool: $out"
  fi

  dir="$tmp/pins"
  mkdir -p "$dir"
  pins_mutate "$here/tool-pins.txt" "$dir/range.txt" 's/^twine==.*/twine>=7.0.0/'
  pins_mutate "$here/tool-pins.txt" "$dir/empty.txt" 's/^build==.*/build==/'
  pins_mutate "$here/tool-pins.txt" "$dir/wild.txt" 's/^pytest==.*/pytest==9.*/'
  pins_mutate "$here/tool-pins.txt" "$dir/missing.txt" '/^setuptools==/d'
  pins_mutate "$here/tool-pins.txt" "$dir/extra.txt" '$a\
twine==7.0.0'
  for name in range empty wild missing extra; do
    if out="$(pins_file_errors "$dir/$name.txt")"; then
      fail "AZ-2214 AC-3 the pins check passed a violating file: $name"
    else
      echo "pins check rejects $name: $(head -n 1 <<< "$out")"
    fi
  done
  cp "$here/tool-pin.sh" "$dir/tool-pin.sh"
  for name in range empty wild extra; do
    cp "$dir/$name.txt" "$dir/tool-pins.txt"
    case "$name" in
      range) version=twine ;;
      empty) version=build ;;
      wild) version=pytest ;;
      extra) version=twine ;;
    esac
    if out="$(bash "$dir/tool-pin.sh" "$version" 2>&1)"; then
      fail "AZ-2214 AC-3 the reader printed [$out] for $version in a $name file"
    fi
  done
}

# A venv directory whose python and pip are stubs; the pip stub logs its argv to $PINS_LOG.
pins_stub_venv() {
  mkdir -p "$1/venv/bin"
  printf '#!/bin/sh\nexit 0\n' > "$1/venv/bin/python"
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$PINS_LOG"\n' > "$1/venv/bin/pip"
  chmod +x "$1/venv/bin/python" "$1/venv/bin/pip"
}

pins_install_checks() {
  local tmp="$1" name version file line wf log prepare_fn
  wf="$tmp/wf"
  log="$tmp/pip.log"
  prepare_fn='/^prepare_tools() {/,/^}/p'
  mkdir -p "$wf" "$tmp/tools"
  cp "$here"/*.sh "$here/tool-pins.txt" "$wf/"
  pins_stub_venv "$tmp/tools"
  : > "$log"
  env PATH=/usr/bin:/bin PINS_LOG="$log" PACKBIN_TOOLS="$tmp/tools" bash -c '
    set -euo pipefail
    source "$1/publish-lib.sh"
    ensure_tool twine twine
    ensure_tool pio platformio
    ensure_tool compote idf-component-manager
  ' _ "$wf" || fail "AZ-2214 AC-4 ensure_tool failed against the stub pip"
  for name in twine platformio idf-component-manager; do
    version="$(bash "$here/tool-pin.sh" "$name")"
    grep -qF -- "--only-binary=:all: $name==$version" "$log" \
      || fail "AZ-2214 AC-4 the install of $name did not carry --only-binary=:all: $name==$version: $(cat "$log")"
  done
  assert_eq "$(wc -l < "$log" | tr -d ' ')" "3" "AZ-2214 AC-4 install calls"

  : > "$log"
  if env PATH=/usr/bin:/bin PINS_LOG="$log" PACKBIN_TOOLS="$tmp/tools" bash -c '
    set -euo pipefail
    source "$1/publish-lib.sh"
    ensure_tool nosuchcmd nosuchpkg
  ' _ "$wf" > "$tmp/nopin.out" 2>&1; then
    fail "AZ-2214 NFR an unpinned package was installed"
  fi
  [ ! -s "$log" ] || fail "AZ-2214 NFR pip ran for a package without a pin: $(cat "$log")"
  grep -q "no single exact pin for 'nosuchpkg'" "$tmp/nopin.out" || fail "AZ-2214 NFR the missing pin was not named: $(cat "$tmp/nopin.out")"

  # AC-5: one edit of the pins file is the whole bump; the real prepare_tools function runs.
  sed 's/^twine==.*/twine==99.0.1/' "$here/tool-pins.txt" > "$wf/tool-pins.txt"
  if cmp -s "$here/tool-pins.txt" "$wf/tool-pins.txt"; then
    fail "AZ-2214 AC-5 temp pins copy is unchanged"
  fi
  : > "$log"
  env PATH=/usr/bin:/bin PINS_LOG="$log" PACKBIN_TOOLS="$tmp/tools" bash -c '
    set -euo pipefail
    source "$1/publish-lib.sh"
    eval "$(sed -n "$2" "$1/publish-upload.sh")"
    prepare_tools python
  ' _ "$wf" "$prepare_fn" || fail "AZ-2214 AC-5 prepare_tools failed against the stub pip"
  grep -qF -- "twine==99.0.1" "$log" || fail "AZ-2214 AC-5 the edited pin did not reach pip: $(cat "$log")"
  cp "$here/tool-pins.txt" "$wf/tool-pins.txt"
  : > "$log"
  env PATH=/usr/bin:/bin PINS_LOG="$log" PACKBIN_TOOLS="$tmp/tools" bash -c '
    set -euo pipefail
    source "$1/publish-lib.sh"
    eval "$(sed -n "$2" "$1/publish-upload.sh")"
    prepare_tools python
  ' _ "$wf" "$prepare_fn" || fail "AZ-2214 AC-5 prepare_tools failed with the committed pins"
  grep -qF -- "twine==$(bash "$here/tool-pin.sh" twine)" "$log" || fail "AZ-2214 AC-5 the committed pin did not reach pip: $(cat "$log")"

  # AC-4 static scan: every pip install line in the scripts is wheels-only and reads the pins file.
  for file in "$here"/*.sh "$root"/cpp/embedded/*.sh; do
    while IFS= read -r line; do
      case "$line" in
        *--only-binary=:all:*) ;;
        *) fail "AZ-2214 AC-4 $(basename "$file"): an install line without --only-binary=:all: [$line]" ;;
      esac
      case "$line" in
        *'==$'* | *'"${specs[@]}"'*) ;;
        *) fail "AZ-2214 AC-4 $(basename "$file"): an install line that does not use a pinned spec [$line]" ;;
      esac
      grep -Eq 'tool-pin\.sh|pip_install_pinned' "$file" || fail "AZ-2214 AC-4 $(basename "$file") installs with pip and never reads the pins file"
    done < <(grep -E '^[^#]*pip3?"?[[:space:]]+install' "$file" || true)
  done
  grep -qF 'tool-pin.sh" pytest' "$here/run-suite.sh" || fail "AZ-2214 AC-7 run-suite.sh does not read the pytest pin"
  grep -qF 'tool-pin.sh" platformio' "$root/cpp/embedded/examples.sh" || fail "AZ-2214 AC-7 examples.sh does not read the platformio pin"
  grep -qF 'tool-pin.sh" platformio' "$here/publish-phases.test.sh" || fail "AZ-2214 AC-4 the harness venv does not read the platformio pin"
  grep -qF 'tool-pin.sh" idf-component-manager' "$here/publish-phases.test.sh" || fail "AZ-2214 AC-4 the harness venv does not read the idf pin"
  grep -qF 'PIP_CONSTRAINT="$here/tool-pins.txt"' "$here/publish-inside.sh" || fail "AZ-2214 AC-6 the python build does not use the pins as constraints"
  grep -qF 'tool-pin.sh npm' "$here/publish.yml" || fail "AZ-2214 AC-4 the npm step does not read the pin"
}

pins_doc_checks() {
  local doc="$root/_docs/04_deploy/ci_cd_pipeline.md" word
  grep -q '^## Pins and how to bump them' "$doc" || fail "AZ-2214 AC-8 the pins section is missing from ci_cd_pipeline.md"
  for word in 'tool-pins.txt' 'tool-pin.sh' "git ls-remote --tags https://github.com/<owner>/<repo>.git <tag> '<tag>^{}'"; do
    grep -qF -- "$word" "$doc" || fail "AZ-2214 AC-8 ci_cd_pipeline.md does not name: $word"
  done
}

# Real installs and a real container build. The pip tools come from PyPI into a throwaway venv through ensure_tool,
# and the python package is built in its container on a tree copy.
pins_real_checks() {
  local tmp="$1" name version freeze tree out wheel generator shim venv
  shim="$tmp/shim"
  venv="$tmp/real/venv"
  mkdir -p "$shim" "$tmp/real"
  ln -s "$(command -v python3)" "$shim/python3"
  env PATH="$shim:/usr/bin:/bin" PACKBIN_TOOLS="$tmp/real" bash -c '
    set -euo pipefail
    source "$1/publish-lib.sh"
    ensure_tool twine twine
    ensure_tool pio platformio
    ensure_tool compote idf-component-manager
    twine --version
    pio --version
    compote version
  ' _ "$here" > "$tmp/real.out" 2>&1 || fail "AZ-2214 AC-4 the pinned tools did not install and run: $(tail -n 5 "$tmp/real.out")"
  freeze="$("$venv/bin/pip" freeze)"
  for name in twine platformio idf-component-manager; do
    version="$(bash "$here/tool-pin.sh" "$name")"
    grep -qix "$name==$version" <<< "$freeze" || fail "AZ-2214 AC-4 pip freeze of the tools venv lacks $name==$version"
  done

  tree="$tmp/tree"
  copy_tree "$tree"
  out="$tree/.github/workflows/out/pins"
  if ! env PACKBIN_BUILD_ONLY=1 SRC_ROOT="$tree" PACKBIN_OUT="$out" PACKBIN_VERSION=v0.1.9 \
    bash "$tree/.github/workflows/publish-build.sh" python > "$tmp/build-python.out" 2>&1; then
    fail "AZ-2214 AC-6 the python build failed: $(tail -n 5 "$tmp/build-python.out")"
    return
  fi
  grep -qx 'build ok python' "$tmp/build-python.out" || fail "AZ-2214 AC-6 no build ok python"
  wheel="$out/artifacts/python/packbin-0.1.9-py3-none-any.whl"
  [ -f "$wheel" ] && [ -f "$out/artifacts/python/packbin-0.1.9.tar.gz" ] || fail "AZ-2214 AC-6 the wheel or the sdist is missing"
  generator="$(python3 -c '
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
print(z.read([n for n in z.namelist() if n.endswith(".dist-info/WHEEL")][0]).decode())
' "$wheel" | grep '^Generator:')"
  assert_eq "$generator" "Generator: setuptools ($(bash "$here/tool-pin.sh" setuptools))" "AZ-2214 AC-6 wheel generator"
}

pins_checks() {
  local tmp
  if ! command -v ruby >/dev/null 2>&1; then
    fail "AZ-2214 ruby is required to parse the workflow YAML"
    return
  fi
  tmp="$(mktemp -d)"
  pins_action_checks "$tmp"
  pins_file_checks "$tmp"
  pins_install_checks "$tmp"
  pins_doc_checks
  pins_real_checks "$tmp"
  if ! rm -rf "$tmp"; then
    echo "note: could not remove $tmp (files written by a build container)"
  fi
}
