import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, Scheme, bytes, scheme, type SchemeHandler } from "../src/index.ts"
import { protect, protectPercent, repairPercent, parityCount } from "../src/ecc.ts"
import { bytesOf, corrupt, hexOf, positionHex, positionScheme, positionValue } from "./support/ecc.ts"
import { countOf, largestOf, percentRows } from "./support/ecc-percent.ts"

const rowsOf = (kind: string) => percentRows.filter((r) => r.kind === kind)
const hex = (s: string) => (s === "-" ? "" : s)
const positionPercent = (p: number) => positionScheme(0).withLimits({ parityPercent: p })

describe("parity percentage shared vectors", () => {
  it("covers every row kind of the file", () => {
    assert.deepEqual([...new Set(percentRows.map((r) => r.kind))].sort(), ["badp", "encp", "fixp", "inv", "limp", "lmtp", "parp", "pct"])
  })

  for (const row of rowsOf("pct")) {
    it(`${row.id} count`, () => {
      const [p, l, n] = row.args.map(Number)
      assert.equal(parityCount(p!, l!), n)
      assert.equal(countOf(p!, l!), n)
    })
  }

  for (const row of rowsOf("encp")) {
    it(`${row.id} protect appends exactly the vector parity`, () => {
      const [p, clear, want] = row.args
      assert.equal(hexOf(protectPercent(bytesOf(clear!), Number(p))), hex(want!))
    })
  }

  for (const row of rowsOf("inv")) {
    it(`${row.id} clear length of a sent length`, () => {
      const [p, sent, want] = row.args
      if (want === "none") {
        assert.deepEqual(repairPercent(new Uint8Array(Number(sent)), Number(p), 0), { ok: false, kind: "uncorrectable" })
        return
      }
      const word = protectPercent(new Uint8Array(Number(want)), Number(p))
      assert.equal(word.length, Number(sent))
      const got = repairPercent(word, Number(p), 0)
      assert.equal(got.ok && got.clear.length, Number(want))
    })
  }

  for (const row of rowsOf("limp")) {
    it(`${row.id} protect of ${row.args[1]} bytes: ${row.args[2]}`, () => {
      const [p, length] = row.args.map(Number)
      const run = () => protectPercent(new Uint8Array(length!), p!)
      if (row.args[2] === "ok") assert.equal(run().length, length! + countOf(p!, length!))
      else
        assert.throws(run, (e: unknown) => {
          assert.ok(e instanceof RangeError)
          assert.ok(e.message.includes(String(length)) && e.message.includes(String(largestOf(p!))), e.message)
          return true
        })
    })
  }

  for (const row of rowsOf("fixp")) {
    it(`${row.id} repair returns the clear message and the count`, () => {
      const [p, t, received, clear, count] = row.args
      const got = repairPercent(bytesOf(received!), Number(p), Number(t))
      assert.equal(got.ok, true)
      if (got.ok) {
        assert.equal(hexOf(got.clear), hex(clear!))
        assert.equal(got.repaired, Number(count))
      }
    })
  }

  for (const row of rowsOf("badp")) {
    it(`${row.id} repair is refused`, () => {
      const [p, t, received, kind] = row.args
      const got = repairPercent(bytesOf(received!), Number(p), Number(t))
      assert.equal(got.ok, false)
      if (!got.ok) assert.equal((got as { kind?: string }).kind, kind)
    })
  }

  for (const row of rowsOf("parp")) {
    it(`${row.id} percentage ${row.args[0]} with count ${row.args[1]} is not built`, () => {
      const [p, n] = row.args.map(Number)
      assert.throws(
        () => new Scheme(1, [], { parityPercent: p!, parity: n! }),
        (e: unknown) => e instanceof RangeError && e.message.includes(String(p)) && e.message.includes("100"),
      )
    })
  }

  for (const row of rowsOf("lmtp")) {
    it(`${row.id} limit ${row.args[0]} is refused before any byte is read`, () => {
      const touched: unknown[] = []
      const handler = positionPercent(25).on((r) => touched.push(r)) as SchemeHandler<object>
      const message = BinaryPacker.pack(positionPercent(25), positionValue)
      assert.throws(() => BinaryPacker.unpackRepair(message, Number(row.args[0]), handler), RangeError)
      assert.equal(touched.length, 0)
    })
  }
})

