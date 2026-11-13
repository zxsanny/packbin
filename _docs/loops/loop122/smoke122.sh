#!/usr/bin/env bash
# Loop 122 smoke (hygiene: AZ-4277, AZ-4278): one paste, PASS/FAIL per step. Run from the repository root with a clean
# application tree (the code of the batch commit). Needs Docker (gcc:16 with network for apt), dart, and python3.13 with
# PyYAML for the self-test (PACKBIN_SMOKE_PY_DIR: a dir with python3 -> python3.13; default the Homebrew one).
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
s1() { # the application tree is the batch commit's
  [ -z "$(git status --porcelain -- . ':(exclude)_docs')" ] || { git status --short -- . ':(exclude)_docs'; return 1; }
  git log -1 --format='%h %s' --grep='Dart cost test best of three; C++ sanitizer in CI'
}
s2() { # Dart cost test, three runs
  local i
  for i in 1 2 3; do (cd dart && limit 300 dart test test/rounds/repeat_last_cost_test.dart < /dev/null) > "$work/dart$i" 2>&1 || { tail -5 "$work/dart$i"; return 1; }; done
  tail -1 "$work/dart3"; echo "3 of 3 runs passed"
}
s3() { # a quadratic first-writer walk fails the Dart cost test (scratch copy of dart/)
  local q="$work/quad"
  mkdir -p "$q" && rsync -a --exclude .dart_tool --exclude build dart/ "$q/dart/" || return 1
  python3 - "$q/dart/lib/src/checks.dart" <<'PY' || return 1
import sys
p = sys.argv[1]; s = open(p).read()
old = """    for (var i = nodes.length - 1; i >= 0; i--) {
      next[i] = _writer(nodes[i]) ?? next[i + 1];
    }"""
new = """    for (var i = 0; i < nodes.length; i++) {
      Node? found;
      for (var j = i; j < nodes.length && found == null; j++) {
        _held.clear();
        found = _writer(nodes[j]);
      }
      next[i] = found ?? after;
    }"""
assert old in s, "the walk changed: update the smoke mutant"
open(p, "w").write(s.replace(old, new))
PY
  if (cd "$q/dart" && limit 600 dart test test/rounds/repeat_last_cost_test.dart < /dev/null) > "$work/quad.log" 2>&1; then
    echo "the quadratic copy passed"; return 1
  fi
  grep -E 'took [0-9]+ ms' "$work/quad.log" | sed 's/^ *//' | cut -c1-120
}
s4() { # run-suite self-test (C1: flag on, failing sanitizer build, flag off) and the pin
  PATH="${PACKBIN_SMOKE_PY_DIR:-$work/py}:$PATH"
  mkdir -p "$work/py" && ln -sf /opt/homebrew/bin/python3.13 "$work/py/python3"
  limit 600 bash .github/workflows/run-suite.test.sh < /dev/null > "$work/rs" 2>&1 || { tail -5 "$work/rs"; return 1; }
  [ "$(bash .github/workflows/tool-pin.sh clang)" = 19 ] || return 1
  grep -q '^PINS_NAMES=".* clang"$' .github/workflows/publish-pins.test.sh || { echo "clang is not an allowed pin name"; return 1; }
  tail -1 "$work/rs"; echo "pin clang==19, allowed by the pins check"
}
s5() { # the cpp suite in its container: plain suite, then the sanitizer build with clang 19 under 600 s, green
  limit 1800 docker compose -f docker-compose.test.yml run --rm cpp \
    'make -C /src/cpp clean && exec /src/.github/workflows/run-suite.sh cpp' < /dev/null > "$work/cpp" 2>&1 || { grep -E 'runtime error|ERROR: AddressSanitizer|Unable to locate|step took' "$work/cpp" | tail -6; return 1; }
  grep -q 'step took .*: timeout 600 make -C /src/cpp CXX=clang++-19 sanitizer-test' "$work/cpp" || { echo "no sanitizer step"; return 1; }
  grep -E 'run-suite: cpp (step took .*sanitizer-test|total)' "$work/cpp"
}
s6() { # a planted heap overflow fails the sanitizer build (scratch copy of cpp/ and fixtures/)
  local c="$work/ac2"
  mkdir -p "$c" && rsync -a --exclude build cpp fixtures "$c/" || return 1
  python3 - "$c/cpp/tests/core/main.cpp" <<'PY' || return 1
import re, sys
p = sys.argv[1]; s = open(p).read()
m = re.search(r"int main\([^)]*\)\s*\{", s)
s = s[:m.end()] + "\n  { int* planted = new int[4](); volatile int i = 4; volatile int v = planted[i]; (void)v; delete[] planted; }\n" + s[m.end():]
open(p, "w").write(s)
PY
  if limit 1200 docker run --rm -v "$c:/src" -w /src gcc:16 bash -c 'apt-get -o Acquire::Retries=3 update -q >/dev/null && DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends clang-19 libclang-rt-19-dev >/dev/null && timeout 600 make -C /src/cpp CXX=clang++-19 sanitizer-test' < /dev/null > "$work/ac2.log" 2>&1; then
    echo "the planted overflow passed"; return 1
  fi
  grep -m1 'ERROR: AddressSanitizer' "$work/ac2.log" | cut -c1-90
}
s7() { # lint: the two changed CI shell files gain no warning
  shellcheck -S warning .github/workflows/run-suite.sh .github/workflows/run-suite.test.sh && echo "shellcheck -S warning: clean"
}
step "1. the application tree is the batch commit" s1
step "2. Dart repeat-last cost test passes 3 of 3 runs (best of three builds)" s2
step "3. a quadratic copy of the Dart walk fails that test" s3
step "4. run-suite self-test C1 passes; clang==19 pinned and allowed" s4
step "5. cpp suite in its container: plain tests, then ASan+UBSan with clang 19, green" s5
step "6. a planted heap overflow fails the sanitizer build" s6
step "7. shellcheck on the changed CI shell files" s7
rm -rf "$work"
if [ "$fail" -eq 0 ]; then echo "smoke 122: 7/7 PASS"; else echo "smoke 122: FAIL (see above)"; fi
exit "$fail"
