import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  eq,
  flagByte,
  flags,
  group,
  list,
  repeat,
  u8,
  when,
  type DispatchResult,
} from "../src/index.ts"

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

const repeatK = (limits = {}): Scheme<Row> => new Scheme<Row>(1, [repeat(0, [u8(0, (x) => x.k)])], limits)

function unpack(layout: Scheme<Row>, bytes: Uint8Array): { result: DispatchResult; row?: Row } {
  let row: Row | undefined
  const result = BinaryPacker.unpack(bytes, layout.on((r) => { row = r as Row }))
  return { result, row }
}

describe("AZ-2355 pack refuses a repeat with more entries than maxRounds", () => {
  it("AC-1 maxRounds + 1 entries are refused naming the member", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(repeatK(), { k: Array(65_536).fill(7) }))

    // Assert
    assert.equal(message, "k: the repeat count is 65536, above the limit of 65535 rounds")
  })

  it("AC-1 the member named is the one whose list passes the limit", () => {
    // Arrange
    const layout = new Scheme<Row>(1, [repeat(0, [u8(0, (x) => x.a), u8(1, (x) => x.b)])], { maxRounds: 3 })

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, { a: 1, b: [1, 2, 3, 4] }))

    // Assert
    assert.equal(message, "b: the repeat count is 4, above the limit of 3 rounds")
  })

  it("AC-1 the cap holds in flags, a split bit, a when and a list element", () => {
    // Arrange
    const fb = flagByte("m")
    const k = [1, 2, 3, 4]
    const cases: [string, Scheme<Row>, Row][] = [
      ["flags", new Scheme<Row>(1, [flags(0, [repeat(0, [u8(0, (x) => x.k)])])], { maxRounds: 3 }), { k }],
      ["split bit", new Scheme<Row>(1, [fb, fb.bit(repeat(0, [u8(0, (x) => x.k)]))], { maxRounds: 3 }), { k }],
      [
        "when",
        new Scheme<Row>(1, [u8(0, (x) => x.m), when(1, eq(0, 1), [repeat(1, [u8(1, (x) => x.k)])])], { maxRounds: 3 }),
        { m: 1, k },
      ],
      [
        "list element",
        new Scheme<Row>(1, [list((x) => x.items, group((x) => x.item, [repeat(0, [u8(0, (x) => x.k)])]))], { maxRounds: 3 }),
        { items: [{ k }] },
      ],
    ]

    // Act / Assert
    for (const [where, layout, row] of cases) {
      assert.equal(refusal(() => BinaryPacker.pack(layout, row)), "k: the repeat count is 4, above the limit of 3 rounds", where)
    }
  })

  it("AC-2 maxRounds entries pack in maxRounds + 1 bytes and round-trip", () => {
    // Arrange
    const layout = repeatK()

    // Act
    const wire = BinaryPacker.pack(layout, { k: Array(65_535).fill(7) })
    const { result, row } = unpack(layout, wire)

    // Assert
    assert.equal(wire.length, 65_536)
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(BinaryPacker.pack(layout, row!), wire)
  })

  it("AC-3 with maxRounds raised to 70 000, 70 000 entries pack", () => {
    // Act
    const wire = BinaryPacker.pack(repeatK({ maxRounds: 70_000 }), { k: Array(70_000).fill(7) })

    // Assert
    assert.equal(wire.length, 70_001)
  })

  it("a lowered limit lowers what packs; at the limit the bytes are as before", () => {
    // Arrange
    const layout = repeatK({ maxRounds: 3 })

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, { k: [1, 2, 3, 4] }))

    // Assert
    assert.equal(message, "k: the repeat count is 4, above the limit of 3 rounds")
    assert.equal(hex(BinaryPacker.pack(layout, { k: [1, 2, 3] })), "01010203")
  })
})
