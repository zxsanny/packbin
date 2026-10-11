import assert from "node:assert/strict"
import { spawnSync } from "node:child_process"
import { fileURLToPath } from "node:url"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  flagByte,
  flags,
  group,
  list,
  repeat,
  scheme,
  times,
  u8,
  u32,
  u64,
  utf8,
  type DispatchResult,
  type Field,
} from "../src/index.ts"

type Row = Record<string, unknown>

const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

const refusal = (run: () => unknown): string => {
  let message = ""
  assert.throws(run, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

function unpack(layout: Scheme<Row>, bytes: Uint8Array): { result: DispatchResult; row?: Row } {
  let row: Row | undefined
  const result = BinaryPacker.unpack(bytes, layout.on((r) => { row = r as Row }))
  return { result, row }
}

// u32 n, then a times of n rounds of one u8 k.
const timesK = (limits = {}): Scheme<Row> =>
  new Scheme<Row>(1, [u32(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.k)])], limits)

// AC-2: a list whose item holds a count and a times of that many u64.
const elementTimes = (limits = {}): Scheme<Row> =>
  new Scheme<Row>(
    1,
    [list((x) => x.items, group((x) => x.item, [u32(0, (x) => x.n), times(1, 0, [u64(1, (x) => x.k)])]))],
    limits,
  )

// AC-4: a times round of 65 u8 members, m0 to m64, each given as a lone scalar 1.
function wideRound(limits = {}): { layout: Scheme<Row>; row: Row } {
  const body: Field[] = []
  const row: Row = { n: 65_535 }
  for (let i = 0; i < 65; i++) {
    body.push(u8(i + 1, new Function("x", `return x.m${i}`) as (x: Row) => unknown))
    row[`m${i}`] = 1
  }
  return { layout: new Scheme<Row>(1, [u32(0, (x) => x.n), times(1, 0, body)], limits), row }
}

