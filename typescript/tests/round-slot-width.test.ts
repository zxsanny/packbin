import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  bool,
  bytes,
  dict,
  eq,
  flagByte,
  flags,
  group,
  list,
  repeat,
  sized,
  times,
  u2,
  u8,
  when,
  type DispatchResult,
  type Field,
} from "../src/index.ts"

// AZ-2382: the slots one round charges against maxSlots, on pack and on unpack. Every shape below is a
// repeat whose round holds `width` names; the limit is two rounds' worth, so two rounds pack exactly at
// maxSlots and a third round would hold maxSlots + width.

type Row = Record<string, unknown>

const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

const rounds = <T>(count: number, make: (i: number) => T): T[] => Array.from({ length: count }, (_, i) => make(i))

type Shape = {
  name: string
  width: number
  body: () => Field[]
  row: (count: number) => Row
  first: string
  atLimit: string
  oneRoundMore: string
  unpackRefusal: { field: string; left: number }
}

const fb = flagByte("m")

const SHAPES: Shape[] = [
  {
    // An empty group's name is a slot; `flags` and its flag byte are not.
    name: "empty group under flags: a, g",
    width: 2,
    body: () => [u8(0, (x) => x.a), flags(1, [group((x) => x.g, [])])],
    row: (n) => ({ a: rounds(n, (i) => i + 1), g: rounds(n, (i) => (i % 2 === 0 ? true : undefined)) }),
    first: "a",
    atLimit: "0101010200",
    oneRoundMore: "01010102000301",
    unpackRefusal: { field: "a", left: 2 },
  },
  {
    // The two `when` branches declare k twice: one name, one slot.
    name: "duplicate leaf names in two when branches: m, k",
    width: 2,
    body: () => [
      u8(0, (x) => x.m),
      when(1, eq(0, 1), [u8(1, (x) => x.k)]),
      when(2, eq(0, 2), [u8(2, (x) => x.k)]),
    ],
    row: (n) => ({ m: rounds(n, (i) => (i % 2) + 1), k: rounds(n, (i) => 7 + i) }),
    first: "m",
    atLimit: "0101070208",
    oneRoundMore: "01010702080109",
    unpackRefusal: { field: "m", left: 2 },
  },
  {
    // Combined flags: the members' names, not the flags and not its byte.
    name: "combined flags: on, v",
    width: 2,
    body: () => [flags(0, [bool(0, (x) => x.on), u8(1, (x) => x.v)])],
    row: (n) => ({ on: rounds(n, () => true), v: rounds(n, (i) => 5 + i) }),
    first: "on",
    atLimit: "0103050306",
    oneRoundMore: "01030503060307",
    unpackRefusal: { field: "on", left: 2 },
  },
  {
    // Split bits: the bits' names; the flag byte name `m` is not a slot.
    name: "split bits with flag byte m: a, b",
    width: 2,
    body: () => [fb, fb.bit(u8(0, (x) => x.a)), fb.bit(u8(1, (x) => x.b))],
    row: (n) => ({ a: rounds(n, (i) => 1 + i), b: rounds(n, (i) => 4 + i) }),
    first: "a",
    atLimit: "01030104030205",
    oneRoundMore: "01030104030205030306",
    unpackRefusal: { field: "m", left: 3 },
  },
  {
    // A `when` is charged whether or not its condition holds in the round.
    name: "when that is clear in every round: m, k",
    width: 2,
    body: () => [u8(0, (x) => x.m), when(1, eq(0, 1), [u8(1, (x) => x.k)])],
    row: (n) => ({ m: rounds(n, () => 0) }),
    first: "m",
    atLimit: "010000",
    oneRoundMore: "01000000",
    unpackRefusal: { field: "m", left: 1 },
  },
  {
    // Group names are not slots, at any depth: only a, b, c.
    name: "nested anchored groups: a, b, c",
    width: 3,
    body: () => [
      u8(0, (x) => x.a),
      group(1, (x) => x.g, [u8(1, (x) => x.b), group(2, (x) => x.h, [u8(2, (x) => x.c)])]),
    ],
    row: (n) => ({ a: rounds(n, (i) => 1 + i), b: rounds(n, (i) => 4 + i), c: rounds(n, (i) => 7 + i) }),
    first: "a",
    atLimit: "01010407020508",
    oneRoundMore: "01010407020508030609",
    unpackRefusal: { field: "a", left: 3 },
  },
  {
    name: "unanchored group: a, b",
    width: 2,
    body: () => [u8(0, (x) => x.a), group((x) => x.g, [u8(0, (x) => x.b)])],
    row: (n) => ({ a: rounds(n, (i) => 1 + i), b: rounds(n, (i) => 4 + i) }),
    first: "a",
    atLimit: "0101040205",
    oneRoundMore: "01010402050306",
    unpackRefusal: { field: "a", left: 2 },
  },
  {
    // One slot per u2 slot name.
    name: "u2 with three slots: a, p, q, r",
    width: 4,
    body: () => [u8(0, (x) => x.a), u2(1, (x) => x.p, 2, (x) => x.q, 3, (x) => x.r)],
    row: (n) => ({
      a: rounds(n, (i) => 1 + i),
      p: rounds(n, () => 1),
      q: rounds(n, () => 2),
      r: rounds(n, () => 3),
    }),
    first: "a",
    atLimit: "0101390239",
    oneRoundMore: "01013902390339",
    unpackRefusal: { field: "a", left: 2 },
  },
  {
    // A list or dict is one slot however many items it holds.
    name: "list and dict names: n, l, d",
    width: 3,
    body: () => [
      u8(0, (x) => x.n),
      list((x) => x.l, u8(0, (x) => x.e)),
      dict((x) => x.d, u8(0, (x) => x.e)),
    ],
    row: (n) => ({
      n: rounds(n, (i) => 1 + i),
      l: rounds(n, (i) => [i, i + 1]),
      d: rounds(n, (i) => ({ k: i })),
    }),
    first: "n",
    atLimit: "010102000001010002106b000202000102010002106b01",
    oneRoundMore: "010102000001010002106b000202000102010002106b010302000203010002106b02",
    unpackRefusal: { field: "n", left: 11 },
  },
  {
    // A byte run is one slot, a sized one too.
    name: "bytes and sized names: n, b, s",
    width: 3,
    body: () => [u8(0, (x) => x.n), bytes(1, (x) => x.b, 2), sized(2, (x) => x.s, 0)],
    row: (n) => ({
      n: rounds(n, () => 1),
      b: rounds(n, (i) => new Uint8Array([i, i])),
      s: rounds(n, () => new Uint8Array([9])),
    }),
    first: "n",
    atLimit: "010100000901010109",
    oneRoundMore: "01010000090101010901020209",
    unpackRefusal: { field: "n", left: 4 },
  },
]

