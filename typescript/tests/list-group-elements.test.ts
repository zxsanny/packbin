import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  bool,
  dict,
  flags,
  group,
  list,
  repeat,
  scheme,
  sized,
  u8,
  u16,
  utf8,
  type Field,
} from "../src/index.ts"

type Row = Record<string, unknown>

const bytesOf = (h: string): Uint8Array => Uint8Array.from(Buffer.from(h, "hex"))
const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

const pair = (): Field => group((x) => x.p, [u8(0, (p) => p.a), u8(1, (p) => p.b)])
const optional = (): Field => flags(0, [u8(0, (p) => p.a), u16(1, (p) => p.b)])

function unpack(layout: Scheme<Row>, h: string): { result: unknown; row: Row | undefined } {
  let row: Row | undefined
  const result = BinaryPacker.unpack(bytesOf(h), layout.on((r) => {
    row = r as Row
  }))
  return { result, row }
}

function repacks(layout: Scheme<Row>, wire: string): void {
  const { row } = unpack(layout, wire)
  assert.equal(hex(BinaryPacker.pack(layout, row!)), wire)
}

describe("list and dict elements of kind group and flags", () => {
  it("AC-1 list of group packs each item", () => {
    // Arrange
    const layout = scheme<Row>(1, list((x) => x.pts, pair()))

    // Act
    const wire = BinaryPacker.pack(layout, { pts: [{ a: 1, b: 2 }, { a: 3, b: 4 }] })

    // Assert
    assert.equal(hex(wire), "01020001020304")
  })

  it("AC-2 list of group unpacks each item", () => {
    // Arrange
    const layout = scheme<Row>(1, list((x) => x.pts, pair()))

    // Act
    const { result, row } = unpack(layout, "01020001020304")

    // Assert
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(row!.pts, [{ a: 1, b: 2 }, { a: 3, b: 4 }])
    repacks(layout, "01020001020304")
  })

  it("AC-3 dict of group keeps each entry", () => {
    // Arrange
    const layout = scheme<Row>(1, dict((x) => x.m, pair()))
    const wire = "01020001007801020100790304"

    // Act
    const packed = BinaryPacker.pack(layout, { m: { y: { a: 3, b: 4 }, x: { a: 1, b: 2 } } })
    const { result, row } = unpack(layout, wire)

    // Assert
    assert.equal(hex(packed), wire)
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(row!.m, { x: { a: 1, b: 2 }, y: { a: 3, b: 4 } })
    repacks(layout, wire)
  })

  it("AC-4 list of flags is accepted and matches Python", () => {
    // Arrange
    const layout = scheme<Row>(1, list((x) => x.pts, optional()))
    const wire = "010300010100020200"

    // Act
    const packed = BinaryPacker.pack(layout, { pts: [{ a: 1 }, {}, { b: 2 }] })
    const { result, row } = unpack(layout, wire)

    // Assert
    assert.equal(hex(packed), wire)
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(row!.pts, [{ a: 1 }, {}, { b: 2 }])
    repacks(layout, wire)
  })

  it("AC-4 dict of flags is accepted", () => {
    // Arrange
    const layout = scheme<Row>(1, dict((x) => x.m, optional()))
    const wire = "01" + "0200" + "0100" + "78" + "00" + "0100" + "79" + "02" + "0200"

    // Act
    const packed = BinaryPacker.pack(layout, { m: { y: { b: 2 }, x: {} } })
    const { row } = unpack(layout, wire)

    // Assert
    assert.equal(hex(packed), wire)
    assert.deepEqual(row!.m, { x: {}, y: { b: 2 } })
  })

  it("AC-5 a short group element is an error with no row", () => {
    // Arrange
    const layout = scheme<Row>(1, list((x) => x.pts, pair()))

    // Act
    const { result, row } = unpack(layout, "010200010203")

    // Assert
    assert.deepEqual(result, { ok: false, field: "b", needed: 1, left: 0 })
    assert.equal(row, undefined)
  })

  it("AC-5 a short flags element is an error with no row", () => {
    // Arrange
    const layout = scheme<Row>(1, list((x) => x.pts, optional()))

    // Act
    const { result, row } = unpack(layout, "01" + "0100" + "02" + "05")

    // Assert
    assert.deepEqual(result, { ok: false, field: "b", needed: 2, left: 1 })
    assert.equal(row, undefined)
  })

  it("AC-6 leaf elements keep their bytes", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      list((x) => x.ids, u16(0, (x) => x.id)),
      dict((x) => x.names, utf8(0, (x) => x.name)),
    )
    const row = { ids: [1, 2], names: { k: "v" } }

    // Act
    const wire = BinaryPacker.pack(layout, row)

    // Assert
    assert.equal(hex(wire), "01" + "0200" + "0100" + "0200" + "0100" + "0100" + "6b" + "0100" + "76")
    repacks(layout, hex(wire))
  })

  it("an absent required member throws on pack, naming it", () => {
    // Arrange
    const layout = scheme<Row>(1, list((x) => x.pts, pair()))

    // Act
    const pack = () => BinaryPacker.pack(layout, { pts: [{ a: 1, b: 2 }, { a: 3 }] })

    // Assert
    assert.throws(pack, (e: unknown) => e instanceof RangeError && e.message === "missing b")
  })

  it("an item that is not an object throws on pack, naming the list", () => {
    // Arrange
    const layout = scheme<Row>(1, list((x) => x.pts, pair()))

    // Act
    const pack = () => BinaryPacker.pack(layout, { pts: [7] })

    // Assert
    assert.throws(pack, (e: unknown) => e instanceof RangeError && e.message.includes("pts"))
  })

  it("an item may be a class instance", () => {
    // Arrange
    class Point {
      a = 1
      b = 2
    }
    const layout = scheme<Row>(1, list((x) => x.pts, pair()))

    // Act
    const wire = BinaryPacker.pack(layout, { pts: [new Point()] })

    // Assert
    assert.equal(hex(wire), "01" + "0100" + "01" + "02")
  })

  it("element members do not collide with row members of the same name", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.a),
      list((x) => x.pts, pair()),
    )
    const wire = "01" + "09" + "0100" + "0102"

    // Act
    const packed = BinaryPacker.pack(layout, { a: 9, pts: [{ a: 1, b: 2 }] })
    const { row } = unpack(layout, wire)

    // Assert
    assert.equal(hex(packed), wire)
    assert.equal(row!.a, 9)
    assert.deepEqual(row!.pts, [{ a: 1, b: 2 }])
  })

  it("a reference inside an element reads the item it sits in", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      list((x) => x.rows, group((x) => x.row, [u8(0, (r) => r.n), sized(1, (r) => r.d, 0)])),
    )
    const wire = "01" + "0200" + "01" + "aa" + "02" + "0102"
    const row = { rows: [{ n: 1, d: bytesOf("aa") }, { n: 2, d: bytesOf("0102") }] }

    // Act
    const packed = BinaryPacker.pack(layout, row)
    const { row: got } = unpack(layout, wire)

    // Assert
    assert.equal(hex(packed), wire)
    assert.deepEqual(got!.rows, row.rows)
  })

  it("a list inside a group element has its own ids and items", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      list(
        (x) => x.pts,
        group((x) => x.p, [u8(0, (p) => p.a), list((p) => p.tags, u8(0, (t) => t.t))]),
      ),
    )
    const wire = "01" + "0200" + "01" + "0200" + "0708" + "02" + "0000"

    // Act
    const packed = BinaryPacker.pack(layout, {
      pts: [{ a: 1, tags: [7, 8] }, { a: 2, tags: [] }],
    })
    const { row } = unpack(layout, wire)

    // Assert
    assert.equal(hex(packed), wire)
    assert.deepEqual(row!.pts, [{ a: 1, tags: [7, 8] }, { a: 2, tags: [] }])
  })

  it("a group element in a repeat round packs the items of each round", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [u8(0, (x) => x.k), list((x) => x.rows, pair())]),
    )
    const rows = [[{ a: 1, b: 2 }], [{ a: 3, b: 4 }, { a: 5, b: 6 }]]
    const wire = "01" + "01" + "0100" + "0102" + "02" + "0200" + "0304" + "0506"

    // Act
    const packed = BinaryPacker.pack(layout, { k: [1, 2], rows })
    const { row } = unpack(layout, wire)

    // Assert
    assert.equal(hex(packed), wire)
    assert.deepEqual(row!.rows, rows)
  })

  it("a flags element keeps its flag byte apart from the flags of the row", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      flags(0, [u8(0, (x) => x.t)]),
      list((x) => x.pts, flags(0, [u8(0, (p) => p.a)])),
    )
    const wire = "01" + "01" + "05" + "0200" + "01" + "01" + "00"

    // Act
    const packed = BinaryPacker.pack(layout, { t: 5, pts: [{ a: 1 }, {}] })
    const { row } = unpack(layout, wire)

    // Assert
    assert.equal(hex(packed), wire)
    assert.deepEqual(row, { t: 5, pts: [{ a: 1 }, {}] })
  })

  it("a bool in a flags element sets its bit only for true", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      list((x) => x.pts, flags(0, [bool(0, (p) => p.on), u8(1, (p) => p.n)])),
    )
    const items = [{ on: true, n: 3 }, { n: 4 }, { on: true }]
    const wire = "01" + "0300" + "03" + "03" + "02" + "04" + "01"

    // Act
    const packed = BinaryPacker.pack(layout, { pts: items })
    const { row } = unpack(layout, wire)

    // Assert
    assert.equal(hex(packed), wire)
    assert.deepEqual(row!.pts, items)
  })

  it("a flags element anchor must be 0, like every element id", () => {
    // Arrange
    const build = () => list((x) => x.pts, flags(1, [u8(1, (p) => p.a)]))

    // Act
    const refused = () => new Scheme<Row>(1, [build()])

    // Assert
    assert.throws(refused, (e: unknown) => e instanceof RangeError && e.message === "field id: expected 0, got 1")
  })
})
