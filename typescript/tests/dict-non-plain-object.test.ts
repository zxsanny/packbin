import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, dict, flags, scheme, times, u8, u16, utf8 } from "../src/index.ts"

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

const outside = () => scheme<Row>(1, dict((r) => r.d, utf8(0, (r) => r.e)))
const inTimes = () => scheme<Row>(1, u8(0, (r) => r.n), times(1, 0, [dict((r) => r.d, utf8(0, (r) => r.e))]))
const inFlags = () =>
  scheme<Row>(
    1,
    u8(0, (r) => r.n),
    flags(1, [times(1, 0, [dict((r) => r.d, utf8(0, (r) => r.e))]), u16(1, (r) => r.h)]),
  )

class Rowish {
  a = "x"
}

describe("a value that is not a plain object is no dictionary", () => {
  const notPlain: [string, unknown][] = [
    ["Map", new Map([["a", "x"]])],
    ["empty Map", new Map()],
    ["Set", new Set(["a"])],
    ["Date", new Date(0)],
    ["class instance", new Rowish()],
    ["array", ["a"]],
    ["string", "a"],
  ]

  for (const [label, value] of notPlain) {
    it(`outside a round a ${label} for a dict name is refused, naming the member`, () => {
      const message = refusal(() => BinaryPacker.pack(outside(), { d: value }))

      assert.equal(message, "d: expected dictionary")
    })
  }

  it("a Map in a times round is refused as a lone dictionary, not broadcast", () => {
    const message = refusal(() => BinaryPacker.pack(inTimes(), { n: 2, d: new Map([["a", "x"]]) }))

    assert.equal(message, "d: a dictionary in a repeat or times round needs a list with one dictionary per round")
  })

  it("a Set and a Date in a times round are refused as lone dictionaries", () => {
    for (const value of [new Set(["a"]), new Date(0)]) {
      const message = refusal(() => BinaryPacker.pack(inTimes(), { n: 2, d: value }))

      assert.match(message, /^d: a dictionary in a repeat or times round/)
    }
  })

  it("a plain object and a prototype-less object still pack as a dictionary", () => {
    const bare = Object.assign(Object.create(null) as Row, { a: "x" })

    assert.equal(hex(BinaryPacker.pack(outside(), { d: { a: "x" } })), "010100021061021078")
    assert.equal(hex(BinaryPacker.pack(outside(), { d: bare })), "010100021061021078")
  })

  it("a list of prototype-less rows still packs in a round", () => {
    const bare = Object.assign(Object.create(null) as Row, { a: "x" })

    assert.equal(hex(BinaryPacker.pack(inTimes(), { n: 1, d: [bare] })), "01010100021061021078")
  })
})

describe("a lone dictionary under a times in flags is refused whatever the count", () => {
  it("a times with count 0 in flags refuses a lone dictionary, as outside flags", () => {
    const message = refusal(() => BinaryPacker.pack(inFlags(), { n: 0, d: { a: "x" }, h: 5 }))

    assert.equal(message, "d: a dictionary in a repeat or times round needs a list with one dictionary per round")
  })

  it("a times with count 0 outside flags refuses the same lone dictionary", () => {
    const message = refusal(() => BinaryPacker.pack(inTimes(), { n: 0, d: { a: "x" } }))

    assert.equal(message, "d: a dictionary in a repeat or times round needs a list with one dictionary per round")
  })

  it("a times with count 0 in flags and no dictionary given still packs", () => {
    assert.equal(hex(BinaryPacker.pack(inFlags(), { n: 0, h: 5 })), "0100020500")
  })
})
