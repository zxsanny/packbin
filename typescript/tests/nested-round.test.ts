import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  bool,
  dict,
  eq,
  flagByte,
  flags,
  group,
  list,
  repeat,
  scheme,
  times,
  u8,
  when,
  type Field,
} from "../src/index.ts"

type Row = Record<string, unknown>

const hex = (bytes: Uint8Array): string => Buffer.from(bytes).toString("hex")

function refusal(build: () => unknown): string {
  let message = ""
  assert.throws(build, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

function roundTrip(layout: Scheme<Row>, row: Row): { wire: string; again: string } {
  const wire = BinaryPacker.pack(layout, row)
  let got: Row | undefined
  const result = BinaryPacker.unpack(wire, layout.on((r) => {
    got = r as Row
  }))
  assert.deepEqual(result, { ok: true })
  return { wire: hex(wire), again: hex(BinaryPacker.pack(layout, got!)) }
}

// Each builder makes fresh fields: a flag-byte handle numbers its bits per call.
const SHAPES: { name: string; fields: () => Field[]; nested: RegExp }[] = [
  {
    name: "repeat in repeat",
    fields: () => [repeat(0, [u8(0, (x) => x.m), repeat(1, [u8(1, (x) => x.v)])])],
    nested: /^repeat 1 is inside a repeat or times round; a round cannot hold another repeat or times$/,
  },
  {
    name: "times in repeat",
    fields: () => [repeat(0, [u8(0, (x) => x.c), times(1, 0, [u8(1, (x) => x.v)])])],
    nested: /^times 1 is inside a repeat or times round; a round cannot hold another repeat or times$/,
  },
  {
    name: "repeat in times",
    fields: () => [u8(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.m), repeat(2, [u8(2, (x) => x.v)])])],
    nested: /^repeat 2 is inside a repeat or times round; a round cannot hold another repeat or times$/,
  },
  {
    name: "times in times",
    fields: () => [u8(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.c), times(2, 1, [u8(2, (x) => x.v)])])],
    nested: /^times 2 is inside a repeat or times round; a round cannot hold another repeat or times$/,
  },
  {
    name: "repeat in a when in a repeat",
    fields: () => [repeat(0, [u8(0, (x) => x.k), when(1, eq(0, 1), [repeat(1, [u8(1, (x) => x.v)])])])],
    nested: /^repeat 1 is inside a repeat or times round/,
  },
  {
    name: "repeat in flags in a repeat",
    fields: () => [repeat(0, [flags(0, [repeat(0, [u8(0, (x) => x.v)])])])],
    nested: /^repeat 0 is inside a repeat or times round/,
  },
  {
    name: "repeat in flags in flags in a repeat",
    fields: () => [repeat(0, [flags(0, [flags(0, [repeat(0, [u8(0, (x) => x.v)])])])])],
    nested: /^repeat 0 is inside a repeat or times round/,
  },
  {
    name: "repeat in a repeat inside a list element",
    fields: () => [
      list((x) => x.rows, group((x) => x.row, [repeat(0, [u8(0, (x) => x.a), repeat(1, [u8(1, (x) => x.b)])])])),
    ],
    nested: /^repeat 1 is inside a repeat or times round; a round cannot hold another repeat or times$/,
  },
  {
    name: "repeat in a repeat inside a dict element",
    fields: () => [
      dict((x) => x.rows, group((x) => x.row, [repeat(0, [u8(0, (x) => x.a), repeat(1, [u8(1, (x) => x.b)])])])),
    ],
    nested: /^repeat 1 is inside a repeat or times round; a round cannot hold another repeat or times$/,
  },
  {
    name: "repeat in a split flag bit in a repeat",
    fields: () => {
      const fb = flagByte("m")
      return [repeat(0, [fb, fb.bit(repeat(0, [u8(0, (x) => x.v)])), fb.bit(bool(1, (x) => x.on))])]
    },
    nested: /^repeat 0 is inside a repeat or times round/,
  },
  {
    name: "repeat in an anchored group in a repeat",
    fields: () => [repeat(0, [group(0, (x) => x.g, [repeat(0, [u8(0, (x) => x.v)])])])],
    nested: /^repeat 0 is inside a repeat or times round/,
  },
  {
    name: "times in an unanchored group in a repeat",
    fields: () => [
      repeat(0, [group((x) => x.g, [u8(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.v)])])]),
    ],
    nested: /^times 1 is inside a repeat or times round/,
  },
  {
    name: "repeat in a group in a group in a times",
    fields: () => [
      u8(0, (x) => x.n),
      times(1, 0, [group(1, (x) => x.a, [group((x) => x.b, [repeat(0, [u8(0, (x) => x.v)])])])]),
    ],
    nested: /^repeat 0 is inside a repeat or times round/,
  },
]

describe("nested rounds", () => {
  for (const c of SHAPES) {
    it(`${c.name} is refused by scheme() and new Scheme()`, () => {
      // Arrange
      const build = () => c.fields()

      // Act
      const viaScheme = refusal(() => scheme<Row>(1, ...build()))
      const viaNew = refusal(() => new Scheme<Row>(1, build()))

      // Assert
      assert.match(viaScheme, c.nested)
      assert.equal(viaNew, viaScheme)
    })
  }

  it("a repeat in a list element inside a repeat round builds; empty collections round-trip", () => {
    // Arrange
    // AZ-2102: a non-empty group element does not pack per item yet, so only empty collections round-trip.
    const fields = () => [
      repeat(0, [
        u8(0, (x) => x.k),
        list((x) => x.rows, group((x) => x.row, [repeat(0, [u8(0, (x) => x.v)])])),
      ]),
    ]

    // Act
    const layout = scheme<Row>(1, ...fields())
    const viaNew = new Scheme<Row>(1, fields())
    const { wire, again } = roundTrip(layout, { k: [1, 2], rows: [[], []] })

    // Assert
    assert.equal(hex(BinaryPacker.pack(viaNew, { k: [1, 2], rows: [[], []] })), wire)
    assert.equal(wire, "01010000020000")
    assert.equal(again, wire)
  })

  it("a times in a dict element inside a times round builds; empty collections round-trip", () => {
    // Arrange
    // AZ-2102: a non-empty group element does not pack per item yet, so only empty collections round-trip.
    const fields = () => [
      u8(0, (x) => x.n),
      times(1, 0, [
        u8(1, (x) => x.k),
        dict((x) => x.rows, group((x) => x.row, [u8(0, (x) => x.c), times(1, 0, [u8(1, (x) => x.v)])])),
      ]),
    ]

    // Act
    const layout = scheme<Row>(1, ...fields())
    const viaNew = new Scheme<Row>(1, fields())
    const row = { n: 2, k: [1, 2], rows: [{}, {}] }
    const { wire, again } = roundTrip(layout, row)

    // Assert
    assert.equal(hex(BinaryPacker.pack(viaNew, row)), wire)
    assert.equal(wire, "0102010000020000")
    assert.equal(again, wire)
  })

  it("a list element outside a round may hold a repeat before a round that does not", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      list((x) => x.rows, group((x) => x.row, [repeat(0, [u8(0, (x) => x.v)])])),
      repeat(0, [u8(0, (x) => x.k)]),
    )

    // Act
    const { wire, again } = roundTrip(layout, { rows: [], k: [3, 4] })

    // Assert
    assert.equal(wire, "010000" + "0304")
    assert.equal(again, wire)
  })
})
