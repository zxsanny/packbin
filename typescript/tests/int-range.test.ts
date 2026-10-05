import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  PackSession,
  be,
  dict,
  eq,
  f32,
  f64,
  flags,
  i16,
  i32,
  i64,
  i8,
  list,
  repeat,
  scheme,
  times,
  u16,
  u32,
  u64,
  u8,
  when,
  type Field,
  type Scheme,
} from "../src/index.ts"

type Row = Record<string, unknown>

const hex = (bytes: Uint8Array) => Buffer.from(bytes).toString("hex")

const field = {
  u8: (): Field => u8(0, (x: Row) => x.a),
  i8: (): Field => i8(0, (x: Row) => x.a),
  u16: (): Field => u16(0, (x: Row) => x.a),
  i16: (): Field => i16(0, (x: Row) => x.a),
  u32: (): Field => u32(0, (x: Row) => x.a),
  i32: (): Field => i32(0, (x: Row) => x.a),
  u64: (): Field => u64(0, (x: Row) => x.a),
  i64: (): Field => i64(0, (x: Row) => x.a),
  f32: (): Field => f32(0, (x: Row) => x.a),
  f64: (): Field => f64(0, (x: Row) => x.a),
}

type Kind = keyof typeof field

function single(kind: Kind): Scheme<Row> {
  return scheme<Row>(1, field[kind]())
}

function refuses(build: () => unknown, kind: string, row = kind): void {
  assert.throws(build, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    assert.ok(/^[a-z]+: /.test(e.message), `message does not start with the member name: ${e.message}`)
    assert.match(e.message, new RegExp(`\\b${kind}\\b`))
    return true
  }, row)
}

function refusesValue(kind: Kind, value: unknown): void {
  refuses(() => BinaryPacker.pack(single(kind), { a: value }), kind, `${kind} ${String(value)}`)
}

function unpackRow(layout: Scheme<Row>, wire: Uint8Array): Row {
  let got: Row | undefined
  const result = BinaryPacker.unpack(wire, layout.on((row) => {
    got = row as Row
  }))
  assert.deepEqual(result, { ok: true })
  return got!
}

describe("integer range", () => {
  it("integer out of range throws", () => {
    const rows: [Kind, unknown][] = [
      ["u8", 300],
      ["u8", -1],
      ["i8", 200],
      ["i8", -129],
      ["u16", 65536],
      ["i16", -32769],
      ["i16", 32768],
      ["u32", 2 ** 32],
      ["u32", -1],
      ["i32", 3_000_000_000],
      ["i32", -2147483649],
      ["i64", 2n ** 63n],
      ["i64", -(2n ** 63n) - 1n],
      ["u64", -1n],
      ["u64", 2n ** 64n],
      ["u64", 2 ** 53 + 1],
      ["u64", 2 ** 60],
      ["i64", 2 ** 60],
      ["u8", 2n ** 70n],
      ["u8", 1e300],
      ["u8", Infinity],
      ["u8", -Infinity],
    ]
    for (const [kind, value] of rows) refusesValue(kind, value)
  })

  it("an unsafe 64-bit number tells the caller to pass a bigint", () => {
    assert.throws(
      () => BinaryPacker.pack(single("u64"), { a: 2 ** 60 }),
      (e: unknown) => e instanceof RangeError && /bigint/.test(e.message),
    )
    assert.equal(hex(BinaryPacker.pack(single("u64"), { a: 2n ** 60n })), "010000000000000010")
  })

  it("integer range edges pack as before", () => {
    const rows: [Kind, unknown, string][] = [
      ["u8", 0, "0100"],
      ["u8", 255, "01ff"],
      ["i8", -128, "0180"],
      ["i8", 127, "017f"],
      ["u16", 65535, "01ffff"],
      ["i16", -32768, "010080"],
      ["u32", 4294967295, "01ffffffff"],
      ["i32", -2147483648, "0100000080"],
      ["u64", 2n ** 64n - 1n, "01ffffffffffffffff"],
      ["i64", -(2n ** 63n), "010000000000000080"],
      ["i64", 2n ** 63n - 1n, "01ffffffffffffff7f"],
      ["u8", 5n, "0105"],
      ["u64", 2 ** 53 - 1, "01ffffffffffff1f00"],
      ["i64", -(2 ** 53 - 1), "01010000000000e0ff"],
    ]
    for (const [kind, value, wire] of rows) {
      assert.equal(hex(BinaryPacker.pack(single(kind), { a: value })), wire, `${kind} ${String(value)}`)
    }
  })

  it("negative zero packs as zero", () => {
    // Arrange
    const rows: [Kind, string][] = [
      ["u8", "0100"],
      ["i8", "0100"],
      ["u64", "010000000000000000"],
    ]

    for (const [kind, wire] of rows) {
      // Act
      const packed = hex(BinaryPacker.pack(single(kind), { a: -0 }))

      // Assert
      assert.equal(packed, wire, kind)
    }
  })

  it("big-endian fields are checked and keep their byte order", () => {
    const layout = scheme<Row>(1, be(u16(0, (x) => x.a)))
    assert.equal(hex(BinaryPacker.pack(layout, { a: 0x1234 })), "011234")
    refuses(() => BinaryPacker.pack(layout, { a: 65536 }), "u16")
    refuses(() => BinaryPacker.pack(scheme<Row>(1, be(i32(0, (x) => x.a))), { a: 2 ** 31 }), "i32")
  })

  it("every container position is checked", () => {
    const m = scheme<Row>(1, u8(0, (x) => x.k), when(1, eq(0, 1), [u8(1, (x) => x.a)]))
    refuses(() => BinaryPacker.pack(m, { k: 1, a: 256 }), "u8")

    const flagged = scheme<Row>(1, flags(0, [u8(0, (x) => x.a)]))
    refuses(() => BinaryPacker.pack(flagged, { a: -1 }), "u8")

    const rep = scheme<Row>(1, repeat(0, [u8(0, (x) => x.a)]))
    refuses(() => BinaryPacker.pack(rep, { a: [1, 2, 256] }), "u8")

    const rounds = scheme<Row>(1, u8(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.a)]))
    refuses(() => BinaryPacker.pack(rounds, { n: 2, a: [1, 300] }), "u8")

    const items = scheme<Row>(1, list((x) => x.a, u16(0, (x) => x)))
    assert.throws(() => BinaryPacker.pack(items, { a: [1, 70000] }), RangeError)

    const named = scheme<Row>(1, dict((x) => x.m, u8(0, (x) => x.a)))
    refuses(() => BinaryPacker.pack(named, { m: { k: 256 } }), "u8")
  })

  it("a refused session pack leaves the pad position alone", () => {
    const layout = single("u8")
    const seed = Uint8Array.from({ length: 32 }, (_, i) => i + 1)
    const nonce = Buffer.from("01000000000000000000000000000000", "hex")
    const refused = PackSession.load(seed)!
    const fresh = PackSession.load(seed)!
    assert.ok(refused.start(nonce))
    assert.ok(fresh.start(nonce))
    refuses(() => refused.pack(layout, { a: 300 }), "u8")
    assert.equal(hex(refused.pack(layout, { a: 7 })!), hex(fresh.pack(layout, { a: 7 })!))
  })
})

