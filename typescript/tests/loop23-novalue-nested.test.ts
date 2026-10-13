import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  bits,
  eq,
  flagByte,
  flags,
  group,
  packed,
  repeat,
  sized,
  times,
  u8,
  when,
  type Field,
} from "../src/index.ts"

// Loop 23 G3 (AZ-2436): the U11 refusal (AZ-2410, `reference_loop22.md` row 56) pinned below the top level of a
// scheme. The row 56 body is `u8 mode; when mode == 1 { u8 c }; <bit> { member(count c) }`, with the bit a split
// flag byte bit or a combined `flags`. Positions: the body inside a group, a bit that holds a group holding the
// member, the body inside an outer holding `when`, a bit that holds a holding `when` around the member, the body
// as a `times` round and as a `repeat` round. Every position is spellable in TypeScript and refuses; count 0,
// the count left out and a holding inner `when` (with and without a value) pack as at b8b2809.

type Row = Record<string, unknown>
type Kind = "bits" | "packed" | "sized"
type Bit = "split" | "flags"

const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

const NOT_WRITTEN =
  "v: the count c is 3 in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold"

const KINDS: Kind[] = ["bits", "packed", "sized"]
const BITS: Bit[] = ["split", "flags"]

const member = (kind: Kind, id: number, countId: number): Field =>
  kind === "bits"
    ? bits(id, (x: Row) => x.v, countId)
    : kind === "packed"
      ? packed(1, id, (x: Row) => x.v, countId)
      : sized(id, (x: Row) => x.v, countId)

const value = (kind: Kind): unknown => (kind === "sized" ? new Uint8Array([1, 2, 3]) : [1, 0, 1])

// The member (or what holds it) behind a split bit or as the one member of a combined `flags` at `id`.
const behind = (bit: Bit, id: number, inner: Field): Field[] => {
  if (bit === "flags") return [flags(id, [inner])]
  const fb = flagByte("fb")
  return [fb, fb.bit(inner)]
}

// Row 56 with ids from `b`: mode b, c b+1, member b+2.
const body = (kind: Kind, bit: Bit, b: number): Field[] => [
  u8(b, (x: Row) => x.mode),
  when(b + 1, eq(b, 1), [u8(b + 1, (x: Row) => x.c)]),
  ...behind(bit, b + 2, member(kind, b + 2, b + 1)),
]

const outcome = (layout: Scheme<Row>, row: Row): string => {
  try {
    return hex(BinaryPacker.pack(layout, row))
  } catch (e) {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    return e.message
  }
}

type Position = {
  name: string
  ac: string
  layout: (kind: Kind, bit: Bit) => Scheme<Row>
  refused: (kind: Kind) => Row[]
  // count 0, left out, holding inner when with no value, holding inner when with the value
  unchanged: (kind: Kind) => Row[]
  wires: (kind: Kind) => string[]
}

const setHex = (kind: Kind): string => (kind === "sized" ? "010203" : "05")

