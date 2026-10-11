import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  eq,
  flagByte,
  flags,
  group,
  scheme,
  times,
  u8,
  u16,
  when,
  type Field,
  type Scheme,
} from "../src/index.ts"

type Row = Record<string, unknown>

const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

function refusal(run: () => unknown): string {
  let message = ""
  assert.throws(run, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

function split(fields: (m: ReturnType<typeof flagByte>) => Field[]): Scheme<Row> {
  const m = flagByte("m")
  return scheme<Row>(1, ...fields(m))
}

function unpack(layout: Scheme<Row>, wire: string): Row | undefined {
  let row: Row | undefined
  const result = BinaryPacker.unpack(Buffer.from(wire, "hex"), layout.on((r) => { row = r as Row }))
  assert.deepEqual(result, { ok: true })
  return row
}

const speed = (x: Row) => x.speed
// WS: the condition is written before the byte.
const ws = () => split((m) => [
  u8(0, (x) => x.mode), m, m.bit(when(1, eq(0, 1), [u8(1, speed)])), m.bit(u16(2, (x) => x.heading)),
])
// The condition is written between the byte and the bit.
const whenAfter = () => split((m) => [
  m, u8(0, (x) => x.mode), m.bit(when(1, eq(0, 1), [u8(1, speed)])), m.bit(u16(2, (x) => x.heading)),
])
// The condition is written by an earlier bit of the same byte.
const whenInBit = () => split((m) => [
  m, m.bit(u8(0, (x) => x.mode)), m.bit(when(1, eq(0, 1), [u8(1, speed)])), m.bit(u16(2, (x) => x.heading)),
])
// TS: the count is written before the byte.
const ts = () => split((m) => [
  u8(0, (x) => x.n), m, m.bit(times(1, 0, [u8(1, (x) => x.pt)])), m.bit(u16(2, (x) => x.heading)),
])
const timesAfter = () => split((m) => [
  m, u8(0, (x) => x.n), m.bit(times(1, 0, [u8(1, (x) => x.pt)])), m.bit(u16(2, (x) => x.heading)),
])
// The count lives in a bit of its own, so a row can leave it out.
const timesSkipped = () => split((m) => [
  m, m.bit(u8(0, (x) => x.n)), m.bit(times(1, 0, [u8(1, (x) => x.pt)])), m.bit(u16(2, (x) => x.heading)),
])
const timesInGroup = () => split((m) => [
  m, m.bit(u8(0, (x) => x.n)),
  m.bit(group(1, (x) => x.g, [times(1, 0, [u8(1, (x) => x.pt)])])),
  m.bit(u16(2, (x) => x.heading)),
])

const WHY = "a value is given, but the condition or count of its when or times is not written before the flag byte, so its bit is clear; write that field before the flag byte"

describe("AZ-2331 a split flag byte pack refuses a body its bit cannot carry", () => {
  it("AC-1 a when condition written after the byte, body given, is refused naming the body member", () => {
    assert.equal(refusal(() => BinaryPacker.pack(whenAfter(), { mode: 1, speed: 7, heading: 90 })), `speed: ${WHY}`)
  })

  it("AC-1 a when condition written by an earlier bit, body given, is refused", () => {
    assert.equal(refusal(() => BinaryPacker.pack(whenInBit(), { mode: 1, speed: 7, heading: 90 })), `speed: ${WHY}`)
  })

  it("AC-1 a times count written after the byte, values given, is refused naming the value", () => {
    assert.equal(refusal(() => BinaryPacker.pack(timesAfter(), { n: 2, pt: [5, 6], heading: 90 })), `pt: ${WHY}`)
  })

  it("AC-2 a times whose count field was skipped, values given, is refused", () => {
    assert.equal(refusal(() => BinaryPacker.pack(timesSkipped(), { pt: [5], heading: 90 })), `pt: ${WHY}`)
  })

  it("AC-2 the same inside a group of the bit is refused", () => {
    assert.equal(refusal(() => BinaryPacker.pack(timesInGroup(), { pt: [5], heading: 90 })), `pt: ${WHY}`)
  })

  it("a count or condition written after the byte with no body given still packs", () => {
    // Act
    const noBody = hex(BinaryPacker.pack(whenAfter(), { mode: 1, heading: 90 }))
    const noValues = hex(BinaryPacker.pack(timesAfter(), { n: 0, heading: 90 }))
    const noCount = hex(BinaryPacker.pack(timesSkipped(), { heading: 90 }))

    // Assert
    assert.deepEqual([noBody, noValues, noCount], ["0102015a00", "0102005a00", "01045a00"])
  })

  it("AC-3 unchanged: a false condition with a body given is dropped without an error (reference row)", () => {
    // Act
    const wire = hex(BinaryPacker.pack(ws(), { mode: 0, speed: 7, heading: 90 }))

    // Assert
    assert.equal(wire, "0100025a00")
    assert.deepEqual(unpack(ws(), wire), { mode: 0, heading: 90 })
  })

  it("AC-3 unchanged: a false condition written after the byte, body given, is dropped without an error", () => {
    assert.equal(hex(BinaryPacker.pack(whenAfter(), { mode: 0, speed: 7, heading: 90 })), "0102005a00")
  })

  it("AC-4 the reference rows with the source before the byte keep their bytes", () => {
    // Act
    const trueRow = hex(BinaryPacker.pack(ws(), { mode: 1, speed: 7, heading: 90 }))
    const noBody = hex(BinaryPacker.pack(ws(), { mode: 1, heading: 90 }))
    const t0 = hex(BinaryPacker.pack(ts(), { n: 0, heading: 90 }))
    const t1 = hex(BinaryPacker.pack(ts(), { n: 1, pt: [5], heading: 90 }))
    const t2 = hex(BinaryPacker.pack(ts(), { n: 2, pt: [5, 6], heading: 90 }))
    const only = hex(BinaryPacker.pack(ts(), { n: 2, pt: [5, 6] }))

    // Assert
    assert.deepEqual(
      [trueRow, noBody, t0, t1, t2, only],
      ["010103075a00", "0101025a00", "0100025a00", "010103055a00", "01020305065a00", "0102010506"],
    )
    assert.deepEqual(unpack(ts(), t2), { n: 2, pt: [5, 6], heading: 90 })
  })

  it("AC-4 the split count rows keep their errors for a list that disagrees with the count", () => {
    assert.match(refusal(() => BinaryPacker.pack(ts(), { n: 0, pt: [5], heading: 90 })), /^pt: 1 items, times count 0$/)
    assert.match(refusal(() => BinaryPacker.pack(ts(), { n: 2, pt: [5], heading: 90 })), /^missing pt$/)
  })

  it("the combined flags form decides each bit in order; a skipped count with values is refused (AZ-2360)", () => {
    // Arrange
    const wa = scheme<Row>(
      1,
      u8(0, (x) => x.mode),
      flags(1, [when(1, eq(0, 1), [u8(1, speed)]), u16(2, (x) => x.heading)]),
    )
    const tc = scheme<Row>(1, flags(0, [u8(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.pt)])]))

    // Act
    const falseBody = hex(BinaryPacker.pack(wa, { mode: 0, speed: 7, heading: 90 }))
    const countSkipped = hex(BinaryPacker.pack(tc, {}))
    const countGiven = hex(BinaryPacker.pack(tc, { n: 2, pt: [5, 6] }))

    // Assert
    assert.deepEqual([falseBody, countSkipped, countGiven], ["0100025a00", "0100", "0103020506"])
    assert.match(refusal(() => BinaryPacker.pack(tc, { pt: [5] })), /^pt: a value is given, but the count of its times is not written/)
  })

  it("a value outside the member's range still fails naming the member, with no bytes", () => {
    assert.match(refusal(() => BinaryPacker.pack(ws(), { mode: 1, speed: 300, heading: 90 })), /^speed/)
    assert.match(refusal(() => BinaryPacker.pack(ts(), { n: 1, pt: [300], heading: 90 })), /^pt/)
  })
  it("review B2 a skipped count under a when inside a split bit is refused naming the member", () => {
    // Arrange
    const layout = split((m) => [
      u8(0, (x) => x.mode), m, m.bit(u8(1, (x) => x.n)),
      m.bit(when(2, eq(0, 1), [times(2, 1, [u8(2, (x) => x.pt)])])),
    ])

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, { mode: 1, pt: [5] }))
    const falseCondition = hex(BinaryPacker.pack(layout, { mode: 0, pt: [5] }))

    // Assert
    assert.equal(message, `pt: ${WHY}`)
    assert.equal(falseCondition, "010000")
  })

  it("review B7 an empty list under a skipped count holds no value and packs", () => {
    // Arrange
    const layout = split((m) => [
      u8(0, (x) => x.mode), m, m.bit(u8(1, (x) => x.n)),
      m.bit(when(2, eq(0, 1), [times(2, 1, [u8(2, (x) => x.pt)])])),
    ])

    // Act
    const inWhen = hex(BinaryPacker.pack(layout, { mode: 1, pt: [] }))
    const bare = hex(BinaryPacker.pack(timesSkipped(), { pt: [], heading: 90 }))

    // Assert
    assert.equal(inWhen, "010100")
    assert.equal(bare, "01045a00")
  })
})
