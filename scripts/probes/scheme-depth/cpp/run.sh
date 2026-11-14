#!/usr/bin/env bash
# C++ probe of AZ-4291 (see ../README.md). Compiles probe.cpp with the core sources of this checkout
# in a temporary directory outside the repository, then runs each shape and depth in a process of
# its own through ../case.sh (limit 60 s), so a stack overflow or a hang is one `crashed:` line.
# Prints six lines: when-1000, when-5000, when-50000, group-1000, group-5000, group-50000.
# CXX picks the compiler (default c++); PACKBIN_CXX_SYSROOT is honoured as in cpp/Makefile.
# Exit: 0 the probe ran, whatever it found; 1 the build failed.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../../.." && pwd)"
out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

# CORE_SRCS of cpp/Makefile.
core=(values pack unpack crypto frame)

cxx="${CXX:-c++}"
# The flags of cpp/Makefile without -Werror: the library is built the embedded way on the host too.
flags=(-std=c++17 -O2 -Wall -Wextra -fno-exceptions -fno-rtti -I "$root/cpp/include")
if [[ -n "${PACKBIN_CXX_SYSROOT:-}" ]]; then
  flags+=(-isysroot "$PACKBIN_CXX_SYSROOT" -I "$PACKBIN_CXX_SYSROOT/usr/include/c++/v1")
fi

objects=()
for name in "${core[@]}"; do
  "$cxx" "${flags[@]}" -c -o "$out/$name.o" "$root/cpp/src/core/$name.cpp" >&2
  objects+=("$out/$name.o")
done
"$cxx" "${flags[@]}" -o "$out/probe" "$here/probe.cpp" "${objects[@]}" >&2

for shape in when group; do
  for depth in 1000 5000 50000; do
    bash "$here/../case.sh" cpp "$shape-$depth" 60 "$out/probe" "$shape" "$depth"
  done
done
