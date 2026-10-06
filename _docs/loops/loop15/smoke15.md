# Loop 15 smoke — proposed checks

LOCAL_URL: none (the publish pipeline and the unpack limits have no site; the local run is the dry run, the four package suites and the gate tests)
Branch: dev (no worktree, owner decision as loops 11 to 14)

## Run this one script from the repo root (packbin)

It prints `[n/N] title`, `PASS (Ns)` or `FAIL` with the last log lines, and ends with `N/M steps passed`. Nothing is uploaded and no credential is read. It needs Docker and about 7.5 minutes (the last step is the 6 minute gate test). It trial-ran 8/8 on 2026-10-06 against commit 049d27c.

```bash
bash <<'SMOKE'
# Loop 15 smoke: publish pipeline (read-only containers, pins) and the unpack round limits. No registry write, no credential read.
cd "$(git rev-parse --show-toplevel)" || exit 1
CREDS="NUGET_TOKEN NPM_TOKEN PYPI_TOKEN CARGO_REGISTRY_TOKEN MAVEN_CENTRAL_TOKEN MAVEN_GPG_PRIVATE_KEY PLATFORMIO_AUTH_TOKEN IDF_COMPONENT_API_TOKEN GITHUB_TOKEN ACTIONS_ID_TOKEN_REQUEST_URL ACTIONS_ID_TOKEN_REQUEST_TOKEN"
UNSET=(); for v in $CREDS; do UNSET+=(-u "$v"); done
W=.github/workflows
N=8; pass=0; n=0
step() { n=$((n+1)); title="$1"; shift; start=$(date +%s); echo "[$n/$N] $title"
  out="$("$@" 2>&1 </dev/null)"; code=$?; el=$(( $(date +%s) - start ))
  if [ "$code" -eq 0 ]; then pass=$((pass+1)); echo "  PASS (${el}s) $(printf '%s\n' "$out" | tail -n 1 | cut -c1-110)"
  else echo "  FAIL (${el}s, exit $code)"; printf '%s\n' "$out" | tail -n 8 | cut -c1-160; fi; }

check_gate() { bash $W/publish-gate.sh | tee /dev/stderr | grep -qx "mismatch 0" && [ "$(wc -l < $W/out/publish-plan.txt | tr -d ' ')" = 6 ] && echo "gate through the read-only containers: mismatch 0, plan of 6 languages"; }
check_preflight() { o="$(env -i PATH="$PATH" HOME="$HOME" PACKBIN_PUBLISH=1 PACKBIN_VERSION=v0.2.2 bash $W/publish-registries.sh 2>&1)"; c=$?; printf '%s\n' "$o"
  [ "$c" -eq 1 ] && printf '%s' "$o" | grep -q "NUGET_TOKEN" && printf '%s' "$o" | grep -q "nothing was built or written" && echo "preflight: refused before any build, all missing credentials named"; }
check_dryrun() { printf 'csharp\ntypescript\npython\nrust\ncpp\n' > /tmp/loop15-plan5.txt; before="$(git status --porcelain)"
  env "${UNSET[@]}" PACKBIN_PUBLISH=1 PACKBIN_BUILD_ONLY=1 PACKBIN_PLAN=/tmp/loop15-plan5.txt PACKBIN_VERSION=v0.2.2 bash $W/publish-registries.sh | tail -n 3
  [ "$(grep -c '^build ok ' $W/out/artifacts/build.log)" = 8 ] && [ -e $W/out/artifacts/dry-run ] && [ "$before" = "$(git status --porcelain)" ] && echo "dry run: 8 targets built and checked in read-only containers, the tree did not change, nothing uploaded"; }
check_refuse() { o="$(PACKBIN_OUT="$PWD/$W/out" bash $W/publish-upload.sh csharp 2>&1)"; c=$?; printf '%s\n' "$o"
  [ "$c" -eq 1 ] && printf '%s' "$o" | grep -q "build-only run; refusing to upload" && echo "upload: refuses dry-run artifacts"; }
check_limits() { for lang in csharp typescript java rust; do docker compose -f docker-compose.test.yml run --rm $lang > /tmp/loop15-$lang.log 2>&1 </dev/null || { tail -n 8 /tmp/loop15-$lang.log; return 1; }; done
  echo "round limits: csharp, typescript, java and rust suites green"; }
check_pins() { n5=$(grep -hE '^\s*-?\s*uses:' $W/*.yml | grep -v './.github/workflows/' | grep -cE '@[0-9a-f]{40}( |$)'); t=$(grep -hE '^\s*-?\s*uses:' $W/*.yml | grep -vc './.github/workflows/')
  [ "$n5" = "$t" ] && [ "$t" -ge 5 ] && bash $W/tool-pin.sh twine >/dev/null && echo "pins: all $t non-local uses are 40-hex commits, the pins file reads"; }

step "position gate through the read-only containers (publish-gate.sh)" check_gate
step "credential preflight: a real publish with no credentials stops before any build" check_preflight
step "build-only dry run in read-only containers: the tree does not change" check_dryrun
step "upload phase refuses the dry-run artifacts" check_refuse
step "round limits: C#, TypeScript, Java and Rust suites" check_limits
step "hostile cases (19, with the two limit cases)" bash fixtures/hostile/cases.test.sh
step "every non-local uses is a commit SHA; the pins file reads" check_pins
step "publish gate tests (two-phase, pins, read-only mount, workflow structure)" bash $W/publish-gate.test.sh
echo "$pass/$N steps passed"
SMOKE
```

## What each step proves

- [ ] 1. The golden position gate runs through the read-only containers and still gives mismatch 0 for six languages (AZ-2215).
- [ ] 2. A real publish with no credentials stops before any build and names every missing credential (AZ-2097, kept).
- [ ] 3. A build-only dry run builds eight targets in read-only containers, checks them, leaves the tree unchanged and uploads nothing (AZ-2215, AZ-2096).
- [ ] 4. The upload phase refuses the dry-run artifacts (AZ-2096).
- [ ] 5. The C#, TypeScript, Java and Rust suites pass, including the round-limit tests (AZ-2216 to AZ-2219).
- [ ] 6. The 19 hostile cases pass, including the two limit cases (AZ-2220).
- [ ] 7. Every non-local `uses:` is a 40-hex commit and the pins file reads (AZ-2214).
- [ ] 8. The publish gate tests: two-phase publish, pins, read-only mount, symlink refusal, workflow structure.

## Not proven here

Only the first CI run on the Ubuntu runner proves: Compose 2.38.2 merging `docker-compose.publish.yml`, the `/out` bind mount and file ownership (AZ-2215), the pinned actions and pip tools (AZ-2214), and the Linux ownership assertion. Only a real `v*` tag proves the registry-side checks (Central `published`, the crates.io token lifetime). This Mac has no `gpg`, so the Java dry run is covered by the gate tests (a shim).

## Agent walk

No browser surface. The agent ran the script above on 2026-10-06: 8/8.
