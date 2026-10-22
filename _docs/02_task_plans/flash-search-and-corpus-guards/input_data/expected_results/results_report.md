# Expected results — loop 57

| Input | Expected output |
|-------|-----------------|
| Cortex-M4F flash image after the search | at most 8,040 B |
| Cortex-M4F flash image after the fold try | at most 8,080 B if kept; else the try is restored and the figures are recorded |
| Stack, 3-deep `when` chain / flag-byte chain / round chain | not above 504 B / 500 B / 436 B |
| `cases.txt` copy with the only line of an unpack or limit handler removed | plain Rust loader fails naming that case id |
| Rust nostd corpus with one case moved from run to skip | the test fails naming the id |
| `corpus.txt` copy with one extra line | Swift and Rust nostd pass with the new count |
| Go loader with a missing and an unused handler | one helper, the messages of today |
| Arm stage with the pin one byte below the measured flash (copy) | fails naming measured and pinned bytes |
| Every packet and refusal of the hostile and differential corpora | byte-identical to HEAD |
