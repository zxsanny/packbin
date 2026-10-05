# Glossary

**Status**: confirmed-by-user
**Date**: 2026-09-22

## Field list

The ordered description of one packet: widths, endian, and which flag bit includes the next field. The caller owns it. The packages do not ship a product's lists. (source: problem.md; solution.md)

## Flags

A byte whose bits say which following fields are present. A set bit writes the field. A clear bit skips it. Zero is a real value, so a missing field is absence, not `0`. (source: solution.md)

## Golden fixture

A shared hex buffer. All six first-release languages must pack it to the same bytes and unpack it to the same fields. The position fixture is `4001000065cd1d00a3e1110100`. (source: problem.md; acceptance_criteria.md AC-1)

## Pack

The call that turns a value into the exact bytes of one field list. (source: problem.md)

## Packbin

The library, and the npm package name. The NuGet package name is `Packbin`. (source: problem.md; packages.md)

## Repeat

A group that is read until the buffer is used up. The buffer must end on a group boundary. One leftover byte is a short packet. (source: schema.md)

## Short form

The flags byte and the fields it controls sit next to each other. (source: schema.md)

## Short packet

Unpack found that a present field does not fit in the bytes that remain. The error names the field, how many bytes it needed, and how many remained. No value is returned. In C++ the `ShortPacket` result carries the field order id, the byte offset and the bytes needed, and the fields read before it keep their values in the caller's row. (source: problem.md; acceptance_criteria.md AC-8; cpp-microcontroller restrictions.md)

## Split form

The flags byte is stored now, and each bit's field is placed later in the list. The bit must come after its flag byte in the same scope (top level, one `repeat` or `times` round, or one `list` or `dict` element); a flag byte read inside a `when` is not visible after it. TypeScript, C#, Java and Rust refuse a violation at construction; Python does so with AZ-2100. (source: schema.md; loop 11)

## Unpack

The call that turns bytes back into a value, or into a short-packet or trailing-bytes error. In C#, TypeScript, Python, Rust and Java it returns an error value for every bad buffer and never throws; a negative count, a count with no source field, invalid UTF-8, and a `times`, `list` or `dict` round that reads nothing come back as an interim short-packet-style error until C15 sets their kind. (source: problem.md; loop 11)

## Version tag

A Git tag that starts the publish of each language present in that commit. (source: restrictions.md; packages.md)

## When

A group that is written only when an earlier field equals a given value. (source: schema.md)
