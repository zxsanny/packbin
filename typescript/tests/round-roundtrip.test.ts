import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  bool,
  eq,
  flagByte,
  flags,
  group,
  repeat,
  scheme,
  sized,
  times,
  u2,
  u8,
  u16,
  when,
} from "../src/index.ts"

type Row = Record<string, unknown>

const hex = (bytes: Uint8Array): string => Buffer.from(bytes).toString("hex")

function unpackRow(layout: Scheme<Row>, bytes: Uint8Array): Row | undefined {
  let got: Row | undefined
  const result = BinaryPacker.unpack(bytes, layout.on((row) => {
    got = row as Row
  }))
  return result.ok ? got : undefined
}

// Every body is built so that each byte 0..3 is a canonical value of whatever reads it (a flag
// byte has two members, a u2 pair fits in two bits), so a packet that unpacks must repack to the
// same bytes.
const SHAPES: Record<string, { build: () => Scheme<Row> }> = {
  whenRepeat: {
    build: () => scheme<Row>(
      1,
      repeat(0, [u8(0, (x) => x.k), when(1, eq(0, 1), [u8(1, (x) => x.v)])]),
    ),
  },
  boolFlags: {
    build: () => scheme<Row>(1, repeat(0, [flags(0, [bool(0, (x) => x.on), u8(1, (x) => x.n)])])),
  },
  groupInFlags: {
    build: () => scheme<Row>(
      1,
      repeat(0, [
        u8(0, (x) => x.k),
        flags(1, [group(1, (x) => x.mark, [u8(1, (x) => x.g)]), u16(2, (x) => x.n)]),
      ]),
    ),
  },
  u2AndWhen: {
    build: () => scheme<Row>(
      1,
      repeat(0, [
        u8(0, (x) => x.k),
        u2(1, (x) => x.p, 2, (x) => x.q),
        when(3, eq(0, 2), [u8(3, (x) => x.v)]),
      ]),
    ),
  },
  unanchoredGroup: {
    build: () => scheme<Row>(
      1,
      repeat(0, [
        u8(0, (x) => x.k),
        group((x) => x.row, [u8(0, (x) => x.v), when(1, eq(0, 1), [u8(1, (x) => x.w)])]),
      ]),
    ),
  },
  whenWithFlags: {
    build: () => scheme<Row>(
      1,
      repeat(0, [
        u8(0, (x) => x.k),
        flags(1, [u8(1, (x) => x.a), u8(2, (x) => x.b)]),
        when(3, eq(0, 1), [flags(3, [u8(3, (x) => x.c), bool(4, (x) => x.d)])]),
      ]),
    ),
  },
  splitFlagByte: {
    build: () => {
      const fb = flagByte("m")
      return scheme<Row>(1, repeat(0, [fb, fb.bit(u8(0, (x) => x.a)), fb.bit(bool(1, (x) => x.b))]))
    },
  },
  countInRound: {
    build: () => scheme<Row>(1, repeat(0, [u8(0, (x) => x.n), sized(1, (x) => x.p, 0)])),
  },
  whenTimes: {
    build: () => scheme<Row>(
      1,
      u8(0, (x) => x.a),
      times(1, 0, [
        u8(1, (x) => x.k),
        when(2, eq(1, 1), [u8(2, (x) => x.v)]),
        flags(3, [u8(3, (x) => x.f), bool(4, (x) => x.g)]),
      ]),
    ),
  },
  flagsTimes: {
    build: () => scheme<Row>(
      1,
      u8(0, (x) => x.a),
      times(1, 0, [flags(1, [bool(1, (x) => x.on), u8(2, (x) => x.n)])]),
    ),
  },
}

function mulberry32(seed: number): () => number {
  let a = seed
  return () => {
    a = (a + 0x6d2b79f5) | 0
    let t = Math.imul(a ^ (a >>> 15), 1 | a)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function lists(row: Row): unknown[][] {
  return Object.values(row).filter((v): v is unknown[] => Array.isArray(v))
}

describe("round trip of random packets", () => {
  for (const [name, shape] of Object.entries(SHAPES)) {
    it(`${name}: a packet that unpacks repacks to the same bytes, one entry per round`, () => {
      // Arrange
      const layout = shape.build()
      const rng = mulberry32(0x5eed)
      let accepted = 0
      let manyRounds = 0

      // Act and Assert
      for (let i = 0; i < 3000; i++) {
        const body = Array.from({ length: Math.floor(rng() * 14) }, () => Math.floor(rng() * 4))
        const bytes = Uint8Array.from([1, ...body])
        const row = unpackRow(layout, bytes)
        if (row === undefined) continue
        accepted++
        const again = BinaryPacker.pack(layout, row)
        assert.equal(hex(again), hex(bytes), `repack of ${hex(bytes)}`)
        const sizes = new Set(lists(row).map((list) => list.length))
        assert.ok(sizes.size <= 1, `${hex(bytes)}: lists of different lengths ${[...sizes]}`)
        if (Math.max(0, ...sizes) >= 2) manyRounds++
      }

      assert.ok(accepted > 200, `only ${accepted} of 3000 packets unpacked`)
      assert.ok(manyRounds > 50, `only ${manyRounds} packets had two rounds or more`)
    })
  }
})

// The accessor text is what names the member, so a generated name needs generated source.
const member = (name: string) => new Function("x", `return x.${name}`) as (x: Row) => unknown

describe("unpack of a large packet", () => {
  it("keeps one entry per round for every name a round can hold", () => {
    // Arrange
    const names = Array.from({ length: 36 }, (_, i) => `f${i}`)
    const layout = scheme<Row>(
      1,
      repeat(0, [
        u8(0, (x) => x.k),
        when(1, eq(0, 1), names.map((n, i) => (i % 2 === 0 ? u8(1 + i, member(n)) : u16(1 + i, member(n))))),
      ]),
    )
    const rounds = 50_000
    const bytes = new Uint8Array(1 + rounds)
    bytes[0] = 1

    // Act
    const row = unpackRow(layout, bytes)

    // Assert
    assert.equal((row!.k as unknown[]).length, rounds)
    for (const n of names) assert.equal((row![n] as unknown[]).length, rounds, n)
  })
})
