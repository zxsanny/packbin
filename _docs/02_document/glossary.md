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

Unpack found that a present field does not fit in the bytes that remain. The error names the field, how many bytes it needed, and how many remained. No value is returned. (source: problem.md; acceptance_criteria.md AC-8)

## Split form

The flags byte is stored now, and each bit's field is placed later in the list. (source: schema.md)

## Unpack

The call that turns bytes back into a value, or into a short-packet or trailing-bytes error. (source: problem.md)

## Version tag

A Git tag that starts the publish of each language present in that commit. (source: restrictions.md; packages.md)

## When

A group that is written only when an earlier field equals a given value. (source: schema.md)