describe("parity percentage setting", () => {
  it("reports the percentage; the default is 0", () => {
    assert.equal(positionScheme(0).parityPercent, 0)
    assert.equal(positionPercent(25).parityPercent, 25)
    assert.equal(new Scheme(1, [], { parityPercent: 7 }).parityPercent, 7)
  })

  it("refuses a percentage below 0, above 100 or not an integer, naming it and 100", () => {
    for (const p of [-1, 101, 1.5, Number.NaN]) {
      assert.throws(
        () => positionPercent(p),
        (e: unknown) => e instanceof RangeError && e.message.includes(String(p)) && e.message.includes("100"),
        String(p),
      )
    }
  })

  it("the last setter wins, and the other limits keep what the scheme has", () => {
    const counted = positionScheme(4)
    const pct = counted.withLimits({ parityPercent: 50 })
    assert.deepEqual([pct.parity, pct.parityPercent], [0, 50])
    const back = pct.withLimits({ parity: 8 })
    assert.deepEqual([back.parity, back.parityPercent], [8, 0])
    const kept = pct.withLimits({ maxRounds: 5 })
    assert.deepEqual([kept.parity, kept.parityPercent, kept.maxRounds], [0, 50, 5])
    assert.deepEqual([counted.withLimits({ maxRounds: 5 }).parity], [4])
  })
})

describe("parity percentage pack", () => {
  const lengths = [0, 1, 3, 10, 40, 100, 221]
  for (const p of [0, 10, 25, 50, 100]) {
    for (const len of lengths) {
      it(`p ${p}, ${len} clear bytes: the bytes of the fixed count scheme`, () => {
        const s = scheme<{ b: Uint8Array }>(0, bytes(0, (r) => r.b, len)).withLimits({ parityPercent: p })
        const row = { b: Uint8Array.from({ length: len }, (_, i) => (i * 7 + 3) & 0xff) }
        const n = Math.min(32, Math.ceil((p * (len + 1)) / 100))
        const fixed = scheme<{ b: Uint8Array }>(0, bytes(0, (r) => r.b, len)).withLimits({ parity: n })
        const got = BinaryPacker.pack(s, row)
        assert.equal(got.length, len + 1 + n)
        assert.equal(hexOf(got), hexOf(BinaryPacker.pack(fixed, row)))
      })
    }
  }

  it("the position fixture under 10 percent is the fixed count scheme with 2", () => {
    assert.equal(hexOf(BinaryPacker.pack(positionPercent(10), positionValue)), positionHex + "16bd")
  })

  it("a clear message above the largest length is refused, writing nothing", () => {
    for (const [p, limit] of [[1, 251], [10, 230], [25, 222], [50, 222], [100, 222]] as const) {
      assert.equal(largestOf(p), limit)
      const clear = new Uint8Array(limit + 1)
      assert.throws(
        () => protectPercent(clear, p),
        (e: unknown) => e instanceof RangeError && e.message.includes(String(limit + 1)) && e.message.includes(String(limit)),
      )
      assert.equal(protectPercent(new Uint8Array(limit), p).length <= 254, true)
    }
    const big = scheme<{ b: Uint8Array }>(0, bytes(0, (r) => r.b, 255)).withLimits({ parityPercent: 0 })
    assert.equal(BinaryPacker.pack(big, { b: new Uint8Array(255) }).length, 256)
  })
})

