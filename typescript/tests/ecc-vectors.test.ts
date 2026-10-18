import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, Scheme, bytes, scheme, type SchemeHandler } from "../src/index.ts"
import { checkLimit, checkParity, protect, repair } from "../src/ecc.ts"
import {
  bytesOf,
  eccRows,
  hexOf,
  positionHex,
  positionScheme,
  positionValue,
  unpackPosition,
} from "./support/ecc.ts"

const rowsOf = (kind: string) => eccRows.filter((r) => r.kind === kind)

describe("message ECC shared vectors (codec)", () => {
  it("covers every row kind of the file", () => {
    // Arrange
    const kinds = new Set(eccRows.map((r) => r.kind))

    // Assert
    assert.deepEqual([...kinds].sort(), ["bad", "enc", "fix", "lim", "lmt", "par"])
  })

  for (const row of rowsOf("enc")) {
    it(`${row.id} protect appends exactly the vector parity`, () => {
      // Arrange
      const [n, clear, protectedHex] = row.args

      // Act
      const got = protect(bytesOf(clear!), Number(n))

      // Assert
      assert.equal(hexOf(got), protectedHex === "-" ? "" : protectedHex)
    })
  }

  for (const row of rowsOf("fix")) {
    it(`${row.id} repair returns the clear message and the count`, () => {
      // Arrange
      const [n, t, received, clear, count] = row.args

      // Act
      const got = repair(bytesOf(received!), Number(n), Number(t))

      // Assert
      assert.equal(got.ok, true)
      if (got.ok) {
        assert.equal(hexOf(got.clear), clear === "-" ? "" : clear)
        assert.equal(got.repaired, Number(count))
      }
    })
  }

  for (const row of rowsOf("bad")) {
    it(`${row.id} repair is refused`, () => {
      // Arrange
      const [n, t, received, kind] = row.args
      const input = bytesOf(received!)

      // Act
      const got = repair(input, Number(n), Number(t))

      // Assert
      assert.equal(got.ok, false)
      if (got.ok) return
      if (kind === "short") {
        assert.deepEqual(got, { ok: false, field: "parity", needed: Number(n), left: input.length })
      } else if (kind === "too_long") {
        assert.equal((got as { kind?: string }).kind, "too_long")
      } else {
        assert.deepEqual(got, { ok: false, kind })
      }
    })
  }

  for (const row of rowsOf("lim")) {
    it(`${row.id} protect of ${row.args[1]} bytes under ${row.args[0]} parity bytes: ${row.args[2]}`, () => {
      // Arrange
      const n = Number(row.args[0])
      const length = Number(row.args[1])
      const clear = new Uint8Array(length)

      // Act
      const run = () => protect(clear, n)

      // Assert
      if (row.args[2] === "ok") {
        assert.equal(run().length, length + n)
      } else {
        assert.throws(run, (e: unknown) => {
          assert.ok(e instanceof RangeError)
          assert.ok(e.message.includes(String(length)) && e.message.includes(String(254 - n)), e.message)
          return true
        })
      }
    })

    it(`${row.id} pack through a scheme with the same limit: ${row.args[2]}`, () => {
      // Arrange
      const n = Number(row.args[0])
      const length = Number(row.args[1])
      const s = scheme<{ b: Uint8Array }>(0, bytes(0, (r) => r.b, length - 1)).withLimits({ parity: n })
      const row0 = { b: new Uint8Array(length - 1) }

      // Act
      const run = () => BinaryPacker.pack(s, row0)

      // Assert
      if (row.args[2] === "ok") assert.equal(run().length, length + n)
      else assert.throws(run, RangeError)
    })
  }

  for (const row of rowsOf("par")) {
    it(`${row.id} a scheme with ${row.args[0]} parity bytes is not built`, () => {
      // Arrange
      const n = Number(row.args[0])

      // Act
      const build = () => new Scheme(1, [], { parity: n })

      // Assert
      assert.throws(build, (e: unknown) => {
        assert.ok(e instanceof RangeError)
        assert.ok(e.message.includes(String(n)) && e.message.includes("32"), e.message)
        return true
      })
      assert.throws(() => checkParity(n), RangeError)
    })
  }

  for (const row of rowsOf("lmt")) {
    it(`${row.id} limit ${row.args[1]} over ${row.args[0]} parity bytes is refused before any byte is read`, () => {
      // Arrange
      const n = Number(row.args[0])
      const t = Number(row.args[1])
      const touched: unknown[] = []
      const handler = positionScheme(n).on((r) => touched.push(r)) as SchemeHandler<object>
      const message = BinaryPacker.pack(positionScheme(n), positionValue)

      // Act
      const run = () => BinaryPacker.unpackRepair(message, t, handler)

      // Assert
      assert.throws(run, RangeError)
      assert.throws(() => checkLimit(t, n), RangeError)
      assert.equal(touched.length, 0)
    })
  }
})

