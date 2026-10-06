import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  eq,
  repeat,
  scheme,
  sized,
  times,
  u8,
  u16,
  u32,
  when,
  type DispatchResult,
} from "../src/index.ts"

type Row = Record<string, unknown>

const bytesOf = (hexText: string): Uint8Array => Uint8Array.from(Buffer.from(hexText, "hex"))

// `rows` holds every row a handler received, so "the handler is not called" is `rows.length === 0`.
function run(layout: Scheme<Row>, bytes: Uint8Array): { result: DispatchResult; rows: Row[] } {
  const rows: Row[] = []
  const result = BinaryPacker.unpack(bytes, layout.on((row) => rows.push(row as Row)))
  return { result, rows }
}

const repeatK = () => scheme<Row>(1, repeat(0, [u8(0, (x) => x.k)]))
const timesK = () => scheme<Row>(1, u8(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.k)]))
const timesK32 = () => scheme<Row>(1, u32(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.k)]))

// Type byte, then `rounds` bytes of 7.
function roundsPacket(rounds: number): Uint8Array {
  const bytes = new Uint8Array(1 + rounds).fill(7)
  bytes[0] = 1
  return bytes
}

// Type byte, a little-endian u32 count, then `rounds` bytes of 7.
function countedPacket(count: number, rounds: number): Uint8Array {
  const bytes = new Uint8Array(5 + rounds).fill(7)
  bytes[0] = 1
  new DataView(bytes.buffer).setUint32(1, count, true)
  return bytes
}

const refused = (field: string, left: number) => ({ ok: false, field, needed: 0, left })

describe("scheme limits surface", () => {
  it("has the documented defaults, constants and a withLimits that keeps the other default", () => {
    // Arrange
    const base = repeatK()

    // Act
    const lowered = base.withLimits({ maxRounds: 10 })

    // Assert
    assert.deepEqual(
      [base.maxRounds, base.maxSlots, Scheme.DefaultMaxRounds, Scheme.DefaultMaxSlots],
      [65_535, 4_194_304, 65_535, 4_194_304],
    )
    assert.deepEqual([lowered.maxRounds, lowered.maxSlots], [10, 4_194_304])
  })

  it("takes the default, not the receiver's value, for a member left out", () => {
    // Arrange
    const base = repeatK().withLimits({ maxRounds: 10, maxSlots: 20 })

    // Act
    const next = base.withLimits({ maxSlots: 30 })
    const reset = base.withLimits()

    // Assert
    assert.deepEqual([next.maxRounds, next.maxSlots], [65_535, 30])
    assert.deepEqual([reset.maxRounds, reset.maxSlots], [65_535, 4_194_304])
  })

  it("keeps the type number and the receiver's limits on a derived scheme", () => {
    // Arrange
    const base = scheme<Row>(9, repeat(0, [u8(0, (x) => x.k)]))

    // Act
    const strict = base.withLimits({ maxRounds: 3 })

    // Assert
    assert.equal(strict.typeNumber, 9)
    assert.equal(base.maxRounds, 65_535)
  })

  it("leaves existing call sites compiling and behaving as before", () => {
    // Arrange
    const viaConstructor = new Scheme<Row>(1, [repeat(0, [u8(0, (x) => x.k)])])
    const viaFactory = repeatK()

    // Act
    const a = run(viaConstructor, bytesOf("01aabb"))
    const b = run(viaFactory, bytesOf("01aabb"))

    // Assert
    assert.deepEqual(a.rows, [{ k: [170, 187] }])
    assert.deepEqual(b.rows, [{ k: [170, 187] }])
    assert.equal(viaConstructor.maxRounds, Scheme.DefaultMaxRounds)
  })

  it("packs and unpacks a derived scheme with a bound reference like its source", () => {
    // Arrange
    const base = scheme<Row>(1, u8(0, (x) => x.n), sized(1, (x) => x.body, 0))
    const derived = base.withLimits({ maxRounds: 3 })
    const row = { n: 2, body: Uint8Array.of(5, 6) }

    // Act
    const wire = BinaryPacker.pack(derived, row)
    const back = run(derived, wire)

    // Assert
    assert.equal(Buffer.from(wire).toString("hex"), Buffer.from(BinaryPacker.pack(base, row)).toString("hex"))
    assert.deepEqual(back.rows, [row])
  })
})

