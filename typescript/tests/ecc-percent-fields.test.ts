import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, Scheme, flags, scheme, u8, u16, u32, utf8, type SchemeHandler } from "../src/index.ts"
import { corrupt } from "./support/ecc.ts"

// AZ-3512: a parity percentage over a message whose length varies by an optional field (AC-17, S12b), over a string
// field read after the repair (AC-18, S12c), and the refusal of a dispatch mix naming the percentage (AC-19, D4).

type Optional = { a: number; b: number; h?: number | null; s?: number | null }
const optional = scheme<Optional>(
  1,
  u32(0, (r) => r.a),
  u32(1, (r) => r.b),
  flags(2, [u16(2, (r) => r.h), u8(3, (r) => r.s)]),
).withLimits({ parityPercent: 25 })

type Note = { s: string; n: number }
const note = scheme<Note>(1, utf8(0, (r) => r.s), u8(1, (r) => r.n)).withLimits({ parityPercent: 25 })

const unpackOne = <T extends object>(s: Scheme<T>, message: Uint8Array, limit: number) => {
  const rows: T[] = []
  const result = BinaryPacker.unpackRepair(message, limit, s.on((r) => rows.push(r)) as SchemeHandler<object>)
  return { result, rows }
}

describe("parity percentage with an optional field", () => {
  const cases: [string, Optional, number, number][] = [
    ["with the field", { a: 1, b: 2, h: 3, s: 4 }, 13, 4],
    ["without the field", { a: 1, b: 2 }, 10, 3],
  ]

  for (const [name, row, clear, parity] of cases) {
    it(`a message ${name} is ${clear + parity} bytes (${clear} clear, ${parity} parity) and round trips`, () => {
      // Arrange
      const sent = BinaryPacker.pack(optional, row)
      const positions = Array.from({ length: parity >> 1 }, (_, i) => i * 4)

      // Act
      const intact = unpackOne(optional, sent, 0)
      const repaired = unpackOne(optional, corrupt(sent, positions, positions.map(() => 0x5a)), parity >> 1)

      // Assert
      assert.equal(sent.length, clear + parity)
      assert.deepEqual(intact.result, { ok: true, repaired: 0 })
      assert.deepEqual(repaired.result, { ok: true, repaired: parity >> 1 })
      assert.equal(intact.rows[0]!.a, 1)
      assert.equal(repaired.rows[0]!.b, 2)
      assert.equal(repaired.rows[0]!.h ?? null, row.h ?? null)
    })
  }
})

describe("parity percentage with a string field", () => {
  for (const text of ["pack bin ecc 0123456789", "Олександр, диспетчер", "gps_fix 48.46"]) {
    it(`one wrong byte anywhere in the message of "${text}" is repaired and the string is the original`, () => {
      // Arrange
      const sent = BinaryPacker.pack(note, { s: text, n: 200 })
      let wrong = 0

      // Act
      for (let place = 0; place < sent.length; place++) {
        const { result, rows } = unpackOne(note, corrupt(sent, [place], [0x5a]), 1)
        if (!(result.ok && result.repaired === 1 && rows.length === 1 && rows[0]!.s === text && rows[0]!.n === 200)) wrong++
      }

      // Assert
      assert.equal(wrong, 0)
    })
  }
})

describe("parity percentage dispatch mix", () => {
  const handler = (type: number, settings: { parity?: number; parityPercent?: number }) =>
    new Scheme(type, [u8(0, (r: { x: number }) => r.x)], settings).on(() => undefined) as SchemeHandler<object>

  it("a handler of 25 percent with a handler of count 25 is refused telling the percentage", () => {
    // Arrange
    const message = new Uint8Array([0x40, 0])
    const percent = handler(0x40, { parityPercent: 25 })
    const count = handler(0x41, { parity: 25 })

    // Act
    const refusals = [
      () => BinaryPacker.unpackRepair(message, 1, percent, count),
      () => BinaryPacker.unpackRepair(message, 1, count, percent),
    ]

    // Assert
    for (const refused of refusals) {
      assert.throws(refused, (e: unknown) => e instanceof RangeError && /25 percent/.test(e.message) && /25 parity bytes/.test(e.message))
    }
  })
})
