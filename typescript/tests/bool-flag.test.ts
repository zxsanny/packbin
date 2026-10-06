import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
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
  type Scheme,
} from "../src/index.ts"

type Row = Record<string, unknown>

function hex(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("hex")
}

function unpackRow(layout: Scheme<Row>, wire: string): Row {
  let got: Row | undefined
  const result = BinaryPacker.unpack(Buffer.from(wire, "hex"), layout.on((row) => {
    got = row as Row
  }))
  assert.deepEqual(result, { ok: true }, wire)
  return got!
}

function rejects(build: () => unknown, member: string): void {
  assert.throws(build, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    assert.match(e.message, new RegExp(`\\b${member}\\b`))
    assert.match(e.message, /flags/)
    return true
  })
}

const eightU8 = (): Field[] => [
  u8(0, (x: Row) => x.f0),
  u8(1, (x: Row) => x.f1),
  u8(2, (x: Row) => x.f2),
  u8(3, (x: Row) => x.f3),
  u8(4, (x: Row) => x.f4),
  u8(5, (x: Row) => x.f5),
  u8(6, (x: Row) => x.f6),
  u8(7, (x: Row) => x.f7),
]

describe("bool presence and the 8-bit flag limit", () => {
  it("bool false leaves the flag bit clear", () => {
    const layout = scheme<Row>(1, flags(0, [bool(0, (x) => x.on)]))
    assert.equal(hex(BinaryPacker.pack(layout, { on: false })), "0100")
    assert.equal(hex(BinaryPacker.pack(layout, {})), "0100")
    assert.equal(hex(BinaryPacker.pack(layout, { on: true })), "0101")
  })

  it("bool unpacks true only when set", () => {
    const layout = scheme<Row>(1, flags(0, [bool(0, (x) => x.on)]))
    assert.equal("on" in unpackRow(layout, "0100"), false)
    assert.equal(unpackRow(layout, "0101").on, true)
    const back = unpackRow(layout, hex(BinaryPacker.pack(layout, { on: false })))
    assert.equal("on" in back, false)
  })

  it("bool values other than true leave the bit clear", () => {
    const layout = scheme<Row>(1, flags(0, [bool(0, (x) => x.on)]))
    assert.equal(hex(BinaryPacker.pack(layout, { on: 1 })), "0100")
    assert.equal(hex(BinaryPacker.pack(layout, { on: "yes" })), "0100")
    assert.equal("on" in unpackRow(layout, "0100"), false)
  })

  it("split form bool false", () => {
    const m = flagByte("m")
    const layout = scheme<Row>(1, m, m.bit(bool(0, (x) => x.on)))
    assert.equal(hex(BinaryPacker.pack(layout, { on: false })), "0100")
    assert.equal(hex(BinaryPacker.pack(layout, { on: true })), "0101")
    assert.equal(unpackRow(layout, "0101").on, true)
    assert.equal("on" in unpackRow(layout, "0100"), false)
  })

  it("empty group mark false", () => {
    const layout = scheme<Row>(1, flags(0, [group((x) => x.mark, [])]))
    assert.equal(hex(BinaryPacker.pack(layout, { mark: true })), "0101")
    assert.equal(hex(BinaryPacker.pack(layout, { mark: false })), "0100")
    assert.equal(hex(BinaryPacker.pack(layout, {})), "0100")
    assert.equal(unpackRow(layout, "0101").mark, true)
    assert.equal("mark" in unpackRow(layout, "0100"), false)
  })

  it("bool outside flags is a scheme error", () => {
    rejects(() => scheme<Row>(1, u8(0, (x) => x.a), bool(1, (x) => x.top)), "top")
    rejects(
      () => scheme<Row>(1, group((x) => x.g, [u8(0, (x) => x.n), bool(1, (x) => x.inGroup)])),
      "inGroup",
    )
    rejects(
      () =>
        scheme<Row>(
          1,
          flags(0, [group((x) => x.g, [u8(0, (x) => x.n), bool(1, (x) => x.underFlags)])]),
        ),
      "underFlags",
    )
    rejects(
      () =>
        scheme<Row>(1, u8(0, (x) => x.k), when(1, eq(0, 1), [bool(1, (x) => x.inWhen)])),
      "inWhen",
    )
    rejects(() => scheme<Row>(1, repeat(0, [bool(0, (x) => x.inRepeat)])), "inRepeat")
    rejects(
      () =>
        scheme<Row>(
          1,
          u8(0, (x) => x.n),
          times(1, 0, [u8(1, (x) => x.v), bool(2, (x) => x.inTimes)]),
        ),
      "inTimes",
    )
    rejects(() => scheme<Row>(1, list((x) => x.xs, bool(0, (x) => x.inList))), "inList")
    rejects(() => scheme<Row>(1, dict((x) => x.d, bool(0, (x) => x.inDict))), "inDict")
  })

  it("empty group outside flags is a scheme error", () => {
    rejects(() => scheme<Row>(1, u8(0, (x) => x.n), group((x) => x.mark, [])), "mark")
    const m = flagByte("m")
    rejects(
      () =>
        scheme<Row>(
          1,
          m,
          m.bit(group((x) => x.g, [u8(0, (x) => x.n), group((x) => x.inner, [])])),
        ),
      "inner",
    )
  })

  it("ninth flag bit is a scheme error", () => {
    const nine = [...eightU8(), u8(8, (x: Row) => x.f8)]
    assert.throws(() => flags(0, nine), RangeError)
    assert.throws(() => scheme<Row>(1, flags(0, nine)), RangeError)

    const m = flagByte("m")
    const eight = eightU8().map((f) => m.bit(f))
    // A handle can be shared by many schemes (AZ-2135), so the ninth bit is refused when the scheme
    // is built, not when `bit` is called.
    assert.throws(() => scheme<Row>(1, m, ...eight, m.bit(u8(8, (x: Row) => x.f8))), RangeError)

    const short = scheme<Row>(1, flags(0, eightU8()))
    const split = scheme<Row>(1, m, ...eight)
    for (const layout of [short, split]) {
      const wire = hex(BinaryPacker.pack(layout, { f0: 1, f7: 7 }))
      assert.equal(wire, "01810107")
      const back = unpackRow(layout, wire)
      assert.equal(back.f0, 1)
      assert.equal(back.f7, 7)
      assert.equal("f1" in back, false)
    }
  })
})
