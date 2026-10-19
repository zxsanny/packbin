#!/bin/bash
# build_cpp.sh <repo checkout or git-archive copy> <probe dir> <out dir> [both|asan|o2]:
# the ASan/UBSan (probe_asan) and -O2 (probe_o2) builds of the probe (every .cpp of <probe dir>,
# which holds audit41_probe.cpp and probe_common.hpp); outputs in <out dir> only.
set -euo pipefail
REPO=$1; PROBE=$2; OUT=$3
mode=${4:-both}
SRCS=("$PROBE"/*.cpp)
CORE=("$REPO/cpp/src/core/values.cpp" "$REPO/cpp/src/core/pack.cpp" "$REPO/cpp/src/core/unpack.cpp" "$REPO/cpp/src/core/session.cpp")
INC=(-I"$REPO/cpp/include" -I"$REPO/cpp/src/core" -I"$PROBE")
if command -v xcrun > /dev/null; then
  SDK="$(xcrun --show-sdk-path)"
  INC=(-isysroot "$SDK" -I"$SDK/usr/include/c++/v1" "${INC[@]}")
fi
CXX=${CXX:-clang++}
if [ "$mode" != o2 ]; then
  "$CXX" -std=c++17 -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=all \
    -Wall -Wextra "${INC[@]}" "${CORE[@]}" "${SRCS[@]}" -o "$OUT/probe_asan"
fi
if [ "$mode" != asan ]; then
  "$CXX" -std=c++17 -O2 -Wall -Wextra "${INC[@]}" "${CORE[@]}" "${SRCS[@]}" -o "$OUT/probe_o2"
fi
