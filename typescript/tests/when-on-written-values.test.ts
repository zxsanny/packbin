import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  bits,
  bool,
  eq,
  f32,
  flags,
  i16,
  i32,
  packed,
  repeat,
  scheme,
  sized,
  times,
  u8,
  u16,
  when,
  type Field,
} from "../src/index.ts"
import { ACCESSORS, NAMES, random } from "./support/random.ts"

type Row = Record<string, unknown>

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..")
const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

function unpack(layout: Scheme<Row>, wire: string | Uint8Array): { result: { ok: boolean }; row: Row | undefined } {
  let row: Row | undefined
  const bytes = typeof wire === "string" ? Buffer.from(wire, "hex") : wire
  const result = BinaryPacker.unpack(bytes, layout.on((r) => {
    row = r as Row
  }))
  return { result: result as { ok: boolean }, row }
}

// `p; when(p == 0) { n }; <tail>`: a count or a second `when` names `n`, which the first `when` can skip.
const skipN = (tail: Field): Scheme<Row> =>
  scheme<Row>(1, u8(0, (x) => x.p), when(1, eq(0, 0), [u8(1, (x) => x.n)]), tail)

describe("when and counts read what pack wrote", () => {
  it("AC-1 a when on a field that another when skipped does not match", () => {
    // Arrange
    const layout = skipN(when(2, eq(1, 0), [u8(2, (x) => x.v)]))

    // Act
    const wire = hex(BinaryPacker.pack(layout, { p: 1, n: 0, v: 4 }))
    const { result, row } = unpack(layout, wire)

    // Assert
    assert.equal(wire, "0101")
    assert.deepEqual(result, { ok: true })
    assert.equal(row!.p, 1)
  })

  it("AC-1 the same chain writes both bodies when the first when matches", () => {
    // Arrange
    const layout = skipN(when(2, eq(1, 0), [u8(2, (x) => x.v)]))

    // Act
    const wire = hex(BinaryPacker.pack(layout, { p: 0, n: 0, v: 4 }))
    const { row } = unpack(layout, wire)

    // Assert
    assert.equal(wire, "01000004")
    assert.deepEqual(row, { p: 0, n: 0, v: 4 })
  })

  it("AC-2 a when on a field skipped in the round does not match", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [
        u8(0, (x) => x.k),
        when(1, eq(0, 1), [u8(1, (x) => x.a)]),
        when(2, eq(1, 5), [u8(2, (x) => x.b)]),
      ]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { k: [0], a: [5], b: [3] }))
    const { result, row } = unpack(layout, wire)

    // Assert
    assert.equal(wire, "0100")
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(row, { k: [0], a: [undefined], b: [undefined] })
  })

  it("AC-3 a sibling when in a round still reads the earlier field", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [u8(0, (x) => x.k), when(1, eq(0, 1), [u8(1, (x) => x.v)])]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { k: [1, 2], v: [9] }))

    // Assert
    assert.equal(wire, "01010902")
  })

  it("AC-3 the golden bytes are unchanged", () => {
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

  it("AC-4 a sized count that names a skipped field throws naming it", () => {
    // Arrange
    const layout = skipN(sized(2, (x) => x.data, 1))

    // Act
    const pack = () => BinaryPacker.pack(layout, { p: 1, n: 2, data: Uint8Array.of(1, 2) })

    // Assert
    assert.throws(pack, new RangeError("data: count n was not written"))
  })

  it("AC-4 a bits count that names a skipped field throws naming it", () => {
    // Arrange
    const layout = skipN(bits(2, (x) => x.data, 1))

    // Act
    const pack = () => BinaryPacker.pack(layout, { p: 1, n: 2, data: [1, 0] })

    // Assert
    assert.throws(pack, new RangeError("data: count n was not written"))
  })

  it("AC-4 a packed count that names a skipped field throws naming it", () => {
    // Arrange
    const layout = skipN(packed(2, 2, (x) => x.data, 1))

    // Act
    const pack = () => BinaryPacker.pack(layout, { p: 1, n: 2, data: [1, 2] })

    // Assert
    assert.throws(pack, new RangeError("data: count n was not written"))
  })

  it("AC-4 a times count that names a skipped field throws naming it", () => {
    // Arrange
    const layout = skipN(times(2, 1, [u8(2, (x) => x.x)]))

    // Act
    const pack = () => BinaryPacker.pack(layout, { p: 1, n: 2, x: [1, 2] })

    // Assert
    assert.throws(pack, new RangeError("times: count n was not written"))
  })

  it("AC-4 a count that names a skipped field inside a round throws naming it", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [
        u8(0, (x) => x.k),
        when(1, eq(0, 1), [u8(1, (x) => x.n)]),
        packed(2, 2, (x) => x.data, 1),
      ]),
    )

    // Act
    const pack = () => BinaryPacker.pack(layout, { k: [0], n: [3], data: [[1, 2, 3]] })

    // Assert
    assert.throws(pack, new RangeError("data: count n was not written"))
  })

  it("AC-4 counts that name a field written earlier in the scope are unchanged", () => {
    // Arrange
    const layouts = [
      skipN(sized(2, (x) => x.data, 1)),
      skipN(bits(2, (x) => x.data, 1)),
      skipN(packed(2, 2, (x) => x.data, 1)),
      skipN(times(2, 1, [u8(2, (x) => x.x)])),
    ]
    const rows: Row[] = [
      { p: 0, n: 2, data: Uint8Array.of(7, 8) },
      { p: 0, n: 2, data: [1, 0] },
      { p: 0, n: 2, data: [1, 2] },
      { p: 0, n: 2, x: [5, 6] },
    ]

    // Act
    const wires = layouts.map((layout, i) => hex(BinaryPacker.pack(layout, rows[i]!)))

    // Assert
    assert.deepEqual(wires, ["010002" + "0708", "0100" + "02" + "01", "0100" + "02" + "09", "0100" + "02" + "0506"])
  })

  it("AC-5 a when on a clear flag bit does not match", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      flags(0, [bool(0, (x) => x.on)]),
      when(1, eq(0, false), [u8(1, (x) => x.v)]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { on: false, v: 7 }))
    const { result } = unpack(layout, wire)

    // Assert
    assert.equal(wire, "0100")
    assert.deepEqual(result, { ok: true })
  })

  it("AC-5 a when on a set flag bit still matches", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      flags(0, [bool(0, (x) => x.on)]),
      when(1, eq(0, true), [u8(1, (x) => x.v)]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { on: true, v: 7 }))
    const { row } = unpack(layout, wire)

    // Assert
    assert.equal(wire, "010107")
    assert.deepEqual(row, { on: true, v: 7 })
  })

  it("a when on an unwritten field compares undefined, as unpack does (flag bit clear)", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      flags(0, [u8(0, (x) => x.a)]),
      when(1, eq(0, undefined), [u8(1, (x) => x.b)]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { b: 7 }))
    const { result, row } = unpack(layout, wire)

    // Assert
    assert.equal(wire, "010007")
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(row, { b: 7 })
  })

  it("a when on an unwritten field compares undefined, as unpack does (field skipped by a when)", () => {
    // Arrange
    const layout = skipN(when(2, eq(1, undefined), [u8(2, (x) => x.v)]))

    // Act
    const wire = hex(BinaryPacker.pack(layout, { p: 1, v: 4 }))
    const { result, row } = unpack(layout, wire)

    // Assert
    assert.equal(wire, "010104")
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(row, { p: 1, v: 4 })
  })

  it("an f32 is tested as the reader sees it, rounded to 32 bits", () => {
    // Arrange
    const unrounded = scheme<Row>(1, f32(0, (x) => x.x), when(1, eq(0, 0.1), [u8(1, (x) => x.v)]))
    const rounded = scheme<Row>(1, f32(0, (x) => x.x), when(1, eq(0, Math.fround(0.1)), [u8(1, (x) => x.v)]))

    // Act
    const first = hex(BinaryPacker.pack(unrounded, { x: 0.1, v: 5 }))
    const second = hex(BinaryPacker.pack(rounded, { x: 0.1, v: 5 }))

    // Assert
    assert.equal(first, "01cdcccc3d")
    assert.equal(second, "01cdcccc3d05")
    assert.deepEqual(unpack(unrounded, first).result, { ok: true })
    assert.deepEqual(unpack(rounded, second).result, { ok: true })
  })
})

