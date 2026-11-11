#!/usr/bin/env bash
# Loop 110 smoke (release v0.5.1): one paste, PASS/FAIL per step. Run from the repository root.
set -u
fail=0
step() { local name="$1"; shift
  if "$@" > /tmp/smoke110.step.log 2>&1; then echo "PASS  $name"; else echo "FAIL  $name"; sed 's/^/      /' /tmp/smoke110.step.log | head -6; fail=1; fi; }
SHA=9df1db79fae85dc416ecfcf2e437bdd90fe2facf
s1() { curl -sf -m 20 https://registry.npmjs.org/packbin | python3 -c "import json,sys; sys.exit(0 if '0.5.1' in json.load(sys.stdin)['versions'] else 1)"; }
s2() { curl -sf -m 20 https://pypi.org/pypi/packbin/0.5.1/json -o /dev/null; }
s3() { curl -sf -m 20 -H 'User-Agent: packbin-release-check' https://crates.io/api/v1/crates/packbin/0.5.1 -o /dev/null; }
s4() { curl -sf -m 20 https://api.nuget.org/v3-flatcontainer/packbin/index.json | python3 -c "import json,sys; sys.exit(0 if '0.5.1' in json.load(sys.stdin)['versions'] else 1)"; }
s5() { b=https://repo1.maven.org/maven2/io/github/zxsanny/packbin/0.5.1/packbin-0.5.1; curl -sf -m 20 -o /dev/null "$b.pom" && curl -sf -m 20 -o /dev/null "$b.pom.asc"; }
s6() { [ "$(git ls-remote origin 'refs/tags/v0.5.1^{}' | cut -f1)" = "$SHA" ] && [ "$(git ls-remote origin 'refs/tags/go/v0.5.1' | cut -f1)" = "$SHA" ]; }
s7() { git fetch -q origin vcpkg && git log -1 --format=%s origin/vcpkg | grep -q 'version packbin 0.5.1'; }
s8() { [ "$(gh api repos/zxsanny/packbin/releases/latest --jq .tag_name)" = v0.5.1 ]; }
s9() { [ "$(gh run view 43106289000 --json conclusion --jq .conclusion)" = success ] && [ "$(gh run view 43105138008 --json conclusion --jq .conclusion)" = success ]; }
s10() { git show v0.5.1:README.md > /dev/null && git diff --quiet v0.5.1 "$SHA" ; }
step "1 npm packbin 0.5.1" s1
step "2 PyPI packbin 0.5.1" s2
step "3 crates.io packbin 0.5.1" s3
step "4 NuGet Packbin 0.5.1" s4
step "5 Maven Central pom and signature for 0.5.1" s5
step "6 tags v0.5.1 and go/v0.5.1 both at 9df1db7" s6
step "7 vcpkg branch carries 'version packbin 0.5.1'" s7
step "8 GitHub release v0.5.1 is the latest" s8
step "9 tag run 43106289000 and the main run 43105138008 of the tagged commit are success" s9
step "10 the tag points at the tested commit" s10
[ "$fail" -eq 0 ] && echo "SMOKE 110: ALL PASS" || echo "SMOKE 110: FAILED"
exit "$fail"