describe("message ECC position fixture rows", () => {
  const expected: Record<number, string> = {
    1: "ab",
    2: "16bd",
    4: "ca856682",
    8: "6d4f38479f3f2472",
    16: "4ace66ecd5e4a28ffa28098279f5f19d",
  }

  it("EC-1 a scheme without parity packs the clear bytes", () => {
    // Act
    const packed = BinaryPacker.pack(positionScheme(0), positionValue)

    // Assert
    assert.equal(hexOf(packed), positionHex)
  })

  for (const [n, parity] of Object.entries(expected)) {
    it(`EC-2 n = ${n} packs the report bytes`, () => {
      // Act
      const packed = BinaryPacker.pack(positionScheme(Number(n)), positionValue)

      // Assert
      assert.equal(hexOf(packed), positionHex + parity)
    })
  }

  it("EC-3 n = 33 is not built, naming 33 and 32", () => {
    // Act
    const build = () => positionScheme(33)

    // Assert
    assert.throws(build, (e: unknown) => e instanceof RangeError && e.message.includes("33") && e.message.includes("32"))
  })

  it("EC-3 a negative, fractional or non-numeric count is not built", () => {
    for (const n of [-1, 1.5, Number.NaN, Number.POSITIVE_INFINITY]) {
      assert.throws(() => positionScheme(n), RangeError, String(n))
    }
  })

  it("EC-8 row 7: one wrong byte, n = 2, t = 1 is repaired", () => {
    // Arrange
    const message = bytesOf("4001000065cc1d00a3e111010016bd")

    // Act
    const { result, rows } = unpackPosition(message, 2, 1)

    // Assert
    assert.deepEqual(result, { ok: true, repaired: 1 })
    assert.deepEqual(rows.map((r) => r.sid), [1])
    assert.equal(rows[0]!.lat, 500_000_000)
  })

  it("EC-8 row 8: two wrong bytes, n = 4, t = 2 are repaired", () => {
    // Arrange
    const message = bytesOf("40015a0065cd1d00a322110100ca856682")

    // Act
    const { result, rows } = unpackPosition(message, 4, 2)

    // Assert
    assert.deepEqual(result, { ok: true, repaired: 2 })
    assert.equal(rows[0]!.lon, 300_000_000)
  })

  it("EC-8 rows 9 and 10: two wrong bytes beyond t = 1 or t = 0 are refused with 0 rows", () => {
    // Arrange
    const message = bytesOf("40015a0065cd1d00a322110100ca856682")

    // Act
    const one = unpackPosition(message, 4, 1)
    const zero = unpackPosition(message, 4, 0)

    // Assert
    assert.deepEqual(one.result, { ok: false, kind: "uncorrectable" })
    assert.deepEqual(zero.result, { ok: false, kind: "uncorrectable" })
    assert.equal(one.rows.length + zero.rows.length, 0)
  })

  it("EC-8 row 11: an intact message reports 0 repaired", () => {
    // Act
    const { result, rows } = unpackPosition(bytesOf("4001000065cd1d00a3e1110100ca856682"), 4, 2)

    // Assert
    assert.deepEqual(result, { ok: true, repaired: 0 })
    assert.equal(rows.length, 1)
  })

  it("EC-8 row 12: a buffer shorter than n names the parity, the bytes needed and present", () => {
    // Act
    const { result, rows } = unpackPosition(bytesOf("400100"), 4, 2)
    const empty = unpackPosition(new Uint8Array(0), 1, 0)

    // Assert
    assert.deepEqual(result, { ok: false, field: "parity", needed: 4, left: 3 })
    assert.deepEqual(empty.result, { ok: false, field: "parity", needed: 1, left: 0 })
    assert.equal(rows.length + empty.rows.length, 0)
  })

  it("EC-1 a scheme without parity returns the result it returned before, with no count", () => {
    // Act
    const { result } = unpackPosition(bytesOf(positionHex), 0, 0)

    // Assert
    assert.deepEqual(result, { ok: true })
  })
})
