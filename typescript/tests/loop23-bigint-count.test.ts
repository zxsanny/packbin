import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, Scheme, bits, eq, flagByte, flags, packed, sized, times, u8, when, type Field } from "../src/index.ts"

// Loop 23 U23 (AZ-2434): in the U11 shape (a bits / packed / sized member behind a split bit or a combined
// flags, its count in the row behind a clear `when`, no value) a bigint count above 2^53 is a count above 0
// and is refused with the U11 text, as Python, Rust, Java and C# refuse it. Every other count keeps its
// outcome at b8b2809. AC-3: the same 16 counts x 4 members x 2 positions (128 rows) were packed by Python
// (`python/src`, 3.14) and gave the same refused/packed outcome and the same number in every message.

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

const NOT_WRITTEN = (n: string): string =>
  `v: the count c is ${n} in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold`

const members: [string, () => Field][] = [
  ["bits", () => bits(2, (x: Row) => x.v, 1)],
  ["packed", () => packed(1, 2, (x: Row) => x.v, 1)],
  ["packed bias -1", () => packed(1, 2, (x: Row) => x.v, 1, -1)],
  ["sized", () => sized(2, (x: Row) => x.v, 1)],
]

const head = (): Field[] => [u8(0, (x: Row) => x.mode), when(1, eq(0, 1), [u8(1, (x: Row) => x.c)])]

const layouts = (member: () => Field): Scheme<Row>[] => {
  const fb = flagByte("fb")
  return [new Scheme<Row>(1, [...head(), fb, fb.bit(member())]), new Scheme<Row>(1, [...head(), flags(2, [member()])])]
}

const outcome = (layout: Scheme<Row>, row: Row): string => {
  try {
    return hex(BinaryPacker.pack(layout, row))
  } catch (e) {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    return e.message
  }
}

for (const [kind, member] of members) {
  describe(`AZ-2434 U23 a ${kind} count behind a clear when, no value`, () => {
    it("AC-1 a bigint count above 2^53 is refused in the split bit and the combined flags, naming member and count", () => {
      // Arrange
      const counts = [2n ** 60n, 2n ** 53n + 1n, 2n ** 53n]

      // Act
      const messages = layouts(member).flatMap((layout) =>
        counts.map((c) => refusal(() => BinaryPacker.pack(layout, { mode: 0, c }))),
      )

      // Assert
      const expected = ["1152921504606846976", "9007199254740993", "9007199254740992"].map(NOT_WRITTEN)
      assert.deepEqual(messages, [...expected, ...expected])
    })

    it("AC-2 counts that are not above 0 or not a count pack the clear bit as at HEAD", () => {
      // Arrange
      const counts: [string, unknown][] = [
        ["0n", 0n], ["3.5", 3.5], ["-1", -1], ['"3"', "3"], ["NaN", NaN], ["true", true], ["null", null],
        ["-2^60n", -(2n ** 60n)],
      ]

      // Act
      const wires = layouts(member).flatMap((layout) => [
        ...counts.map(([label, c]) => `${label} ${outcome(layout, { mode: 0, c })}`),
        `left out ${outcome(layout, { mode: 0 })}`,
      ])

      // Assert
      const expected = [...counts.map(([label]) => `${label} 010000`), "left out 010000"]
      assert.deepEqual(wires, [...expected, ...expected])
    })

    it("AC-2 safe counts above 0 keep their HEAD refusal (3n, 3, 2^53 - 1 as a bigint)", () => {
      // Arrange
      const counts: unknown[] = [3n, 3, 2n ** 53n - 1n]

      // Act
      const messages = layouts(member).flatMap((layout) => counts.map((c) => outcome(layout, { mode: 0, c })))

      // Assert
      const expected = ["3", "3", "9007199254740991"].map(NOT_WRITTEN)
      assert.deepEqual(messages, [...expected, ...expected])
    })
  })
}

describe("AZ-2434 U23 leaves the times split (U6) alone", () => {
  it("a times behind a clear when with a bigint count above 2^53 still packs its clear bit", () => {
    // Arrange
    const fb = flagByte("fb")
    const layout = new Scheme<Row>(1, [...head(), fb, fb.bit(times(2, 1, [u8(2, (x: Row) => x.pt)]))])

    // Act
    const wire = hex(BinaryPacker.pack(layout, { mode: 0, c: 2n ** 60n }))

    // Assert
    assert.equal(wire, "010000")
  })
})
