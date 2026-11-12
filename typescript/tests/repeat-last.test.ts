import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  bool,
  bytes,
  dict,
  eq,
  flagByte,
  flags,
  group,
  list,
  repeat,
  scheme,
  times,
  u2,
  u8,
  when,
  type Field,
} from "../src/index.ts"
import { validateRepeatLast } from "../src/rounds.ts"
import { followedText as followed, inElementText as inElement, modeThenRepeat, rounds } from "./support/repeat-last-cases.ts"
import { assertWithin, bound } from "./support/timing.ts"

// AZ-4211, contract repeat-last: a repeat is the last thing a packet reads. A scheme that breaks the rule is
// refused when it is built, and the walk that finds it is linear in the size of the scheme; a repeat that is
// last builds and packs the bytes the contract names.

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

function unpackRow(layout: Scheme<Row>, wire: Uint8Array): Row {
  let got: Row | undefined
  const result = BinaryPacker.unpack(wire, layout.on((row) => {
    got = row as Row
  }))
  assert.deepEqual(result, { ok: true })
  return got!
}

type Refused = { name: string; fields: () => Field[]; text: string }

// Each builder makes fresh fields: a flag-byte handle numbers its bits per call.
const CONTRACT_CASES: Refused[] = [
  { name: "R1 a field after the repeat", fields: () => [rounds(0), u8(1, (x) => x.x)], text: followed(0, "x") },
  {
    name: "R2 a field after the when that holds the repeat",
    fields: () => [u8(0, (x) => x.k), when(1, eq(0, 1), [rounds(1)]), u8(2, (x) => x.x)],
    text: followed(1, "x"),
  },
  {
    name: "R3 a field after the flags that holds the repeat",
    fields: () => [flags(0, [rounds(0)]), u8(1, (x) => x.x)],
    text: followed(0, "x"),
  },
  {
    name: "R4 a field after the nested row that holds the repeat",
    fields: () => [group((x) => x.m, [rounds(0)]), u8(0, (x) => x.x)],
    text: followed(0, "x"),
  },
  {
    name: "R4 a field after the anchored group that holds the repeat",
    fields: () => [group(0, (x) => x.m, [rounds(0)]), u8(1, (x) => x.x)],
    text: followed(0, "x"),
  },
  {
    name: "R5 a second repeat",
    fields: () => [rounds(0), repeat(1, [u8(1, (x) => x.w)])],
    text: followed(0, "repeat 1"),
  },
  {
    name: "R6 a field under a when that cannot hold together with the repeat's when",
    fields: () => [u8(0, (x) => x.k), when(1, eq(0, 1), [rounds(1)]), when(2, eq(0, 2), [u8(2, (x) => x.x)])],
    text: followed(1, "x"),
  },
  { name: "R7 a repeat in a list element", fields: () => [list((x) => x.items, modeThenRepeat())], text: inElement(1) },
  { name: "R8 a repeat in a dict element", fields: () => [dict((x) => x.d, modeThenRepeat())], text: inElement(1) },
  {
    name: "R9 a repeat in a times round keeps the text of the nesting rule",
    fields: () => [u8(0, (x) => x.k), times(1, 0, [rounds(1)])],
    text: "repeat 1 is inside a repeat or times round; a round cannot hold another repeat or times",
  },
]

// What the refusal names: the first field after the repeat that can write a byte, the nearest place first.
const FOLLOWERS: Refused[] = [
  {
    name: "a later field of the when that holds the repeat is named before the field after the when",
    fields: () => [u8(0, (x) => x.k), when(1, eq(0, 1), [rounds(1), u8(2, (x) => x.y)]), u8(3, (x) => x.x)],
    text: followed(1, "y"),
  },
  {
    name: "a field two places out: after the when that holds the flags that holds the repeat",
    fields: () => [u8(0, (x) => x.k), when(1, eq(0, 1), [flags(1, [rounds(1)])]), u8(2, (x) => x.x)],
    text: followed(1, "x"),
  },
  {
    name: "a later member of the flags that holds the repeat",
    fields: () => [flags(0, [rounds(0), u8(1, (x) => x.x)])],
    text: followed(0, "x"),
  },
  {
    name: "a later member of the flags around the flags that holds the repeat",
    fields: () => [flags(0, [flags(0, [rounds(0)]), u8(1, (x) => x.x)])],
    text: followed(0, "x"),
  },
  {
    name: "a later split flag bit",
    fields: () => {
      const fb = flagByte("fb")
      return [fb, fb.bit(rounds(0)), fb.bit(u8(1, (x) => x.x))]
    },
    text: followed(0, "x"),
  },
  {
    name: "a field under a group is named, not the group",
    fields: () => [rounds(0), group(1, (x) => x.g, [u8(1, (x) => x.x)])],
    text: followed(0, "x"),
  },
  {
    name: "a times is named by its anchor",
    fields: () => [u8(0, (x) => x.n), rounds(1), times(2, 0, [u8(2, (x) => x.w)])],
    text: followed(1, "times 2"),
  },
  { name: "a list", fields: () => [rounds(0), list((x) => x.items, u8(0, (x) => x.e))], text: followed(0, "items") },
  { name: "a dict", fields: () => [rounds(0), dict((x) => x.d, u8(0, (x) => x.e))], text: followed(0, "d") },
  { name: "a flags", fields: () => [rounds(0), flags(1, [u8(1, (x) => x.x)])], text: followed(0, "flags") },
  {
    name: "a flag byte",
    fields: () => {
      const fb = flagByte("fb")
      return [rounds(0), fb, fb.bit(u8(1, (x) => x.x))]
    },
    text: followed(0, 'flag byte "fb"'),
  },
  { name: "a u2 is named by its first slot", fields: () => [rounds(0), u2(1, (x) => x.a, 2, (x) => x.b)], text: followed(0, "a") },
  {
    name: "a zero-width bytes is passed over for the field after it",
    fields: () => [rounds(0), bytes(1, (x) => x.z, 0), bytes(2, (x) => x.x, 1)],
    text: followed(0, "x"),
  },
]

