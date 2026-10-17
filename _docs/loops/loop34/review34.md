# Loop 34 total review (AZ-2627)

Scope: `git diff dadd32b..HEAD` outside `_docs/` (CI scripts and guards), `/code-review` high, 2026-10-17. Verdict
PASS_WITH_WARNINGS after fixes: 6 findings (1 High), owner chose "fix 1-4, 6" (5 skipped until the CI numbers).

| # | Finding | Severity | Outcome |
|---|---------|----------|---------|
| 1 | Ring `run` mode: the root install made `<dir>` root-owned, so the caller could not create `<dir>/cache`; the ring would never get ccache hits | High | fixed: the caller makes `<dir>/cache` and `<dir>/debs` before the install; real check as uid 1001 in `swift:6.3.3`: miss 3 misses, after a restore 3 hits |
| 2 | The run-mode test could not catch root ownership (stand-in setpriv) | Medium | fixed: S12g asserts the caller's mkdir comes before the first apt-get |
| 3 | The summary left out uncacheable compiles (a bypassed cache would read as all hits) | Medium | fixed: `N uncacheable` (ccache 4.9 keys, links left out), tested |
| 4 | Ring notice lines from the log were not escaped | Low | fixed: `%` and CR escaped, tested |
| 5 | The ring cache restore runs before the image pulls start | Low | skipped (owner): decide from the restore's seconds in the CI runs |
| 6 | The apt download temp dir was left behind | Low | fixed |

Mutants of the fixes (scratch copies): 4 of 4 rejected.
