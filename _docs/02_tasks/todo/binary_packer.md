---
loop: 5
branch: dev
---

# BinaryPacker

**Task**: pending
**Name**: BinaryPacker
**Description**: Pack and unpack are `BinaryPacker` methods. Test rows use each language's own member names. The order id is the binding key, so the names do not have to match across languages.
**Complexity**: 3 points
**Dependencies**: AZ-1950
**Component**: library
**Tracker**: pending
**Epic**: pending

## Problem

AZ-1946 requires `BinaryPacker.Pack` and `BinaryPacker.Unpack`. AZ-1949 then said `BinaryPacker` is gone and the code shipped `Pack.Run` and `Unpack.Run`. Test rows also copied one set of member names into every language.

## Outcome

- C#: `BinaryPacker.Pack` and `BinaryPacker.Unpack`. The handler overload is `BinaryPacker.Unpack`.
- TypeScript and Python: `BinaryPacker.pack` and `BinaryPacker.unpack`.
- Rust: `BinaryPacker::pack` and `BinaryPacker::unpack`. Unknown-buffer dispatch stays `BinaryPacker::unpack_with`.
- C++: `BinaryPacker::pack` and `BinaryPacker::unpack`.
- Java: `BinaryPacker.pack` and `BinaryPacker.unpack`.
- The classes `Pack` and `Unpack` are not the public entry.
- Test and example rows use native names: C# PascalCase, TypeScript camelCase, Python snake_case, Rust snake_case, C++ snake_case, Java camelCase.
- The marker hex `2001000065cd1d00a3e111010000000000` and the position hex `4001000065cd1d00a3e1110100` stay the same.

## Acceptance Criteria

**AC-1: The entry is BinaryPacker.**
Given a scheme and a row.
When packed and unpacked.
Then the call is `BinaryPacker` pack and unpack for that language.

**AC-2: Names are native.**
Given the marker row in each language.
When the test names the members.
Then C# uses PascalCase and Python uses snake_case, and the bytes still match.
