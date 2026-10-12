import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, Scheme, list, times, u8, u32, type Field } from "../src/index.ts"

// AZ-2391 (F34): the cost of one round or one list item does not grow with the fields around it. The test
// compares two sizes in one run (a ratio), never an absolute time.

type Row = Record<string, unknown>

const accessor = (name: string): ((x: Row) => unknown) => new Function("x", `return x.${name}`) as (x: Row) => unknown

// `fill` top-level u8 fields f0..., then the body field; every fill field is given once.
function withFill(fill: number, body: (id: number) => Field[], row: Row): { layout: Scheme<Row>; row: Row } {
  const fields: Field[] = [u32(0, accessor("n"))]
  const values: Row = { ...row }
  for (let i = 0; i < fill; i++) {
    fields.push(u8(i + 1, accessor(`f${i}`)))
    values[`f${i}`] = 1
  }
  fields.push(...body(fill + 1))
  return { layout: new Scheme<Row>(1, fields), row: values }
}

const timesOfU8 = (rounds: number, fill: number) =>
  withFill(fill, (id) => [times(id, 0, [u8(id, accessor("k"))])], { n: rounds, k: Array(rounds).fill(7) })

const listOfU8 = (items: number, fill: number) =>
  withFill(fill, () => [list(accessor("xs"), u8(0, accessor("e")))], { n: 0, xs: Array(items).fill(7) })

// The best of a few runs, after one warm-up, so a collector pause in one run does not decide the ratio.
function best(layout: Scheme<Row>, row: Row): { ms: number; bytes: Uint8Array } {
  let bytes = BinaryPacker.pack(layout, row)
  let ms = Infinity
  for (let run = 0; run < 3; run++) {
    const started = performance.now()
    bytes = BinaryPacker.pack(layout, row)
    ms = Math.min(ms, performance.now() - started)
  }
  return { ms, bytes }
}

describe("AZ-2391 the cost of a round does not grow with the fields around it", () => {
  it("AC-1 times(65535) { u8 } with 1000 top-level fields packs within 2x the 100-field time", () => {
    // Arrange
    const small = timesOfU8(65_535, 100)
    const large = timesOfU8(65_535, 1000)

    // Act
    const a = best(small.layout, small.row)
    const b = best(large.layout, large.row)

    // Assert
    assert.equal(a.bytes.length, 1 + 4 + 100 + 65_535)
    assert.equal(b.bytes.length, 1 + 4 + 1000 + 65_535)
    assert.ok(b.ms <= 2 * a.ms + 5, `100 fields ${a.ms.toFixed(1)} ms, 1000 fields ${b.ms.toFixed(1)} ms`)
  })

  it("AC-1 a list of 65535 u8 items with 1000 top-level fields packs within 2x the 100-field time", () => {
    // Arrange
    const small = listOfU8(65_535, 100)
    const large = listOfU8(65_535, 1000)

    // Act
    const a = best(small.layout, small.row)
    const b = best(large.layout, large.row)

    // Assert
    assert.equal(a.bytes.length, 1 + 4 + 100 + 2 + 65_535)
    assert.equal(b.bytes.length, 1 + 4 + 1000 + 2 + 65_535)
    assert.ok(b.ms <= 2 * a.ms + 5, `100 fields ${a.ms.toFixed(1)} ms, 1000 fields ${b.ms.toFixed(1)} ms`)
  })

  it("AC-2 the bytes are those of a copy: the count and the fields before the times are written as before", () => {
    // Arrange
    const { layout, row } = timesOfU8(3, 2)

    // Act
    const wire = Buffer.from(BinaryPacker.pack(layout, row)).toString("hex")

    // Assert
    assert.equal(wire, "0103000000" + "0101" + "070707")
  })
})
