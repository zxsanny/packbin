# Loop 22 acceptance criteria

Per task: see `_docs/02_tasks/todo/AZ-2410` to `AZ-2418` (inherited map). Cross-cutting:

- L1: wire bytes of rows accepted at HEAD (88c063f) are unchanged in every package.
- L2: each package's own suite is green; the hostile set (55 + new cases) passes in all six loaders.
- L3: Cortex-M4F stays within 8 192 B flash and 512 B stack.
- L4: the default `maxSlots` memory ceiling is measured per package and stated.
