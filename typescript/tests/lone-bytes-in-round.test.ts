import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, bytes, eq, flags, group, repeat, scheme, sized, times, u8, utf8, when, type Scheme } from "../src/index.ts"

type Row = Record<string, unknown>

const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")
const buf = (...b: number[]): Uint8Array => Uint8Array.from(b)

const refusal = (run: () => unknown): string => {
  let message = ""
  assert.throws(run, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

const timesBytes = (): Scheme<Row> =>
  scheme<Row>(1, u8(0, (x) => x.n), times(1, 0, [bytes(1, (x) => x.b, 2)]))
const repeatBytes = (): Scheme<Row> => scheme<Row>(1, repeat(0, [bytes(0, (x) => x.b, 2)]))
const timesSized = (): Scheme<Row> =>
  scheme<Row>(1, u8(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.c), sized(2, (x) => x.s, 1)]))

const LONE = "a byte buffer in a repeat or times round needs a list with one buffer per round"

describe("AZ-2332 a lone byte buffer in a round is refused", () => {
  it("AC-1 a lone Uint8Array for a bytes name in a times is refused naming the member", () => {
    assert.equal(refusal(() => BinaryPacker.pack(timesBytes(), { n: 2, b: buf(1, 2) })), `b: ${LONE}`)
  })

  it("AC-1 a lone ArrayBuffer for a bytes name in a times is refused", () => {
    assert.equal(refusal(() => BinaryPacker.pack(timesBytes(), { n: 2, b: buf(1, 2).buffer })), `b: ${LONE}`)
  })

  it("AC-1 a lone buffer for a one-round times is refused too", () => {
    assert.equal(refusal(() => BinaryPacker.pack(timesBytes(), { n: 1, b: buf(1, 2) })), `b: ${LONE}`)
  })

  it("AC-1 a lone buffer for a bytes name in a repeat is refused", () => {
    assert.equal(refusal(() => BinaryPacker.pack(repeatBytes(), { b: buf(1, 2) })), `b: ${LONE}`)
  })

  it("AC-1 a lone buffer for a sized name in a times is refused even when its length fits", () => {
    assert.equal(refusal(() => BinaryPacker.pack(timesSized(), { n: 1, c: 1, s: buf(9) })), `s: ${LONE}`)
  })

  it("AC-1 a lone buffer for a name under a when, a group and a flags of the round is refused", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.n),
      times(1, 0, [
        u8(1, (x) => x.k),
        flags(2, [group(2, (x) => x.g, [when(2, eq(1, 2), [bytes(2, (x) => x.b, 2)])])]),
      ]),
    )

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, { n: 2, k: [2, 2], b: buf(9, 9) }))

    // Assert
    assert.equal(message, `b: ${LONE}`)
  })

  it("AC-2 a list with one buffer per round packs as before", () => {
    // Act
    const times2 = hex(BinaryPacker.pack(timesBytes(), { n: 2, b: [buf(1, 2), buf(3, 4)] }))
    const repeat2 = hex(BinaryPacker.pack(repeatBytes(), { b: [buf(1, 2), buf(3, 4)] }))
    const sized2 = hex(BinaryPacker.pack(timesSized(), { n: 2, c: [1, 1], s: [buf(9), buf(8)] }))
    const oneRound = hex(BinaryPacker.pack(timesBytes(), { n: 1, b: [buf(1, 2)] }))

    // Assert
    assert.deepEqual([times2, repeat2, sized2, oneRound], ["010201020304", "0101020304", "010201090108", "01010102"])
  })

  it("a lone string for a utf8 name still goes to every round (unchanged)", () => {
    // Arrange
    const layout = scheme<Row>(1, u8(0, (x) => x.n), times(1, 0, [utf8(1, (x) => x.s)]))

    // Act
    const wire = hex(BinaryPacker.pack(layout, { n: 2, s: "ab" }))

    // Assert
    assert.equal(wire, "01020200616202006162")
  })

  it("a bytes field outside a round still takes one buffer", () => {
    // Arrange
    const layout = scheme<Row>(1, bytes(0, (x) => x.b, 2))

    // Act
    const wire = hex(BinaryPacker.pack(layout, { b: buf(1, 2) }))

    // Assert
    assert.equal(wire, "010102")
  })

  it("unpack then repack of a bytes round gives the same bytes", () => {
    // Arrange
    const layout = timesBytes()
    let row: Row | undefined
    BinaryPacker.unpack(Buffer.from("010201020304", "hex"), layout.on((r) => { row = r as Row }))

    // Act
    const wire = hex(BinaryPacker.pack(layout, row!))

    // Assert
    assert.equal(wire, "010201020304")
  })
})