describe("repeat limits", () => {
  it("accepts maxRounds one-byte rounds at the default limit", () => {
    // Arrange
    const layout = repeatK()

    // Act
    const { result, rows } = run(layout, roundsPacket(Scheme.DefaultMaxRounds))

    // Assert
    assert.deepEqual(result, { ok: true })
    assert.equal((rows[0]!.k as unknown[]).length, Scheme.DefaultMaxRounds)
  })

  it("refuses maxRounds + 1 one-byte rounds at the default limit without a handler call", () => {
    // Arrange
    const layout = repeatK()

    // Act
    const { result, rows } = run(layout, roundsPacket(Scheme.DefaultMaxRounds + 1))

    // Assert
    assert.deepEqual(result, refused("k", 1))
    assert.equal(rows.length, 0)
  })

  it("accepts exactly maxRounds rounds under a lowered limit", () => {
    // Arrange
    const layout = repeatK().withLimits({ maxRounds: 3 })

    // Act
    const { result, rows } = run(layout, bytesOf("01aabbcc"))

    // Assert
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(rows, [{ k: [170, 187, 204] }])
  })

  it("refuses when round maxRounds + 1 would start, leaving its byte unread", () => {
    // Arrange
    const layout = repeatK().withLimits({ maxRounds: 3 })

    // Act
    const { result, rows } = run(layout, bytesOf("01aabbccdd"))

    // Assert
    assert.deepEqual(result, refused("k", 1))
    assert.equal(rows.length, 0)
  })
})

describe("times limits", () => {
  const layout = () => timesK().withLimits({ maxRounds: 3 })

  it("accepts a count equal to maxRounds", () => {
    // Arrange
    const bytes = bytesOf("0103090909")

    // Act
    const { result, rows } = run(layout(), bytes)

    // Assert
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(rows, [{ n: 3, k: [9, 9, 9] }])
  })

  it("refuses round 4 of a count of 4 when one byte is left", () => {
    // Arrange
    const bytes = bytesOf("010409090909")

    // Act
    const { result, rows } = run(layout(), bytes)

    // Assert
    assert.deepEqual(result, refused("k", 1))
    assert.equal(rows.length, 0)
  })

  it("refuses round 4 before the short read the unlimited walk gives", () => {
    // Arrange
    const bytes = bytesOf("0104090909")

    // Act
    const { result } = run(layout(), bytes)

    // Assert
    assert.deepEqual(result, refused("k", 0))
  })

  it("keeps the short read when a huge count never reaches the limit", () => {
    // Arrange
    const bytes = bytesOf("01ff09")

    // Act
    const { result } = run(layout(), bytes)

    // Assert
    assert.deepEqual(result, { ok: false, field: "k", needed: 1, left: 0 })
  })

  it("keeps the short read when fewer rounds are present than the count", () => {
    // Arrange
    const bytes = bytesOf("01030909")

    // Act
    const { result } = run(layout(), bytes)

    // Assert
    assert.deepEqual(result, { ok: false, field: "k", needed: 1, left: 0 })
  })
})

describe("times at the default limit", () => {
  it("accepts a count of maxRounds with that many rounds", () => {
    // Arrange
    const bytes = countedPacket(65_535, 65_535)

    // Act
    const { result, rows } = run(timesK32(), bytes)

    // Assert
    assert.deepEqual(result, { ok: true })
    assert.equal((rows[0]!.k as unknown[]).length, 65_535)
  })

  it("refuses a count of maxRounds + 1 when round maxRounds + 1 starts", () => {
    // Arrange
    const bytes = countedPacket(65_536, 65_536)

    // Act
    const { result } = run(timesK32(), bytes)

    // Assert
    assert.deepEqual(result, refused("k", 1))
  })

  it("refuses a count of 2^32 - 1 with maxRounds + 1 rounds present", () => {
    // Arrange
    const bytes = countedPacket(4_294_967_295, 65_536)

    // Act
    const { result } = run(timesK32(), bytes)

    // Assert
    assert.deepEqual(result, refused("k", 1))
  })

  it("refuses a count of 2^32 - 1 with maxRounds rounds present once round maxRounds + 1 starts", () => {
    // Arrange
    const bytes = countedPacket(4_294_967_295, 65_535)

    // Act
    const { result } = run(timesK32(), bytes)

    // Assert
    assert.deepEqual(result, refused("k", 0))
  })

  it("keeps the short read of a count of 2^32 - 1 with one round present", () => {
    // Arrange
    const bytes = bytesOf("01ffffffff00")

    // Act
    const { result } = run(timesK32(), bytes)

    // Assert
    assert.deepEqual(result, { ok: false, field: "k", needed: 1, left: 0 })
  })
})

describe("slot limit", () => {
  const layout = () =>
    scheme<Row>(
      1,
      repeat(0, [
        u8(0, (x) => x.k),
        when(1, eq(0, 1), [u8(1, (x) => x.a), u8(2, (x) => x.b)]),
      ]),
    ).withLimits({ maxSlots: 6 })

  it("accepts rounds whose slots equal maxSlots", () => {
    // Arrange
    const bytes = bytesOf("010000")

    // Act
    const { result, rows } = run(layout(), bytes)

    // Assert
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(rows, [{ k: [0, 0], a: [undefined, undefined], b: [undefined, undefined] }])
  })

  it("refuses the round that would take the slot total above maxSlots", () => {
    // Arrange
    const bytes = bytesOf("01000000")

    // Act
    const { result, rows } = run(layout(), bytes)

    // Assert
    assert.deepEqual(result, refused("k", 1))
    assert.equal(rows.length, 0)
  })

  it("reports every byte still unread when round 3 is refused", () => {
    // Arrange
    const bytes = bytesOf("0100000000")

    // Act
    const { result } = run(layout(), bytes)

    // Assert
    assert.deepEqual(result, refused("k", 2))
  })

  it("keeps one slot total for every field of one unpack call", () => {
    // Arrange
    const base = scheme<Row>(
      1,
      u8(0, (x) => x.n),
      times(1, 0, [u8(1, (x) => x.k)]),
      times(2, 0, [u8(2, (x) => x.v)]),
    )
    const bytes = bytesOf("0102aabbccdd")

    // Act
    const fits = run(base.withLimits({ maxRounds: 3, maxSlots: 4 }), bytes)
    const over = run(base.withLimits({ maxRounds: 3, maxSlots: 3 }), bytes)

    // Assert
    assert.deepEqual(fits.rows, [{ n: 2, k: [170, 187], v: [204, 221] }])
    assert.deepEqual(over.result, refused("v", 1))
    assert.equal(over.rows.length, 0)
  })
})

