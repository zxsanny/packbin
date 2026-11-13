#!/usr/bin/env bash
# Loop 123 smoke (hygiene: AZ-4279, AZ-4280): one paste, PASS/FAIL per step. Run from the repository root with a clean
# application tree, after step 11 (it reads the stage stamps). Needs Docker (gcc:16 with network for apt) and
# python3.13 with PyYAML for the self-test.
set -u
fail=0
work="$(mktemp -d)"
step() { # name, command...
  local name="$1"; shift
  if "$@" > "$work/step.log" 2>&1; then echo "PASS  $name"; sed 's/^/      /' "$work/step.log" | tail -3; else echo "FAIL  $name"; sed 's/^/      /' "$work/step.log" | tail -12; fail=1; fi
}
limit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' -- "$s" "$@"; }
batch="$(git log -1 --format=%H --grep='C++ member folds without nesting')"
s1() { # the application tree is the batch commit's, and step 11 passed its stages there or later
  [ -z "$(git status --porcelain -- . ':(exclude)_docs')" ] || { git status --short -- . ':(exclude)_docs'; return 1; }
  local stage stamp
  for stage in cpp cpp-embedded-arm ring scaffold publish-gate dart swift; do
    stamp="$(cat "test-results/stamps/$stage")" || return 1
    git merge-base --is-ancestor "$batch" "$stamp" || { echo "stamp $stage is older than ${batch:0:7}"; return 1; }
  done
  echo "7 stage stamps at or after ${batch:0:7}"
}
s2() { # a 300-field scheme: clang 19 at default limits fails on the old headers and compiles on the new ones
  local d="$work/wide"
  mkdir -p "$d/old" "$d/new" && rsync -a cpp/include "$d/new/" && rsync -a cpp/include "$d/old/" || return 1
  git show "$batch^:cpp/include/packbin/table.hpp" > "$d/old/include/packbin/table.hpp" || return 1
  git show "$batch^:cpp/include/packbin/codec.hpp" > "$d/old/include/packbin/codec.hpp" || return 1
  cat > "$d/wide.cpp" <<'CPP'
#include <packbin/packbin.hpp>
#include <utility>
namespace pb = packbin;
struct Row { int x; };
template <std::size_t... Is>
auto wide(std::index_sequence<Is...>) { return pb::scheme<Row>(1, pb::u8(static_cast<int>(Is))...); }
int main() { auto const s = wide(std::make_index_sequence<300>()); return pb::validate(s).ok() ? 0 : 1; }
CPP
  limit 900 docker run --rm -v "$d:/src" -w /src gcc:16 bash -c 'apt-get -o Acquire::Retries=3 update -q >/dev/null && DEBIAN_FRONTEND=noninteractive apt-get install -y -q --no-install-recommends clang-19 >/dev/null || exit 9
    if clang++-19 -std=c++17 -Iold/include -fno-exceptions -fno-rtti -fsyntax-only wide.cpp 2>old.err; then echo "old headers compiled"; exit 1; fi
    grep -m1 -o "fold expression with [0-9]* arguments exceeded expression nesting limit of 256" old.err || exit 1
    clang++-19 -std=c++17 -Inew/include -fno-exceptions -fno-rtti -o wide wide.cpp && ./wide && echo "new headers: built and validated"' < /dev/null
}
s3() { # the sanitizer flags no longer raise clang's limit; the m33f pins are untouched by the loop
  ! grep -n 'bracket-depth' cpp/Makefile || return 1
  git diff --quiet "$batch^" "$batch" -- cpp/embedded/lib.sh rust/embedded || { echo "pins changed"; return 1; }
  echo "no -fbracket-depth; cpp/embedded/lib.sh pins unchanged"
}
s4() { # run-suite self-test: a failed clang install names the pin and the Debian release
  mkdir -p "$work/py" && ln -sf /opt/homebrew/bin/python3.13 "$work/py/python3"
  PATH="$work/py:$PATH" limit 600 bash .github/workflows/run-suite.test.sh < /dev/null > "$work/rs" 2>&1 || { tail -5 "$work/rs"; return 1; }
  grep -q 'is not installable on Debian' .github/workflows/run-suite.sh && tail -1 "$work/rs"
}
s5() { # lint: the changed CI shell files gain no warning; run-suite.sh within the 500-line cap
  shellcheck -S warning .github/workflows/run-suite.sh .github/workflows/run-suite.test.sh || return 1
  [ "$(wc -l < .github/workflows/run-suite.sh | tr -d ' ')" -le 500 ] && echo "clean; run-suite.sh $(wc -l < .github/workflows/run-suite.sh | tr -d ' ') lines"
}
step "1. tree is the batch commit; step 11 stamps (7 stages) at it or later" s1
step "2. 300-field scheme with clang 19: old headers refused (nesting limit), new headers build and validate" s2
step "3. no -fbracket-depth; m33f pins unchanged" s3
step "4. run-suite self-test: failed clang install names pin and Debian release" s4
step "5. lint clean; run-suite.sh within 500 lines" s5
rm -rf "$work"
if [ "$fail" -eq 0 ]; then echo "smoke 123: 5/5 PASS"; else echo "smoke 123: FAIL (see above)"; fi
exit "$fail"
