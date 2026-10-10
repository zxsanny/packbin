import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  bits,
  bool,
  bytes,
  eq,
  f32,
  f64,
  flags,
  group,
  i16,
  packed,
  scheme,
  sized,
  times,
  u2,
  u8,
  u64,
  utf8,
  when,
  type Field,
} from "../src/index.ts"

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

const onFlag = (value: unknown): Field[] => [
  flags(0, [bool(0, (x: Row) => x.on)]),
  when(1, eq(0, value), [u8(1, (x: Row) => x.v)]),
]

describe("AZ-2126 eq on a bool accepts only true", () => {
  it("AC-1 eq(bool, false) is a scheme error naming the when and the field", () => {
    // Act
    const message = refusal(() => scheme<Row>(1, ...onFlag(false)))

    // Assert
    assert.equal(message, "when 1: eq names bool field id 0 (on) and accepts only true, not false")
  })

  for (const value of [1, 0, "yes", "true", null, undefined, {}, [true]]) {
    it(`AC-1 eq(bool, ${typeof value === "object" ? JSON.stringify(value) : String(value)}) is a scheme error`, () => {
      const message = refusal(() => scheme<Row>(1, ...onFlag(value)))

      assert.match(message, /^when 1: eq names bool field id 0 \(on\) and accepts only true, not /)
    })
  }

  it("AC-1 new Scheme refuses like scheme()", () => {
    const viaNew = refusal(() => new Scheme<Row>(1, onFlag(false)))

    assert.equal(viaNew, refusal(() => scheme<Row>(1, ...onFlag(false))))
  })

  it("AC-1 a flag bit holding a bool is refused the same way as the combined form", () => {
    const fb = flags(0, [bool(0, (x: Row) => x.on)])

    const message = refusal(() => scheme<Row>(1, fb, when(1, eq(0, false), [u8(1, (x: Row) => x.v)])))

    assert.match(message, /^when 1: eq names bool field id 0 \(on\)/)
  })

  it("AC-2 eq(bool, true) packs 010105 and round-trips", () => {
    // Arrange
    const layout = scheme<Row>(1, ...onFlag(true))
    let row: Row | undefined

    // Act
    const wire = hex(BinaryPacker.pack(layout, { on: true, v: 5 }))
    const result = BinaryPacker.unpack(Buffer.from(wire, "hex"), layout.on((r) => {
      row = r as Row
    }))

    // Assert
    assert.equal(wire, "010105")
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(row, { on: true, v: 5 })
  })

  it("AC-2 eq(bool, true) with the bool false leaves the body out", () => {
    const layout = scheme<Row>(1, ...onFlag(true))

    assert.equal(hex(BinaryPacker.pack(layout, { on: false, v: 5 })), "0100")
  })
})

describe("AZ-2126 a when names an integer or a bool only", () => {
  const SOURCES: { kind: string; build: () => Field[]; id: number }[] = [
    { kind: "f32", build: () => [f32(0, (x: Row) => x.x)], id: 0 },
    { kind: "f64", build: () => [f64(0, (x: Row) => x.x)], id: 0 },
    { kind: "utf8", build: () => [utf8(0, (x: Row) => x.x)], id: 0 },
    { kind: "bytes", build: () => [bytes(0, (x: Row) => x.x, 2)], id: 0 },
    { kind: "sized", build: () => [u8(0, (x: Row) => x.n), sized(1, (x: Row) => x.x, 0)], id: 1 },
    { kind: "bits", build: () => [u8(0, (x: Row) => x.n), bits(1, (x: Row) => x.x, 0)], id: 1 },
    { kind: "packed", build: () => [u8(0, (x: Row) => x.n), packed(1, 1, (x: Row) => x.x, 0)], id: 1 },
  ]

  for (const c of SOURCES) {
    it(`AC-1 a when naming a ${c.kind} field is a scheme error`, () => {
      const anchor = c.id + 1
      const message = refusal(() => scheme<Row>(
        1,
        ...c.build(),
        when(anchor, eq(c.id, 1), [u8(anchor, (x: Row) => x.v)]),
      ))

      assert.equal(message, `when ${anchor}: eq names field id ${c.id} (x), which is not an integer or a bool`)
    })
  }

  it("a when naming an integer, a u2 slot, or a clear bool still builds", () => {
    assert.doesNotThrow(() => scheme<Row>(1, u64(0, (x: Row) => x.k), when(1, eq(0, 1n), [u8(1, (x: Row) => x.v)])))
    assert.doesNotThrow(() => scheme<Row>(1, i16(0, (x: Row) => x.k), when(1, eq(0, -1), [u8(1, (x: Row) => x.v)])))
    assert.doesNotThrow(() => scheme<Row>(
      1,
      u2(0, (x: Row) => x.a, 1, (x: Row) => x.b),
      when(2, eq(1, 1), [u8(2, (x: Row) => x.v)]),
    ))
  })

  it("an empty-group mark has no id in TypeScript, so no eq can name it", () => {
    const message = refusal(() => scheme<Row>(
      1,
      flags(0, [group((x: Row) => x.mark, [])]),
      when(0, eq(0, true), [u8(0, (x: Row) => x.v)]),
    ))

    assert.equal(message, "when 0: eq names field id 0, which is not declared earlier in the same scope")
  })
})

describe("AZ-2126 a count names an integer field only", () => {
  const COUNTS: { kind: string; source: () => Field; label: string }[] = [
    { kind: "bool", source: () => flags(0, [bool(0, (x: Row) => x.n)]), label: "n" },
    { kind: "f32", source: () => f32(0, (x: Row) => x.n), label: "n" },
    { kind: "f64", source: () => f64(0, (x: Row) => x.n), label: "n" },
    { kind: "utf8", source: () => utf8(0, (x: Row) => x.n), label: "n" },
  ]

  for (const c of COUNTS) {
    it(`AC-1 a times count naming a ${c.kind} field is a scheme error`, () => {
      const message = refusal(() => scheme<Row>(1, c.source(), times(1, 0, [u8(1, (x: Row) => x.v)])))

      assert.equal(message, `times 1: count names field id 0 (${c.label}), which is not an integer`)
    })

    it(`AC-1 a sized count naming a ${c.kind} field is a scheme error`, () => {
      const message = refusal(() => scheme<Row>(1, c.source(), sized(1, (x: Row) => x.p, 0)))

      assert.equal(message, `sized 1: count names field id 0 (${c.label}), which is not an integer`)
    })
  }
})
