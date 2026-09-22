# Fact cards — Phase 1

## Fact 1

Statement: On 2026-09-22 the current .NET LTS is .NET 10, supported until 2028-11-14. .NET 8, the previous LTS, ends support on 2026-11-10.
Source: #1, #2
Confidence: high

## Fact 2

Statement: On 2026-09-22 Node.js 24 is Active LTS. Node.js 26 is Current and is scheduled to enter LTS on 2026-10-28. Node.js 22 remains Maintenance LTS until 2027-04-30.
Source: #3, #4
Confidence: high

## Fact 3

Statement: A 100000 round-trip budget of 1 second is 10 µs per round trip. Published C# MessagePack times for a small object are tens to a few hundred nanoseconds per call. A fast Node MessagePack pack of a small object is about 2 µs.
Source: #5, #6
Confidence: medium for the Node number (old hardware, different payload). High that 10 µs is a loose floor, not a tuning target.

## Fact 4

Statement: Protobuf tells users not to treat serialized bytes as canonical across languages. A fixed field layout that forbids tags can require 0 mismatched bytes. That bar is stricter than Protobuf and is the point of this library.
Source: #7, #8
Confidence: high

## Fact 5

Statement: Kaitai Struct 0.11 can write only Java and Python. C# and JavaScript remain parse-only there.
Source: #9, #10
Confidence: high

## Fact 6

Statement: Python's `struct` module rejects a buffer whose size does not match the format, rejects an integer outside the format range, and tells callers to set endian explicitly when bytes leave the process.
Source: #11
Confidence: high

## Fact 7

Statement: npm and NuGet both document GitHub Actions publish through OIDC trusted publishing. A long-lived registry token is the older path, not the one their current docs prefer.
Source: #12, #13, #14
Confidence: high

## Fact 8

Statement: `BinaryPrimitives.WriteInt32LittleEndian` writes exactly 4 little-endian bytes and throws if the destination is shorter than 4. The same family reads those bytes back.
Source: #15
Confidence: high

## Fact 9

Statement: `DataView.setInt32(byteOffset, value, littleEndian)` stores a signed 32-bit integer at any offset. `littleEndian` false is big-endian. A write past the view throws `RangeError`.
Source: #16
Confidence: high

## Fact 10

Statement: A Node 22 script and a .NET 10 program, each walking fixed little-endian fields with no tag bytes, both emitted `4001000065cd1d00a3e1110100`. Each unpacked that hex to type 64, sid 1, lat 500000000, lon 300000000, profile 1, flags 0. A clear optional bit stayed 2 bytes; a set bit grew to 4. A 3-byte buffer for a set bit returned no value. A conditional group added 0 or 1 byte. A repeated 2-byte group rejected a 1-byte leftover. 100000 round trips took 17.4 ms in Node and 1.8 ms in .NET.
Source: #17
Confidence: high
