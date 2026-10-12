import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, Scheme, bool, eq, flagByte, flags, group, repeat, times, u2, u8, when } from "../src/index.ts"

// AZ-2383 (U3): a non-empty list shorter than the rounds of a repeat, under a member a flag bit can leave
// absent (under `flags` or a flag bit, also through a when or group), is refused. The row that packed
// `010101050200` before is the full list `v: [5, undefined]` now.

type Row = Record<string, unknown>

const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

const refusal = (run: () => unknown): string => {
  let message = ""
  assert.throws(run, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

const short = (member: string, items: number, count: number): string =>
  `${member}: ${items} items, repeat count ${count}; give one entry per round, undefined where the member is absent`

// repeat { u8 w; flags { u8 v } }
const optionalU8 = (): Scheme<Row> =>
  new Scheme<Row>(1, [repeat(0, [u8(0, (x) => x.w), flags(1, [u8(1, (x) => x.v)])])])

describe("AZ-2383 a short list in an optional flags position of a repeat is refused", () => {
  it("AC-1 the U3 row {w: [1, 2], v: [5]} is refused naming v, with no bytes", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(optionalU8(), { w: [1, 2], v: [5] }))

    // Assert
    assert.equal(message, short("v", 1, 2))
  })

  it("AC-1 three rounds and two entries is refused the same way", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(optionalU8(), { w: [1, 2, 3], v: [5, undefined] }))

    // Assert
    assert.equal(message, short("v", 2, 3))
  })

  it("AC-1 a bool, a split bit, a group member, a u2 slot and a when under flags are refused the same way", () => {
    // Arrange
    const fb = flagByte("m")
    const bools = new Scheme<Row>(1, [repeat(0, [u8(0, (x) => x.w), flags(1, [bool(1, (x) => x.on)])])])
    const split = new Scheme<Row>(1, [repeat(0, [u8(0, (x) => x.w), fb, fb.bit(u8(1, (x) => x.v))])])
    const grouped = new Scheme<Row>(1, [
      repeat(0, [u8(0, (x) => x.w), flags(1, [group(1, (x) => x.g, [u8(1, (x) => x.v)])])]),
    ])
    const slots = new Scheme<Row>(1, [
      repeat(0, [u8(0, (x) => x.w), flags(1, [u2(1, (x) => x.p, 2, (x) => x.q)])]),
    ])
    const conditional = new Scheme<Row>(1, [
      repeat(0, [u8(0, (x) => x.w), flags(1, [when(1, eq(0, 1), [u8(1, (x) => x.v)])])]),
    ])

    // Act
    const messages = [
      refusal(() => BinaryPacker.pack(bools, { w: [1, 2], on: [true] })),
      refusal(() => BinaryPacker.pack(split, { w: [1, 2], v: [5] })),
      refusal(() => BinaryPacker.pack(grouped, { w: [1, 2], v: [5] })),
      refusal(() => BinaryPacker.pack(slots, { w: [1, 2], p: [1], q: [2, 3] })),
      refusal(() => BinaryPacker.pack(conditional, { w: [1, 1], v: [5] })),
    ]

    // Assert
    assert.deepEqual(messages, [
      short("on", 1, 2),
      short("v", 1, 2),
      short("v", 1, 2),
      short("p", 1, 2),
      short("v", 1, 2),
    ])
  })

  it("AC-1 in a combined flags the short member is the one named, whichever list is longer", () => {
    // Arrange
    const layout = new Scheme<Row>(1, [repeat(0, [flags(0, [u8(0, (x) => x.a), u8(1, (x) => x.b)])])])

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, { a: [1], b: [5, 6] }))

    // Assert
    assert.equal(message, short("a", 1, 2))
  })

  it("AC-2 the full list packs to the bytes the short list gave before", () => {
    // Act
    const undef = hex(BinaryPacker.pack(optionalU8(), { w: [1, 2], v: [5, undefined] }))
    const nulled = hex(BinaryPacker.pack(optionalU8(), { w: [1, 2], v: [5, null] }))

    // Assert
    assert.equal(undef, "010101050200")
    assert.equal(nulled, "010101050200")
  })

  it("AC-2 accepted rows keep their bytes: both entries, no entry, an empty list, a lone value", () => {
    // Act
    const rows = [
      { w: [1, 2], v: [5, 6] },
      { w: [1, 2] },
      { w: [1, 2], v: [] },
      { w: [1, 2], v: 5 },
    ].map((row) => hex(BinaryPacker.pack(optionalU8(), row)))

    // Assert
    assert.deepEqual(rows, ["01010105020106", "0101000200", "0101000200", "01010105020105"])
  })

  it("AC-2 the bool full list packs and sets the bit only where it is true", () => {
    // Arrange
    const bools = new Scheme<Row>(1, [repeat(0, [u8(0, (x) => x.w), flags(1, [bool(1, (x) => x.on)])])])

    // Act
    const wire = hex(BinaryPacker.pack(bools, { w: [1, 2], on: [true, undefined] }))

    // Assert
    assert.equal(wire, "0101010200")
  })
})

describe("AZ-2383 what the rule does not touch", () => {
  it("a times keeps its short-list rule: a short list under flags is absent for the missing rounds", () => {
    // Arrange
    const layout = new Scheme<Row>(1, [u8(0, (x) => x.c), times(1, 0, [flags(1, [u8(1, (x) => x.v)])])])

    // Act
    const wire = hex(BinaryPacker.pack(layout, { c: 2, v: [5] }))

    // Assert
    assert.equal(wire, "0102010500")
  })

  it("a member under a when outside flags keeps its short list (the README repeat(k, when(k == 1, v)) row)", () => {
    // Arrange
    const layout = new Scheme<Row>(1, [
      repeat(0, [u8(0, (x) => x.k), when(1, eq(0, 1), [u8(1, (x) => x.v)])]),
    ])

    // Act
    const wire = hex(BinaryPacker.pack(layout, { k: [1, 2], v: [9] }))

    // Assert
    assert.equal(wire, "01010902")
  })

  it("a required member keeps its own error for a short list", () => {
    // Arrange
    const layout = new Scheme<Row>(1, [repeat(0, [u8(0, (x) => x.a), u8(1, (x) => x.b)])])

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, { a: [1, 2], b: [3] }))

    // Assert
    assert.equal(message, "missing b")
  })

  it("a short list for the required member beside an optional one is still missing, not repeat count", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(optionalU8(), { w: [1], v: [5, 6] }))

    // Assert
    assert.equal(message, "missing w")
  })
})