// A repeat inside an element is refused wherever it sits there, and whatever stands after it.
const IN_ELEMENT: Refused[] = [
  {
    name: "under a when of the element",
    fields: () => [
      list((x) => x.items, group((x) => x.item, [u8(0, (x) => x.mode), when(1, eq(0, 1), [rounds(1)])])),
    ],
    text: inElement(1),
  },
  {
    name: "under a flags of the element",
    fields: () => [dict((x) => x.d, group((x) => x.item, [flags(0, [rounds(0)])]))],
    text: inElement(0),
  },
  { name: "in a flags element", fields: () => [list((x) => x.items, flags(0, [rounds(0)]))], text: inElement(0) },
  {
    name: "under a nested row of the element",
    fields: () => [list((x) => x.items, group((x) => x.item, [group((x) => x.g, [rounds(0)])]))],
    text: inElement(0),
  },
  {
    name: "in the element of a list inside a list element",
    fields: () => [list((x) => x.outer, list((x) => x.inner, group((x) => x.item, [rounds(0)])))],
    text: inElement(0),
  },
  {
    name: "in the element of a list inside a repeat round",
    fields: () => [repeat(0, [u8(0, (x) => x.k), list((x) => x.rows, group((x) => x.row, [rounds(0)]))])],
    text: inElement(0),
  },
  {
    name: "with a field after it in the element: the element text, not the follower text",
    fields: () => [list((x) => x.items, group((x) => x.item, [rounds(0), u8(1, (x) => x.x)]))],
    text: inElement(0),
  },
  // Two rules broken at once: the first refusal in document order is named. The element inside the repeat's
  // body comes before the field after the repeat.
  {
    name: "in the body of a repeat that a field follows: the element text, not the follower text",
    fields: () => [
      repeat(0, [u8(0, (x) => x.k), list((x) => x.rows, group((x) => x.row, [rounds(0)]))]),
      u8(1, (x) => x.x),
    ],
    text: inElement(0),
  },
]

function itRefuses(cases: Refused[]): void {
  for (const c of cases) {
    it(`${c.name} is refused by scheme() and new Scheme()`, () => {
      // Arrange
      const build = c.fields

      // Act
      const viaScheme = refusal(() => scheme<Row>(1, ...build()))
      const viaNew = refusal(() => new Scheme<Row>(1, build()))

      // Assert
      assert.equal(viaScheme, c.text)
      assert.equal(viaNew, c.text)
    })
  }
}

// AC-1: the refused cases R1 to R9 of the contract, in both ways a scheme is built.
describe("AZ-4211 AC-1 a repeat that is not the last thing read is refused when the scheme is built", () => {
  itRefuses(CONTRACT_CASES)
})

// AC-1: "after" is the repeat's own place and every place around it; the first field that can write a byte is named.
describe("AZ-4211 AC-1 the refusal names the first field after the repeat that can write a byte", () => {
  itRefuses(FOLLOWERS)
})

// AC-1: contract rule 2, a repeat directly or under a when, flags, group or nested row of an element.
describe("AZ-4211 AC-1 a repeat inside a list or dict element is refused", () => {
  itRefuses(IN_ELEMENT)
})

type Kept = { name: string; build: () => Scheme<Row>; row: Row; packet: string }

