import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, eq, flagByte, flags, group, scheme, u8, u16, when } from "../src/index.ts"
import { failsNaming, hex, runCases, type Case, type Row } from "./support/member-cases.ts"

const speed = when(1, eq(0, 1), [u8(1, (x) => x.speed)])
const mode = u8(0, (x) => x.mode)
const heading = u16(2, (x) => x.heading)

const WA = scheme<Row>(1, mode, flags(1, [speed, heading]))
const WS = (() => {
  const fb = flagByte("m")
  return scheme<Row>(1, mode, fb, fb.bit(speed), fb.bit(heading))
})()
const WG = scheme<Row>(1, mode, flags(1, [group(1, (x) => x.g, [speed]), heading]))
const W2 = scheme<Row>(
  1,
  mode,
  flags(1, [when(1, eq(0, 1), [u8(1, (x) => x.speed), u8(2, (x) => x.extra)]), u16(3, (x) => x.heading)]),
)
const GS = scheme<Row>(
  1,
  mode,
  flags(1, [
    group(1, (x) => x.g, [u8(1, (x) => x.extra), when(2, eq(0, 1), [u8(2, (x) => x.speed)])]),
    u16(3, (x) => x.heading),
  ]),
)
const WE = scheme<Row>(1, flags(0, [u8(0, (x) => x.mode), when(1, eq(0, 1), [u8(1, (x) => x.speed)])]))

const shapes: [string, typeof WA][] = [["flags", WA], ["split", WS], ["group", WG]]

const whenCases: Case[] = shapes.flatMap(([kind, layout]) => [
  { name: `AC-3 ${kind} when true`, layout, row: { mode: 1, speed: 7, heading: 90 }, hex: "010103075a00", unpacks: { mode: 1, speed: 7, heading: 90 } },
  { name: `AC-3 ${kind} when false`, layout, row: { mode: 0, heading: 90 }, hex: "0100025a00", unpacks: { mode: 0, heading: 90 } },
  { name: `AC-3 ${kind} when true without body`, layout, row: { mode: 1, heading: 90 }, hex: "0101025a00", unpacks: { mode: 1, heading: 90 } },
  { name: `AC-3 ${kind} when false with a body given`, layout, row: { mode: 0, speed: 7, heading: 90 }, hex: "0100025a00", unpacks: { mode: 0, heading: 90 } },
  { name: `AC-5 ${kind} old packet`, layout, hex: "0101025a00", unpacks: { mode: 1, heading: 90 }, unpackOnly: true },
]).concat(
  [["flags", WA], ["group", WG]].flatMap(([kind, layout]) => [
    { name: `AC-3 ${kind as string} only the when`, layout: layout as typeof WA, row: { mode: 1, speed: 7 }, hex: "01010107", unpacks: { mode: 1, speed: 7 } },
  ]),
  [
    { name: "AC-3 flags only mode", layout: WA, row: { mode: 0 }, hex: "010000", unpacks: { mode: 0 } },
    { name: "AC-5 flags new packet", layout: WA, hex: "010103075a00", unpacks: { mode: 1, speed: 7, heading: 90 }, unpackOnly: true },
    { name: "AC-3 two body values", layout: W2, row: { mode: 1, speed: 7, extra: 8, heading: 90 }, hex: "01010307085a00", unpacks: { mode: 1, speed: 7, extra: 8, heading: 90 } },
    { name: "AC-3 group sibling with the when true", layout: GS, row: { mode: 1, extra: 4, speed: 7, heading: 90 }, hex: "01010304075a00", unpacks: { mode: 1, extra: 4, speed: 7, heading: 90 } },
    { name: "AC-3 group sibling with the when false", layout: GS, row: { mode: 0, extra: 4, heading: 90 }, hex: "010003045a00", unpacks: { mode: 0, extra: 4, heading: 90 } },
    { name: "AC-3 group with nothing in it", layout: GS, row: { mode: 1, heading: 90 }, hex: "0101025a00", unpacks: { mode: 1, heading: 90 } },
    { name: "AC-3 when names an earlier member of its own flags", layout: WE, row: { mode: 1, speed: 7 }, hex: "01030107", unpacks: { mode: 1, speed: 7 } },
    { name: "AC-3 same-flags when false", layout: WE, row: { mode: 0, speed: 7 }, hex: "010100", unpacks: { mode: 0 } },
    { name: "AC-3 same-flags when without body", layout: WE, row: { mode: 1 }, hex: "010101", unpacks: { mode: 1 } },
    { name: "AC-3 same-flags when without mode", layout: WE, row: { speed: 7 }, hex: "0100", unpacks: {} },
  ],
)

describe("a when as a flags member is written like any other value", () => {
  runCases(whenCases)

  failsNaming("AC-3 W2 body value missing", W2, { mode: 1, speed: 7, heading: 90 }, "extra")
  failsNaming("AC-3 GS when body missing", GS, { mode: 1, extra: 4, heading: 90 }, "speed")
  failsNaming("AC-3 GS sibling missing, group on through the when", GS, { mode: 1, speed: 7, heading: 90 }, "extra")

  it("AC-3 a body value outside its field range fails naming the field", () => {
    // Act
    const pack = () => BinaryPacker.pack(WA, { mode: 1, speed: 300, heading: 90 })

    // Assert
    assert.throws(pack, (error: unknown) => error instanceof RangeError && /speed/.test(error.message))
  })

  it("AC-6 a row that does not use the shape is unchanged", () => {
    // Arrange
    const layout = scheme<Row>(1, flags(0, [u8(0, (x) => x.a), u16(1, (x) => x.b)]))

    // Act
    const wire = hex(BinaryPacker.pack(layout, { a: 1, b: 2 }))

    // Assert
    assert.equal(wire, "0103010200")
  })
})