// A seeded chain of `when`s over small values, so bodies are skipped and matched often. Each `when`
// tests an earlier field, which an earlier `when` may have skipped.
describe("pack never writes what its own unpack cannot read", () => {
  function chain(rand: () => number): { fields: Field[]; names: string[] } {
    const names: string[] = []
    const fields: Field[] = [u8(0, ACCESSORS[NAMES[0]])]
    names.push(NAMES[0])
    let id = 1
    const count = 2 + Math.floor(rand() * 4)
    for (let i = 0; i < count; i++) {
      const tested = Math.floor(rand() * id)
      const anchor = id
      const body: Field[] = []
      const inside = 1 + Math.floor(rand() * 2)
      for (let j = 0; j < inside; j++) {
        const name = NAMES[names.length]!
        names.push(name)
        body.push(u8(id + j, ACCESSORS[name]))
      }
      id += inside
      fields.push(when(anchor, eq(tested, Math.floor(rand() * 3)), body))
    }
    return { fields, names }
  }

  it("AC-1 a top-level chain reads back what was written", () => {
    // Arrange
    const rand = random(2197)
    let checked = 0

    for (let n = 0; n < 500; n++) {
      const { fields, names } = chain(rand)
      const layout = scheme<Row>(1, ...fields)
      for (let r = 0; r < 20; r++) {
        const row: Row = {}
        for (const name of names) row[name] = Math.floor(rand() * 3)

        // Act
        const wire = BinaryPacker.pack(layout, row)
        const back = unpack(layout, wire)
        checked++

        // Assert
        assert.deepEqual(back.result, { ok: true }, `${JSON.stringify(row)} -> ${hex(wire)}`)
        assert.equal(hex(BinaryPacker.pack(layout, back.row!)), hex(wire))
      }
    }
    assert.equal(checked, 10_000)
  })

  it("AC-2 a round chain reads back what was written", () => {
    // Arrange
    const rand = random(2198)

    for (let n = 0; n < 500; n++) {
      const layout = scheme<Row>(
        1,
        repeat(0, [
          u8(0, ACCESSORS.a),
          when(1, eq(0, Math.floor(rand() * 3)), [u8(1, ACCESSORS.b)]),
          when(2, eq(Math.floor(rand() * 2), Math.floor(rand() * 3)), [u8(2, ACCESSORS.c)]),
        ]),
      )
      for (let r = 0; r < 20; r++) {
        const rounds = 1 + Math.floor(rand() * 3)
        const list = () => Array.from({ length: rounds }, () => Math.floor(rand() * 3))
        const row: Row = { a: list(), b: list(), c: list() }

        // Act
        const wire = BinaryPacker.pack(layout, row)
        const back = unpack(layout, wire)

        // Assert
        assert.deepEqual(back.result, { ok: true }, `${JSON.stringify(row)} -> ${hex(wire)}`)
        assert.equal(hex(BinaryPacker.pack(layout, back.row!)), hex(wire))
      }
    }
  })
})
