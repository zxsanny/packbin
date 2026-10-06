import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
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
  u16,
  when,
  type Field,
} from "../src/index.ts"

type Row = Record<string, unknown>

const bytesOf = (h: string): Uint8Array => Uint8Array.from(Buffer.from(h, "hex"))
const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

const anchored = (): Field => group(0, (x) => x.p, [u8(0, (p) => p.a)])
const pair = (): Field => group((x) => x.p, [u8(0, (p) => p.a), u8(1, (p) => p.b)])

const MESSAGE = "element is an anchored group (p); use a group without an anchor"

function refusal(message: string): { name: string; message: string } {
  return { name: "RangeError", message }
}

function repacks(layout: Scheme<Row>, wire: string): void {
  let row: Row | undefined
  const result = BinaryPacker.unpack(bytesOf(wire), layout.on((r) => {
    row = r as Row
  }))
  assert.deepEqual(result, { ok: true })
  assert.equal(hex(BinaryPacker.pack(layout, row!)), wire)
}

describe("list and dict elements of an anchored group are refused when the scheme is built", () => {
  it("AC-1 a list of anchored groups is refused by scheme and by new Scheme", () => {
    // Arrange
    const fields = [list((x) => x.g, anchored())]

    // Act and Assert
    assert.throws(() => scheme<Row>(1, ...fields), refusal(`list g: ${MESSAGE}`))
    assert.throws(() => new Scheme<Row>(1, fields), refusal(`list g: ${MESSAGE}`))
  })

  it("AC-1 withLimits on a valid scheme still builds", () => {
    // Arrange
    const layout = scheme<Row>(1, list((x) => x.pts, pair()))

    // Act
    const limited = layout.withLimits({ maxRounds: 5 })

    // Assert
    assert.equal(hex(BinaryPacker.pack(limited, { pts: [{ a: 1, b: 2 }] })), "0101000102")
  })

  it("AC-2 a dict of anchored groups is refused", () => {
    // Arrange
    const fields = [dict((x) => x.g, anchored())]

    // Act and Assert
    assert.throws(() => scheme<Row>(1, ...fields), refusal(`dict g: ${MESSAGE}`))
    assert.throws(() => new Scheme<Row>(1, fields), refusal(`dict g: ${MESSAGE}`))
  })

  describe("AC-3 wherever the list or dict stands", () => {
    const m = flagByte("m")
    const places: [string, () => Field[], string][] = [
      [
        "a when body",
        () => [u8(0, (x) => x.k), when(1, eq(0, 1), [list((x) => x.g, anchored())])],
        `list g: ${MESSAGE}`,
      ],
      ["a repeat body", () => [repeat(0, [list((x) => x.g, anchored())])], `list g: ${MESSAGE}`],
      [
        "a times body",
        () => [u8(0, (x) => x.n), times(1, 0, [list((x) => x.g, anchored())])],
        `list g: ${MESSAGE}`,
      ],
      [
        "an unanchored group element",
        () => [list((x) => x.t, group((x) => x.q, [list((x) => x.g, anchored())]))],
        `list g: ${MESSAGE}`,
      ],
      ["a flags member", () => [flags(0, [list((x) => x.g, anchored())])], `list g: ${MESSAGE}`],
      ["a flag bit", () => [m, m.bit(list((x) => x.g, anchored()))], `list g: ${MESSAGE}`],
      [
        "a flags nested directly in flags",
        () => [flags(0, [flags(0, [list((x) => x.g, anchored())])])],
        `list g: ${MESSAGE}`,
      ],
      [
        "the element of an inner dict",
        () => [dict((x) => x.t, dict((y) => y.u, group(0, (x) => x.g, [u8(0, (p) => p.a)])))],
        `dict u: element is an anchored group (g); use a group without an anchor`,
      ],
    ]
    for (const [place, build, message] of places) {
      it(`AC-3 ${place}`, () => {
        // Arrange
        const fields = build()

        // Act and Assert
        assert.throws(() => scheme<Row>(1, ...fields), refusal(message))
        assert.throws(() => new Scheme<Row>(1, fields), refusal(message))
      })
    }
  })

  it("AC-4 a when element keeps its refusal", () => {
    assert.throws(
      () => scheme<Row>(1, list((x) => x.w, when(0, eq(0, 1), [u8(0, (p) => p.a)]))),
      refusal("when 0: eq names field id 0, which is not declared earlier in the same scope"),
    )
  })

  it("AC-4 a times element keeps its refusal", () => {
    assert.throws(
      () => scheme<Row>(1, list((x) => x.t, times(0, 0, [u8(0, (p) => p.a)]))),
      refusal("times 0: count names field id 0, which is not declared earlier in the same scope"),
    )
  })

  it("AC-5 a wrong field id keeps its message", () => {
    assert.throws(
      () => scheme<Row>(1, list((x) => x.g, group(1, (x) => x.p, [u8(1, (p) => p.a)]))),
      refusal("field id: expected 0, got 1"),
    )
  })

  it("AC-5 an empty anchored group keeps its message", () => {
    assert.throws(
      () => scheme<Row>(1, list((x) => x.g, group(0, (x) => x.p, []))),
      refusal("empty group p: allowed only directly inside flags or a flag bit; move it into flags"),
    )
  })

  it("AC-5 an earlier refusal elsewhere in the scheme comes first", () => {
    assert.throws(
      () =>
        scheme<Row>(
          1,
          list((x) => x.g, anchored()),
          when(0, eq(5, 1), [u8(0, (p) => p.b)]),
        ),
      refusal("when 0: eq names field id 5, which is not declared earlier in the same scope"),
    )
  })
})

