# Loop 14 smoke — proposed checks

LOCAL_URL: none (the publish pipeline has no site; the local run is the dry run and the gate tests)
Branch: dev (no worktree, owner decision as loops 11 to 13)

## Run this one script from the repo root (packbin)

It prints `[n/N] title`, `PASS (Ns)` or `FAIL` with the last log lines, and ends with `N/M steps passed`. Nothing is uploaded and no credential is read. It needs Docker and about 5 minutes (the last step is the 4 minute gate test). It trial-ran 7/7 on 2026-10-06 against commit 3a6b5f2.

```bash
bash <<'SMOKE'
# Loop 14 smoke: publish pipeline, no registry write anywhere. Run from the repo root (packbin).
cd "$(git rev-parse --show-toplevel)" || exit 1
CREDS="NUGET_TOKEN NPM_TOKEN PYPI_TOKEN CARGO_REGISTRY_TOKEN MAVEN_CENTRAL_TOKEN MAVEN_GPG_PRIVATE_KEY PLATFORMIO_AUTH_TOKEN IDF_COMPONENT_API_TOKEN GITHUB_TOKEN ACTIONS_ID_TOKEN_REQUEST_URL ACTIONS_ID_TOKEN_REQUEST_TOKEN"
UNSET=(); for v in $CREDS; do UNSET+=(-u "$v"); done
W=.github/workflows
N=7; pass=0; n=0
step() { n=$((n+1)); title="$1"; shift; start=$(date +%s); echo "[$n/$N] $title"
  out="$("$@" 2>&1 </dev/null)"; code=$?; el=$(( $(date +%s) - start ))
  if [ "$code" -eq 0 ]; then pass=$((pass+1)); echo "  PASS (${el}s) $(printf '%s\n' "$out" | tail -n 1 | cut -c1-110)"
  else echo "  FAIL (${el}s, exit $code)"; printf '%s\n' "$out" | tail -n 8 | cut -c1-160; fi; }

check_gate() { bash $W/publish-gate.sh | tee /dev/stderr | grep -qx "mismatch 0" && [ "$(wc -l < $W/out/publish-plan.txt | tr -d ' ')" = 6 ] && echo "gate: mismatch 0, plan of 6 languages"; }
check_preflight() { o="$(env -i PATH="$PATH" HOME="$HOME" PACKBIN_PUBLISH=1 PACKBIN_VERSION=v0.2.2 bash $W/publish-registries.sh 2>&1)"; c=$?; printf '%s\n' "$o"
  [ "$c" -eq 1 ] && printf '%s' "$o" | grep -q "NUGET_TOKEN" && printf '%s' "$o" | grep -q "nothing was built or written" && echo "preflight: refused before any build, all missing credentials named"; }
check_dryrun() { printf 'csharp\ntypescript\npython\nrust\ncpp\n' > /tmp/loop14-plan5.txt
  env "${UNSET[@]}" PACKBIN_PUBLISH=1 PACKBIN_BUILD_ONLY=1 PACKBIN_PLAN=/tmp/loop14-plan5.txt PACKBIN_VERSION=v0.2.2 bash $W/publish-registries.sh | tee /tmp/loop14-dryrun.log | tail -n 3
  [ "$(grep -c '^build ok ' $W/out/artifacts/build.log)" = 8 ] && [ -e $W/out/artifacts/dry-run ] && echo "dry run: 8 targets built and checked (no Java: no gpg on this Mac), dry-run marker written, nothing uploaded"; }
check_javadry() { printf 'java\n' > /tmp/loop14-plan-java.txt
  if command -v gpg >/dev/null; then echo "gpg present: the Java dry run is covered by the gate tests"; return 0; fi
  o="$(env "${UNSET[@]}" PACKBIN_PUBLISH=1 PACKBIN_BUILD_ONLY=1 PACKBIN_PLAN=/tmp/loop14-plan-java.txt PACKBIN_VERSION=v0.2.2 bash $W/publish-registries.sh 2>&1)"; c=$?; printf '%s\n' "$o"
  [ "$c" -eq 1 ] && printf '%s' "$o" | grep -q "gpg is required" && echo "java dry run without gpg: stops before any build and names gpg"; }
check_refuse() { o="$(PACKBIN_OUT="$PWD/$W/out" bash $W/publish-upload.sh csharp 2>&1)"; c=$?; printf '%s\n' "$o"
  [ "$c" -eq 1 ] && printf '%s' "$o" | grep -q "build-only run; refusing to upload" && echo "upload: refuses dry-run artifacts"; }

step "position gate: every present package packs the golden bytes (publish-gate.sh)" check_gate
step "credential preflight: a real publish with no credentials stops before any build" check_preflight
step "build-only dry run: the 8 non-Java targets build and are checked with every credential unset" check_dryrun
step "upload phase refuses the dry-run artifacts" check_refuse
step "Java dry run without gpg stops early and names gpg" check_javadry
step "Java suite with the Android API 26 check" docker compose -f docker-compose.test.yml run --rm java
step "publish gate tests (two-phase, credential matrix, re-run, workflow structure)" bash $W/publish-gate.test.sh
SMOKE
```

## What each step proves

- [ ] 1. Position gate: every present package still packs the golden bytes; the plan has six languages.
- [ ] 2. Credential preflight (AZ-2097 AC-1): a real publish with no credentials stops before any build and names every missing credential.
- [ ] 3. Build-only dry run (AZ-2096 AC-3): the eight non-Java targets are built and checked with every credential unset, nothing is uploaded.
- [ ] 4. The upload phase refuses the dry-run artifacts (AZ-2096).
- [ ] 5. Java without `gpg` stops early and names it (the fix made at smoke time); with `gpg` on the host this step defers to the gate tests.
- [ ] 6. Java suite with the Android API 26 check (AZ-2094).
- [ ] 7. The publish gate tests: two-phase publish, credential matrix, re-run, workflow structure (AZ-2095 to AZ-2097).

## Not proven here

Only a real `v*` tag proves GitHub's own behavior (the `workflow_call`, `needs` and branch-only `push` filter), Central's `published` answer, the crates.io token lifetime and the cold build time. The owner confirms the tag (plan13 `## Release`).

## Agent walk

No browser surface. The agent ran the script above on 2026-10-06: first run 4/6 (the dry run needed `gpg`, and the upload refusal depended on a marker written too late); both fixed in `3a6b5f2`, second run 7/7.
