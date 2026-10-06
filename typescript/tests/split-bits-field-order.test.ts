import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  eq,
  flagByte,
  flags,
  group,
  i16,
  i32,
  scheme,
  u8,
  u16,
  when,
  type Scheme,
} from "../src/index.ts"

type Row = Record<string, unknown>

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..")
const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

function unpack(layout: Scheme<Row>, wire: string): Row | undefined {
  let row: Row | undefined
  const result = BinaryPacker.unpack(Buffer.from(wire, "hex"), layout.on((r) => {
    row = r as Row
  }))
  assert.deepEqual(result, { ok: true })
  return row
}

// A split bit is numbered by its place in the scheme among the bits of its flag byte read, not by
// the order the handle's `bit` was called in.
describe("AZ-2135 split bits are numbered by field order", () => {
  it("AC-1 a handle shared by two schemes numbers the bits of each from 0", () => {
    // Arrange
    const m = flagByte("m")
    const first = scheme<Row>(1, m, m.bit(u8(0, (x) => x.x)))
    const second = scheme<Row>(1, m, m.bit(u8(0, (x) => x.x)))

    // Act
    const wires = [first, second].map((layout) => hex(BinaryPacker.pack(layout, { x: 5 })))

    // Assert
    assert.deepEqual(wires, ["010105", "010105"])
  })

  it("AC-1 a handle shared by two 5-bit schemes builds both", () => {
    // Arrange
    const m = flagByte("m")
    const fiveBits = (typeNumber: number): Scheme<Row> =>
      scheme<Row>(
        typeNumber,
        m,
        m.bit(u8(0, (x) => x.f0)),
        m.bit(u8(1, (x) => x.f1)),
        m.bit(u8(2, (x) => x.f2)),
        m.bit(u8(3, (x) => x.f3)),
        m.bit(u8(4, (x) => x.f4)),
      )
    const first = fiveBits(1)
    const second = fiveBits(2)

    // Act
    const wires = [hex(BinaryPacker.pack(first, { f4: 7 })), hex(BinaryPacker.pack(second, { f0: 3, f4: 7 }))]

    // Assert
    assert.deepEqual(wires, ["011007", "02110307"])
    assert.deepEqual(unpack(first, wires[0]!), { f4: 7 })
    assert.deepEqual(unpack(second, wires[1]!), { f0: 3, f4: 7 })
  })

  it("AC-1 bits take their numbers from the scheme order, not the order of the bit calls", () => {
    // Arrange
    const m = flagByte("m")
    const late = m.bit(u8(1, (x) => x.b))
    const early = m.bit(u8(0, (x) => x.a))
    const layout = scheme<Row>(1, m, early, late)

    // Act
    const wire = hex(BinaryPacker.pack(layout, { b: 9 }))

    // Assert
    assert.equal(wire, "010209")
    assert.deepEqual(unpack(layout, wire), { b: 9 })
  })

  it("AC-1 a flag byte read twice numbers the bits of each read from 0", () => {
    // Arrange
    const m = flagByte("m")
    const layout = scheme<Row>(1, m, m.bit(u8(0, (x) => x.a)), m, m.bit(u8(1, (x) => x.b)))

    // Act
    const onlySecond = hex(BinaryPacker.pack(layout, { b: 9 }))
    const both = hex(BinaryPacker.pack(layout, { a: 3, b: 9 }))

    // Assert
    assert.deepEqual([onlySecond, both], ["01000109", "0101030109"])
    assert.deepEqual(unpack(layout, onlySecond), { b: 9 })
    assert.deepEqual(unpack(layout, both), { a: 3, b: 9 })
  })

  it("AC-1 a bit belongs to the latest read of its flag byte, so 8 bits per read build", () => {
    // Arrange
    const m = flagByte("m")
    const accessors = [
      u8(0, (x: Row) => x.a0),
      u8(1, (x: Row) => x.a1),
      u8(2, (x: Row) => x.a2),
      u8(3, (x: Row) => x.a3),
      u8(4, (x: Row) => x.a4),
      u8(5, (x: Row) => x.a5),
      u8(6, (x: Row) => x.a6),
      u8(7, (x: Row) => x.a7),
      u8(8, (x: Row) => x.b0),
      u8(9, (x: Row) => x.b1),
      u8(10, (x: Row) => x.b2),
      u8(11, (x: Row) => x.b3),
      u8(12, (x: Row) => x.b4),
      u8(13, (x: Row) => x.b5),
      u8(14, (x: Row) => x.b6),
      u8(15, (x: Row) => x.b7),
    ]

    // Act
    const layout = scheme<Row>(
      1,
      m,
      ...accessors.slice(0, 8).map((f) => m.bit(f)),
      m,
      ...accessors.slice(8).map((f) => m.bit(f)),
    )
    const wire = hex(BinaryPacker.pack(layout, { a7: 1, b0: 2 }))

    // Assert
    assert.equal(wire, "0180010102")
    assert.deepEqual(unpack(layout, wire), { a7: 1, b0: 2 })
  })

  it("AC-1 a flag byte read inside a when numbers its own bits and does not take the outer ones", () => {
    // Arrange
    const m = flagByte("m")
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.k),
      m,
      when(1, eq(0, 1), [m, m.bit(u8(1, (x) => x.x))]),
      m.bit(u8(2, (x) => x.y)),
    )

    // Act
    const taken = hex(BinaryPacker.pack(layout, { k: 1, x: 5, y: 6 }))
    const skipped = hex(BinaryPacker.pack(layout, { k: 0, y: 6 }))

    // Assert
    assert.deepEqual([taken, skipped], ["010101010506", "01000106"])
    assert.deepEqual(unpack(layout, taken), { k: 1, x: 5, y: 6 })
    assert.deepEqual(unpack(layout, skipped), { k: 0, y: 6 })
  })

  it("AC-1 withLimits keeps the numbering of a flag byte read twice", () => {
    // Arrange
    const m = flagByte("m")
    const layout = scheme<Row>(1, m, m.bit(u8(0, (x) => x.a)), m, m.bit(u8(1, (x) => x.b)))

    // Act
    const wire = hex(BinaryPacker.pack(layout.withLimits({ maxRounds: 3 }), { b: 9 }))

    // Assert
    assert.equal(wire, "01000109")
  })

  it("AC-1 a bit is numbered before the bits nested in its field", () => {
    // Arrange
    const m = flagByte("m")
    const layout = scheme<Row>(
      1,
      m,
      m.bit(group((x) => x.g, [u8(0, (x) => x.y), m.bit(u8(1, (x) => x.x))])),
    )

    // Act
    const outerOnly = hex(BinaryPacker.pack(layout, { y: 1 }))
    const both = hex(BinaryPacker.pack(layout, { y: 1, x: 2 }))

    // Assert
    assert.deepEqual([outerOnly, both], ["010101", "01030102"])
    assert.deepEqual(unpack(layout, outerOnly), { y: 1 })
    assert.deepEqual(unpack(layout, both), { y: 1, x: 2 })
  })

  it("AC-1 the ninth bit of one read is refused when the scheme is built", () => {
    // Arrange
    const m = flagByte("m")
    const nine = [
      u8(0, (x: Row) => x.f0),
      u8(1, (x: Row) => x.f1),
      u8(2, (x: Row) => x.f2),
      u8(3, (x: Row) => x.f3),
      u8(4, (x: Row) => x.f4),
      u8(5, (x: Row) => x.f5),
      u8(6, (x: Row) => x.f6),
      u8(7, (x: Row) => x.f7),
      u8(8, (x: Row) => x.f8),
    ].map((f) => m.bit(f))

    // Act
    const build = () => scheme<Row>(1, m, ...nine)

    // Assert
    assert.throws(build, /^RangeError: flag byte "m": ninth bit \(f8\); a flag byte holds 8 bits$/)
  })

  it("AC-3 the position golden bytes are the same in split form", () => {
    // Arrange
    const golden = readFileSync(join(root, "fixtures/golden.hex"), "utf8").trim()
    const m = flagByte("m")
    const split = scheme<Row>(
      0x40,
      u16(0, (x) => x.sid),
      i32(1, (x) => x.lat),
      i32(2, (x) => x.lon),
      u8(3, (x) => x.profile),
      m,
      m.bit(u16(4, (x) => x.heading)),
      m.bit(u8(5, (x) => x.speed)),
      m.bit(i16(6, (x) => x.altitude)),
    )
    const joined = scheme<Row>(
      0x40,
      u16(0, (x) => x.sid),
      i32(1, (x) => x.lat),
      i32(2, (x) => x.lon),
      u8(3, (x) => x.profile),
      flags(4, [u16(4, (x) => x.heading), u8(5, (x) => x.speed), i16(6, (x) => x.altitude)]),
    )
    const row = { sid: 1, lat: 500_000_000, lon: 300_000_000, profile: 1 }
    const moving = { ...row, speed: 7, altitude: -2 }

    // Act
    const wire = hex(BinaryPacker.pack(split, row))
    const movingWire = hex(BinaryPacker.pack(split, moving))

    // Assert
    assert.equal(wire, golden)
    assert.equal(movingWire, hex(BinaryPacker.pack(joined, moving)))
  })
})
