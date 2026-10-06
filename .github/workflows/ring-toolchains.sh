#!/usr/bin/env bash
# Logs the version of every toolchain the cross-language ring uses (language-pair.sh) and fails,
# naming each toolchain that is not the version the per-package suites use (docker-compose.test.yml).
# The wanted versions are the RING_* variables of the `ring` job in test.yml; each is compared at
# its own precision (10.0 compares major and minor, 24 compares the major).
set -euo pipefail

bad=0

# check <toolchain> <wanted version> <version found>
check() {
  local name="$1" want="$2" full="$3" fields got
  fields="$(awk -F. '{ print NF }' <<< "$want")"
  got="$(cut -d. -f1-"$fields" <<< "$full")"
  if [ "$got" = "$want" ]; then
    echo "toolchain $name: $full"
  else
    echo "toolchain $name: found $full, the suites use $want" >&2
    bad=1
  fi
}

check dotnet "${RING_DOTNET:?}" "$(dotnet --version)"
check node "${RING_NODE:?}" "$(node --version | tr -d v)"
check python "${RING_PYTHON:?}" "$(python3 -c 'import platform; print(platform.python_version())')"
check rust "${RING_RUST:?}" "$(rustc --version | awk '{ print $2 }')"
check java "${RING_JDK:?}" "$(javac --version | awk '{ print $2 }')"

# The compiler is the one the ring uses: CXX, which is ring-cxx.sh (g++ from the gcc image) in the
# ring job. Clang also defines __GNUC__ (as 4), so name the compiler family first.
cxx="${CXX:-c++}"
if family="$(printf '%s\n' '#if defined(__clang__)' 'clang' '#elif defined(__GNUC__)' '__GNUC__' '#endif' \
  | "$cxx" -E -P -x c++ - | tr -d '[:space:]')"; then
  echo "compiler: $("$cxx" --version | head -n 1)"
  if [ "$family" = clang ]; then
    echo "toolchain gcc: $cxx is clang, the suites use GCC ${RING_GCC:?}" >&2
    bad=1
  else
    check gcc "${RING_GCC:?}" "$family"
  fi
else
  echo "toolchain gcc: $cxx did not run, the suites use GCC ${RING_GCC:?}" >&2
  bad=1
fi

exit "$bad"
