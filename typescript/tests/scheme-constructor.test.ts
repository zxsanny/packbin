import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  bool,
  flagByte,
  flags,
  i16,
  i32,
  scheme,
  u8,
  u16,
  type Field,
} from "../src/index.ts"

type Row = Record<string, unknown>

function refusal(build: () => unknown): string {
  let message = ""
  assert.throws(build, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

// Each builder makes fresh fields: a flag-byte handle numbers its bits per call.
const REFUSED: { name: string; typeNumber: number; fields: () => Field[]; message: RegExp }[] = [
  {
    name: "bool outside flags",
    typeNumber: 1,
    fields: () => [bool(0, (x: Row) => x.on)],
    message: /^bool on: allowed only directly inside flags or a flag bit/,
  },
  {
    name: "wrong field id",
    typeNumber: 1,
    fields: () => [u8(1, (x: Row) => x.a)],
    message: /^field id: expected 0, got 1$/,
  },
  {
    name: "split bit outside its flag byte's scope",
    typeNumber: 1,
    fields: () => [flagByte("fb").bit(u8(0, (x: Row) => x.early))],
    message: /^flag bit 0 \(early\)/,
  },
  {
    name: "type number out of range",
    typeNumber: 256,
    fields: () => [u8(0, (x: Row) => x.a)],
    message: /^type number: expected 0\.\.255$/,
  },
]

describe("Scheme constructor", () => {
  for (const c of REFUSED) {
    it(`new Scheme refuses ${c.name} like scheme()`, () => {
      const viaScheme = refusal(() => scheme<Row>(c.typeNumber, ...c.fields()))
      assert.match(viaScheme, c.message)
      const viaNew = refusal(() => new Scheme<Row>(c.typeNumber, c.fields()))
      assert.equal(viaNew, viaScheme)
    })
  }

  it("new Scheme builds the same valid scheme as scheme()", () => {
    const position = (): Field[] => [
      u16(0, (r: Row) => r.sid),
      i32(1, (r: Row) => r.lat),
      i32(2, (r: Row) => r.lon),
      u8(3, (r: Row) => r.profile),
      flags(4, [
        u16(4, (r: Row) => r.heading),
        u8(5, (r: Row) => r.speed),
        i16(6, (r: Row) => r.altitude),
      ]),
    ]
    const row = { sid: 1, lat: 500_000_000, lon: 300_000_000, profile: 1 }
    const viaNew = new Scheme<Row>(0x40, position())
    const viaScheme = scheme<Row>(0x40, ...position())
    const wire = Buffer.from(BinaryPacker.pack(viaNew, row)).toString("hex")
    assert.equal(wire, "4001000065cd1d00a3e1110100")
    assert.equal(wire, Buffer.from(BinaryPacker.pack(viaScheme, row)).toString("hex"))
    assert.deepEqual(viaNew.fields.map((f) => f.kind), viaScheme.fields.map((f) => f.kind))
  })
})
