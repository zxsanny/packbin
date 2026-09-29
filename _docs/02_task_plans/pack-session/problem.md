---
loop: 9
branch: loop/9-pack-session
---

# Pack session

A caller who already packs a field list can keep those bytes exactly as they are. A caller who wants the same bytes hidden on a connection loads one 32-byte seed, and the side that opens the connection produces 16 bytes once. The waiting side uses those same 16 bytes. After that, either side packs and unpacks on that connection, and each payload is the same length as the clear packed bytes.

Vue and Android open. The server waits, once per client. Hundreds of clients means hundreds of sessions from the same seed. The library does not open the socket and does not store the seed.

## Change location

"vue and android starts, and server joins" and "what about multiple clients? we would have hundreds of clients" and "keep that design" and "add to update readme to the task". The place is each client connection that already sends packed packets, plus the README in this library. The Archangel socket wiring stays in that repository.

## Flagged concerns

| Concern | Policy / owner | Status | Severity |
|---------|----------------|--------|----------|
| One copy of the shared seed decrypts every client until the next software update | Caller stores the seed | accepted-risk | High |
| A flipped bit on the path is not detected, because a later packet adds 0 bytes | Caller, accepted for this design | accepted-risk | High |
| A dropped or reordered packet on the connection makes later unpack fail | Caller provides an ordered connection | accepted-risk | Medium |
