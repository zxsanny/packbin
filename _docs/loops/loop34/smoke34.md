# Loop 34 smoke — checks

LOCAL_URL: none (CI and test tooling, no UI; the proof is the CI runs and the step 11 log)
Branch: dev

## Checks

- [x] 1. No application source is dirty at the close (only `_docs/` files, the close commit)
- [x] 2. CI run A (the first push after the priming run): every job `success`, wall at most 225 s (AC-1; the median with the close push is recorded after it)
- [x] 3. At most 20 jobs, each started within 15 s of the first (AC-2)
- [x] 4. The three Swift suite parts: cache `hit` in their notices (AC-3; the ccache clause is withdrawn with ccache)
- [x] 5. The ring: `ring-swift: cache hit` in its notice (AC-3)
- [x] 6. Each Swift build under its loop 33 best: `tests` debug build < 48 s, `gates` sanitizer build < 85 s, `speed` step < 131 s, ring `swift-drivers` < 84 s (AC-4)
- [x] 7. The current (`swift-v2-`) cache entries total at most 3 GB, and the measured run saved none (AC-7)
- [x] 8. Step 11 report: PASS
- [x] 9. Every changed script and workflow is at most 500 lines (AC-11)
- [x] 10. No tag contains a loop 34 commit, and `origin/main` does not contain the loop (no push of `main`)

## Result

