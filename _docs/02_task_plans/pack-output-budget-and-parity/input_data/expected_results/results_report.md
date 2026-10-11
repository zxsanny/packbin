# Expected I/O — loop 20

Mapped onto rows of `fixtures/hostile/cases.txt` (stage `pack`) added by AZ-2367, plus the unchanged golden and route fixtures (accepted rows keep their bytes). The exact error texts and hex rows come from the TypeScript reference table `_docs/03_implementation/reference_loop20_budget.md` (AZ-2354 D1).

| Input | Expected |
|-------|----------|
| `u32 n; times(n) { utf8 s }`, `{n: 65535, s: "a" x 65535}` | pack error naming `s`, no bytes |
| `list(group(u32 n, times(n) { u64 k }))`, 40 items `{n: 65535, k: 5}` | pack error at default; packs (about 21 MB, exact length pinned by the reference table) with `maxBytes` 32 MiB |
| `repeat { u8 k }` with 65 536 entries | pack error naming `k` |
| `repeat { u8 k }` with 65 535 entries | 65 536 bytes |
| 65-name round, count 65 535 | pack error (slots) |
