import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, dict, eq, group, repeat, scheme, times, u8, utf8, when } from "../src/index.ts"

type Row = Record<string, unknown>

const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

function refusal(build: () => unknown): string {
  let message = ""
  assert.throws(build, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

const inTimes = () => scheme<Row>(1, u8(0, (r) => r.n), times(1, 0, [dict((r) => r.d, utf8(0, (r) => r.e))]))
const inRepeat = () => scheme<Row>(1, repeat(0, [dict((r) => r.d, utf8(0, (r) => r.e))]))
const lone = "d: a dictionary in a repeat or times round needs a list with one dictionary per round"

describe("AZ-2308 a lone dictionary in a round is refused", () => {
  it("AC-2 a lone dictionary for a Dict name in a times round is refused, naming the member", () => {
    const message = refusal(() => BinaryPacker.pack(inTimes(), { n: 2, d: { a: "x" } }))

    assert.equal(message, lone)
  })

  it("AC-2 a lone dictionary in a repeat round is refused", () => {
    const message = refusal(() => BinaryPacker.pack(inRepeat(), { d: { a: "x" } }))

    assert.equal(message, lone)
  })

  it("AC-2 a lone Map is refused, not packed as an empty dictionary", () => {
    const message = refusal(() => BinaryPacker.pack(inTimes(), { n: 2, d: new Map([["a", "x"]]) }))

    assert.equal(message, lone)
  })

  it("AC-2 a lone dictionary under a when, flags and a group in a round is refused", () => {
    const layout = scheme<Row>(
      1,
      u8(0, (r) => r.n),
      times(1, 0, [
        u8(1, (r) => r.k),
        when(2, eq(1, 1), [group((r) => r.g, [dict((r) => r.d, utf8(0, (r) => r.e))])]),
      ]),
    )

    const message = refusal(() => BinaryPacker.pack(layout, { n: 1, k: [1], d: { a: "x" } }))

    assert.equal(message, lone)
  })

  it("AC-3 a list with one dictionary per round packs, in times and repeat", () => {
    const rows = [{ a: "x" }, { b: "y" }]

    assert.equal(hex(BinaryPacker.pack(inTimes(), { n: 2, d: rows })), "010201000210610210780100021062021079")
    assert.equal(hex(BinaryPacker.pack(inRepeat(), { d: rows })), "0101000210610210780100021062021079")
  })

  it("a dictionary outside a round still packs", () => {
    const layout = scheme<Row>(1, dict((r) => r.d, utf8(0, (r) => r.e)))

    assert.equal(hex(BinaryPacker.pack(layout, { d: { a: "x" } })), "010100021061021078")
  })

  it("a lone string for a Utf8 name in a round still broadcasts", () => {
    const layout = scheme<Row>(1, u8(0, (r) => r.n), times(1, 0, [utf8(1, (r) => r.s)]))

    assert.equal(hex(BinaryPacker.pack(layout, { n: 2, s: "a" })), "0102021061021061")
  })
})
