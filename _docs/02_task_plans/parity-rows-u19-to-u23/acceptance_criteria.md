# Loop 23 acceptance criteria

Per task: see `_docs/02_tasks/todo/AZ-2431` to `AZ-2436` (inherited map). Cross-cutting:

- L1: wire bytes of rows accepted at HEAD (b8b2809) are unchanged in every package.
- L2: each package's own suite is green; the hostile set (65 cases) passes in all six loaders.
- L3: Cortex-M4F stays within 8 192 B flash and 512 B stack.
- L4: every refusal added this loop names the field (and the count where there is one).