const positions: Position[] = [
  {
    name: "the row 56 body inside a group",
    ac: "AC-1",
    layout: (kind, bit) => new Scheme<Row>(1, [group(0, (x: Row) => x.g, body(kind, bit, 0))]),
    refused: () => [{ g: { mode: 0, c: 3 } }],
    unchanged: (kind) => [{ g: { mode: 0, c: 0 } }, { g: { mode: 0 } }, { g: { mode: 1, c: 3 } }, { g: { mode: 1, c: 3, v: value(kind) } }],
    wires: (kind) => ["010000", "010000", "01010300", `01010301${setHex(kind)}`],
  },
  {
    name: "a bit that holds a group holding the member",
    ac: "AC-1",
    layout: (kind, bit) =>
      new Scheme<Row>(1, [
        u8(0, (x: Row) => x.mode),
        when(1, eq(0, 1), [u8(1, (x: Row) => x.c)]),
        ...behind(bit, 2, group(2, (x: Row) => x.g, [member(kind, 2, 1)])),
      ]),
    refused: () => [{ mode: 0, c: 3 }],
    unchanged: (kind) => [{ mode: 0, c: 0 }, { mode: 0 }, { mode: 1, c: 3 }, { mode: 1, c: 3, g: { v: value(kind) } }],
    wires: (kind) => ["010000", "010000", "01010300", `01010301${setHex(kind)}`],
  },
  {
    name: "the row 56 body inside an outer holding when",
    ac: "AC-2",
    layout: (kind, bit) => new Scheme<Row>(1, [u8(0, (x: Row) => x.o), when(1, eq(0, 1), body(kind, bit, 1))]),
    refused: () => [{ o: 1, mode: 0, c: 3 }],
    unchanged: (kind) => [
      { o: 1, mode: 0, c: 0 },
      { o: 1, mode: 0 },
      { o: 1, mode: 1, c: 3 },
      { o: 1, mode: 1, c: 3, v: value(kind) },
    ],
    wires: (kind) => ["01010000", "01010000", "0101010300", `0101010301${setHex(kind)}`],
  },
  {
    name: "a bit that holds a holding when around the member",
    ac: "AC-2",
    layout: (kind, bit) =>
      new Scheme<Row>(1, [
        u8(0, (x: Row) => x.o),
        u8(1, (x: Row) => x.mode),
        when(2, eq(1, 1), [u8(2, (x: Row) => x.c)]),
        ...behind(bit, 3, when(3, eq(0, 1), [member(kind, 3, 2)])),
      ]),
    refused: () => [{ o: 1, mode: 0, c: 3 }],
    unchanged: (kind) => [
      { o: 1, mode: 0, c: 0 },
      { o: 1, mode: 0 },
      { o: 1, mode: 1, c: 3 },
      { o: 1, mode: 1, c: 3, v: value(kind) },
    ],
    wires: (kind) => ["01010000", "01010000", "0101010300", `0101010301${setHex(kind)}`],
  },
  {
    name: "a times round body",
    ac: "AC-3",
    layout: (kind, bit) => new Scheme<Row>(1, [u8(0, (x: Row) => x.n), times(1, 0, body(kind, bit, 1))]),
    refused: () => [
      { n: 1, mode: [0], c: [3] },
      { n: 2, mode: [1, 0], c: [0, 3] },
    ],
    unchanged: (kind) => [
      { n: 2, mode: [1, 0], c: [0, 0] },
      { n: 1, mode: [0] },
      { n: 1, mode: [1], c: [3] },
      { n: 1, mode: [1], c: [3], v: [value(kind)] },
    ],
    wires: (kind) => ["01020100000000", "01010000", "0101010300", `0101010301${setHex(kind)}`],
  },
  {
    name: "a repeat round body",
    ac: "AC-3",
    layout: (kind, bit) => new Scheme<Row>(1, [repeat(0, body(kind, bit, 0))]),
    refused: () => [
      { mode: [0], c: [3] },
      { mode: [1, 0], c: [0, 3] },
    ],
    unchanged: (kind) => [
      { mode: [1, 0], c: [0, 0] },
      { mode: [0] },
      { mode: [1], c: [3] },
      { mode: [1], c: [3], v: [value(kind)] },
    ],
    wires: (kind) => ["010100000000", "010000", "01010300", `01010301${setHex(kind)}`],
  },
]

for (const position of positions) {
  describe(`AZ-2436 U11 no-value count in ${position.name}`, () => {
    for (const kind of KINDS) {
      it(`${position.ac} a ${kind} with count 3 and no value is refused, naming member and count (split bit and combined flags)`, () => {
        // Arrange
        const rows = position.refused(kind)

        // Act
        const messages = BITS.flatMap((bit) => rows.map((row) => outcome(position.layout(kind, bit), row)))

        // Assert
        assert.deepEqual(messages, Array<string>(BITS.length * rows.length).fill(NOT_WRITTEN))
      })

      it(`AC-4 a ${kind} with count 0, the count left out or a holding inner when packs as at HEAD`, () => {
        // Arrange
        const rows = position.unchanged(kind)

        // Act
        const wires = BITS.map((bit) => rows.map((row) => outcome(position.layout(kind, bit), row)))

        // Assert
        assert.deepEqual(wires, [position.wires(kind), position.wires(kind)])
      })
    }
  })
}

describe("AZ-2436 a member inside the clear inner when itself is a silent skip, not U11", () => {
  // `when(outer holds) { when(inner clear) { c; <bit> { member } } }`: the member and its bit sit in the clear
  // `when`, so nothing of them is written or looked at; the U11 rule reaches only members outside the clear
  // `when` that holds the count (the positions above). Pinned as observed at b8b2809.
  it("packs only the outer bytes for every kind and bit", () => {
    // Arrange
    const layout = (kind: Kind, bit: Bit): Scheme<Row> =>
      new Scheme<Row>(1, [
        u8(0, (x: Row) => x.o),
        when(1, eq(0, 1), [
          u8(1, (x: Row) => x.mode),
          when(2, eq(1, 1), [u8(2, (x: Row) => x.c), ...behind(bit, 3, member(kind, 3, 2))]),
        ]),
      ])

    // Act
    const wires = KINDS.flatMap((kind) => BITS.map((bit) => outcome(layout(kind, bit), { o: 1, mode: 0, c: 3 })))

    // Assert
    assert.deepEqual(wires, Array<string>(KINDS.length * BITS.length).fill("010100"))
  })
})
