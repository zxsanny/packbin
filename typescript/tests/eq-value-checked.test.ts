import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, bool, eq, flags, i8, scheme, u2, u8, u16, u32, u64, when, type Field } from "../src/index.ts"

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

const SOURCES: Record<string, () => Field> = {
  u8: () => u8(0, (x) => x.mode),
  i8: () => i8(0, (x) => x.mode),
  u16: () => u16(0, (x) => x.mode),
  u32: () => u32(0, (x) => x.mode),
  u64: () => u64(0, (x) => x.mode),
  u2: () => u2(0, (x) => x.mode),
}

const build = (kind: string, value: unknown) =>
  scheme<Row>(1, SOURCES[kind]!(), when(1, eq(0, value), [u8(1, (x) => x.speed)]))

const REFUSED: [string, unknown, string, string][] = [
  ["u8", 300, "300", "0 to 255"],
  ["u8", -1, "-1", "0 to 255"],
  ["u8", "x", '"x"', "0 to 255"],
  ["u8", Number.NaN, "NaN", "0 to 255"],
  ["u8", 1.5, "1.5", "0 to 255"],
  ["u8", true, "true", "0 to 255"],
  ["u8", 1e30, "1e+30", "0 to 255"],
  ["u8", 256n, "256", "0 to 255"],
  ["i8", 128, "128", "-128 to 127"],
  ["i8", -129, "-129", "-128 to 127"],
  ["u16", 65_536, "65536", "0 to 65535"],
  ["u32", 4_294_967_296, "4294967296", "0 to 4294967295"],
  ["u64", -1, "-1", "0 to 18446744073709551615"],
  ["u64", 1e20, "100000000000000000000", "0 to 18446744073709551615"],
  ["u64", 1n << 64n, "18446744073709551616", "0 to 18446744073709551615"],
  ["u2", 4, "4", "0 to 3"],
  ["u2", -1, "-1", "0 to 3"],
]

const BUILT: [string, unknown][] = [
  ["u8", 5], ["u8", 5.0], ["u8", 255], ["u8", 0], ["u8", 5n],
  ["i8", -128], ["i8", 127], ["u16", 65_535], ["u32", 4_294_967_295],
  ["u64", 18_446_744_073_709_551_615n], ["u64", 2 ** 53], ["u2", 3],
]

describe("AZ-2338 an eq value is checked against the integer source when the scheme is built", () => {
  for (const [kind, value, shown, range] of REFUSED) {
    it(`AC-1..3 eq(${kind}, ${shown}) is a scheme error naming the when and the member`, () => {
      assert.equal(
        refusal(() => build(kind, value)),
        `when 1 tests ${kind} field 0 ('mode') against ${shown}; the value must be a whole number from ${range}`,
      )
    })
  }

  for (const [kind, value] of BUILT) {
    it(`AC-4 eq(${kind}, ${String(value)}) builds`, () => {
      assert.doesNotThrow(() => build(kind, value))
    })
  }

  it("AC-4 a valid value packs the same bytes and a whole-number float equals the integer", () => {
    // Arrange
    const layout = build("u8", 5.0)

    // Act
    const held = hex(BinaryPacker.pack(layout, { mode: 5, speed: 9 }))
    const other = hex(BinaryPacker.pack(layout, { mode: 4, speed: 9 }))

    // Assert
    assert.deepEqual([held, other], ["010509", "0104"])
  })

  it("the refusal does not depend on member order: a source in a list element is checked too", () => {
    // Arrange / Act
    const message = refusal(() => scheme<Row>(
      1,
      u8(0, (x) => x.mode),
      when(1, eq(0, 5), [u8(1, (x) => x.a), when(2, eq(1, 999), [u8(2, (x) => x.b)])]),
    ))

    // Assert
    assert.equal(message, "when 2 tests u8 field 1 ('a') against 999; the value must be a whole number from 0 to 255")
  })

  it("eq on a bool source keeps the AZ-2126 rule (only true)", () => {
    // Arrange
    const on = (value: unknown) =>
      scheme<Row>(1, flags(0, [bool(0, (x) => x.on)]), when(1, eq(0, value), [u8(1, (x) => x.b)]))

    // Act
    const message = refusal(() => on(1))

    // Assert
    assert.doesNotThrow(() => on(true))
    assert.equal(message, "when 1: eq names bool field id 0 (on) and accepts only true, not 1")
  })
})
