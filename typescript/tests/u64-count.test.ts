import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, packed, scheme, sized, times, u8, u64, type Scheme } from "../src/index.ts"

type Row = Record<string, unknown>

const bytesOf = (h: string): Uint8Array => Uint8Array.from(Buffer.from(h, "hex"))
const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

const COUNT_3 = "0300000000000000"
const COUNT_2_POW_53 = "0000000000002000"
const COUNT_MAX_U64 = "ffffffffffffffff"
const COUNT_MAX_SAFE = "ffffffffffff1f00"

// One scheme per counted kind; each counts on the u64 `n` and holds three entries for count 3.
const KINDS: { name: string; layout: Scheme<Row>; body: string; list: string; field: string; row: Row }[] = [
  {
    name: "sized",
    layout: scheme<Row>(1, u64(0, (r) => r.n), sized(1, (r) => r.p, 0)),
    body: "616263",
    list: "p",
    field: "p",
    row: { n: 3n, p: bytesOf("616263") },
  },
  {
    name: "packed",
    layout: scheme<Row>(1, u64(0, (r) => r.n), packed(2, 1, (r) => r.p, 0)),
    body: "24",
    list: "p",
    field: "p",
    row: { n: 3n, p: [0, 1, 2] },
  },
  {
    name: "times",
    layout: scheme<Row>(1, u64(0, (r) => r.n), times(1, 0, [u8(1, (r) => r.x)])),
    body: "010203",
    list: "x",
    field: "x",
    row: { n: 3n, x: [1, 2, 3] },
  },
]

function unpack(layout: Scheme<Row>, h: string): { result: unknown; row: Row | undefined } {
  let row: Row | undefined
  const result = BinaryPacker.unpack(bytesOf(h), layout.on((r) => {
    row = r as Row
  }))
  return { result, row }
}

describe("u64 counts", () => {
  for (const k of KINDS) {
    it(`AC-1 ${k.name} counted by a u64 is unpacked`, () => {
      // Arrange
      const wire = `01${COUNT_3}${k.body}`

      // Act
      const { result, row } = unpack(k.layout, wire)

      // Assert
      assert.deepEqual(result, { ok: true })
      assert.equal(row!.n, 3n)
      assert.deepEqual(row![k.list], k.row[k.list])
    })

    it(`AC-1 ${k.name} counted by a u64 is packed, from the unpacked row and from a bigint`, () => {
      // Arrange
      const wire = `01${COUNT_3}${k.body}`
      const { row } = unpack(k.layout, wire)

      // Act
      const again = hex(BinaryPacker.pack(k.layout, row!))
      const fromBigint = hex(BinaryPacker.pack(k.layout, k.row))

      // Assert
      assert.equal(again, wire)
      assert.equal(fromBigint, wire)
    })

    for (const [label, count] of [["2^53", COUNT_2_POW_53], ["2^64-1", COUNT_MAX_U64]] as const) {
      it(`AC-2 ${k.name} with a u64 count of ${label} is an error value, not a throw`, () => {
        // Arrange
        const wire = `01${count}${k.body}`

        // Act
        const { result, row } = unpack(k.layout, wire)

        // Assert
        assert.deepEqual(result, { ok: false, field: k.field, needed: 0, left: k.body.length / 2 })
        assert.equal(row, undefined)
      })
    }

    it(`AC-2 ${k.name} refuses a bigint count past 2^53 on pack with a RangeError`, () => {
      // Arrange
      const row = { ...k.row, n: 2n ** 53n }

      // Act
      const pack = () => BinaryPacker.pack(k.layout, row)

      // Assert
      assert.throws(pack, RangeError)
    })
  }

  it("AC-2 the largest exact count (2^53-1) reads as a count, so sized reports the bytes it lacks", () => {
    // Arrange
    const wire = `01${COUNT_MAX_SAFE}61`

    // Act
    const { result } = unpack(KINDS[0]!.layout, wire)

    // Assert
    assert.deepEqual(result, { ok: false, field: "p", needed: Number.MAX_SAFE_INTEGER, left: 1 })
  })
})
