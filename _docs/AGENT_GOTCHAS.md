# Agent gotchas

Session-start don’ts. One line each. Under one page. Do not duplicate `_docs/LESSONS.md`.

## Gotchas

- The auditor's fuzz corpora, per-language drivers, `cmp.py` and amplification probes live in a session scratchpad. Commit them under `fixtures/hostile/fuzz/` or the next unpack-changing loop rebuilds them from an old temp dir (recommended in loop 11, ignored, repeated in loop 13).