describe("AZ-2354 pack has one output budget, maxBytes", () => {
  it("AC-1 a lone string under a capped times is refused naming it, in under 1 s and 256 MB", () => {
    // Arrange
    const child = fileURLToPath(new URL("./support/lone-utf8-budget.ts", import.meta.url))

    // Act
    const run = spawnSync(process.execPath, [child], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], timeout: 30_000 })
    const outcome = JSON.parse(run.stdout) as { error?: string; message?: string; bytes?: number; ms: number; peakBytes: number }

    // Assert
    assert.equal(run.status, 0, run.stderr)
    assert.equal(outcome.bytes, undefined, "no bytes are returned")
    assert.equal(outcome.error, "RangeError")
    assert.equal(outcome.message, "s: the packet would be 16777477 bytes, above the limit of 16777216 bytes")
    assert.ok(outcome.ms < 1000, `took ${outcome.ms} ms`)
    assert.ok(outcome.peakBytes < 256 * 1024 * 1024, `peak ${outcome.peakBytes} bytes`)
  })

  it("AC-2 an element that holds a times is refused at the default budget naming its member", () => {
    // Arrange
    const items = Array.from({ length: 40 }, () => ({ n: 65_535, k: 5 }))

    // Act
    const message = refusal(() => BinaryPacker.pack(elementTimes(), { items }))

    // Assert
    assert.equal(message, "k: the packet would be 16777223 bytes, above the limit of 16777216 bytes")
  })

  it("AC-2 with maxBytes raised to 32 MiB the same row packs and unpacks to it", () => {
    // Arrange
    const layout = elementTimes({ maxBytes: 33_554_432 })
    const items = Array.from({ length: 40 }, () => ({ n: 65_535, k: 5 }))

    // Act
    const wire = BinaryPacker.pack(layout, { items })
    const { result, row } = unpack(layout, wire)

    // Assert
    assert.equal(wire.length, 20_971_363)
    assert.equal(hex(wire.subarray(0, 16)), "012800ffff0000050000000000000005")
    assert.equal(hex(wire.subarray(wire.length - 16)), "05000000000000000500000000000000")
    assert.deepEqual(result, { ok: true })
    const back = row!.items as { n: number; k: bigint[] }[]
    assert.equal(back.length, 40)
    assert.ok(back.every((item) => item.n === 65_535 && item.k.length === 65_535 && item.k.every((k) => k === 5n)))
  })

  it("AC-3 a packet of exactly maxBytes packs; one byte more is refused", () => {
    // Arrange
    const layout = new Scheme<Row>(1, [utf8(0, (x) => x.s)], { maxBytes: 64 })

    // Act
    const exact = BinaryPacker.pack(layout, { s: "a".repeat(61) })
    const message = refusal(() => BinaryPacker.pack(layout, { s: "a".repeat(62) }))

    // Assert
    assert.equal(exact.length, 64)
    assert.equal(hex(exact), `013d00${"61".repeat(61)}`)
    assert.equal(message, "s: the packet would be 65 bytes, above the limit of 64 bytes")
  })

  it("AC-3 the boundary holds round by round: 63 rounds pack in 64 bytes, a 64th is refused", () => {
    // Arrange
    const layout = new Scheme<Row>(1, [repeat(0, [u8(0, (x) => x.k)])], { maxBytes: 64 })

    // Act
    const exact = BinaryPacker.pack(layout, { k: Array(63).fill(7) })
    const message = refusal(() => BinaryPacker.pack(layout, { k: Array(64).fill(7) }))

    // Assert
    assert.equal(hex(exact), `01${"07".repeat(63)}`)
    assert.equal(message, "k: the packet would be 65 bytes, above the limit of 64 bytes")
  })

  it("AC-3 the type byte counts, and a flag byte or a list length is named by its member", () => {
    // Arrange
    const fb = flagByte("m")
    const split = new Scheme<Row>(1, [fb, fb.bit(u8(0, (x) => x.c))], { maxBytes: 1 })
    const combined = new Scheme<Row>(1, [flags(0, [u8(0, (x) => x.c)])], { maxBytes: 1 })
    const items = new Scheme<Row>(1, [list((x) => x.xs, u8(0, (x) => x.v))], { maxBytes: 2 })

    // Act
    const bare = BinaryPacker.pack(new Scheme<Row>(1, [], { maxBytes: 1 }), {})

    // Assert
    assert.equal(hex(bare), "01")
    assert.equal(
      refusal(() => BinaryPacker.pack(new Scheme<Row>(1, [u8(0, (x) => x.a)], { maxBytes: 1 }), { a: 1 })),
      "a: the packet would be 2 bytes, above the limit of 1 bytes",
    )
    assert.equal(refusal(() => BinaryPacker.pack(split, { c: 1 })), "m: the packet would be 2 bytes, above the limit of 1 bytes")
    assert.equal(refusal(() => BinaryPacker.pack(combined, { c: 1 })), "c: the packet would be 2 bytes, above the limit of 1 bytes")
    assert.equal(refusal(() => BinaryPacker.pack(items, { xs: [] })), "xs: the packet would be 3 bytes, above the limit of 2 bytes")
    const timesFirst = new Scheme<Row>(1, [u8(0, (x) => x.n), flags(1, [times(1, 0, [u8(1, (x) => x.k)])])], { maxBytes: 2 })
    assert.equal(refusal(() => BinaryPacker.pack(timesFirst, { n: 1, k: 3 })), "k: the packet would be 3 bytes, above the limit of 2 bytes")
  })
})

