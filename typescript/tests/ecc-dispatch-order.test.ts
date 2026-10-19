import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, PackSession, type SchemeHandler } from "../src/index.ts"
import { positionScheme, positionValue, type Position } from "./support/ecc.ts"

const nonce = Buffer.from("01000000000000000000000000000000", "hex")

function pair(): { opener: PackSession; waiter: PackSession } {
  const seed = Uint8Array.from({ length: 32 }, (_, i) => i + 1)
  const opener = PackSession.load(seed)!
  const waiter = PackSession.load(seed)!
  assert.ok(opener.start(nonce))
  assert.equal(waiter.join(nonce), true)
  return { opener, waiter }
}

describe("message ECC dispatch order (AZ-2694)", () => {
  for (const parity of [0, 4]) {
    it(`a duplicate type number is refused before the receive index advances, parity ${parity}`, () => {
      // Arrange
      const scheme = positionScheme(parity)
      const { opener, waiter } = pair()
      const first = opener.pack(scheme, positionValue)!
      const second = opener.pack(scheme, positionValue)!
      const rows: Position[] = []
      const handler = scheme.on((r) => rows.push(r)) as SchemeHandler<object>

      // Act
      const refuse = () => waiter.unpackRepair(first, 0, handler, handler)
      const next = waiter.unpackRepair(first, 0, handler)

      // Assert
      assert.throws(refuse, /duplicate type number/)
      assert.deepEqual(next, parity === 0 ? { ok: true } : { ok: true, repaired: 0 })
      assert.deepEqual(rows, [positionValue])
      assert.deepEqual(waiter.unpackRepair(second, 0, handler), parity === 0 ? { ok: true } : { ok: true, repaired: 0 })
      assert.equal(rows.length, 2)
    })

    it(`a duplicate type number is refused before any byte is read by the static unpack, parity ${parity}`, () => {
      // Arrange
      const scheme = positionScheme(parity)
      const rows: Position[] = []
      const handler = scheme.on((r) => rows.push(r)) as SchemeHandler<object>

      // Act
      const refuse = () => BinaryPacker.unpack(new Uint8Array(0), handler, handler)

      // Assert
      assert.throws(refuse, /duplicate type number/)
      assert.equal(rows.length, 0)
    })

    it(`a session that is not open answers not-open before it checks a duplicate type, parity ${parity} (AZ-2704)`, () => {
      // Arrange
      const scheme = positionScheme(parity)
      const closed = PackSession.load(Uint8Array.from({ length: 32 }, (_, i) => i + 1))!
      const handler = scheme.on(() => {}) as SchemeHandler<object>

      // Act
      const result = closed.unpackRepair(new Uint8Array(4), 0, handler, handler)

      // Assert
      assert.deepEqual(result, { ok: false, field: "", needed: 1, left: 0 })
    })

    it(`a duplicate type number is refused before a mix of parity counts and a bad limit, parity ${parity} (AZ-2704)`, () => {
      // Arrange
      const scheme = positionScheme(parity)
      const other = positionScheme(parity === 0 ? 4 : 0)
      const { waiter } = pair()
      const handler = scheme.on(() => {}) as SchemeHandler<object>
      const mixed = other.on(() => {}) as SchemeHandler<object>

      // Act
      const withMix = () => waiter.unpackRepair(new Uint8Array(4), 0, handler, mixed, handler)
      const withLimit = () => BinaryPacker.unpackRepair(new Uint8Array(4), 9, handler, handler)

      // Assert
      assert.throws(withMix, /duplicate type number/)
      assert.throws(withLimit, /duplicate type number/)
    })
  }
})