function unpackWith(layout: Scheme<Row>, wire: Uint8Array): { result: DispatchResult; row?: Row } {
  let row: Row | undefined
  const result = BinaryPacker.unpack(wire, layout.on((r) => { row = r as Row }))
  return { result, row }
}

const refusal = (run: () => unknown): string => {
  let message = ""
  assert.throws(run, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

describe("AZ-2382 a repeat round is charged the names it holds, on pack and unpack", () => {
  for (const shape of SHAPES) {
    const limit = 2 * shape.width
    const at = (maxSlots: number): Scheme<Row> => new Scheme<Row>(1, [repeat(0, shape.body())], { maxSlots })

    describe(shape.name, () => {
      it(`AC-1 two rounds charge ${limit} slots and pack at maxSlots`, () => {
        // Act
        const wire = BinaryPacker.pack(at(limit), shape.row(2))

        // Assert
        assert.equal(hex(wire), shape.atLimit)
      })

      it(`AC-1 a third round would hold ${limit + shape.width} slots and is refused at maxSlots ${limit}`, () => {
        // Act
        const message = refusal(() => BinaryPacker.pack(at(limit), shape.row(3)))

        // Assert
        assert.equal(
          message,
          `${shape.first}: the rounds would hold ${limit + shape.width} slots, above the limit of ${limit} slots`,
        )
      })

      it(`AC-1 the same third round packs at maxSlots ${limit + shape.width}`, () => {
        // Act
        const wire = BinaryPacker.pack(at(limit + shape.width), shape.row(3))

        // Assert
        assert.equal(hex(wire), shape.oneRoundMore)
      })

      it("AC-2 the packet written at maxSlots unpacks and packs again to the same bytes", () => {
        // Arrange
        const layout = at(limit)
        const wire = BinaryPacker.pack(layout, shape.row(2))

        // Act
        const { result, row } = unpackWith(layout, wire)

        // Assert
        assert.deepEqual(result, { ok: true })
        assert.equal(hex(BinaryPacker.pack(layout, row!)), shape.atLimit)
      })

      it("AC-2 unpack refuses the third round at the round where pack refuses it", () => {
        // Arrange
        const wire = BinaryPacker.pack(at(limit + shape.width), shape.row(3))

        // Act
        const { result, row } = unpackWith(at(limit), wire)

        // Assert
        assert.deepEqual(result, { ok: false, field: shape.unpackRefusal.field, needed: 0, left: shape.unpackRefusal.left })
        assert.equal(row, undefined, "the handler is not called")
      })
    })
  }
})

describe("AZ-2382 times charges the same width as repeat, one counter for the whole call", () => {
  // u8 n; times(n) { u8 m; when m == 1 { u8 k }; when m == 2 { u8 k } }: width 2 (m, k).
  const layout = (maxSlots: number): Scheme<Row> =>
    new Scheme<Row>(
      1,
      [
        u8(0, (x) => x.n),
        times(1, 0, [
          u8(1, (x) => x.m),
          when(2, eq(1, 1), [u8(2, (x) => x.k)]),
          when(3, eq(1, 2), [u8(3, (x) => x.k)]),
        ]),
      ],
      { maxSlots },
    )

  it("AC-1 two rounds pack at maxSlots 4", () => {
    // Act
    const wire = BinaryPacker.pack(layout(4), { n: 2, m: [1, 2], k: [7, 8] })

    // Assert
    assert.equal(hex(wire), "01020107" + "0208")
  })

  it("AC-1 three rounds are refused at maxSlots 4, naming the first member", () => {
    // Act
    const message = refusal(() => BinaryPacker.pack(layout(4), { n: 3, m: [1, 2, 1], k: [7, 8, 9] }))

    // Assert
    assert.equal(message, "m: the rounds would hold 6 slots, above the limit of 4 slots")
  })

  it("AC-1 two repeats and a times in one call share one counter", () => {
    // Arrange: each of the three rounds holds one slot name.
    const shared = new Scheme<Row>(
      1,
      [u8(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.a)]), repeat(2, [u8(2, (x) => x.b)])],
      { maxSlots: 3 },
    )

    // Act
    const packs = hex(BinaryPacker.pack(shared, { n: 1, a: [1], b: [2, 3] }))
    const message = refusal(() => BinaryPacker.pack(shared, { n: 1, a: [1], b: [2, 3, 4] }))

    // Assert
    assert.equal(packs, "01010102" + "03")
    assert.equal(message, "b: the rounds would hold 4 slots, above the limit of 3 slots")
  })
})
