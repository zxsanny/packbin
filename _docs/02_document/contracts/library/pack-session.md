# Contract: pack session

**Component**: library
**Producer task**: AZ-2019 — csharp_session
**Consumer tasks**: AZ-2020, AZ-2021, AZ-2022, AZ-2023, AZ-2024, AZ-2025, AZ-2026
**Version**: 1.0.0
**Status**: draft
**Last Updated**: 2026-09-29

## Purpose

One optional connection session beside clear pack. The opener sends 16 bytes once. The waiter joins. Later payloads match the clear packed length. Each language implements this itself.

## Shape

### Operations

| Operation | Input | Output | Failure |
|-----------|--------|--------|---------|
| Load | 32 bytes | a session that is not yet open | length other than 32 creates 0 sessions |
| Start | the loaded session | 16 bytes, and the session is the opener | — |
| Join | the loaded session and 16 bytes | the session is the waiter | length other than 16 joins 0 sessions |
| Pack | an open session, a scheme, a row | a payload the same length as clear pack | pack before start or join produces 0 payloads |
| Unpack | an open session and a payload | the row, or the same error clear unpack would return | — |

The opener's send direction is the waiter's receive direction. A second pack on the same direction uses the next position. Two sessions with different 16-byte values do not recover each other's rows.

Clear pack and unpack stay as they are.

## Consumers

TypeScript, Python, Rust, C++, Java, the six-language match, and the README. Archangel is not a consumer in this repository.
