# Expected results — loop 85

| Input | Expected |
|-------|----------|
| `test.yml` copy, `scaffold` job env `RING_PYTHON: "3.12"` | `ring-wiring-check.py` exit 1, one line naming `scaffold` and `RING_PYTHON` (HEAD: exit 0) |
| real `test.yml` + `docker-compose.test.yml` | exit 0, no output (as HEAD) |
| `RING_FRAME_SHOWN=abc`, `0`, `-1`, `1.5`, `1000001`, empty | `ring_frame.py check` exit 2, one line naming `RING_FRAME_SHOWN` and `1 to 1000000`, no `Traceback` (HEAD: `abc` gives ValueError, exit 1) |
| `RING_FRAME_SHOWN` unset / `1000` | shown lines 5 / 1000; default `ring-frame.sh`: 64 pairs, 0 mismatched |
