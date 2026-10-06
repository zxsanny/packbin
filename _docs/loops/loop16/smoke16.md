# Loop 16 smoke — proposed checks

LOCAL_URL: none (the packages have no site; the local run is the cross-language ring, the headline behaviors of this loop in Python, TypeScript, Rust and Java, and the shared hostile cases)
Branch: dev (no worktree, owner decision as loops 11 to 15)

## Run this one script from the repo root (packbin)

It prints `[n/N] title`, `PASS (Ns)` or `FAIL` with the last log lines, and ends with `N/M steps passed`. Nothing is uploaded, no credential is read, no registry is touched. It needs Docker (the ring builds C++ in a `gcc:16` container), node 22 or newer, the Python venv `/tmp/packbin-pytest`, cargo and a JDK, about 6 minutes. A step that cannot run for a missing tool prints `NOT RUN` and counts as FAIL, never as a pass.

```bash
bash <<'SMOKE'
# Loop 16 smoke: the language-pair ring and the headline behaviors of the loop. No registry write, no credential read.
cd "$(git rev-parse --show-toplevel)" || exit 1
export PACKBIN_CXX_SYSROOT="$(xcrun --show-sdk-path 2>/dev/null || true)"
PY=/tmp/packbin-pytest/bin/python
[ -x "$PY" ] || PY=python3
N=7; pass=0; n=0
step() { n=$((n+1)); title="$1"; shift; start=$(date +%s); echo "[$n/$N] $title"
  out="$("$@" 2>&1 </dev/null)"; code=$?; el=$(( $(date +%s) - start ))
  if [ "$code" -eq 0 ]; then pass=$((pass+1)); echo "  PASS (${el}s) $(printf '%s\n' "$out" | tail -n 1 | cut -c1-110)"
  else echo "  FAIL (${el}s, exit $code)"; printf '%s\n' "$out" | tail -n 8 | cut -c1-160; fi; }

check_ring() { o="$(bash .github/workflows/language-pair.sh 2>&1)"; c=$?; printf '%s\n' "$o" | tail -n 3
  [ "$c" -eq 0 ] && printf '%s' "$o" | grep -qx "language pairs passed" && echo "ring: every pair, the golden bytes and the three element rings (listgroup, dictgroup, listflags) passed"; }

check_python() { PYTHONPATH=python/src "$PY" -c '
from packbin import *
from packbin import PackSession
assert PackSession.load(32) is None, "load(32) must return None"
s = PackSession.load(bytes(32)); assert s is not None
assert s.start(16) is None, "start(16) must return None"
assert PackSession.load(bytes(32)).join(16) is False
k = lambda n: (lambda r: r[n])
try:
    Scheme(1, dict, u8(0, k("x")), u8(1, k("x")))
except ValueError as e:
    assert "declared twice" in str(e), str(e)
else:
    raise AssertionError("a name declared twice was not refused")
sch = Scheme(1, dict, u8(0, k("c")), times(1, 0, flags(1, u8(1, k("v")))))
out = BinaryPacker.pack(sch, {"c": 2, "v": [5]}).hex()
assert out == "0102010500", out
print("python: seeds and nonces strict, duplicate name refused, short times list packs", out)
'; }
check_ts() { node --experimental-strip-types --no-warnings --input-type=module -e '
import { PackSession } from "./typescript/src/index.ts";
if (PackSession.load("a".repeat(32)) !== null) throw new Error("load(string) must be null");
if (PackSession.load(null) !== null) throw new Error("load(null) must be null");
if (PackSession.load(new Uint8Array(32)) === null) throw new Error("a 32-byte Uint8Array must open");
console.log("typescript: PackSession.load takes only a 32-byte Uint8Array");
'; }
check_rust() { o="$(cargo test --manifest-path rust/Cargo.toml --lib -- duplicate_names when_written when_names times_longer 2>&1)"; c=$?; printf '%s\n' "$o" | grep -E '^test result' | head -3
  [ "$c" -eq 0 ] && echo "rust: duplicate names, when from written values, longer times list"; }
check_java() { o="$(bash java/test.sh 2>&1)"; c=$?; printf '%s\n' "$o" | tail -n 4
  [ "$c" -eq 0 ] && echo "java: all checks pass, api-check, duplicate names"; }

step "language-pair ring (all pairs, golden bytes, element rings)" check_ring
step "Python: strict seeds and nonces, duplicate name, short times list" check_python
step "TypeScript: PackSession.load takes only a Uint8Array" check_ts
step "Rust: duplicate names, when from written values, longer times list" check_rust
step "Java: suite, api-check, duplicate names" check_java
step "hostile cases (19, with the two limit cases)" bash fixtures/hostile/cases.test.sh
step "scaffold: report row, ring wiring, embedded lib checks" bash -c 'bash .github/workflows/report-row.test.sh && bash fixtures/hostile/check-cases.sh && bash cpp/embedded/lib.test.sh && bash .github/workflows/ring-wiring.test.sh && bash .github/workflows/publish-position.test.sh'
echo "$pass/$N steps passed"
SMOKE
```

## What each step proves

- [ ] 1. Every language pair reads the bytes the other packs, the golden position row is identical in six languages, and the new rings for a list of group, a dict of group and a list of flags pass in TypeScript, Python and Java, each refusing the cut-short packets (AZ-2239, AZ-2238).
- [ ] 2. Python: `PackSession.load`, `start` and `join` refuse anything that is not bytes-like of the right size without raising (AZ-2231, AZ-2244); a member name declared twice is refused when the scheme is built (AZ-2245); a short `times` list for an optional member packs (AZ-2248).
- [ ] 3. TypeScript: `PackSession.load` returns `null` for a string or `null` and opens for a 32-byte `Uint8Array` (AZ-2243).
- [ ] 4. Rust: the duplicate-name refusal, `when` decided from the values pack wrote, and the longer-list refusal (AZ-2247, AZ-2237).
- [ ] 5. Java: the whole suite, the Android API 26 check, the duplicate-name rule and the loud pack for nulls (AZ-2246, AZ-2234).
- [ ] 6. The 19 hostile cases still pass in the file format check.
- [ ] 7. The scaffold checks pass: report row, hostile case checker, the embedded `find | head` scan, the ring wiring and the symlinked-temp position gate (AZ-2238).

## Not proven here

Only the first CI run on the Ubuntu runner proves: the `ring` job (node 24, JDK 26, Python 3.14, the gcc 16 wrapper), `npm ci --prefix` through a symlinked temp path on Linux, `mawk` as the awk of the scan, the vcpkg `x64-linux` dry-run and the second consumer, the Windows refusal of the port, `GITHUB_ACTIONS=true` turning a missing tool into a failure. The full publish gate (6 minutes) and the Docker suites are the step 11 run (`_docs/03_implementation/test_run_loop16_report.md`).

## Agent walk

No browser surface. The agent trial-ran the script on 2026-10-07: 7/7 (the first trial found two mistakes in the script itself, a wrong Python call and a Rust test filter, both fixed).
