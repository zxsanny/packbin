#!/usr/bin/env bash
# Loop 71 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop71/smoke71.sh
# Needs dotnet, a JDK, the Xcode Swift toolchain and python3; about 6 minutes on a quiet host (check `uptime` first).
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0
step() { # step <n> <name> <exit code> [detail]
  if [ "$3" -eq 0 ]; then echo "PASS step $1: $2"; else echo "FAIL step $1: $2 ${4:-}"; fails=$((fails + 1)); fi
}
limit() { perl -e 'alarm shift; exec @ARGV' -- "$@"; }

# 1. The tree is clean (the smoke runs at the commit before the close commit).
code=0
[ -z "$(git status --porcelain)" ] || code=1
step 1 "the working tree is clean" "$code" "$(git status --porcelain | head -n 3)"

# 2. AZ-3232: the C# frame and primitive tests on both targets.
code=0
for target in net10.0 netstandard2.0; do
  extra=""
  [ "$target" = netstandard2.0 ] && extra="-p:PackbinTarget=netstandard2.0"
  limit 900 env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo $extra --filter "FullyQualifiedName~Frame|FullyQualifiedName~CryptoVector" > "$work/cs-$target.log" 2>&1 < /dev/null || code=1
  grep -qE 'Passed!.*Failed: +0' "$work/cs-$target.log" || code=1
done
step 2 "C# frame and primitive tests pass on net10.0 and netstandard2.0" "$code" "$(grep -hE 'Passed!|Failed!' "$work"/cs-*.log | tr '\n' ' ' | cut -c1-240)"

# 3. AZ-3233: the Java suite, including the Android API 26 check and the seven frame test classes.
code=0
limit 900 bash java/test.sh > "$work/java.log" 2>&1 < /dev/null || code=1
grep -q 'api-check PASS' "$work/java.log" || code=1
for t in CryptoVectorsTest FrameVectorsTest FrameTamperReplayTest FrameMacRefusalsTest FrameHostileTest FrameLifecycleTest FrameReadmeExample; do
  grep -q "$t passed" "$work/java.log" || { code=1; echo "$t not passed" >> "$work/java.miss"; }
done
step 3 "Java test.sh: api-check and the 7 frame test classes pass" "$code" "$(cat "$work/java.miss" 2>/dev/null | tr '\n' ' ')"

# 4. AZ-3234: the Swift frame, primitive, README and error-kind suites.
code=0
limit 1200 swift test --filter 'Frame|CryptoVector|ReadmeExample|ShortTrailing|ConcurrencyTests' > "$work/swift.log" 2>&1 < /dev/null || code=1
grep -qE 'Test run with [0-9]+ tests? in [0-9]+ suites? passed' "$work/swift.log" || code=1
step 4 "Swift frame, primitive, README, error-kind and concurrency suites pass" "$code" "$(grep -E 'Test run with' "$work/swift.log" | tail -n 1 | cut -c1-200)"

# 5. AZ-3235: each README frame example equals its example test.
code=0
bash scripts/frame/readme-examples.sh > "$work/readme.log" 2>&1 < /dev/null || code=1
[ "$(grep -c '^PASS' "$work/readme.log")" -eq 3 ] || code=1
step 5 "README examples for C#, Java, Swift equal their tests" "$code" "$(tr '\n' ' ' < "$work/readme.log" | cut -c1-200)"

# 6. The shared fixtures still check against the reference.
code=0
bash fixtures/frame/check-vectors.test.sh > "$work/fv.log" 2>&1 < /dev/null || code=1
bash fixtures/crypto/check-vectors.test.sh > "$work/cv.log" 2>&1 < /dev/null || code=1
step 6 "frame and primitive fixture checks pass" "$code" "$(tail -n 1 "$work/fv.log" | cut -c1-120)"

# 7. AZ-3232..3234 AC-12: stream code, the Rust reference and the fixtures are untouched since the loop 71 claim.
code=0
git diff --quiet 6fd61df -- csharp/PackSession.cs java/src/main/java/packbin/PackSession.java swift/Sources/Packbin/PackSession.swift rust fixtures || code=1
step 7 "PackSession in 3 packages, rust/ and fixtures/ unchanged since the claim" "$code" "$(git diff --stat 6fd61df -- rust fixtures csharp/PackSession.cs | tail -n 1)"

# 8. Source files of the loop stay at or under 500 lines.
code=0
long="$(git diff --name-only --diff-filter=A 6fd61df -- csharp java/src swift/Sources swift/Tests csharp/tests | xargs wc -l 2>/dev/null | awk '$2 != "total" && $1 > 500 { print $2 " " $1 }')"
[ -z "$long" ] || code=1
step 8 "no new source or test file over 500 lines" "$code" "$long"

echo "smoke71: $fails failed"
[ "$fails" -eq 0 ]
