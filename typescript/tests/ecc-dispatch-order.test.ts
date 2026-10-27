import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, Scheme, type SchemeHandler } from "../src/index.ts"
import { positionScheme, type Position } from "./support/ecc.ts"

describe("message ECC dispatch order (AZ-2694)", () => {
  for (const parity of [0, 4]) {
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

    // AZ-2704: the checks run in one order in every package (no handler, duplicate type, parity mix, limit); a
    // duplicate later in the list than a mix of counts is still the duplicate refusal.
    it(`a duplicate type number is refused before a mix of parity counts and a bad limit, parity ${parity} (AZ-2704)`, () => {
      // Arrange
      const scheme = positionScheme(parity)
      const other = positionScheme(parity === 0 ? 4 : 0)
      const handler = scheme.on(() => {}) as SchemeHandler<object>
      const mixed = new Scheme<Position>(other.typeNumber + 1, other.fields, { parity: other.parity }).on(() => {}) as SchemeHandler<object>

      // Act
      const mixOnly = () => BinaryPacker.unpackRepair(new Uint8Array(4), 0, handler, mixed)
      const withMix = () => BinaryPacker.unpackRepair(new Uint8Array(4), 0, handler, mixed, handler)
      const withLimit = () => BinaryPacker.unpackRepair(new Uint8Array(4), 9, handler, handler)

      // Assert
      assert.throws(mixOnly, /must declare the same count/)
      assert.throws(withMix, /duplicate type number/)
      assert.throws(withLimit, /duplicate type number/)
    })
  }
})
