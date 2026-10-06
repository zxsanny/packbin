import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, eq, flagByte, scheme, u8, u16, when, type Scheme } from "../src/index.ts"

type Row = Record<string, unknown>

const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

// The split-form reference scheme: a `when` between the flag byte and its bit.
function reference(): Scheme<Row> {
  const m = flagByte("m")
  return scheme<Row>(
    1,
    u8(0, (x) => x.sid),
    m,
    when(1, eq(0, 9), [u8(1, (x) => x.shape)]),
    m.bit(u16(2, (x) => x.heading)),
  )
}

function unpack(layout: Scheme<Row>, wire: string): Row | undefined {
  let row: Row | undefined
  const result = BinaryPacker.unpack(Buffer.from(wire, "hex"), layout.on((r) => {
    row = r as Row
  }))
  assert.deepEqual(result, { ok: true })
  return row
}

describe("AZ-2115 split-form reference bytes", () => {
  it("AC-1 the reference row packs to 010901045a00 and unpacks to the same row", () => {
    // Arrange
    const layout = reference()
    const row = { sid: 9, shape: 4, heading: 90 }

    // Act
    const wire = hex(BinaryPacker.pack(layout, row))

    // Assert
    assert.equal(wire, "010901045a00")
    assert.deepEqual(unpack(layout, wire), row)
  })

  it("AC-1 the short row packs to 010100 and unpacks to the same row", () => {
    // Arrange
    const layout = reference()
    const row = { sid: 1 }

    // Act
    const wire = hex(BinaryPacker.pack(layout, row))

    // Assert
    assert.equal(wire, "010100")
    assert.deepEqual(unpack(layout, wire), row)
  })
})
