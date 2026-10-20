# Implementation report — rust-nostd-core wave B (loop 52)

Tasks: AZ-2754 (compact text and dictionaries, `text` feature), AZ-2755 (message ECC, `ecc` feature). Epic AZ-2750. Three batches in one directory (`rust/src/nostd/**`), one after another; per the owner rule no per-batch review or test run (one total review and one step 11 run at the end of the loop).

| Batch | Task | Commit | Result |
|-------|------|--------|--------|
| 1 | AZ-2754 text | `91716d0` | codec in `nostd/text/` (tables built at compile time, decoder into a bounded sink, encoder in caller scratch), kinds `Utf8`, `Utf8Wire`, `pack_with` |
| 2 | AZ-2754 dicts | `91716d0` | kind `Dict`, key entry `key()`, keys ascending by decoded bytes on pack, compared from the payloads on unpack |
| 3 | AZ-2755 ecc | `eddfd53` | `ecc_core` shared by the std walker and the core, `Scheme::with_parity`, `unpack_repair`, `nostd::ecc` codec |

Focused proof: 850 tests with all features (818 + 2 default before ECC), the text differential (20 layouts x 3,000 random rows, every cut, every bit flip, random bytes), the 427-row text vectors file, the 1,339-row ECC vectors file, the six hostile dictionary packets, the embedded stage (QEMU Cortex-M4F: no heap, no panic path).

Sizes (embedded stage, no limits set for `text`, `ecc`): base 14,532 B flash (was 13,724) and 456 B stack (limit 16,384 and 512); text 24,856 B and 1,328 B; ecc 17,804 B and 760 B. The figures of `text` and `ecc` include the probe's own round trip (rows, scratch of 192 B).

## Discovered during implementation

| # | Scenario or question | Spec ref | Proposed handling | clear / unclear |
|---|----------------------|----------|-------------------|-----------------|
| 1 | The C++ raw memo (AZ-2742: scratch words 0 and 1 remember the last raw string so a repeat of the same long text skips the parse) is not ported; the std Rust walker has none either. Pack input is the caller's own row, so the cost is CPU only | AZ-2754 AC-1 | no memo; measure a repeat of long strings in AZ-2757 | clear |
| 2 | A string kept as on the wire needs its own kind: the spec's "Packed" is a word that the Rust core already uses for bit-packed numbers, so the kind is `Utf8Wire` (`utf8_wire(id)`) | AZ-2754 AC-3 | done | clear |
| 3 | A dictionary item row holds its key under `DICT_KEY` (= `NO_ID`); the element keeps ids from 0 | AZ-2754 AC-5 | done, documented on `dict` and `key` | clear |
| 4 | Unpack of an empty string asks the row for `slots(id)` before `set_count(id, 0)`, so a row with a blob store reads `Some(empty)` | AZ-2754 AC-1 | done | clear |
| 5 | The std ECC module now runs on the shared core (the C++ shape: repair verified on the syndromes before a byte is written); the 22 std ECC tests and the 1,339 vector rows are unchanged and green | AZ-2755 risk 1 | done | clear |
| 6 | `nostd::ecc` exposes the codec (`protect`, `check`, `repair`), as the C++ `ecc::` namespace does | AZ-2755 | done | clear |
| 7 | `unpack_repair` returns `Unpacked { bytes, repaired }` (the C++ `Result::repaired`) | AZ-2755 AC-1 | done | clear |
| 8 | Several schemes with different parity in one dispatch (the C++ rule) is not in the core: it has no dispatch | AZ-2755 excluded | stays out | clear |
| 9 | Base flash grew 784 B (Utf8Wire, count header, new kinds in the checks); the dictionary and `Utf8` paths are behind `text` | AZ-2751 AC-3 | the base limit of 16,384 B holds with 1,852 B margin | clear |
| 10 | The device stack of the text set is 1,328 B (probe frames included); no limit exists | owner | owner sets the limits of `text` and `ecc` | unclear (owner) |
| 11 | The C++ `when` of a skipped source (loop 51) is still no ticket | handoff52 | ticket in the loop record | clear |
