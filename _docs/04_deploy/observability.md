# Observability

The library does not log, emit metrics, or trace. A short packet returns the field name, bytes needed, and bytes left (in Go an `*Error` with `Kind`, `Field`, `Name`, `Needed` and `Left`). GitHub Actions keeps the test log and the publish log. There is no paging service.