// AC-2: the cases K1 to K5 of the contract.
const KEPT: Kept[] = [
  {
    name: "K1 a repeat after a field",
    build: () => scheme<Row>(1, u8(0, (x) => x.x), rounds(1)),
    row: { x: 9, v: [5, 6] },
    packet: "01090506",
  },
  {
    name: "K2 a repeat that is the last thing in a when that nothing follows",
    build: () => scheme<Row>(1, u8(0, (x) => x.k), when(1, eq(0, 1), [rounds(1)])),
    row: { k: 1, v: [5, 6] },
    packet: "01010506",
  },
  {
    name: "K3 a repeat that is the last member of a flags that nothing follows",
    build: () => scheme<Row>(1, flags(0, [u8(0, (x) => x.x), rounds(1)])),
    row: { x: 9, v: [5, 6] },
    packet: "0103090506",
  },
  {
    name: "K4 a times with fields after it",
    build: () => scheme<Row>(1, u8(0, (x) => x.k), times(1, 0, [u8(1, (x) => x.v)]), u8(2, (x) => x.x)),
    row: { k: 2, v: [5, 6], x: 9 },
    packet: "0102050609",
  },
  {
    name: "K5 a bool bit of an earlier flag byte after the repeat (split form)",
    build: () => {
      const fb = flagByte("fb")
      return scheme<Row>(1, fb, fb.bit(u8(0, (x) => x.x)), rounds(1), fb.bit(bool(2, (x) => x.on)))
    },
    row: { x: 9, v: [5, 6], on: true },
    packet: "0103090506",
  },
]

// AC-1 (unit row 2): a field after the repeat that cannot write a byte does not count.
const NO_BYTE_AFTER: Kept[] = [
  {
    name: "a bool member of the flags after the repeat",
    build: () => scheme<Row>(1, flags(0, [u8(0, (x) => x.x), rounds(1), bool(2, (x) => x.on)])),
    row: { x: 9, v: [5, 6], on: true },
    packet: "0107090506",
  },
  {
    name: "a zero-width bytes",
    build: () => scheme<Row>(1, rounds(0), bytes(1, (x) => x.z, 0)),
    row: { v: [5, 6], z: new Uint8Array(0) },
    packet: "010506",
  },
  {
    name: "a when that holds only a zero-width bytes",
    build: () => scheme<Row>(1, u8(0, (x) => x.k), rounds(1), when(2, eq(0, 1), [bytes(2, (x) => x.z, 0)])),
    row: { k: 1, v: [5, 6], z: new Uint8Array(0) },
    packet: "01010506",
  },
  {
    name: "a times whose body holds only a zero-width bytes, with no round",
    build: () => scheme<Row>(1, u8(0, (x) => x.n), rounds(1), times(2, 0, [bytes(2, (x) => x.z, 0)])),
    row: { n: 0, v: [5, 6] },
    packet: "01000506",
  },
]

function itKeeps(cases: Kept[]): void {
  for (const c of cases) {
    it(`${c.name} builds, packs ${c.packet} and reads the values back`, () => {
      // Arrange
      const layout = c.build()

      // Act
      const wire = BinaryPacker.pack(layout, c.row)
      const back = unpackRow(layout, wire)

      // Assert
      assert.equal(hex(wire), c.packet)
      assert.deepEqual(back, c.row)
    })
  }
}

describe("AZ-4211 AC-2 a repeat that is the last thing read builds and packs the same bytes", () => {
  itKeeps(KEPT)
})

describe("AZ-4211 AC-1 a field after the repeat that cannot write a byte does not refuse the scheme", () => {
  itKeeps(NO_BYTE_AFTER)
})

// N containers that write nothing, one after the other: the first writer after each of them is not found by
// scanning the rest of the place again for every container. The check is timed by itself, so the bound is about
// the walk and not about the rest of the build.
const SIBLINGS = 16_000

const member = (name: string) => new Function("x", `return x.${name}`) as (x: Row) => unknown

function walkWithin(fields: Field[], what: string): void {
  // Arrange
  const limit = bound(0.3)

  // Act
  const started = performance.now()
  validateRepeatLast(fields)
  const seconds = (performance.now() - started) / 1000

  // Assert
  assertWithin(seconds, limit, what)
}

describe("AZ-4211 AC-1 the check is one walk of the scheme: the time is linear in its size", () => {
  it(`${SIBLINGS} sibling whens that each hold a zero-width bytes are walked within the bound`, () => {
    // Arrange
    const fields: Field[] = [u8(0, (x) => x.k)]
    for (let i = 0; i < SIBLINGS; i++) fields.push(when(i + 1, eq(0, 1), [bytes(i + 1, member(`z${i}`), 0)]))

    // Act / Assert
    walkWithin(fields, "whens")
  })

  it(`${SIBLINGS} sibling repeats that each hold a zero-width bytes are walked within the bound`, () => {
    // Arrange
    const fields: Field[] = []
    for (let i = 0; i < SIBLINGS; i++) fields.push(repeat(i, [bytes(i, member(`z${i}`), 0)]))

    // Act / Assert
    walkWithin(fields, "repeats")
  })
})
