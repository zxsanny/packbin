# Scenarios — ring-and-test-build-fixes

Source of rows: `intake` (new-task Step 4.7). Status: confirmed / out-of-scope / deferred.

| id | scenario | status | behavior (confirmed) | AC ref | source |
|----|----------|--------|----------------------|--------|--------|
| S1 | a maintainer adds a ring row with a number above its range | confirmed | the loader stops with exit 1 and names the row | AC-4 | intake |
| S2 | a driver reads a line with a number above its range or with a sign | confirmed | the driver exits non-zero, prints no result for it, names the line | AC-1 | intake |
| S3 | a driver reads the largest number of each range | confirmed | the number reaches the package unchanged; the package answers as the reference | AC-2, AC-5 | intake |
| S4 | the existing 25 seal and 38 refusal rows run after the change | confirmed | same answers: 64 pairs and every refusal row match | AC-5 | intake |
| S5 | a reader or pair has more than 5 mismatches | confirmed | 5 lines, then `... and N more`; totals unchanged | AC-7 | intake |
| S6 | an old lenient driver is put back | confirmed | the new driver cases fail for it | AC-3 | intake |
| S7 | a Rust test helper's cfg is broader than its callers' | confirmed | the build warns and the suite fails naming the set | AC-8, AC-9 | intake |
| S8 | a std test file loses its feature gate | confirmed | the `none` set build fails the suite | AC-10 | intake |
| S9 | multi-part MAC messages in the ring | out-of-scope | — | — | intake |

## Fit decisions

| card | collision | chosen option | constraint recorded |
|------|-----------|---------------|---------------------|
| — | none found (the ring and the suite runner are test infrastructure; no public contract, ADR or package behavior changes) | — | — |

## Not walked

- A writer that prints a malformed word (L-2 of loop 78): unchanged, kept green by the existing `ring-frame.test.sh` cases.
