#!/usr/bin/env bash
# Loop 72 smoke: one script, per-step PASS / FAIL. Run from the repository root:
#   bash _docs/loops/loop72/smoke72.sh
# Needs dotnet, a JDK, the Xcode Swift toolchain and python3; about 6 minutes on a quiet host (check `uptime` first).
set -uo pipefail
root="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$root" || exit 2
claim=dc98688
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

# 2. AZ-3254: the C# frame, primitive and session tests on both targets.
code=0
for target in net10.0 netstandard2.0; do
  extra=""
  [ "$target" = netstandard2.0 ] && extra="-p:PackbinTarget=netstandard2.0"
  limit 900 env MSBUILDDISABLENODEREUSE=1 dotnet test csharp --nologo $extra --filter "FullyQualifiedName~Frame|FullyQualifiedName~CryptoVector|FullyQualifiedName~Session" > "$work/cs-$target.log" 2>&1 < /dev/null || code=1
  grep -qE 'Passed!.*Failed: +0' "$work/cs-$target.log" || code=1
done
step 2 "C# frame, primitive and session tests pass on net10.0 and netstandard2.0" "$code" "$(grep -hE 'Passed!|Failed!' "$work"/cs-*.log | tr '\n' ' ' | cut -c1-240)"

# 3. AZ-3254 AC-1: the C# tests still build and pass in Release (stage ac10).
code=0
limit 900 env MSBUILDDISABLENODEREUSE=1 dotnet test csharp -c Release --nologo --filter "FullyQualifiedName~Nfr_PublicTyped" > "$work/ac10.log" 2>&1 < /dev/null || code=1
grep -qE 'Passed!.*Failed: +0' "$work/ac10.log" || code=1
step 3 "C# Release test build (ac10) passes" "$code" "$(grep -hE 'Passed!|Failed!|error' "$work/ac10.log" | head -n 2 | tr '\n' ' ' | cut -c1-200)"

# 4. AZ-3255: the Java suite, including the Android API 26 check and the frame test classes.
code=0
limit 900 bash java/test.sh > "$work/java.log" 2>&1 < /dev/null || code=1
grep -q 'api-check PASS' "$work/java.log" || code=1
for t in CryptoVectorsTest FrameVectorsTest FrameTamperReplayTest FrameMacRefusalsTest FrameHostileTest FrameLifecycleTest FrameStaticStateTest FrameReadmeExample; do
  grep -q "$t passed" "$work/java.log" || { code=1; echo "$t not passed" >> "$work/java.miss"; }
done
touch "$work/java.miss"
step 4 "Java test.sh: api-check and the frame test classes pass" "$code" "$(tr '\n' ' ' < "$work/java.miss")"

# 5. AZ-3256: the Swift frame, primitive, README and session suites.
code=0
limit 1200 swift test --filter 'Frame|CryptoVector|ChaCha20|ReadmeExample|Session' > "$work/swift.log" 2>&1 < /dev/null || code=1
grep -qE 'Test run with [0-9]+ tests? in [0-9]+ suites? passed' "$work/swift.log" || code=1
step 5 "Swift frame, primitive, README and session suites pass" "$code" "$(grep -E 'Test run with' "$work/swift.log" | tail -n 1 | cut -c1-200)"

# 6. AZ-3254..3256 AC-1 (owner decision B): hooks only through each language's own-tests visibility.
code=0
hits="$(grep -rn -E '_spi|@testable' swift; grep -nE 'public .*\b(KeyArrays|CurrentKeys|MacComputations|KeyArray)\b' csharp/FrameSession.cs csharp/MacKey.cs; grep -rnE '(public|protected) .*ForTest' java/src/main)"
[ -z "$hits" ] || code=1
step 6 "no SPI or @testable in swift/; C# hooks internal; Java hooks package-private" "$code" "$(printf '%s' "$hits" | head -n 3 | tr '\n' ' ' | cut -c1-240)"

# 6b. AZ-3256 AC-1: the one release test build of CI (run-suite.sh swift_speed) passes with no extra flag, and the speed run passes.
code=0
limit 1200 swift build -c release --build-tests -Xswiftc -warnings-as-errors -Xswiftc -strict-concurrency=complete > "$work/swrel.log" 2>&1 < /dev/null || code=1
if [ "$code" -eq 0 ]; then
  limit 600 swift test -c release --skip-build --verbose --filter '\.SpeedTests/' --filter '\.TextSpeedTests/' --filter '\.FuzzTests/mebibyte' > "$work/swspeed.log" 2>&1 < /dev/null || code=1
  grep -qE 'Test run with [0-9]+ tests? in [0-9]+ suites? passed' "$work/swspeed.log" || code=1
fi
step 6b "Swift strict release test build and speed run pass" "$code" "$(grep -hE 'error:|Test run with' "$work"/sw*.log | head -n 2 | tr '\n' ' ' | cut -c1-200)"

# 7. AZ-3255 AC-3: no static mutable field in the Java frame code.
code=0
statics="$(grep -nE '^[[:space:]]*((private|public|protected)[[:space:]]+)?static[[:space:]]' java/src/main/java/packbin/FrameCrypto.java java/src/main/java/packbin/FrameSession.java java/src/main/java/packbin/MacKey.java | grep -v 'final' | grep -vE '\(|[[:space:]](class|interface|enum|record)[[:space:]]')"
[ -z "$statics" ] || code=1
step 7 "Java FrameCrypto, FrameSession, MacKey hold no static mutable field" "$code" "$statics"

# 8. Bytes unchanged: fixtures check against the reference, and rust/ and fixtures/ are untouched since the claim.
code=0
bash fixtures/frame/check-vectors.test.sh > "$work/fv.log" 2>&1 < /dev/null || code=1
bash fixtures/crypto/check-vectors.test.sh > "$work/cv.log" 2>&1 < /dev/null || code=1
git diff --quiet "$claim" -- rust fixtures || code=1
step 8 "fixture checks pass; rust/ and fixtures/ unchanged since $claim" "$code" "$(tail -n 1 "$work/fv.log" | cut -c1-120)"

# 9. The README frame examples still equal their example tests.
code=0
bash scripts/frame/readme-examples.sh > "$work/readme.log" 2>&1 < /dev/null || code=1
[ "$(grep -c '^PASS' "$work/readme.log")" -eq 3 ] || code=1
step 9 "README examples for C#, Java, Swift equal their tests" "$code" "$(tr '\n' ' ' < "$work/readme.log" | cut -c1-200)"

# 10. Files the loop touched stay at or under 500 lines.
code=0
long="$(git diff --name-only "$claim" -- csharp java/src swift/Sources swift/Tests | while IFS= read -r f; do [ -f "$f" ] && wc -l < "$f" | awk -v f="$f" '$1 > 500 { print f " " $1 }'; done)"
[ -z "$long" ] || code=1
step 10 "no touched source or test file over 500 lines" "$code" "$long"

echo "smoke72: $fails failed"
[ "$fails" -eq 0 ]
