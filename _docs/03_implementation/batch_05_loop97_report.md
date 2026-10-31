# Batch 05 report — loop 97

Task: AZ-3509 (README, component docs, module layout, glossary; 3 points), by the parent after the packages merged; the spellings were read from the shipped code.

| Check | Result |
|-------|--------|
| README-reading tests | `python/tests/test_binding.py` 9 passed; `scripts/frame/readme-examples.sh` PASS (Go, Python, TypeScript, Rust); Swift `ReadmeExampleTests` 5 passed in `swift:6.3.3` (no code block was added, so `readme_swiftBlocks_areTheSnippets` is unchanged) |
| Diff scope (AC-3) | `README.md`, `_docs/02_document/{glossary.md, module-layout.md, components/*/description.md}` only |

Review: documents only; no code-review pass. CI-parity: not applicable (no application source).

## Discovered during implementation

| Spec ref | Discovery | Proposed handling | clear/unclear |
|----------|-----------|-------------------|---------------|
| AC-2 | `module-layout.md` is a table, not a per-loop log; the loop 97 file list is one section at its end | accepted | clear |
| AC-1 | Swift DocC page `Packbin.md` still describes only the count | a follow-up if wanted; not a README or component doc | open (Low) |
