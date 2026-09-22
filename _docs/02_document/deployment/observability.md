# Observability

The library does not log, emit metrics, or trace. A short packet is a return value: field name, bytes needed, bytes left. The caller logs it if they want a log.

GitHub Actions keeps the test log and the publish log. A failed golden check is the alert. There is no paging service.
