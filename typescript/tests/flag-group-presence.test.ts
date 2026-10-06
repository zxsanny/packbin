import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  bits,
  flags,
  group,
  i16,
  i32,
  packed,
  scheme,
  sized,
  u2,
  u8,
  u16,
} from "../src/index.ts"

type Row = Record<string, unknown>

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..")
const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

function unpackRow(layout: Scheme<Row>, wire: string): Row {
  let got: Row | undefined
  const result = BinaryPacker.unpack(Buffer.from(wire, "hex"), layout.on((row) => {
    got = row as Row
  }))
  assert.deepEqual(result, { ok: true }, wire)
  return got!
}

// The row packs to `wire`, and the row read back from `wire` packs to `wire` again.
function roundTrips(layout: Scheme<Row>, row: Row, wire: string): Row {
  assert.equal(hex(BinaryPacker.pack(layout, row)), wire)
  const back = unpackRow(layout, wire)
  assert.equal(hex(BinaryPacker.pack(layout, back)), wire)
  return back
}

const u2Only = () =>
  scheme<Row>(1, flags(0, [group(0, (x) => x.g, [u2(0, (x) => x.p, 1, (x) => x.q)])]))

const bitsOnly = () =>
  scheme<Row>(
    1,
    u8(0, (x) => x.n),
    flags(1, [group(1, (x) => x.g, [bits(1, (x) => x.b, 0)])]),
  )

const sizedOnly = () =>
  scheme<Row>(
    1,
    u8(0, (x) => x.n),
    flags(1, [group(1, (x) => x.g, [sized(1, (x) => x.d, 0)])]),
  )

const packedOnly = () =>
  scheme<Row>(
    1,
    u8(0, (x) => x.n),
    flags(1, [group(1, (x) => x.g, [packed(2, 1, (x) => x.k, 0)])]),
  )

const nestedFlags = () =>
  scheme<Row>(1, flags(0, [group(0, (x) => x.g, [flags(0, [u8(0, (x) => x.n)])])]))

const nestedGroup = () =>
  scheme<Row>(
    1,
    flags(0, [group(0, (x) => x.g, [group(0, (x) => x.h, [u8(0, (x) => x.n)])])]),
  )

const siblingAndFlags = () =>
  scheme<Row>(
    1,
    flags(0, [group(0, (x) => x.g, [u8(0, (x) => x.a), flags(1, [u8(1, (x) => x.c)])])]),
  )

describe("a flags group is on when any value inside it is present", () => {
  it("AC-1 a u2-only group sets its bit and round-trips", () => {
    // Arrange
    const layout = u2Only()

    // Act
    const back = roundTrips(layout, { p: 1, q: 2 }, "010109")

    // Assert
    assert.deepEqual(back, { p: 1, q: 2 })
  })

  it("AC-1 a u2-only group given as a nested object packs the same bytes", () => {
    // Arrange
    const layout = u2Only()

    // Act
    const wire = hex(BinaryPacker.pack(layout, { g: { p: 1, q: 2 } }))

    // Assert
    assert.equal(wire, "010109")
  })

  it("AC-1 an anchored bits-only group sets its bit and round-trips", () => {
    // Arrange
    const layout = bitsOnly()

    // Act
    const back = roundTrips(layout, { n: 8, b: [1, 0, 1, 0, 1, 0, 1, 0] }, "01080155")

    // Assert
    assert.deepEqual(back, { n: 8, b: [1, 0, 1, 0, 1, 0, 1, 0] })
  })

  it("AC-1 a sized-only group sets its bit and round-trips", () => {
    // Arrange
    const layout = sizedOnly()

    // Act
    const back = roundTrips(layout, { n: 1, d: Uint8Array.of(9) }, "01010109")

    // Assert
    assert.deepEqual(back, { n: 1, d: Uint8Array.of(9) })
  })

  it("AC-1 a packed-only group sets its bit and round-trips", () => {
    // Arrange
    const layout = packedOnly()

    // Act
    const back = roundTrips(layout, { n: 2, k: [1, 2] }, "01020109")

    // Assert
    assert.deepEqual(back, { n: 2, k: [1, 2] })
  })

  it("AC-1 a group holding only flags packs from the flat unpacked row", () => {
    // Arrange
    const layout = nestedFlags()

    // Act
    const back = roundTrips(layout, { n: 5 }, "01010105")

    // Assert
    assert.deepEqual(back, { n: 5 })
  })

  it("AC-1 a group holding only a nested group packs from the flat unpacked row", () => {
    // Arrange
    const layout = nestedGroup()

    // Act
    const back = roundTrips(layout, { n: 5 }, "010105")

    // Assert
    assert.deepEqual(back, { n: 5 })
  })

  it("an absent group keeps its bit clear", () => {
    // Arrange
    const cases: [Scheme<Row>, Row, string][] = [
      [u2Only(), {}, "0100"],
      [bitsOnly(), { n: 1 }, "010100"],
      [sizedOnly(), { n: 1 }, "010100"],
      [packedOnly(), { n: 1 }, "010100"],
      [nestedFlags(), {}, "0100"],
      [nestedGroup(), {}, "0100"],
    ]

    // Act
    const wires = cases.map(([layout, row]) => hex(BinaryPacker.pack(layout, row)))

    // Assert
    assert.deepEqual(wires, cases.map(([, , wire]) => wire))
  })

  it("AC-2 a nested container with a value and a missing sibling fails naming the sibling", () => {
    // Arrange
    const layout = siblingAndFlags()

    // Act
    const flat = () => BinaryPacker.pack(layout, { c: 2 })
    const nested = () => BinaryPacker.pack(layout, { g: { c: 2 } })

    // Assert
    assert.throws(flat, new RangeError("missing a"))
    assert.throws(nested, new RangeError("missing a"))
  })

  it("AC-2 a u2 group with one slot set fails naming the slot that is missing", () => {
    // Arrange
    const layout = u2Only()

    // Act
    const pack = () => BinaryPacker.pack(layout, { p: 1 })

    // Assert
    assert.throws(pack, new RangeError("q: expected 2-bit int"))
  })

  it("a u2 group with only its second slot set is on, and fails naming the first slot", () => {
    // Arrange
    const layout = u2Only()

    // Act
    const pack = () => BinaryPacker.pack(layout, { q: 1 })

    // Assert
    assert.throws(pack, new RangeError("p: expected 2-bit int"))
  })

  it("AC-2 the sibling and the nested value together still pack", () => {
    // Arrange
    const layout = siblingAndFlags()

    // Act
    const back = roundTrips(layout, { a: 1, c: 2 }, "0101010102")

    // Assert
    assert.deepEqual(back, { a: 1, c: 2 })
  })

  it("AC-3 the position golden bytes are unchanged", () => {
    // Arrange
    const golden = readFileSync(join(root, "fixtures/golden.hex"), "utf8").trim()
    const position = scheme<Row>(
      0x40,
      u16(0, (x) => x.sid),
      i32(1, (x) => x.lat),
      i32(2, (x) => x.lon),
      u8(3, (x) => x.profile),
      flags(4, [u16(4, (x) => x.heading), u8(5, (x) => x.speed), i16(6, (x) => x.altitude)]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(position, { sid: 1, lat: 500_000_000, lon: 300_000_000, profile: 1 }))

    // Assert
    assert.equal(wire, golden)
  })
})
