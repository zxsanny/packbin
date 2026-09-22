# Acceptance criteria

Outcomes only. Numbers are the pass line.

## Bytes

- **AC-1.** Pack of type `64`, sid `1`, latitude `500000000`, longitude `300000000`, profile `1`, and motion flags clear yields exactly 13 bytes: `4001000065cd1d00a3e1110100`. Mismatched bytes: 0.
- **AC-2.** Unpack of that hex yields those same five fields. Field mismatches: 0. Motion fields in the result: 0.
- **AC-3.** On every shared golden fixture, the bytes from all six first-release languages are identical. Mismatched bytes: 0.
- **AC-4.** A clear flags bit adds 0 bytes for that field. A set bit adds exactly that field's width. For a list whose bit 5 is a `uint16`, flags `0x20` add 2 bytes and flags `0x00` add 0 bytes.
- **AC-5.** A stored `0` is written, so that field's bit is set. Omission is the absence of the field, and the result does not substitute `0`.
- **AC-6.** A conditional group whose tested field does not match adds 0 bytes. A match adds exactly that group's width.
- **AC-7.** A repeated group that stops on a group boundary unpacks one value per complete group. A buffer that ends with 1 leftover byte returns an error and 0 values.

## Errors

- **AC-8.** Unpack of a buffer that ends inside a field returns an error and 0 values. The error names the field, the byte count it needed, and the byte count that remained.
- **AC-9.** Unpack of a buffer with 1 or more bytes left after the field list returns an error and 0 values.

## Speed

- **AC-10.** In each first-release language, 100000 pack-then-unpack round trips of the AC-1 fixture finish in ≤ 1 second on one core.

## Release

- **AC-11.** CI runs the tests on 100% of pushes and pull requests. A failing test fails that check.
- **AC-12.** A version tag whose languages match on the golden fixtures (0 mismatched bytes) publishes 1 package per language present in that commit, to that language's public registry, with 0 manual uploads.
- **AC-13.** The first tag publishes exactly 6 packages from the same commit: npm `packbin`, NuGet `Packbin`, PyPI `packbin`, crates.io `packbin`, Maven Central `packbin` (Java), and vcpkg `packbin`.
- **AC-14.** A tag that fails the golden-byte check publishes 0 packages.
- **AC-15.** A language missing from the tagged tree publishes 0 packages.
- **AC-16.** Each published package declares the MIT license. License identifiers other than MIT: 0.

## Out of scope

- A new envelope, compression, or RPC
- A hosted service
- Dictionary tables, map state, or keeping the previous value when a field is absent
- Replacing Protobuf where a new protocol can accept its tags
- Kotlin, a wiki, or a seventh language before the six languages agree on the golden bytes
- A code generator in the first release
- Any speed target other than AC-10, including allocation budgets, SIMD, and a zero-copy API
- Authentication, secrets, or TLS inside the library
- GitHub Packages as the install path
- A calendar deadline