describe("AC-6 elements that work today keep their bytes", () => {
  const cases: [string, () => Field[], Row, string][] = [
    ["list of group", () => [list((x) => x.pts, pair())], { pts: [{ a: 1, b: 2 }, { a: 3, b: 4 }] }, "01020001020304"],
    [
      "dict of group",
      () => [dict((x) => x.m, pair())],
      { m: { y: { a: 3, b: 4 }, x: { a: 1, b: 2 } } },
      "01020001007801020100790304",
    ],
    [
      "list of flags",
      () => [list((x) => x.pts, flags(0, [u8(0, (p) => p.a), u16(1, (p) => p.b)]))],
      { pts: [{ a: 1 }, {}, { b: 2 }] },
      "010300010100020200",
    ],
    ["list of leaf", () => [list((x) => x.t, u8(0, (a) => a.p))], { t: [1, 2] }, "0102000102"],
    [
      "list of list of group",
      () => [list((x) => x.t, list((y) => y.u, group((x) => x.g, [u8(0, (p) => p.a)])))],
      { t: [[{ a: 1 }]] },
      "010100010001",
    ],
    [
      "anchored group inside the element",
      () => [
        list((x) => x.t, group((x) => x.g, [u8(0, (p) => p.a), group(1, (p) => p.q, [u8(1, (p) => p.b)])])),
      ],
      { t: [{ a: 1, b: 2 }] },
      "0101000102",
    ],
    [
      "when inside the element",
      () => [
        list((x) => x.t, group((x) => x.g, [u8(0, (p) => p.a), when(1, eq(0, 1), [u8(1, (p) => p.b)])])),
      ],
      { t: [{ a: 1, b: 2 }, { a: 0 }] },
      "010200010200",
    ],
    [
      "times inside the element",
      () => [list((x) => x.t, group((x) => x.g, [u8(0, (p) => p.a), times(1, 0, [u8(1, (p) => p.b)])]))],
      { t: [{ a: 2, b: [3, 4] }] },
      "010100020304",
    ],
    [
      "anchored group beside a list of group",
      () => [
        group(0, (x) => x.h, [u8(0, (p) => p.k)]),
        list((x) => x.pts, group((x) => x.p, [u8(0, (p) => p.a)])),
      ],
      { k: 7, pts: [{ a: 1 }] },
      "0107010001",
    ],
    ["top-level anchored group", () => [group(0, (x) => x.g, [u8(0, (p) => p.a)])], { a: 1 }, "0101"],
  ]
  for (const [label, build, row, wire] of cases) {
    it(`AC-6 ${label}`, () => {
      // Arrange
      const layout = scheme<Row>(1, ...build())

      // Act
      const packed = hex(BinaryPacker.pack(layout, row))

      // Assert
      assert.equal(packed, wire)
      repacks(layout, wire)
    })
  }
})