describe("non-integer and non-numeric values", () => {
  it("fraction and non-number throw", () => {
    refusesValue("u8", 1.7)
    refusesValue("u8", NaN)
    refusesValue("u8", true)
    refusesValue("u8", "5")
    refusesValue("i64", 1.5)
    refusesValue("u64", "5")
    refusesValue("f64", "1.5")
    refusesValue("f64", "abc")
    refusesValue("f64", true)
    refusesValue("f64", 1n)
    refusesValue("f32", "1.5")
  })
})

describe("float range", () => {
  it("f32 overflow throws, specials pass", () => {
    const layout = single("f32")
    refuses(() => BinaryPacker.pack(layout, { a: 1e39 }), "f32")
    refuses(() => BinaryPacker.pack(layout, { a: -1e39 }), "f32")
    assert.equal(hex(BinaryPacker.pack(layout, { a: Infinity })), "010000807f")
    assert.equal(hex(BinaryPacker.pack(layout, { a: -Infinity })), "01000080ff")
    assert.equal(hex(BinaryPacker.pack(layout, { a: NaN })), "010000c07f")
  })

  it("the largest f32 and f64 values still pack", () => {
    assert.equal(hex(BinaryPacker.pack(single("f32"), { a: 3.4028234663852886e38 })), "01ffff7f7f")
    assert.equal(hex(BinaryPacker.pack(single("f64"), { a: 1.5 })), "01000000000000f83f")
    assert.equal(hex(BinaryPacker.pack(single("f64"), { a: 1e300 })), "019c7500883ce4377e")
  })
})

describe("unpacked rows pack again", () => {
  it("64-bit unpacked row packs again", () => {
    const layout = scheme<Row>(1, u64(0, (x) => x.big), i64(1, (x) => x.neg), u32(2, (x) => x.mid))
    const first = BinaryPacker.pack(layout, { big: 2n ** 60n, neg: -5n, mid: 4294967295 })
    const row = unpackRow(layout, first)
    assert.equal(typeof row.big, "bigint")
    assert.equal(hex(BinaryPacker.pack(layout, row)), hex(first))
  })

  it("an unpacked float row packs again", () => {
    const layout = scheme<Row>(1, f32(0, (x) => x.s), f64(1, (x) => x.d))
    const first = BinaryPacker.pack(layout, { s: 1.5, d: NaN })
    const row = unpackRow(layout, first)
    assert.equal(hex(BinaryPacker.pack(layout, row)), hex(first))
  })
})
