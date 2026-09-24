# Ripple log — loop 4

The six packages do not import each other. A change in one language does not stale another language's module doc.

- README.md — public examples now construct a Scheme with a type number and order ids
- `_docs/01_solution/schema.md` — dispatch is the leading type byte on the scheme
- `_docs/02_document/tests/blackbox-tests.md` — scheme and marker scenarios
- `_docs/02_document/tests/traceability-matrix.md` — AZ-1945, AZ-1946, AZ-1949, AZ-1950

Component description files under `_docs/02_document/components/` still describe the earlier pack API. They are the remaining doc update.