describe("AZ-2354 pack charges maxSlots per round as unpack does", () => {
  it("AC-4 a 65-member round counted 65 535 times is refused naming the member", () => {
    // Arrange
    const { layout, row } = wideRound()

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, row))

    // Assert
    assert.equal(message, "m0: the rounds would hold 4194320 slots, above the limit of 4194304 slots")
  })

  it("AC-4 with maxSlots raised to 4 259 775 it packs and unpacks; the default unpack refuses that packet", () => {
    // Arrange
    const { layout, row } = wideRound({ maxSlots: 4_259_775 })

    // Act
    const wire = BinaryPacker.pack(layout, row)
    const { result, row: back } = unpack(layout, wire)

    // Assert
    assert.equal(wire.length, 4_259_780)
    assert.equal(hex(wire.subarray(0, 16)), "01ffff00000101010101010101010101")
    assert.deepEqual(result, { ok: true })
    assert.equal((back!.m64 as number[]).length, 65_535)
    assert.deepEqual(unpack(wideRound().layout, wire).result, { ok: false, field: "m0", needed: 0, left: 65_520 })
  })

  it("slots are charged before the round's bytes and across the whole call", () => {
    // Arrange
    const both = timesK({ maxSlots: 3, maxBytes: 8 })
    const inItems = new Scheme<Row>(
      1,
      [list((x) => x.items, group((x) => x.item, [u8(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.k)])]))],
      { maxSlots: 5 },
    )

    // Act
    const atBoth = hex(BinaryPacker.pack(both, { n: 3, k: 7 }))

    // Assert
    assert.equal(atBoth, "0103000000070707")
    assert.equal(
      refusal(() => BinaryPacker.pack(both, { n: 10, k: 7 })),
      "k: the rounds would hold 4 slots, above the limit of 3 slots",
    )
    assert.equal(
      refusal(() => BinaryPacker.pack(timesK({ maxSlots: 3, maxBytes: 7 }), { n: 10, k: 7 })),
      "k: the packet would be 8 bytes, above the limit of 7 bytes",
    )
    assert.equal(
      refusal(() => BinaryPacker.pack(inItems, { items: [{ n: 3, k: 1 }, { n: 3, k: 2 }] })),
      "k: the rounds would hold 6 slots, above the limit of 5 slots",
    )
    assert.equal(hex(BinaryPacker.pack(inItems, { items: [{ n: 3, k: 1 }, { n: 2, k: 2 }] })), "01020003010101020202")
  })

  it("a round charges the width unpack charges: a non-empty group's own name is not a slot", () => {
    // Arrange
    const layout = new Scheme<Row>(
      1,
      [repeat(0, [u8(0, (x) => x.a), group(1, (x) => x.g, [u8(1, (x) => x.b)])])],
      { maxSlots: 5 },
    )

    // Act
    const two = hex(BinaryPacker.pack(layout, { a: [1, 2], b: [3, 4] }))

    // Assert
    assert.equal(two, "0101030204")
    assert.equal(
      refusal(() => BinaryPacker.pack(layout, { a: [1, 2, 3], b: [3, 4, 5] })),
      "a: the rounds would hold 6 slots, above the limit of 5 slots",
    )
  })

  it("the round cap fires before any round, and a count field before the round cap", () => {
    // Act
    const rounds = refusal(() => BinaryPacker.pack(timesK({ maxRounds: 5, maxSlots: 3, maxBytes: 8 }), { n: 10, k: 7 }))
    const count = refusal(() => BinaryPacker.pack(timesK({ maxRounds: 5, maxSlots: 3, maxBytes: 4 }), { n: 10, k: 7 }))

    // Assert
    assert.equal(rounds, "k: the times count is 10, above the limit of 5 rounds")
    assert.equal(count, "n: the packet would be 5 bytes, above the limit of 4 bytes")
  })
})

describe("AZ-2354 maxBytes limit surface", () => {
  it("AC-5 defaults to 16 MiB, and withLimits keeps resetting a member left out", () => {
    // Arrange
    const base = scheme<Row>(1, u8(0, (x) => x.a))

    // Act
    const raised = base.withLimits({ maxBytes: 64 })
    const reset = raised.withLimits({ maxSlots: 9 })

    // Assert
    assert.deepEqual(
      [base.maxBytes, Scheme.DefaultMaxBytes, raised.maxBytes, reset.maxBytes, base.withLimits({ maxRounds: 9 }).maxBytes],
      [16_777_216, 16_777_216, 64, 16_777_216, 16_777_216],
    )
  })

  it("AC-5 a maxBytes below 1 or not an integer is refused like the other limits", () => {
    // Arrange
    const message = "maxBytes: expected a positive integer up to 9007199254740991"

    // Act / Assert
    for (const bad of [0, -1, 1.5, Number.NaN, 2 ** 53]) {
      assert.equal(refusal(() => new Scheme<Row>(1, [], { maxBytes: bad })), message, String(bad))
      assert.equal(refusal(() => scheme<Row>(1).withLimits({ maxBytes: bad })), message, String(bad))
    }
  })

  it("AC-5 and AC-6 existing limit calls compile and pack the same bytes", () => {
    // Arrange
    const layout = timesK().withLimits({ maxRounds: 3, maxSlots: 3 })

    // Act
    const wire = hex(BinaryPacker.pack(layout, { n: 3, k: 7 }))

    // Assert
    assert.equal(wire, "0103000000070707")
    assert.equal(layout.maxBytes, Scheme.DefaultMaxBytes)
  })
})
