import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { MacKey } from "../src/index.ts"
import { access } from "../src/frame-access.ts"
import { bytes, caseOf, int, kindName, loadFixture, SENTINEL } from "./support/frame-vectors.ts"

// AZ-3295: the MAC-only call (contract "MAC-only call"): E4 and E5, every split of the message, refusals, release.

const rows = loadFixture()
const rowOf = (name: string) => rows.find((r) => caseOf(r) === name)!
const split = (message: Uint8Array, ...cuts: number[]): Uint8Array[] => {
  const parts: Uint8Array[] = []
  let at = 0
  for (const cut of [...cuts, message.length]) {
    parts.push(message.subarray(at, cut))
    at = cut
  }
  return parts
}

describe("MAC-only call (AZ-3295)", () => {
  for (const name of ["E4.mac", "E5.mac"]) {
    it(`${name}: every split in one, two and three parts gives the same tag and verifies`, () => {
      // Arrange
      const row = rowOf(name)
      const message = bytes(row, "message")
      const expected = bytes(row, "tag")
      const key = MacKey.derive(bytes(row, "key"), int(row, "epoch"), bytes(row, "label"))!
      let splits = 0
      const check = (parts: Uint8Array[]) => {
        const made = key.tag(parts, expected.length)
        assert.ok(made.ok)
        assert.deepEqual(made.tag, expected)
        assert.equal(key.verify(parts, expected), true)
        splits++
      }

      // Act
      check(split(message))
      for (let i = 0; i <= message.length; i++) {
        check(split(message, i))
        for (let j = i; j <= message.length; j++) check(split(message, i, j))
      }

      // Assert
      assert.equal(splits, 1 + (message.length + 1) + ((message.length + 1) * (message.length + 2)) / 2)
      const whole = key.tag(message, expected.length)
      assert.ok(whole.ok)
      assert.deepEqual(whole.tag, expected)
    })

    it(`${name}: a flipped tag bit and a wrong tag length verify false`, () => {
      // Arrange
      const row = rowOf(name)
      const message = bytes(row, "message")
      const expected = bytes(row, "tag")
      const key = MacKey.derive(bytes(row, "key"), int(row, "epoch"), bytes(row, "label"))!

      // Act and assert
      for (let bit = 0; bit < expected.length * 8; bit++) {
        const tag = Uint8Array.from(expected)
        tag[bit >> 3]! ^= 1 << (bit & 7)
        assert.equal(key.verify(message, tag), false, `bit ${bit}`)
      }
      assert.equal(key.verify(message, expected), true)
      assert.equal(key.verify(message, expected.subarray(0, expected.length - 1)), false)
      assert.equal(key.verify(message, new Uint8Array(0)), false)
    })
  }

  it("a label of 0 or 33 bytes, a bad key or epoch give null; the longest label works", () => {
    // Arrange
    const master = new Uint8Array(32)
    const net = new TextEncoder().encode("net")

    // Act
    const results = [
      MacKey.derive(master, 1, new Uint8Array(0)),
      MacKey.derive(master, 1, new Uint8Array(33)),
      MacKey.derive(master, 0x1000000, net),
      MacKey.derive(master, -1, net),
      MacKey.derive(master, 1.5, net),
      MacKey.derive(new Uint8Array(31), 1, net),
      MacKey.derive(master, 1, [1] as unknown as Uint8Array),
    ]

    // Assert
    assert.deepEqual(results, results.map(() => null))
    assert.notEqual(MacKey.derive(master, 1, new Uint8Array(32)), null)
    assert.notEqual(MacKey.derive(master, 0xffffff, net), null)
  })

  it("a tag length of 0, 2, 5 or 33 is a bad value and verify is false for such a length", () => {
    // Arrange
    const key = MacKey.derive(new Uint8Array(32), 1, new TextEncoder().encode("net"))!
    const x = new TextEncoder().encode("x")

    // Act and assert
    for (const n of [0, 2, 5, 33, -4, 4.5, NaN]) {
      assert.equal(kindName(key.tag(x, n)), "BadValue", `length ${n}`)
      assert.equal(key.verify(x, new Uint8Array(Math.max(0, Number.isInteger(n) ? n : 0)).fill(SENTINEL)), false)
    }
    assert.equal(kindName(key.tag([x, 5 as unknown as Uint8Array], 4)), "BadValue")
    assert.equal(kindName(key.tag("x" as unknown as Uint8Array, 4)), "BadValue")
  })

  it("the four tag lengths are the leading bytes of the longest tag", () => {
    // Arrange
    const key = MacKey.derive(new Uint8Array(32), 3, new TextEncoder().encode("fp"))!
    const message = new TextEncoder().encode("message")
    const full = key.tag(message, 32)
    assert.ok(full.ok)

    // Act and assert
    for (const n of [4, 8, 16, 32]) {
      const made = key.tag(message, n)
      assert.ok(made.ok)
      assert.deepEqual(made.tag, full.tag.subarray(0, n))
      assert.equal(key.verify(message, made.tag), true)
    }
    assert.equal(key.epoch, 3)
  })

  it("a closed key has a zero key and refuses every call", () => {
    // Arrange
    const key = MacKey.derive(new Uint8Array(32).fill(0x42), 9, new TextEncoder().encode("net"))!
    const bytesOfKey = access.macKeyBytes!(key)
    const message = new TextEncoder().encode("m")
    const made = key.tag(message, 4)
    assert.ok(made.ok)
    assert.ok(bytesOfKey.some((b) => b !== 0))

    // Act
    key.close()
    const after = key.tag(message, 4)
    key.close()

    // Assert
    assert.ok(bytesOfKey.every((b) => b === 0))
    assert.equal(kindName(after), "BadValue")
    assert.equal(key.verify(message, made.tag), false)
  })
})
