import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
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
} from "../src/index.ts"

type Row = Record<string, unknown>

const hex = (b: Uint8Array) => Buffer.from(b).toString("hex")

describe("split flag bit scope", () => {
  it("orphan_flag_bit_is_construction_error", () => {
    const inWhen = flagByte("fb")
    assert.throws(
      () =>
        scheme<Row>(
          1,
          u8(0, (x) => x.k),
          when(1, eq(0, 1), [inWhen]),
          inWhen.bit(u8(1, (x) => x.alpha)),
        ),
      /flag bit 0 \(alpha\)/,
    )

    const outerList = flagByte("fb")
    assert.throws(
      () => scheme<Row>(1, outerList, list((x) => x.xs, outerList.bit(u8(0, (x) => x.beta)))),
      /flag bit 0 \(beta\)/,
    )
    const outerDict = flagByte("fb")
    assert.throws(
      () => scheme<Row>(1, outerDict, dict((x) => x.d, outerDict.bit(u8(0, (x) => x.beta)))),
      /flag bit 0 \(beta\)/,
    )
    const outerRepeat = flagByte("fb")
    assert.throws(
      () => scheme<Row>(1, outerRepeat, repeat(0, [outerRepeat.bit(u8(0, (x) => x.gamma))])),
      /flag bit 0 \(gamma\)/,
    )
    const outerTimes = flagByte("fb")
    assert.throws(
      () =>
        scheme<Row>(
          1,
          u8(0, (x) => x.n),
          outerTimes,
          times(1, 0, [outerTimes.bit(u8(1, (x) => x.delta))]),
        ),
      /flag bit 0 \(delta\)/,
    )
  })

  it("flag bit before its flag byte is construction error", () => {
    const top = flagByte("fb")
    assert.throws(
      () => scheme<Row>(1, top.bit(u8(0, (x) => x.early)), top),
      /flag bit 0 \(early\)/,
    )
    const underWhen = flagByte("fb")
    assert.throws(
      () =>
        scheme<Row>(
          1,
          when(0, eq(0, 1), [underWhen.bit(u8(0, (x) => x.early))]),
          underWhen,
        ),
      /flag bit 0 \(early\)/,
    )
    const insideWhen = flagByte("fb")
    assert.throws(
      () =>
        scheme<Row>(
          1,
          u8(0, (x) => x.k),
          when(1, eq(0, 1), [insideWhen.bit(u8(1, (x) => x.early)), insideWhen]),
        ),
      /flag bit 0 \(early\)/,
    )
    const never = flagByte("fb")
    assert.throws(
      () => scheme<Row>(1, never.bit(u8(0, (x) => x.early))),
      /flag bit 0 \(early\)/,
    )
  })

  it("flag byte declared inside a bit's field does not leak to later siblings", () => {
    const outer = flagByte("outer")
    const inner = flagByte("inner")
    assert.throws(
      () =>
        scheme<Row>(
          1,
          outer,
          outer.bit(group((x) => x.g, [inner])),
          inner.bit(u8(0, (x) => x.leaked)),
        ),
      /flag bit 0 \(leaked\)/,
    )
  })

  it("split bit inside a combined flags member is checked", () => {
    const outer = flagByte("outer")
    const missing = flagByte("missing")
    assert.throws(
      () =>
        scheme<Row>(
          1,
          outer,
          outer.bit(flags(0, [missing.bit(u8(0, (x) => x.nested))])),
        ),
      /flag bit 0 \(nested\)/,
    )
    const earlier = flagByte("earlier")
    assert.doesNotThrow(() =>
      scheme<Row>(
        1,
        earlier,
        earlier.bit(flags(0, [earlier.bit(u8(0, (x) => x.nested))])),
      ),
    )
  })

  it("group is transparent to the flag byte scope", () => {
    const fb = flagByte("fb")
    const built = scheme<Row>(1, group((x) => x.g, [fb]), fb.bit(u8(0, (x) => x.a)))
    assert.equal(hex(BinaryPacker.pack(built, { a: 5 })), "010105")
  })

  it("flag byte inside the round of the bit is accepted", () => {
    const fb = flagByte("fb")
    assert.doesNotThrow(() =>
      scheme<Row>(1, repeat(0, [fb, fb.bit(u8(0, (x) => x.a))])),
    )
    const inner = flagByte("fb")
    assert.doesNotThrow(() =>
      scheme<Row>(
        1,
        u8(0, (x) => x.k),
        when(1, eq(0, 1), [inner, inner.bit(u8(1, (x) => x.a))]),
      ),
    )
  })

  it("same_scope_flag_bit_still_builds", () => {
    const fb = flagByte("fb")
    const split = scheme<Row>(
      1,
      fb,
      fb.bit(u8(0, (x) => x.a)),
      fb.bit(u8(1, (x) => x.b)),
    )
    const joined = scheme<Row>(
      1,
      flags(0, [u8(0, (x) => x.a), u8(1, (x) => x.b)]),
    )
    const row = { a: 5 }
    assert.equal(hex(BinaryPacker.pack(split, row)), "010105")
    assert.equal(hex(BinaryPacker.pack(split, row)), hex(BinaryPacker.pack(joined, row)))
    let got: Row | undefined
    const result = BinaryPacker.unpack(Buffer.from("010105", "hex"), split.on((r) => {
      got = r as Row
    }))
    assert.deepEqual(result, { ok: true })
    assert.equal(got!.a, 5)
    assert.equal(got!.b, undefined)
  })

  it("flag bit under a when finds a flag byte in the enclosing scope", () => {
    const fb = flagByte("fb")
    assert.doesNotThrow(() =>
      scheme<Row>(
        1,
        fb,
        when(0, eq(0, 1), [fb.bit(u8(0, (x) => x.a))]),
      ),
    )
  })

  // Shared bitwhen vector: the bit comes from the row even when the when is not taken; unpack
  // tests the when first and never reads that bit.
  it("split bit inside an untaken when keeps its bit (bitwhen)", () => {
    const m = flagByte("m")
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.k),
      m,
      when(1, eq(0, 1), [m.bit(u8(1, (x) => x.v))]),
    )
    const untaken = hex(BinaryPacker.pack(layout, { k: 0, v: 5 }))
    assert.equal(untaken, "010001")
    let got: Row | undefined
    const result = BinaryPacker.unpack(Buffer.from(untaken, "hex"), layout.on((r) => {
      got = r as Row
    }))
    assert.deepEqual(result, { ok: true })
    assert.equal(got!.k, 0)
    assert.equal("v" in got!, false)

    const taken = hex(BinaryPacker.pack(layout, { k: 1, v: 5 }))
    assert.equal(taken, "01010105")
    const back = BinaryPacker.unpack(Buffer.from(taken, "hex"), layout.on((r) => {
      got = r as Row
    }))
    assert.deepEqual(back, { ok: true })
    assert.equal(got!.k, 1)
    assert.equal(got!.v, 5)
  })
})
