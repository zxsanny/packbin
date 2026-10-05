import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, dict, eq, repeat, scheme, u8, utf8, when } from "../src/index.ts"

type Row = Record<string, unknown>

const bytesOf = (hex: string) => Buffer.from(hex, "hex")
const hexOf = (b: Uint8Array) => Buffer.from(b).toString("hex")

function unpackRow<T extends Row>(layout: ReturnType<typeof scheme<T>>, hex: string) {
  let row: T | undefined
  let called = 0
  const result = BinaryPacker.unpack(bytesOf(hex), layout.on((value) => {
    row = value as T
    called++
  }))
  return { result, row, called }
}

const PROTO = "5f5f70726f746f5f5f"
const acl = scheme<Row>(1, dict((x) => x.acl, dict((x) => x.inner, u8(0, (x) => x.v))))

describe("dict keys", () => {
  it("dict_proto_key_is_ordinary", () => {
    const { result, row } = unpackRow(acl, `010100${"0900"}${PROTO}0100${"0500"}61646d696e01`)
    assert.deepEqual(result, { ok: true })
    const entries = row!.acl as Record<string, unknown>
    assert.equal("admin" in entries, false)
    assert.equal(Object.getPrototypeOf(entries), Object.prototype)
    assert.deepEqual(Object.keys(entries), ["__proto__"])
    const own = Object.getOwnPropertyDescriptor(entries, "__proto__")
    assert.ok(own, "__proto__ must be an own entry")
    assert.deepEqual(own!.value, { admin: 1 })
  })

  it("dict_duplicate_proto_key_rejected", () => {
    const { result, called } = unpackRow(acl, `010200${"0900"}${PROTO}0000${"0900"}${PROTO}0000`)
    assert.equal(result.ok, false)
    assert.equal(called, 0)
  })

  it("a decoded __proto__ entry packs back to the same bytes", () => {
    const wire = `010100${"0900"}${PROTO}0100${"0500"}61646d696e01`
    const { row } = unpackRow(acl, wire)
    assert.equal(hexOf(BinaryPacker.pack(acl, row!)), wire)
  })

  it("dict_proto_key_with_scalar_value_is_kept", () => {
    const flat = scheme<Row>(1, dict((x) => x.m, u8(0, (x) => x.v)))
    const { result, row } = unpackRow(flat, `010100${"0900"}${PROTO}07`)
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(Object.keys(row!.m as object), ["__proto__"])
    assert.equal(Object.getOwnPropertyDescriptor(row!.m, "__proto__")!.value, 7)
  })
})

describe("when inside repeat", () => {
  const layout = scheme<Row>(
    1,
    repeat(0, [u8(0, (x) => x.k), when(1, eq(0, 1), [u8(1, (x) => x.v)])]),
  )

  it("when_in_repeat_reads_own_round", () => {
    const hit = unpackRow(layout, "01010a")
    assert.deepEqual(hit.result, { ok: true })
    assert.deepEqual(hit.row, { k: [1], v: [10] })

    const miss = unpackRow(layout, "010001")
    assert.deepEqual(miss.result, { ok: false, field: "v", needed: 1, left: 0 })
    assert.equal(miss.called, 0)
  })

  it("later rounds see their own value, not the first round's", () => {
    const rows = unpackRow(layout, "010001" + "0b")
    assert.deepEqual(rows.result, { ok: true })
    assert.deepEqual(rows.row, { k: [0, 1], v: [11] })
  })

  it("when in a repeat naming a field outside it is refused", () => {
    assert.throws(
      () => scheme<Row>(
        1,
        u8(0, (x) => x.mode),
        repeat(1, [u8(1, (x) => x.a), when(2, eq(0, 1), [u8(2, (x) => x.b)])]),
      ),
      /^RangeError: when 2: eq names field id 0, which is not declared earlier in the same scope$/,
    )
  })
})

describe("utf8 byte order mark", () => {
  const text = scheme<Row>(1, utf8(0, (x) => x.s))

  it("bom_is_kept", () => {
    const { result, row } = unpackRow(text, "010600efbbbf616263")
    assert.deepEqual(result, { ok: true })
    assert.equal(row!.s, "﻿abc")
  })

  it("a string that starts with U+FEFF round-trips", () => {
    const wire = BinaryPacker.pack(text, { s: "﻿abc" })
    assert.equal(hexOf(wire), "010600efbbbf616263")
    const { row } = unpackRow(text, hexOf(wire))
    assert.equal(row!.s, "﻿abc")
  })
})
