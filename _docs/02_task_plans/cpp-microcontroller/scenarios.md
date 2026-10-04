# Scenarios — C++ on microcontrollers

| Id | Scenario | Proposed behavior | Status | Task | AC ref |
|----|----------|-------------------|--------|------|--------|
| S1 | Firmware packs a row into a buffer exactly the packet size | Ok, length equals size | confirmed | AZ-2060 | AC-1 |
| S2 | Buffer one byte short | `BufferFull`, nothing written past the offset | confirmed | AZ-2060 | AC-2 |
| S3 | Received packet truncated by the radio | `ShortPacket` with field id | confirmed | AZ-2060 | AC-3 |
| S4 | Packet with a type number this firmware does not know | `TypeMismatch`; no handler runs | confirmed | AZ-2061 | AC-1 |
| S5 | Server sends more `repeat` groups than the firmware's array | `TooMany`; fields already read keep their values | confirmed | AZ-2063 | AC-2 |
| S6 | Long string into a fixed `char[16]` | `TooMany`; a borrowed view has no limit | confirmed | AZ-2063 | AC-4 |
| S7 | Big-endian CPU | Same bytes as little-endian | confirmed | AZ-2066 | AC-4 |
| S8 | Board without a working RNG | `start` returns an error, no padding | confirmed | AZ-2065 | AC-2 |
| S9 | Scheme typo (gap in field ids) in firmware source | Compile error naming the id | confirmed | AZ-2061 | AC-3 |
| S10 | Host user upgrades from 0.1.x | Old API is gone; README migration list maps each old symbol to its replacement; same bytes, same speed | confirmed | AZ-2064 | AC-5 |

Decisions 2026-10-04: D-1 A, D-2 B, D-3 A. S7 has a code-path AC on AZ-2060 (AC-4) and its proof on a big-endian CPU in AZ-2066.
