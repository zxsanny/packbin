import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  eq,
  flags,
  group,
  scheme,
  times,
  u8,
  when,
  type Field,
} from "../src/index.ts"

type Row = Record<string, unknown>

const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

function refusal(build: () => unknown): string {
  let message = ""
  assert.throws(build, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

const one = scheme<Row>(1, u8(0, (r) => r.a), times(1, 0, [u8(1, (r) => r.x)]))
const two = scheme<Row>(
  1,
  u8(0, (r) => r.a),
  times(1, 0, [u8(1, (r) => r.x), u8(2, (r) => r.y)]),
)
const under = scheme<Row>(
  1,
  u8(0, (r) => r.a),
  times(1, 0, [u8(1, (r) => r.k), when(2, eq(1, 1), [u8(2, (r) => r.v)])]),
)

// Each builder makes fresh fields: a flag-byte handle numbers its bits per call.
const BODIES: { name: string; body: () => Field[]; longer: Row; member: string }[] = [
  {
    name: "flags",
    body: () => [flags(1, [u8(1, (r) => r.p), u8(2, (r) => r.q)])],
    longer: { a: 1, p: [1], q: [2, 3] },
    member: "q",
  },
  {
    name: "an anchored group",
    body: () => [group(1, (r) => r.g, [u8(1, (r) => r.p)])],
    longer: { a: 1, p: [1, 2] },
    member: "p",
  },
  {
    name: "an unanchored group",
    body: () => [group((r) => r.g, [u8(0, (r) => r.p)])],
    longer: { a: 1, p: [1, 2] },
    member: "p",
  },
]

describe("times with a list longer than its count", () => {
  it("AC-1 a longer list is refused, naming the member, the items and the count", () => {
    // Arrange
    const row = { a: 2, x: [1, 2, 3] }

    // Act
    const message = refusal(() => BinaryPacker.pack(one, row))

    // Assert
    assert.equal(message, "x: 3 items, times count 2")
  })

  it("AC-2 count zero refuses a one-item list and packs an empty or absent one", () => {
    // Arrange
    const longer = { a: 0, x: [1] }

    // Act
    const message = refusal(() => BinaryPacker.pack(one, longer))
    const empty = hex(BinaryPacker.pack(one, { a: 0, x: [] }))
    const absent = hex(BinaryPacker.pack(one, { a: 0 }))

    // Assert
    assert.equal(message, "x: 1 items, times count 0")
    assert.equal(empty, "0100")
    assert.equal(absent, "0100")
  })

  it("AC-3 any member of the body is checked: a second field", () => {
    // Arrange
    const row = { a: 2, x: [1, 2], y: [3, 4, 5] }

    // Act
    const message = refusal(() => BinaryPacker.pack(two, row))

    // Assert
    assert.equal(message, "y: 3 items, times count 2")
  })

  it("AC-3 any member of the body is checked: a member under when", () => {
    // Arrange
    const row = { a: 1, k: [1], v: [7, 8] }

    // Act
    const message = refusal(() => BinaryPacker.pack(under, row))

    // Assert
    assert.equal(message, "v: 2 items, times count 1")
  })

  for (const c of BODIES) {
    it(`AC-3 any member of the body is checked: under ${c.name}`, () => {
      // Arrange
      const layout = new Scheme<Row>(1, [u8(0, (r) => r.a), times(1, 0, c.body())])

      // Act
      const message = refusal(() => BinaryPacker.pack(layout, c.longer))

      // Assert
      assert.match(message, new RegExp(`^${c.member}: 2 items, times count 1$`))
    })
  }

  it("AC-4 an exact list, a lone scalar and two members keep their bytes", () => {
    // Arrange
    const rows: [Scheme<Row>, Row, string][] = [
      [one, { a: 2, x: [1, 2] }, "01020102"],
      [one, { a: 2, x: 5 }, "01020505"],
      [one, { a: 1, x: 5 }, "010105"],
      [two, { a: 2, x: [1, 2], y: [3, 4] }, "010201030204"],
      [under, { a: 2, k: [1, 0], v: [7] }, "0102010700"],
    ]

    // Act
    const wires = rows.map(([layout, row]) => hex(BinaryPacker.pack(layout, row)))

    // Assert
    assert.deepEqual(wires, rows.map(([, , wire]) => wire))
  })

  it("AC-4 a shorter list is still the missing-member error", () => {
    // Arrange
    const row = { a: 2, x: [1] }

    // Act
    const message = refusal(() => BinaryPacker.pack(one, row))

    // Assert
    assert.equal(message, "missing x")
  })

  it("AC-5 an unpacked row packs again", () => {
    // Arrange
    let row: Row | undefined
    BinaryPacker.unpack(Uint8Array.of(1, 2, 1, 2), one.on((r) => {
      row = r as Row
    }))

    // Act
    const wire = BinaryPacker.pack(one, row!)

    // Assert
    assert.equal(hex(wire), "01020102")
  })
})
