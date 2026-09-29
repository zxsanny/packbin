# Acceptance criteria — pack session

Inherited project criteria stay in force. This feature exercises AC-1 and AC-3: the clear position bytes stay the golden hex, and the six languages still match on that hex.

## Criteria

**AC-1: Clear pack is unchanged.**
Given the position row of type 64, sid 1, latitude 500000000, longitude 300000000, profile 1, and motion flags clear.
When packed with the existing packer.
Then the bytes are `4001000065cd1d00a3e1110100`. Mismatched bytes: 0.

**AC-2: One connection round-trips.**
Given a 32-byte seed, an opener, and a waiter that receives the opener's 16 bytes.
When the opener packs that position row and the waiter unpacks it.
Then the waiter gets those five fields. Field mismatches: 0. The payload length equals the clear packed length. Added bytes: 0.

**AC-3: The waiter can send.**
Given that same connection.
When the waiter packs the position row and the opener unpacks it.
Then the opener gets those five fields. Field mismatches: 0.

**AC-4: A second packet on the same connection round-trips.**
Given one packet already unpacked on that connection.
When a second position row is packed and unpacked.
Then field mismatches: 0.

**AC-5: Two clients do not share a stream.**
Given two sessions from the same seed and two different 16-byte values.
When client A's payload is unpacked with client B's session.
Then the result is not the original five fields. Field mismatches: at least 1, or an error. Rows returned as the original row: 0.

**AC-6: A bad setup creates nothing.**
Given a seed whose length is not 32, or a join value whose length is not 16.
When the caller loads or joins.
Then sessions created: 0.

**AC-7: Pack before the connection is open fails.**
Given a loaded seed and no start and no join.
When the caller packs.
Then the call fails. Payloads produced: 0.

**AC-8: The README shows both ways.**
Given the README.
When a reader looks for examples.
Then it still shows clear pack, and it shows one connection that sends 16 bytes once and then packs. Session examples: 1. Clear examples kept: 1.

## Out of scope

- A check that detects a flipped bit
- A clock-based seed
- Storing the seed inside the library
- Opening the socket
- Wiring the Archangel server or the Vue client
