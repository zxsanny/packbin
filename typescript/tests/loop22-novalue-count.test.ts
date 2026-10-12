import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, Scheme, bits, eq, flagByte, flags, packed, sized, u8, when, type Field } from "../src/index.ts"

// Loop 22 U11 (AZ-2410): a bits / packed / sized member whose count sits in the row behind a clear `when`,
// with no value for the member, is refused like the same shape under `times` (U6). Pinned as section 1 of
// `_docs/03_implementation/reference_loop22.md`.

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

const NOT_WRITTEN = (n: number): string =>
  `v: the count c is ${n} in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold`

const members: { kind: string; member: () => Field; value: unknown; setHex: string; splitSetHex: string }[] = [
  { kind: "bits", member: () => bits(2, (x: Row) => x.v, 1), value: [1, 0, 1], setHex: "01010305", splitSetHex: "0101030105" },
  { kind: "packed", member: () => packed(1, 2, (x: Row) => x.v, 1), value: [1, 0, 1], setHex: "01010305", splitSetHex: "0101030105" },
  {
    kind: "sized",
    member: () => sized(2, (x: Row) => x.v, 1),
    value: new Uint8Array([1, 2, 3]),
    setHex: "010103010203",
    splitSetHex: "01010301010203",
  },
]

for (const { kind, member, value, setHex, splitSetHex } of members) {
  const head = (): Field[] => [u8(0, (x: Row) => x.mode), when(1, eq(0, 1), [u8(1, (x: Row) => x.c)])]
  const split = (): Scheme<Row> => {
    const fb = flagByte("fb")
    return new Scheme<Row>(1, [...head(), fb, fb.bit(member())])
  }
  const combined = (): Scheme<Row> => new Scheme<Row>(1, [...head(), flags(2, [member()])])
  const plain = (): Scheme<Row> => new Scheme<Row>(1, [...head(), member()])

  describe(`AZ-2410 U11 a ${kind} count behind a clear when, no value`, () => {
    it("AC-1 a split bit and a combined flags refuse count 3, naming the member and the count, no bytes", () => {
      // Act
      const messages = [split(), combined()].map((layout) => refusal(() => BinaryPacker.pack(layout, { mode: 0, c: 3 })))

      // Assert
      assert.deepEqual(messages, [NOT_WRITTEN(3), NOT_WRITTEN(3)])
    })

    it("AC-1 a bigint count is refused too", () => {
      // Act
      const message = refusal(() => BinaryPacker.pack(split(), { mode: 0, c: 4n }))

      // Assert
      assert.equal(message, NOT_WRITTEN(4))
    })

    it("AC-2 count 0 and the count left out pack the clear bit as before", () => {
      // Act
      const wires = [
        BinaryPacker.pack(split(), { mode: 0, c: 0 }),
        BinaryPacker.pack(split(), { mode: 0 }),
        BinaryPacker.pack(combined(), { mode: 0, c: 0 }),
        BinaryPacker.pack(combined(), { mode: 0 }),
      ].map(hex)

      // Assert
      assert.deepEqual(wires, ["010000", "010000", "010000", "010000"])
    })

    it("AC-2 a holding when with no value still packs the clear bit", () => {
      // Act
      const wires = [BinaryPacker.pack(split(), { mode: 1, c: 3 }), BinaryPacker.pack(combined(), { mode: 1, c: 3 })].map(hex)

      // Assert
      assert.deepEqual(wires, ["01010300", "01010300"])
    })

    it("AC-3 rows 53 to 55 are unchanged: the value with the clear when is refused, the holding when packs", () => {
      // Act
      const refused = [plain(), split(), combined()].map((layout) =>
        refusal(() => BinaryPacker.pack(layout, { mode: 0, c: 3, v: value })),
      )
      const packs = [hex(BinaryPacker.pack(plain(), { mode: 1, c: 3, v: value })), hex(BinaryPacker.pack(split(), { mode: 1, c: 3, v: value }))]

      // Assert
      assert.deepEqual(refused, ["v: count c was not written", "v: count c was not written", "v: count c was not written"])
      assert.deepEqual(packs, [setHex, splitSetHex])
    })

    it("a plain member behind a clear when keeps its own refusal", () => {
      // Act
      const message = refusal(() => BinaryPacker.pack(plain(), { mode: 0, c: 3 }))

      // Assert
      assert.equal(message, "v: count c was not written")
    })
  })
}

describe("AZ-2410 U11 packed with bias -1", () => {
  const layout = (): Scheme<Row> => {
    const fb = flagByte("fb")
    return new Scheme<Row>(1, [
      u8(0, (x: Row) => x.mode),
      when(1, eq(0, 1), [u8(1, (x: Row) => x.c)]),
      fb,
      fb.bit(packed(1, 2, (x: Row) => x.v, 1, -1)),
    ])
  }

  it("the count is looked at after the bias: count 1 reads nothing and packs, count 3 is refused as 3", () => {
    // Act
    const one = hex(BinaryPacker.pack(layout(), { mode: 0, c: 1 }))
    const three = refusal(() => BinaryPacker.pack(layout(), { mode: 0, c: 3 }))

    // Assert
    assert.equal(one, "010000")
    assert.equal(three, NOT_WRITTEN(3))
  })
})
