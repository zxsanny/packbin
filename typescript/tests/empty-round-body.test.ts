import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  bytes,
  eq,
  flagByte,
  flags,
  group,
  list,
  repeat,
  times,
  u8,
  u32,
  when,
} from "../src/index.ts"

// AZ-2390 (F33): a repeat or times whose body holds no member is refused when the scheme is built.

type Row = Record<string, unknown>

const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

const refusal = (run: () => unknown): string => {
  let message = ""
  assert.throws(run, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

const EMPTY_REPEAT = "repeat 0: the body holds no member; a round of it would charge no slot and write nothing"
const EMPTY_TIMES = "times 1: the body holds no member; a round of it would charge no slot and write nothing"

describe("AZ-2390 an empty round body is refused at construction", () => {
  it("AC-1 repeat with no member names the repeat", () => {
    // Act
    const message = refusal(() => new Scheme<Row>(1, [repeat(0, [])]))

    // Assert
    assert.equal(message, EMPTY_REPEAT)
  })

  it("AC-1 times with no member names the times", () => {
    // Act
    const message = refusal(() => new Scheme<Row>(1, [u8(0, (x) => x.n), times(1, 0, [])]))

    // Assert
    assert.equal(message, EMPTY_TIMES)
  })

  it("AC-1 a body of only a when with no member is empty, and so is one nested in another when", () => {
    // Act
    const direct = refusal(() => new Scheme<Row>(1, [repeat(0, [when(0, eq(0, 1), [])])]))
    const nested = refusal(
      () => new Scheme<Row>(1, [repeat(0, [when(0, eq(0, 1), [when(0, eq(0, 2), [])])])]),
    )

    // Assert
    assert.equal(direct, EMPTY_REPEAT)
    assert.equal(nested, EMPTY_REPEAT)
  })

  it("AC-1 a body of only an empty group is refused (an empty group stands only in flags or a flag bit)", () => {
    // Act
    const message = refusal(() => new Scheme<Row>(1, [repeat(0, [group((x) => x.g, [])])]))

    // Assert
    assert.match(message, /^empty group g: allowed only directly inside flags or a flag bit/)
  })

  it("AC-1 the empty body is refused wherever the round stands: flags, a flag bit, a when, a group, a list item", () => {
    // Arrange
    const fb = flagByte("m")
    const shapes: [string, () => unknown][] = [
      ["flags", () => new Scheme<Row>(1, [flags(0, [repeat(0, [])])])],
      ["flag bit", () => new Scheme<Row>(1, [fb, fb.bit(repeat(0, []))])],
      ["when", () => new Scheme<Row>(1, [u8(0, (x) => x.m), when(1, eq(0, 1), [repeat(1, [])])])],
      ["group", () => new Scheme<Row>(1, [group((x) => x.g, [repeat(0, [])])])],
      ["list item", () => new Scheme<Row>(1, [list((x) => x.xs, group((x) => x.item, [repeat(0, [])]))])],
    ]

    // Act
    const messages = shapes.map(([, build]) => refusal(build))

    // Assert
    assert.deepEqual(
      messages,
      [
        EMPTY_REPEAT,
        EMPTY_REPEAT,
        "repeat 1: the body holds no member; a round of it would charge no slot and write nothing",
        EMPTY_REPEAT,
        EMPTY_REPEAT,
      ],
    )
  })

  it("AC-2 the F33 request shape (a list of groups holding times(65535) {}) fails at build in under 1 s", () => {
    // Act
    const started = performance.now()
    const message = refusal(
      () =>
        new Scheme<Row>(1, [
          list((x) => x.items, group((x) => x.item, [u32(0, (x) => x.n), times(1, 0, [])])),
        ]),
    )
    const ms = performance.now() - started

    // Assert
    assert.equal(message, EMPTY_TIMES)
    assert.ok(ms < 1000, `took ${ms} ms`)
  })

  it("AC-3 a body with one u8 builds and packs as before", () => {
    // Arrange
    const layout = new Scheme<Row>(1, [repeat(0, [u8(0, (x) => x.k)])])
    const counted = new Scheme<Row>(1, [u8(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.k)])])

    // Act
    const wire = hex(BinaryPacker.pack(layout, { k: [7, 8] }))
    const withCount = hex(BinaryPacker.pack(counted, { n: 2, k: [7, 8] }))

    // Assert
    assert.equal(wire, "010708")
    assert.equal(withCount, "01020708")
  })
})

describe("AZ-2390 a body whose members are all zero-width still builds: the budgets bound it", () => {
  it("a flag byte alone is a member: it writes a byte, so maxBytes bounds the rounds", () => {
    // Arrange
    const fb = flagByte("m")
    const layout = new Scheme<Row>(1, [repeat(0, [fb])])

    // Act
    const wire = hex(BinaryPacker.pack(layout, {}))

    // Assert
    assert.equal(wire, "01")
  })

  it("a flags with no member is a member: its flag byte is a byte", () => {
    // Act
    const layout = new Scheme<Row>(1, [repeat(0, [flags(0, [])])])

    // Assert
    assert.equal(hex(BinaryPacker.pack(layout, {})), "01")
  })

  it("an empty group under flags is a member: the flags writes a byte and the group's name is a slot", () => {
    // Arrange
    const layout = new Scheme<Row>(1, [repeat(0, [flags(0, [group((x) => x.g, [])])])])

    // Act
    const wire = hex(BinaryPacker.pack(layout, { g: [true, undefined] }))

    // Assert
    assert.equal(wire, "010100")
  })

  it("a zero-width bytes is a member: it names a slot per round, so maxSlots bounds the rounds", () => {
    // Arrange
    const layout = new Scheme<Row>(1, [u8(0, (x) => x.n), times(1, 0, [bytes(1, (x) => x.v, 0)])], { maxSlots: 5 })
    const row = { n: 10, v: Array.from({ length: 10 }, () => new Uint8Array(0)) }

    // Act
    const message = refusal(() => BinaryPacker.pack(layout, row))

    // Assert
    assert.equal(message, "v: the rounds would hold 6 slots, above the limit of 5 slots")
  })

  it("a zero-width bytes round is still refused by unpack as a round that reads nothing", () => {
    // Arrange
    const layout = new Scheme<Row>(1, [u8(0, (x) => x.k), repeat(1, [bytes(1, (x) => x.v, 0)])])

    // Act
    const result = BinaryPacker.unpack(Buffer.from("01ff00", "hex"), layout.on(() => {}))

    // Assert
    assert.deepEqual(result, { ok: false, field: "", needed: 0, left: 1 })
  })
})
