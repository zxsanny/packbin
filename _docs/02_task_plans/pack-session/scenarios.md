# Scenarios — pack session

| Id | Scenario | Proposed behavior | Status | Task |
|----|----------|-------------------|--------|------|
| S1 | First connection: opener sends 16 bytes, waiter joins, one position row | Waiter recovers the five fields. Payload length equals the clear pack. | confirmed | AZ-2019 |
| S2 | Caller packs with no session | Golden hex `4001000065cd1d00a3e1110100`. Mismatched bytes 0. | confirmed | AZ-2019 |
| S3 | A second packet on the same connection | Field mismatches 0. | confirmed | AZ-2019 |
| S4 | Two clients, one seed, two different 16-byte values | B does not recover A's row. | confirmed | AZ-2019 |
| S5 | Pack before start or join | The call fails. Payloads 0. | confirmed | AZ-2019 |
| S6 | Seed length is not 32, or the join value is not 16 bytes | Sessions created 0. | confirmed | AZ-2019 |
| S7 | A row already packed before this feature | Clear unpack still returns that row. | confirmed | AZ-2019 |
| S8 | The waiter packs and the opener unpacks | Field mismatches 0. | confirmed | AZ-2019 |
| S9 | The other five languages use the same seed, nonce, and row | Ciphertext matches C#. Mismatched bytes 0. | confirmed | AZ-2025 |
| S10 | A reader of the README wants both ways | One clear example remains and one session example is present. | confirmed | AZ-2026 |

Not walked: permission checks, undo, and a clock. The library has no login, and this feature has no clock.