describe("limits of a large packet", () => {
  it("refuses a 1 MiB packet of one-byte rounds with 36 names after 65,535 rounds", () => {
    // Arrange
    const names = Array.from({ length: 36 }, (_, i) => `f${i}`)
    const member = (name: string) => new Function("x", `return x.${name}`) as (x: Row) => unknown
    const layout = scheme<Row>(
      1,
      repeat(0, [
        u8(0, (x) => x.k),
        when(1, eq(0, 1), names.map((n, i) => (i % 2 === 0 ? u8(1 + i, member(n)) : u16(1 + i, member(n))))),
      ]),
    )
    const bytes = roundsPacket(1_048_576).fill(0, 1)

    // Act
    const started = performance.now()
    const { result, rows } = run(layout, bytes)
    const elapsed = performance.now() - started

    // Assert
    assert.deepEqual(result, refused("k", 983_041))
    assert.equal(rows.length, 0)
    assert.ok(elapsed < 1000, `refusal took ${elapsed} ms`)
  })
})

describe("limits belong to the scheme", () => {
  it("applies each scheme's own limits and leaves the receiver unchanged", () => {
    // Arrange
    const base = repeatK()
    const strict = base.withLimits({ maxRounds: 3 })
    const bytes = bytesOf("01aabbccdd")

    // Act
    const loose = run(base, bytes)
    const tight = run(strict, bytes)

    // Assert
    assert.deepEqual(loose.rows, [{ k: [170, 187, 204, 221] }])
    assert.deepEqual(tight.result, refused("k", 1))
  })

  it("uses the matched handler's scheme when several handlers are given", () => {
    // Arrange
    const base = repeatK()
    const other = scheme<Row>(2, repeat(0, [u8(0, (x) => x.k)])).withLimits({ maxRounds: 2 })
    const seen: Row[] = []

    // Act
    const result = BinaryPacker.unpack(
      bytesOf("02aabbcc"),
      base.on((row) => seen.push(row as Row)),
      other.on((row) => seen.push(row as Row)),
    )

    // Assert
    assert.deepEqual(result, refused("k", 1))
    assert.equal(seen.length, 0)
  })
})

describe("invalid limits", () => {
  const invalid: [string, { maxRounds?: number; maxSlots?: number }, RegExp][] = [
    ["zero rounds", { maxRounds: 0 }, /maxRounds/],
    ["negative rounds", { maxRounds: -1 }, /maxRounds/],
    ["fractional rounds", { maxRounds: 1.5 }, /maxRounds/],
    ["NaN rounds", { maxRounds: NaN }, /maxRounds/],
    ["infinite rounds", { maxRounds: Infinity }, /maxRounds/],
    ["zero slots", { maxSlots: 0 }, /maxSlots/],
    ["slots past the safe integers", { maxSlots: 2 ** 53 }, /maxSlots/],
  ]
  for (const [label, limits, member] of invalid) {
    it(`refuses ${label} at construction`, () => {
      // Arrange
      const base = repeatK()

      // Act
      const build = () => base.withLimits(limits)

      // Assert
      assert.throws(build, (e) => e instanceof RangeError && member.test(e.message))
    })
  }

  it("takes the largest safe integer as the way to raise a limit", () => {
    // Arrange
    const layout = repeatK().withLimits({
      maxRounds: Number.MAX_SAFE_INTEGER,
      maxSlots: Number.MAX_SAFE_INTEGER,
    })

    // Act
    const { result, rows } = run(layout, roundsPacket(Scheme.DefaultMaxRounds + 1))

    // Assert
    assert.deepEqual(result, { ok: true })
    assert.equal((rows[0]!.k as unknown[]).length, Scheme.DefaultMaxRounds + 1)
  })

  it("refuses a bad limit passed to the constructor too", () => {
    // Arrange
    const fields = [repeat(0, [u8(0, (x: Row) => x.k)])]

    // Act
    const build = () => new Scheme<Row>(1, fields, { maxSlots: 0 })

    // Assert
    assert.throws(build, (e) => e instanceof RangeError && /maxSlots/.test(e.message))
  })
})
