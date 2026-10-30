# Feature assessment — loop 85

verdict: COMPLETE

| Spec row | Evidence | Status |
|----------|----------|--------|
| AC-1 override rejected | `scaffold` copy with `RING_PYTHON: "3.12"`: exit 1, `job scaffold sets RING_PYTHON in its env, the version lives in the workflow env` (HEAD exit 0) | gap-clear closed |
| AC-2 real files unchanged | real pair exit 0; 43 lines of verdicts at HEAD, 44 now (one new) | met |
| AC-3 mutant added | `ring-wiring.test.sh` passes with the mutant | met |
| AC-4 bad value | `abc`, empty, `0`, `-1`, `1.5`, `1000001`: exit 2, one line, no traceback | met |
| AC-5 good value and default | unset and `1000` paths untouched; `id-padded` green; the real 8-language `ring-frame.sh` was not run (needs the toolchains of the ring job; default code path unchanged) | met (default not run end to end) |
| AC-6 case added | `shown-not-a-number` passes through `ring-frame.sh` (exit 2 propagates) | met |
