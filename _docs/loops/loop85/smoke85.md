# Loop 85 smoke — proposed checks

LOCAL_URL: none (CI scripts only; no local deploy script, no UI)
Branch: dev

## Perform these checks in a shell at the repo root

- [ ] `bash .github/workflows/ring-wiring.test.sh | tail -1` prints `ring wiring checks passed` (AC-2, AC-3)
- [ ] `RING_FRAME_SHOWN=abc python3 scripts/frame/ring_frame.py check x -- y; echo $?` prints one line naming `RING_FRAME_SHOWN` and `1 to 1000000`, then `2`, no Traceback (AC-4)
- [ ] `bash .github/workflows/ring-frame.test.sh | tail -1` prints `ring-frame.test: all passed` (AC-5, AC-6)
- [ ] `python3 .github/workflows/ring-wiring-check.py .github/workflows/test.yml docker-compose.test.yml; echo $?` prints `0` (AC-2)
- [ ] Regression: `bash scripts/ci/yaml_get.test.sh` and `bash scripts/ci/workflow_yaml.test.sh` exit 0

## Notes
Agent run on 2026-10-30: all 25 script steps of the `scaffold` job, run locally, exit 0 (CI-parity for the scaffold job). The real 8-language ring (`scripts/loop-tests.sh --all --only ring`, JDK on PATH, Python 3.14) passed in 53 s: `ring-frame: 64 pairs, mismatched: 0`, refusals 72 rows x 8, 0 mismatched, `ring-ecc` 64 pairs 0 mismatched; run at load 13 from a foreign archangel build. CI of the push not read yet.

Result: PASS (owner, 2026-10-30).
