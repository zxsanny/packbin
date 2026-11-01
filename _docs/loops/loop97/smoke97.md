# Loop 97 smoke — proposed checks

LOCAL_URL: none (library; no UI, no local deploy script)
Branch: dev, HEAD e648c61 (7 commits ahead of origin/dev, not pushed)

## Perform these checks (about 5 minutes; the ring check needs all toolchains and takes about 4 more)

- [ ] **1. The idea, in numbers (AC-1, S1).** From the repo root run the Python lines below. Expected: 4 clear bytes; 25 % adds 1 parity byte, 50 % adds 2, 100 % adds 4; a fixed count of 4 still adds 4 (unchanged from 0.4.0).

  ```bash
  cd python && PYTHONPATH=src python3 - <<'PY'
  from dataclasses import dataclass
  from packbin import BinaryPacker, Scheme, u8, u16

  @dataclass
  class Reading:
      level: int = 0
      tail: int = 0

  base = Scheme(2, Reading, u16(0, lambda r: r.level), u8(1, lambda r: r.tail))
  row = Reading(level=500, tail=7)
  for p in (0, 25, 50, 100):
      data = BinaryPacker.pack(base.with_limits(parity_percent=p), row)
      print(p, "percent ->", len(data), "bytes,", len(data) - 4, "parity")
  print("count 4 ->", len(BinaryPacker.pack(base.with_limits(parity=4), row)), "bytes")
  PY
  ```

- [ ] **2. The reference agrees with its vectors (AC-15).** `bash fixtures/ecc/check-vectors.sh` prints `... vectors.txt: 1328 rows, 0 errors` and `... percent-vectors.txt: 1032 rows, 0 errors`.
- [ ] **3. All eight languages agree on the wire (AC-16).** With a Python 3.10 or newer first on `PATH`: `bash .github/workflows/ring-ecc.sh`. Expected last line: `ring-ecc: 64 pairs, 52800 rows, mismatched rows: 0`.
- [ ] **4. The README tells it right (AC-14).** Open `README.md`, section "Error correction", sub-section "A percentage instead of a count": the rule, the 251/230/222 limits, the one-setting-per-call rule and one line per package.
- [ ] **5. Old schemes are untouched (AC-11).** `git diff cb49455~1 HEAD --stat -- fixtures/ecc/vectors.txt` prints nothing.
- [ ] **6. The Rust error change you chose (AC-19).** `grep -n -A6 "MixedParity {" rust/src/value.rs` shows `first_percent` and `other_percent`.

## Notes

- Not run by me, for your information: the CI publish gate and the ESP stage (they run on the push), and the percentage on a Cortex-M33F device or QEMU image (the images prove size and stack only).
- Root-owned folders `cpp/build/embedded/rust-m33f` and `rust-mutants` (left by the Rust embedded container) make the host `make -C cpp clean` fail; they need a root shell to remove.

## Result

PASS (owner, 2026-11-01). All six checks passed.