describe("parity percentage round trip", () => {
  it("every pair (p, L) with p 0 to 100 and L up to its largest clear length: 22,752 pairs", () => {
    let pairs = 0
    for (let p = 0; p <= 100; p++) {
      const top = p === 0 ? 254 : largestOf(p)
      for (let length = 0; length <= top; length++) {
        const clear = Uint8Array.from({ length }, (_, i) => (i * 31 + p) & 0xff)
        const sent = protectPercent(clear, p)
        const n = countOf(p, length)
        assert.equal(sent.length, length + n)
        assert.equal(hexOf(sent), hexOf(p === 0 ? clear : protect(clear, n)))
        const got = repairPercent(sent, p, 0)
        assert.equal(got.ok, true, `p ${p} L ${length}`)
        if (got.ok) {
          assert.equal(hexOf(got.clear), hexOf(clear))
          assert.equal(got.repaired, 0)
        }
        pairs++
      }
    }
    assert.equal(pairs, 22_752)
  })

  it("a buffer above 254 bytes is too_long, except with 0 percent", () => {
    assert.deepEqual(repairPercent(new Uint8Array(255), 10, 0), { ok: false, kind: "too_long", length: 255, limit: 254 })
    assert.equal(repairPercent(new Uint8Array(300), 0, 0).ok, true)
  })

  it("an impossible length is uncorrectable", () => {
    assert.deepEqual(repairPercent(new Uint8Array(1), 100, 0), { ok: false, kind: "uncorrectable" })
  })
})

describe("parity percentage repair, limit and dispatch", () => {
  const message = (len: number, p: number) => protectPercent(Uint8Array.from({ length: len }, (_, i) => i * 5 + 1), p)

  it("p 50 with 40 bytes repairs 10, p 25 repairs 5, with the real count", () => {
    for (const [p, t, n] of [[50, 10, 20], [25, 5, 10]] as const) {
      const sent = message(40, p)
      const bad = corrupt(sent, Array.from({ length: t }, (_, i) => i * 3), Array.from({ length: t }, () => 0x5a))
      const got = repairPercent(bad, p, t)
      assert.equal(got.ok, true)
      if (got.ok) assert.equal(got.repaired, t)
      assert.equal(sent.length, 40 + n)
    }
  })

  it("a limit above n / 2 of the message is lowered to it", () => {
    const sent = message(40, 25)
    const five = corrupt(sent, [0, 4, 9, 20, 33], [1, 2, 3, 4, 5])
    const six = corrupt(sent, [0, 4, 9, 20, 33, 41], [1, 2, 3, 4, 5, 6])
    const ok = repairPercent(five, 25, 16)
    assert.equal(ok.ok && ok.repaired, 5)
    const lowered = repairPercent(six, 25, 16)
    const exact = repairPercent(six, 25, 5)
    assert.deepEqual(lowered, exact)
    assert.equal(lowered.ok, false)
  })

  it("dispatch repairs under one shared percentage and reports the count", () => {
    const rows: unknown[] = []
    const h = positionPercent(50).on((r) => rows.push(r)) as SchemeHandler<object>
    const sent = BinaryPacker.pack(positionPercent(50), positionValue)
    const bad = corrupt(sent, [3], [0x77])
    assert.deepEqual(BinaryPacker.unpackRepair(bad, 1, h), { ok: true, repaired: 1 })
    assert.deepEqual(BinaryPacker.unpack(sent, h), { ok: true, repaired: 0 })
    assert.deepEqual(rows, [positionValue, positionValue])
    assert.deepEqual(BinaryPacker.unpack(bad, h), { ok: false, kind: "uncorrectable" })
  })

  it("mixed settings are refused when the call is built, before any byte is read", () => {
    const touched: unknown[] = []
    const mk = (s: Scheme<typeof positionValue>, type: number) =>
      new Scheme(type, s.fields, { parity: s.parity, parityPercent: s.parityPercent }).on((r) => touched.push(r)) as SchemeHandler<object>
    const sent = BinaryPacker.pack(positionPercent(50), positionValue)
    for (const other of [positionPercent(25), positionScheme(4)]) {
      assert.throws(() => BinaryPacker.unpackRepair(sent, 0, mk(positionPercent(50), 1), mk(other, 2)), RangeError)
    }
    assert.equal(touched.length, 0)
  })

  it("a fixed-count scheme keeps its exact limit rule", () => {
    const h = positionScheme(4).on(() => undefined) as SchemeHandler<object>
    const sent = BinaryPacker.pack(positionScheme(4), positionValue)
    assert.throws(() => BinaryPacker.unpackRepair(sent, 3, h), RangeError)
    assert.throws(() => BinaryPacker.unpackRepair(sent, 17, positionPercent(25).on(() => undefined) as SchemeHandler<object>), RangeError)
  })
})
