# Glossary

**Status**: confirmed-by-user
**Date**: 2026-09-22

## Field list

The ordered description of one packet: widths, endian, and which flag bit includes the next field. The caller owns it. The packages do not ship a product's lists. (source: problem.md; solution.md)

## Bool

A flag bit with no payload. The bit is set only for `true`; `false` and a missing value leave it clear, and unpack gives `true` only for a set bit. A bool stands only directly under `flags` or a flag-byte bit; anywhere else the field list fails when it is built. (source: user decision 2026-10-05; README)

## Empty group

A group with no fields: a presence bit like a bool, bound to something that can carry `true` (its own value in TypeScript and Rust, a `bool` member in C# and C++, a nested-row accessor in Java). One that could never set its bit (Python and Java `group(anchor)` with no fields, a C++ `group(id)` with no member, a C# empty group on a non-`bool` member) fails when the field list is built. (source: user decision 2026-10-05, loop 12 U3)

## Flags

A byte whose bits say which following fields are present. A set bit writes the field. A clear bit skips it. Zero is a real value, so a missing field is absence, not `0`. One flags byte holds at most 8 bits; a ninth fails when the field list is built. A `when`, `times` or `repeat` can be a member (or sit in a group under one): its bit is set exactly when it writes a value, in all six packages since loop 18 (AZ-2120). (source: solution.md; loop 12)

## Golden fixture

A shared hex buffer. All six first-release languages, and Go since loop 24, must pack it to the same bytes and unpack it to the same fields. The position fixture is `4001000065cd1d00a3e1110100`. (source: problem.md; acceptance_criteria.md AC-1)

## Go tag

The git tag `go/vX.Y.Z` that releases the Go module `github.com/zxsanny/packbin/go` (Go fetches a module in a subdirectory by the tag `<directory>/vX.Y.Z`; there is no registry upload). `publish.yml` pushes it at the commit of `vX.Y.Z`, last of all uploads and only after the golden check passes on every language, without force. A Go tag never moves and is never deleted; a bad version is marked `retract` in the `go.mod` of the next version. (source: ADR-004; Go decisions G-1, G-6)

## Limits

Three numbers a scheme carries: the most rounds one `repeat` or `times` field may have (`maxRounds`, 65 535), the most slots one call may charge (`maxSlots`, 1 048 576 since loop 22) and the longest packet pack may write (`maxBytes`, 16 777 216). Unpack refuses the round that would pass the first two before reading it; pack refuses a count or list above `maxRounds`, charges slots per round and checks `maxBytes` before every write. In Go they are `Limits{MaxRounds, MaxSlots, MaxBytes}`, read with `DefaultLimits()` and set with `(*Scheme).WithLimits(Limits)`, which returns a copy, takes all three values and refuses one below 1 as `InvalidScheme`; C#, TypeScript and Python default an omitted value. A refused round is the error kind `TooMany` in Go (the interim short-packet shape with `needed` 0 elsewhere). (source: loop 15 to 22 specs; AZ-2444)

## Nested row

A set of fields with an id and name scope of its own: its ids start at 0, and its references, member names and flag bytes stop at its edge (loop 13). In Go it is `Nested(name, members...)`, given as a nested `map[string]any` in a map row or a struct in a typed row; a `Nested` row in a round is charged the width of its own members against `maxSlots` (Java charges a nested-row group 1 slot, assessment D3, open). The anchored `Group` keeps the outer scope and still refuses a shared name. (source: loop 13; components/07_go_package/description.md)

## No value

A row that leaves a field out. In Go a nil pointer, a nil slice or a map key that is absent or nil is no value: its flag bit stays clear, and a count behind a clear `when` with no value is refused as in the five (U11). An empty slice is a value with 0 items, so its count 0 is written. (source: Go decision G-5; AZ-2440, AZ-2442)

## Pack

The call that turns a value into the exact bytes of one field list. (source: problem.md)

## Packbin

The library, and the npm package name. The NuGet package name is `Packbin`. (source: problem.md; packages.md)

## Repeat

A group that is read until the buffer is used up. The buffer must end on a group boundary. One leftover byte is a short packet. Its body, like that of `times`, must hold at least one member: an empty body is refused when the scheme is built (loop 21; C++ looks through `when` and groups since loop 22). In the Rust map form a `repeat` takes its rounds only as `__repeat__` groups (per-name lists without them are refused, loop 22; since loop 23 a value kept beside the groups must agree with them, as for `times`); in the other packages the round count is the longest list. (source: schema.md)

## Short form

The flags byte and the fields it controls sit next to each other. (source: schema.md)

## Short packet

Unpack found that a present field does not fit in the bytes that remain. The error names the field, how many bytes it needed, and how many remained. No value is returned. In C++ the `ShortPacket` result carries the field order id, the byte offset and the bytes needed, and the fields read before it keep their values in the caller's row. (source: problem.md; acceptance_criteria.md AC-8; cpp-microcontroller restrictions.md)

## Split form

The flags byte is stored now, and each bit's field is placed later in the list. The bit must come after its flag byte in the same scope (top level, one `repeat` or `times` round, or one `list` or `dict` element); a flag byte read inside a `when` is not visible after it. TypeScript, C#, Java, Rust and Python refuse a violation at construction (Python since loop 16, AZ-2100). A bit's number is its place among the bits of the flag byte read it follows (Rust, C++, TypeScript, Java, Python since loop 16 AZ-2230, and C# since loop 17 AZ-2135). A flag byte read inside a `flags` member or the child of a flag bit is not visible after it in C++ either since loop 18 (AZ-2304), as in TypeScript and Java; Rust gives each member of one `flags` its own scope since loop 19 (AZ-2333). Pack of a split bit whose `when` source or `times` count is written after the byte fails, naming the member, when the body would be written and the bit is clear (loop 19, AZ-2331); a false condition packs silently. (source: schema.md; loop 11)

## Unpack

The call that turns bytes back into a value, or into a short-packet or trailing-bytes error. In C#, TypeScript, Python, Rust, Java and Go it returns an error value for every bad buffer and never throws (the typed C# `Unpack` of a `repeat` or `times` round returns an error value too since loop 20, when the row cannot hold the lists of rounds); a negative count, a count with no source field, invalid UTF-8, and a `times`, `list` or `dict` round that reads nothing come back as an interim short-packet-style error until C15 sets their kind. (source: problem.md; loop 11)

## Version tag

A Git tag that starts the publish of each language present in that commit. Go is published by the second tag `go/vX.Y.Z` that this run pushes (see Go tag). (source: restrictions.md; packages.md; ADR-004)

## When

A group that is written only when an earlier field equals a given value. The tested field is an integer, a `u2` slot or a bool; a bool is compared only with `true`, and the field list fails when it is built for any other test or source kind, in all six packages since loop 18 (AZ-2126). Since loop 19 (AZ-2338) it also fails when the tested value is one that an integer source can never hold (out of range, a string, `NaN`, a fraction, a bool); C++ checks out-of-range integers only. C++ accepts an empty group as a source (AZ-2334). (source: schema.md)
