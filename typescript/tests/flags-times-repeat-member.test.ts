import { describe } from "node:test"
import { flagByte, flags, group, repeat, scheme, times, u8, u16 } from "../src/index.ts"
import { failsNaming, runCases, type Case, type Row } from "./support/member-cases.ts"

const n = u8(0, (x) => x.n)
const pt = (id: number) => u8(id, (x) => x.pt)
const heading = (id: number) => u16(id, (x) => x.heading)

const TA = scheme<Row>(1, n, flags(1, [times(1, 0, [pt(1)]), heading(2)]))
const TS = (() => {
  const fb = flagByte("m")
  return scheme<Row>(1, n, fb, fb.bit(times(1, 0, [pt(1)])), fb.bit(heading(2)))
})()
const TG = scheme<Row>(1, n, flags(1, [group(1, (x) => x.g, [times(1, 0, [pt(1)])]), heading(2)]))
const T2 = scheme<Row>(
  1,
  n,
  flags(1, [times(1, 0, [pt(1), u8(2, (x) => x.pu)]), heading(3)]),
)
const RA = scheme<Row>(1, u8(0, (x) => x.mode), flags(1, [heading(1), repeat(2, [pt(2)])]))
const R2 = scheme<Row>(
  1,
  u8(0, (x) => x.mode),
  flags(1, [heading(1), repeat(2, [pt(2), u8(3, (x) => x.pu)])]),
)

const shapes: [string, typeof TA][] = [["flags", TA], ["split", TS], ["group", TG]]

const timesCases: Case[] = shapes.flatMap(([kind, layout]) => [
  { name: `AC-4 ${kind} times 0 rounds`, layout, row: { n: 0, heading: 90 }, hex: "0100025a00", unpacks: { n: 0, heading: 90 } },
  { name: `AC-4 ${kind} times 1 round`, layout, row: { n: 1, pt: [5], heading: 90 }, hex: "010103055a00", unpacks: { n: 1, pt: [5], heading: 90 } },
  { name: `AC-4 ${kind} times 2 rounds`, layout, row: { n: 2, pt: [5, 6], heading: 90 }, hex: "01020305065a00", unpacks: { n: 2, pt: [5, 6], heading: 90 } },
  { name: `AC-5 ${kind} old packet`, layout, hex: "0100025a00", unpacks: { n: 0, heading: 90 }, unpackOnly: true },
] satisfies Case[]).concat([
  { name: "AC-4 times only", layout: TA, row: { n: 2, pt: [5, 6] }, hex: "0102010506", unpacks: { n: 2, pt: [5, 6] } },
  { name: "AC-4 count only", layout: TA, row: { n: 0 }, hex: "010000", unpacks: { n: 0 } },
  { name: "AC-4 two values, one round", layout: T2, row: { n: 1, pt: [5], pu: [6], heading: 90 }, hex: "01010305065a00", unpacks: { n: 1, pt: [5], pu: [6], heading: 90 } },
  { name: "AC-4 two values, two rounds", layout: T2, row: { n: 2, pt: [5, 6], pu: [7, 8], heading: 90 }, hex: "010203050706085a00", unpacks: { n: 2, pt: [5, 6], pu: [7, 8], heading: 90 } },
])

const repeatCases: Case[] = [
  { name: "AC-4 repeat 0 rounds", layout: RA, row: { mode: 1, heading: 90 }, hex: "0101015a00", unpacks: { mode: 1, heading: 90 } },
  { name: "AC-4 repeat 1 round", layout: RA, row: { mode: 1, pt: [5], heading: 90 }, hex: "0101035a0005", unpacks: { mode: 1, pt: [5], heading: 90 } },
  { name: "AC-4 repeat 2 rounds", layout: RA, row: { mode: 1, pt: [5, 6], heading: 90 }, hex: "0101035a000506", unpacks: { mode: 1, pt: [5, 6], heading: 90 } },
  { name: "AC-4 repeat only", layout: RA, row: { mode: 1, pt: [5, 6] }, hex: "0101020506", unpacks: { mode: 1, pt: [5, 6] } },
  { name: "AC-4 repeat none, only mode", layout: RA, row: { mode: 1 }, hex: "010100", unpacks: { mode: 1 } },
  { name: "AC-5 repeat old packet", layout: RA, hex: "0101015a00", unpacks: { mode: 1, heading: 90 }, unpackOnly: true },
  { name: "AC-4 repeat two values, one round", layout: R2, row: { mode: 1, pt: [5], pu: [6], heading: 90 }, hex: "0101035a000506", unpacks: { mode: 1, pt: [5], pu: [6], heading: 90 } },
  { name: "AC-4 repeat two values, two rounds", layout: R2, row: { mode: 1, pt: [5, 6], pu: [7, 8], heading: 90 }, hex: "0101035a0005070608", unpacks: { mode: 1, pt: [5, 6], pu: [7, 8], heading: 90 } },
  { name: "AC-5 repeat two values read from the wire", layout: R2, hex: "0101035a0005060708", unpacks: { mode: 1, pt: [5, 7], pu: [6, 8], heading: 90 }, unpackOnly: true },
]

describe("a times as a flags member is written like any other value", () => {
  runCases(timesCases)

  for (const [kind, layout] of shapes) {
    failsNaming(`AC-4 ${kind} list shorter than the count`, layout, { n: 2, pt: [5], heading: 90 }, "pt")
    failsNaming(`AC-4 ${kind} body values missing`, layout, { n: 1, heading: 90 }, "pt")
    failsNaming(`AC-4 ${kind} count 0 with a list given`, layout, { n: 0, pt: [5], heading: 90 }, "pt")
    failsNaming(`AC-4 ${kind} list longer than the count`, layout, { n: 1, pt: [5, 6], heading: 90 }, "pt")
  }
  failsNaming("AC-4 second body value missing", T2, { n: 1, pt: [5], heading: 90 }, "pu")
})

describe("a repeat as a flags member is written like any other value", () => {
  runCases(repeatCases)

  failsNaming("AC-4 repeat second body value missing", R2, { mode: 1, pt: [5], heading: 90 }, "pu")
})

describe("a times count that was skipped", () => {
  const skipped = scheme<Row>(
    1,
    u8(0, (x) => x.p),
    flags(1, [times(1, 0, [pt(1)]), heading(2)]),
  )
  runCases([
    { name: "AC-4 count in the scope written", layout: skipped, row: { p: 1, pt: [5], heading: 90 }, hex: "010103055a00", unpacks: { p: 1, pt: [5], heading: 90 } },
  ])
  const missingCount = scheme<Row>(
    1,
    flags(0, [u8(0, (x) => x.n), times(1, 0, [pt(1)]), heading(2)]),
  )
  runCases([
    { name: "AC-4 count member skipped, times bit clear", layout: missingCount, row: { heading: 90 }, hex: "01045a00", unpacks: { heading: 90 } },
  ])
})

