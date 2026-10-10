import assert from "node:assert/strict"
import { it } from "node:test"
import { BinaryPacker, type Scheme } from "../../src/index.ts"

export type Row = Record<string, unknown>

// One row of the loop-18 reference table: `packs` is the pinned hex of the row, `unpacks` the row read
// back from it. `old` marks a packet an earlier build wrote; it is only unpacked.
export type Case = {
  name: string
  layout: Scheme<Row>
  row?: Row
  hex: string
  unpacks: Row
  unpackOnly?: boolean
}

export const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

export function unpackRow(layout: Scheme<Row>, wire: string): { ok: boolean; row: Row | undefined } {
  let row: Row | undefined
  const result = BinaryPacker.unpack(Buffer.from(wire, "hex"), layout.on((r) => {
    row = r as Row
  }))
  return { ok: (result as { ok: boolean }).ok, row }
}

export function runCases(cases: Case[]): void {
  for (const c of cases) {
    if (!c.unpackOnly) {
      it(`${c.name}: packs to ${c.hex}`, () => {
        // Act
        const wire = hex(BinaryPacker.pack(c.layout, c.row!))

        // Assert
        assert.equal(wire, c.hex)
      })
    }
    it(`${c.name}: ${c.hex} unpacks to the row`, () => {
      // Act
      const { ok, row } = unpackRow(c.layout, c.hex)

      // Assert
      assert.equal(ok, true)
      assert.deepEqual(row, c.unpacks)
    })
  }
}

export function failsNaming(name: string, layout: Scheme<Row>, row: Row, value: string): void {
  it(`${name}: pack fails naming ${value}`, () => {
    // Act
    const pack = () => BinaryPacker.pack(layout, row)

    // Assert
    assert.throws(pack, (error: unknown) => error instanceof RangeError && new RegExp(`\\b${value}\\b`).test(error.message))
  })
}
