import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, flags, scheme, times, u8, u16, type Scheme } from "../src/index.ts"

type Row = Record<string, unknown>

const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

const refusal = (run: () => unknown): string => {
  let message = ""
  assert.throws(run, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

const plain = (): Scheme<Row> => scheme<Row>(1, u8(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.pt)]))

const combined = (): Scheme<Row> =>
  scheme<Row>(
    1,
    u8(0, (x) => x.n),
    flags(1, [times(1, 0, [u8(1, (x) => x.pt)]), u16(2, (x) => x.heading)]),
  )

describe("AZ-2335 a times count of 0 with values is an error naming the member", () => {
  for (const [name, build] of [["outside flags", plain], ["inside flags", combined]] as const) {
    it(`AC-1 count 0 with a list of one value is refused (${name})`, () => {
      // Act
      const message = refusal(() => BinaryPacker.pack(build(), { n: 0, pt: [5], heading: 90 }))

      // Assert
      assert.equal(message, "pt: 1 items, times count 0")
    })

    it(`AC-2 count 0 without values writes zero rounds (${name})`, () => {
      // Act
      const wire = hex(BinaryPacker.pack(build(), { n: 0, heading: 90 }))

      // Assert
      assert.equal(wire, name === "outside flags" ? "0100" : "0100025a00")
    })

    it(`AC-2 count 0 with an empty list writes zero rounds (${name})`, () => {
      // Act
      const wire = hex(BinaryPacker.pack(build(), { n: 0, pt: [], heading: 90 }))

      // Assert
      assert.equal(wire, name === "outside flags" ? "0100" : "0100025a00")
    })
  }

  it("a lone scalar with count 0 writes zero rounds and is not an error (unchanged)", () => {
    // Act
    const wire = hex(BinaryPacker.pack(plain(), { n: 0, pt: 5 }))

    // Assert
    assert.equal(wire, "0100")
  })

  it("count 0 with a list for the second of two round names names that member", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.n),
      times(1, 0, [u8(1, (x) => x.pt), u8(2, (x) => x.pu)]),
    )

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, { n: 0, pu: [6] }))

    // Assert
    assert.equal(message, "pu: 1 items, times count 0")
  })
})
