# Expected results — loop 109 (embedded-arm DNS cause)

The feature has no library input. Its inputs are CI runs; the expected rows below are what the diagnostic run and the findings document must show.

| # | input | expected result | AC |
|---|-------|-----------------|----|
| 1 | diagnostic workflow, started by hand on `dev` | job success; log has the blocks `host resolver`, `docker daemon`, `bridge container resolv.conf` | AC-1 |
| 2 | the same job, lookup phase | log lines `bridge ok/fail`, `host-network ok/fail`, `host ok/fail` with a time stamp; at least 60 per path over at least 10 minutes | AC-2 |
| 3 | findings document | cause line quoted from the log, or `not reproduced` with run ids and minutes | AC-3 |
| 4 | `cpp/embedded/run.sh`, `Dockerfile` | comments quote the findings | AC-4 |
| 5 | `test.yml` run of the final push | `embedded-arm` success; 20 of 20 jobs | AC-5 |
