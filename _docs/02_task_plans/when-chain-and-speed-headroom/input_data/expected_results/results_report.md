# Expected results — loop 55

## A: `when` chain

Scheme C3 (ids as in the packages' builders): `u8 m; when(m==1){ u8 k1; when(k1==1){ u8 k2; when(k2==1){ u8 k3; when(k3==1){ u8 b } } } }`. Bytes are the Python package's (to be produced by the probe in the task; the C++ result must equal them). Rows: all true (m=1,k1=1,k2=1,k3=1,b=5); m=0; m=1,k1=0; m=1,k1=1,k2=0.

| Check | Expected |
|-------|----------|
| Cortex-M4F deepest pack/unpack stack with C3 in the image | at most 512 B, figure recorded (today 504 B without the chain) |
| Cortex-M4F flash | at most 8,192 B (today 7,952 B) |
| C++ packets for the four rows | byte-equal to the Python packets |

## B: bool source behind a clear `when`

Scheme `u8 mode; when(mode==1){ flags{ bool on }; u8 a }; when(on==true){ u8 b }`. Source of the bytes: Python package on 2026-10-21 (`PYTHONPATH=python/src python3.14`), bytes after the scheme id.

| Row | Packed | Unpacked |
|-----|--------|----------|
| mode 0, on true, a 7, b 5 | `00` | `{mode: 0}` |
| mode 1, on true, a 7, b 5 | `01 01 07 05` | `{mode: 1, on: true, a: 7, b: 5}` |
| mode 1, on false, a 7, b 5 | `01 00 07` | `{mode: 1, a: 7}` |

The group-presence variant's bytes come from the same probe in the task (Python is the reference).

## D: repeated text

| Package | Today (CI run 39548740720) | Bound | Required |
|---------|----------------------------|-------|----------|
| Java | pack 0.029 s, unpack 0.019 s | 1 s | at most 0.5 s |
| Rust | pack 0.040 s, unpack 0.009 s (load 2.60) | 1 s | at most 0.5 s |
| C++ | pack 0.013 s, unpack 0.013 s | 3 s | at most 1.5 s |
| TypeScript | 268 ms (one test, pack and unpack) | 1 s | at most 0.5 s |
| Python | not printed | 1 s | measured and printed, at most 0.5 s |
| Go | no test of the case | 1 s | new test, at most 0.5 s |
| Swift | lone 65,535-byte text only | 1 s | new 200-round test, at most 0.5 s |
