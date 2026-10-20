# Implementation completeness — loop 51

Tasks: AZ-2752 (`fca880d`), AZ-2753 (`b097f54`), epic AZ-2750. Batch reports: `batch_01_loop51_report.md`, `batch_02_loop51_report.md`.

| Task | Outcome / scope vs code | ACs | Scaffolds | Verdict |
|------|-------------------------|-----|-----------|---------|
| AZ-2752 flags, bits, u2, packed, sized, when | All seven kinds (plus `boolean`) in `rust/src/nostd/`, checks in `check.rs`, presence and sources in `present.rs` | AC-1 random-row differential (13 layouts); AC-2 39 refusals; AC-3 cuts, trailing, random bytes; AC-4 presence matrix, clear on unpack | none (`git grep` placeholder/stub/TODO/fake/mock in `rust/src/nostd`: no hit) | PASS |
| AZ-2753 repeat, group, times, lists | Four kinds, item rows, round/slot/storage limits | AC-1 differential (14 layouts); AC-2 limits on pack and unpack, storage; AC-4 hostile counts, cuts | none | PASS, with AC-3 (dict order) moved to AZ-2754 AC-5 (dict keys are strings, compared decoded) |

## System Pipeline Audit

| Pipeline | Production callers | Status |
|----------|--------------------|--------|
| `nostd::pack` / `unpack` → `check::validate` → `Pack` / `Unpack` walk → `Row` | the embedded probe (`rust/embedded/probe`, linked into the Cortex-M4F image under QEMU) and the crate's public API | WIRED (probe is flat; the nested kinds run on the host suite; a nested probe is AZ-2757) |