Agent run 2026-10-17 at `7cb51ca` on run 39044659167 (run D, the first run of the final code after priming run 2; owner rule 2026-10-12 in `deployment_procedures.md`): **10/10 steps passed**. Smoke: PASS. Earlier runs of the script: run A (`c870aa7`, batch 1 with ccache) 7/10 before the ccache question, the three failures being two script defects (step 2's f-string, steps 4 and 5 read a ccache rate that was 0 of 0 because no C file compiled); run B (`bb21e07`) 8/10, wall 226 s and the builds slow because of the stale `v1` entries (batch 3).

## For the operator

- AC-1 is the median of two runs of the final code: run D is 217 s; the close push is the second (recorded after it in `notes34.md`).
- `main` was not pushed, no tag (the spec's constraint; `loop_end_merge: main` is not executed this loop, as in loop 33).
- The 8 stale `swift-v1-...` cache entries expire unused; nothing to do.
- `ubuntu-latest` moves to Ubuntu 26 from 2026-10-19.

## Script (run with the CI run id: `bash smoke34.sh <run id>`)

```bash
#!/usr/bin/env bash
# Loop 34 smoke (AZ-2627): smoke34.sh <run id>. One line per step: [n/N] title, then PASS (Ns) <result> or FAIL with
# the reason. Reads the CI run from the public GitHub API (no token; 8 calls), the rest from the tree.
set -uo pipefail
run="${1:?run id}"
repo=/Users/zxsanny/dev/zxsanny/packbin
api=https://api.github.com/repos/zxsanny/packbin
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$repo" || exit 1
N=10 n=0 passed=0

step() { n=$((n + 1)); printf '[%d/%d] %s\n' "$n" "$N" "$1"; t0=$(date +%s); }
ok() { passed=$((passed + 1)); printf '  PASS (%ss) %s\n' "$(( $(date +%s) - t0 ))" "$1"; }
ko() { printf '  FAIL %s\n' "$1"; }
verdict() { case "$1" in OK*) ok "${1#OK }" ;; *) ko "$1" ;; esac; }

curl -sS -m 30 "$api/actions/runs/$run" -o "$work/run.json" < /dev/null
curl -sS -m 30 "$api/actions/runs/$run/jobs?per_page=50" -o "$work/jobs.json" < /dev/null
curl -sS -m 30 "$api/actions/caches?per_page=50" -o "$work/caches.json" < /dev/null
for name in "suites (swift, tests)" "suites (swift, gates)" "suites (swift, speed)" ring; do
  id="$(python3 -I -c 'import json,sys; print(next(j["id"] for j in json.load(open(sys.argv[1]))["jobs"] if j["name"]==sys.argv[2]))' "$work/jobs.json" "$name")"
  curl -sS -m 30 "$api/check-runs/$id/annotations?per_page=100" -o "$work/ann-$(printf '%s' "$name" | tr -c 'a-z' '-').json" < /dev/null
done
py() { python3 -I - "$work" "$@" < /dev/stdin; }

step "No application source is dirty (only _docs/ may be)"
dirty="$(git status --porcelain | grep -v ' _docs/' || true)"
if [ -z "$dirty" ]; then ok "tree clean outside _docs/ at $(git rev-parse --short HEAD)"; else ko "$dirty"; fi

step "CI run $run: every job success, wall at most 225 s"
verdict "$(py <<'PY'
import json, sys, datetime as d
w = sys.argv[1]
run = json.load(open(w + "/run.json")); jobs = json.load(open(w + "/jobs.json"))["jobs"]
t = lambda s: d.datetime.fromisoformat(s.replace("Z", "+00:00"))
bad = [j["name"] for j in jobs if j["conclusion"] != "success"]
wall = (max(t(j["completed_at"]) for j in jobs) - t(run["created_at"])).total_seconds()
top = sorted(((t(j["completed_at"]) - t(j["started_at"])).total_seconds(), j["name"]) for j in jobs)[::-1][:4]
longest = ", ".join("%s %.0f" % (name, secs) for secs, name in top)
print(("OK" if run["conclusion"] == "success" and not bad and wall <= 225 else "BAD"),
      "%d jobs, wall %.0f s, head %s, longest %s, not green: %s" % (len(jobs), wall, run["head_sha"][:7], longest, bad))
PY
)"

step "At most 20 jobs, each started within 15 s of the first"
verdict "$(py <<'PY'
import json, sys, datetime as d
jobs = json.load(open(sys.argv[1] + "/jobs.json"))["jobs"]
t = lambda s: d.datetime.fromisoformat(s.replace("Z", "+00:00"))
t0 = min(t(j["started_at"]) for j in jobs)
late = {j["name"]: (t(j["started_at"]) - t0).total_seconds() for j in jobs if (t(j["started_at"]) - t0).total_seconds() > 15}
print(("OK" if len(jobs) <= 20 and not late else "BAD"), f"{len(jobs)} jobs, latest start +{max((t(j['started_at']) - t0).total_seconds() for j in jobs):.0f} s, late: {late}")
PY
)"

# The cache state a notice reports: "run-suite: swift cache <state>" or "ring-swift: cache <state>", else none.
cache_of() { python3 -I -c '
import json, re, sys
msg = " ".join(a["message"] for a in json.load(open(sys.argv[1])) if a.get("annotation_level") == "notice")
m = re.search(r"(?:run-suite: swift cache|ring-swift: cache) (\w+)", msg)
print(m.group(1) if m else "none")' "$1"; }

step "Swift suite parts: cache hit"
res="" good=1
for part in tests gates speed; do
  state="$(cache_of "$work/ann-suites--swift--$part-.json")"
  res="$res $part: $state;"
  [ "$state" = hit ] || good=0
done
if [ "$good" = 1 ]; then ok "$res"; else ko "$res"; fi

step "ring: cache hit"
state="$(cache_of "$work/ann-ring.json")"
if [ "$state" = hit ]; then ok "ring: $state"; else ko "ring: $state"; fi

step "Swift builds under the loop 33 best (tests 48, gates 85, speed 131, ring drivers 84 s)"
verdict "$(py <<'PY'
import json, re, sys
w = sys.argv[1]
msg = lambda f: " ".join(a["message"] for a in json.load(open(f"{w}/{f}")) if a.get("annotation_level") == "notice")
got = {
  "tests": re.search(r"(\d+) s: swift build --build-tests\n", msg("ann-suites--swift--tests-.json") + "\n"),
  "gates": re.search(r"(\d+) s: swift build --build-tests --sanitize=thread", msg("ann-suites--swift--gates-.json")),
  "speed": re.search(r"(\d+) s: swift_speed", msg("ann-suites--swift--speed-.json")),
  "ring": re.search(r"swift-drivers took (\d+) s", msg("ann-ring.json")),
}
bound = {"tests": 48, "gates": 85, "speed": 131, "ring": 84}
s = {k: int(m.group(1)) if m else None for k, m in got.items()}
okk = all(v is not None and v < bound[k] for k, v in s.items())
print(("OK" if okk else "BAD"), "; ".join(f"{k} {v} s (< {bound[k]})" for k, v in s.items()))
PY
)"

step "Swift cache entries at most 3 GB, none saved by this run"
verdict "$(py <<'PY'
import json, sys, datetime as d
w = sys.argv[1]
run = json.load(open(w + "/run.json")); caches = json.load(open(w + "/caches.json"))["actions_caches"]
t = lambda s: d.datetime.fromisoformat(s.replace("Z", "+00:00"))
sw = [c for c in caches if c["key"].startswith("swift-v2-") and c["ref"] == "refs/heads/dev"]  # the current key prefix; older entries expire unused
total = sum(c["size_in_bytes"] for c in sw) / 1e6
new = [c["key"][:22] for c in sw if t(c["created_at"]) >= t(run["created_at"])]
print(("OK" if len(sw) == 4 and total <= 3000 and not new else "BAD"), f"{len(sw)} entries, {total:.0f} MB, saved by this run: {new}")
PY
)"

step "Step 11 report: PASS"
if grep -q '^Verdict: PASS' _docs/03_implementation/test_run_loop34_report.md; then ok "$(sed -n 's/^TEST RESULTS: //p' _docs/03_implementation/test_run_loop34_report.md)"; else ko "no PASS verdict"; fi

step "Changed scripts and workflow at most 500 lines"
long="$(git diff --name-only dadd32b..HEAD -- .github scripts | while read -r f; do [ -f "$f" ] && [ "$(wc -l < "$f")" -gt 500 ] && echo "$f"; done)"
max="$(git diff --name-only dadd32b..HEAD -- .github scripts | while read -r f; do [ -f "$f" ] && wc -l < "$f"; done | sort -n | tail -n 1)"
if [ -z "$long" ]; then ok "largest $max lines"; else ko "$long"; fi

step "No tag and no origin/main contains a loop 34 commit"
tags="$(git tag --contains 18b9c76 2>&1)"
if [ -z "$tags" ] && ! git merge-base --is-ancestor 18b9c76 origin/main; then ok "no tag, origin/main $(git rev-parse --short origin/main)"; else ko "tags: $tags"; fi

echo "$passed/$N steps passed"
[ "$passed" -eq "$N" ]
```

## Output (run D)

```
[1/10] No application source is dirty (only _docs/ may be)
  PASS (0s) tree clean outside _docs/ at 7cb51ca
[2/10] CI run 39044659167: every job success, wall at most 225 s
  PASS (0s) 20 jobs, wall 217 s, head 7cb51ca, longest publish-gate-readonly 214, embedded-esp-core 200, publish-gate-readonly-gate-good 188, publish-gate-readonly-gate-bad 184, not green: []
[3/10] At most 20 jobs, each started within 15 s of the first
  PASS (0s) 20 jobs, latest start +1 s, late: {}
[4/10] Swift suite parts: cache hit
  PASS (0s)  tests: hit; gates: hit; speed: hit;
[5/10] ring: cache hit
  PASS (1s) ring: hit
[6/10] Swift builds under the loop 33 best (tests 48, gates 85, speed 131, ring drivers 84 s)
  PASS (0s) tests 19 s (< 48); gates 27 s (< 85); speed 101 s (< 131); ring 26 s (< 84)
[7/10] Swift cache entries at most 3 GB, none saved by this run
  PASS (0s) 4 entries, 398 MB, saved by this run: []
[8/10] Step 11 report: PASS
  PASS (0s) 11 stages passed, 0 failed at the end (scaffold failed once in the pool and passed on the serial retry after a fix; see below)
[9/10] Changed scripts and workflow at most 500 lines
  PASS (0s) largest      500 lines
[10/10] No tag and no origin/main contains a loop 34 commit
  PASS (0s) no tag, origin/main 2cade74
10/10 steps passed
```
