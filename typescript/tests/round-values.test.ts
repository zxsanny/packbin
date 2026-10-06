import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  bool,
  bytes,
  eq,
  flags,
  group,
  repeat,
  scheme,
  sized,
  times,
  u2,
  u8,
  when,
} from "../src/index.ts"

type Row = Record<string, unknown>

const hex = (bytes: Uint8Array): string => Buffer.from(bytes).toString("hex")

function unpackRow(layout: Scheme<Row>, wire: string): Row {
  let got: Row | undefined
  const result = BinaryPacker.unpack(Buffer.from(wire, "hex"), layout.on((row) => {
    got = row as Row
  }))
  assert.deepEqual(result, { ok: true }, wire)
  return got!
}

const flagsRepeat = () => scheme<Row>(
  1,
  repeat(0, [flags(0, [bool(0, (x) => x.on), u8(1, (x) => x.n)])]),
)

const flagsTimes = () => scheme<Row>(
  1,
  u8(0, (x) => x.a),
  times(1, 0, [flags(1, [bool(1, (x) => x.on), u8(2, (x) => x.n)])]),
)

const whenRepeat = () => scheme<Row>(
  1,
  repeat(0, [u8(0, (x) => x.k), when(1, eq(0, 1), [u8(1, (x) => x.v)])]),
)

const whenTimes = () => scheme<Row>(
  1,
  u8(0, (x) => x.a),
  times(1, 0, [u8(1, (x) => x.k), when(2, eq(1, 1), [u8(2, (x) => x.v)])]),
)

describe("repeat and times round values are addressed by round index", () => {
  it("repeat packs each flags round by index", () => {
    // Arrange
    const row = { on: [true, false, true], n: [1, 2, 3] }

    // Act
    const wire = hex(BinaryPacker.pack(flagsRepeat(), row))

    // Assert
    assert.equal(wire, "01030102020303")
  })

  it("repeat unpacks one entry per round and repacks the same bytes", () => {
    // Arrange
    const layout = flagsRepeat()

    // Act
    const row = unpackRow(layout, "01030102020303")
    const again = hex(BinaryPacker.pack(layout, row))

    // Assert
    assert.deepEqual(row.on, [true, undefined, true])
    assert.deepEqual(row.n, [1, 2, 3])
    assert.equal(again, "01030102020303")
  })

  it("a bool under flags unpacks as true or absent, never as the flag bit value", () => {
    // Arrange
    const layout = flagsRepeat()

    // Act
    const on = (unpackRow(layout, "01030102020303").on as unknown[])

    // Assert
    assert.equal(on[0], true)
    assert.equal(on[1], undefined)
    assert.equal(on.length, 3)
  })

  it("times packs each flags round by index and round trips", () => {
    // Arrange
    const layout = flagsTimes()
    const row = { a: 3, on: [true, false, true], n: [1, 2, 3] }

    // Act
    const wire = hex(BinaryPacker.pack(layout, row))
    const back = unpackRow(layout, wire)
    const again = hex(BinaryPacker.pack(layout, back))

    // Assert
    assert.equal(wire, "0103030102020303")
    assert.deepEqual(back.on, [true, undefined, true])
    assert.equal(again, wire)
  })

  it("repeat packs only the rounds where the when holds", () => {
    // Arrange
    const row = { k: [1, 2], v: [9] }

    // Act
    const wire = hex(BinaryPacker.pack(whenRepeat(), row))

    // Assert
    assert.equal(wire, "01010902")
  })

  it("repeat keeps a skipped round's place and repacks the same bytes", () => {
    // Arrange
    const layout = whenRepeat()

    // Act
    const row = unpackRow(layout, "01020109")
    const again = hex(BinaryPacker.pack(layout, row))

    // Assert
    assert.deepEqual(row.k, [2, 1])
    assert.deepEqual(row.v, [undefined, 9])
    assert.equal(again, "01020109")
  })

  it("repeat leaves a value that no round set as a list of absent entries", () => {
    // Arrange
    const layout = whenRepeat()

    // Act
    const row = unpackRow(layout, "010202")

    // Assert
    assert.deepEqual(row.k, [2, 2])
    assert.deepEqual(row.v, [undefined, undefined])
  })

  it("times packs only the matching rounds", () => {
    // Arrange
    const row = { a: 2, k: [1, 2], v: [9] }

    // Act
    const wire = hex(BinaryPacker.pack(whenTimes(), row))

    // Assert
    assert.equal(wire, "0102010902")
  })

  it("times keeps a skipped round's place and repacks the same bytes", () => {
    // Arrange
    const layout = whenTimes()

    // Act
    const row = unpackRow(layout, "0102020109")
    const again = hex(BinaryPacker.pack(layout, row))

    // Assert
    assert.deepEqual(row.k, [2, 1])
    assert.deepEqual(row.v, [undefined, 9])
    assert.equal(again, "0102020109")
  })

  it("scalar values still make one round", () => {
    // Arrange
    const row = { k: 1, v: 9 }

    // Act
    const wire = hex(BinaryPacker.pack(whenRepeat(), row))

    // Assert
    assert.equal(wire, "010109")
  })

  it("a scalar beside a list is read in every round", () => {
    // Arrange
    const layout = scheme<Row>(1, repeat(0, [u8(0, (x) => x.k), u8(1, (x) => x.v)]))

    // Act
    const wire = hex(BinaryPacker.pack(layout, { k: [1, 2], v: 9 }))

    // Assert
    assert.equal(wire, "0101090209")
  })

  it("an absent entry in the middle of a list skips only that round's value", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [u8(0, (x) => x.x), flags(1, [u8(1, (x) => x.n)])]),
    )
    const row = { x: [1, 2], n: [5, null] }

    // Act
    const wire = hex(BinaryPacker.pack(layout, row))
    const back = unpackRow(layout, wire)

    // Assert
    assert.equal(wire, "010101050200")
    assert.deepEqual(back.n, [5, undefined])
  })

  it("the longest list among every name in the round sets the repeat count", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [flags(0, [u8(0, (x) => x.a), u8(1, (x) => x.b)])]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { a: [1], b: [5, 6] }))

    // Assert
    assert.equal(wire, "010301050206")
  })

  it("times takes its count from the borrowed field, not from the lists", () => {
    // Arrange
    const layout = scheme<Row>(1, u8(0, (x) => x.a), times(1, 0, [u8(1, (x) => x.x)]))

    // Act
    const pack = () => BinaryPacker.pack(layout, { a: 3, x: [1] })

    // Assert
    assert.throws(pack, /^RangeError: missing x$/)
  })

  it("a repeat round that reads nothing ends the repeat and keeps its values", () => {
    // Arrange
    const layout = scheme<Row>(1, repeat(0, [bytes(0, (x) => x.v, 0)]), u8(1, (x) => x.tail))

    // Act
    const row = unpackRow(layout, "0105")

    // Assert
    assert.equal(row.tail, 5)
    assert.deepEqual(row.v, [new Uint8Array(0)])
  })

  it("AZ-2188 a repeat member named like an earlier scalar is a duplicate, not a join", () => {
    // Arrange
    const build = () => scheme<Row>(1, u8(0, (x) => x.x), repeat(1, [u8(1, (x) => x.x)]))

    // Act
    const act = () => build()

    // Assert
    assert.throws(act, (e: unknown) => e instanceof RangeError && /\bx\b.*twice/.test(e.message))
  })

  it("a list under a group inside flags sets the repeat count", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [flags(0, [group(0, (x) => x.mark, [u8(0, (x) => x.v)])])]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { v: [7, undefined, 9] }))
    const back = unpackRow(layout, wire)
    const again = hex(BinaryPacker.pack(layout, back))

    // Assert
    assert.equal(wire, "010107000109")
    assert.deepEqual(back.v, [7, undefined, 9])
    assert.equal("mark" in back, false)
    assert.equal(again, wire)
  })

  it("a group's own member turns its bit on, so a missing value is refused", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [flags(0, [group(0, (x) => x.mark, [u8(0, (x) => x.v)])])]),
    )

    // Act
    const pack = () => BinaryPacker.pack(layout, { mark: [true] })

    // Assert
    assert.throws(pack, /^RangeError: missing v$/)
  })

  it("a group's own member is read at the round's index", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [flags(0, [group(0, (x) => x.mark, [u8(0, (x) => x.v)])])]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { mark: [true, undefined], v: [7, undefined] }))

    // Assert
    assert.equal(wire, "01010700")
  })

  it("times reads a group's own member at the round's index", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.a),
      times(1, 0, [flags(1, [group(1, (x) => x.mark, [u8(1, (x) => x.v)])])]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { a: 2, mark: [true, undefined], v: [7, undefined] }))
    const back = unpackRow(layout, wire)
    const again = hex(BinaryPacker.pack(layout, back))

    // Assert
    assert.equal(wire, "0102010700")
    assert.deepEqual(back.v, [7, undefined])
    assert.equal(again, wire)
  })

  it("a when in a round reads only the round's own value, not a same-named one outside it", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.k),
      repeat(1, [
        u8(1, (x) => x.j),
        when(2, eq(1, 1), [u8(2, (x) => x.k)]),
        when(3, eq(2, 7), [u8(3, (x) => x.w)]),
      ]),
    )

    // Act
    const row = unpackRow(layout, "0107000a")

    // Assert
    assert.deepEqual(row.j, [0, 10])
    assert.deepEqual(row.w, [undefined, undefined])
  })

  it("an empty group under flags unpacks as true or absent in each round", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [flags(0, [group((x) => x.mark, []), u8(0, (x) => x.n)])]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { mark: [true, false, true], n: [1, 2, 3] }))
    const back = unpackRow(layout, wire)
    const again = hex(BinaryPacker.pack(layout, back))

    // Assert
    assert.equal(wire, "01030102020303")
    assert.deepEqual(back.mark, [true, undefined, true])
    assert.equal(again, wire)
  })

  it("values of a when in a times round keep one entry per round that set them", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.a),
      times(1, 0, [u8(1, (x) => x.b), when(2, eq(1, 1), [u8(2, (x) => x.c)])]),
    )

    // Act
    const row = unpackRow(layout, "01030107000109")

    // Assert
    assert.deepEqual(row.b, [1, 0, 1])
    assert.deepEqual(row.c, [7, undefined, 9])
  })

  it("an anchored group in a round packs its fields by round index", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [u8(0, (x) => x.k), group(1, (x) => x.mark, [u8(1, (x) => x.v)])]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { k: [1, 2], v: [7, 8] }))
    const back = unpackRow(layout, wire)
    const again = hex(BinaryPacker.pack(layout, back))

    // Assert
    assert.equal(wire, "0101070208")
    assert.deepEqual(back.v, [7, 8])
    assert.equal(again, wire)
  })

  it("an unanchored group in a round packs its fields by round index", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [u8(0, (x) => x.k), group((x) => x.row, [u8(0, (x) => x.v)])]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { k: [1, 2], row: { v: [7, 8] } }))
    const back = unpackRow(layout, wire)
    const again = hex(BinaryPacker.pack(layout, back))

    // Assert
    assert.equal(wire, "0101070208")
    assert.deepEqual(back.v, [7, 8])
    assert.equal(again, wire)
  })

  it("every slot of a u2 in a round is packed by round index", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [u8(0, (x) => x.k), u2(1, (x) => x.p, 2, (x) => x.q)]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { k: [1, 2], p: [1, 2], q: [3, 0] }))
    const back = unpackRow(layout, wire)
    const again = hex(BinaryPacker.pack(layout, back))

    // Assert
    assert.equal(wire, "01010d0202")
    assert.deepEqual(back.p, [1, 2])
    assert.deepEqual(back.q, [3, 0])
    assert.equal(again, wire)
  })

  it("a count read inside a round is that round's value", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [u8(0, (x) => x.n), sized(1, (x) => x.p, 0)]),
    )

    // Act
    const back = unpackRow(layout, "0102aabb01cc")
    const wire = hex(BinaryPacker.pack(layout, back))

    // Assert
    assert.deepEqual(back.n, [2, 1])
    assert.equal(hex((back.p as Uint8Array[])[0]!), "aabb")
    assert.equal(hex((back.p as Uint8Array[])[1]!), "cc")
    assert.equal(wire, "0102aabb01cc")
  })

  it("repeat with no round leaves every key absent and repacks the same bytes", () => {
    // Arrange
    const layout = whenRepeat()

    // Act
    const row = unpackRow(layout, "01")
    const again = hex(BinaryPacker.pack(layout, row))

    // Assert
    assert.equal("k" in row, false)
    assert.equal("v" in row, false)
    assert.equal(again, "01")
  })

  it("times with count zero leaves every round key absent and repacks the same bytes", () => {
    // Arrange
    const layout = whenTimes()

    // Act
    const row = unpackRow(layout, "0100")
    const again = hex(BinaryPacker.pack(layout, row))

    // Assert
    assert.equal("k" in row, false)
    assert.equal("v" in row, false)
    assert.equal(again, "0100")
  })

  it("a name written twice in one round keeps one entry for the round", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [
        u8(0, (x) => x.k),
        when(1, eq(0, 1), [u8(1, (x) => x.v)]),
        when(2, eq(0, 1), [u8(2, (x) => x.v)]),
      ]),
    )

    // Act
    const row = unpackRow(layout, "0101090a02")

    // Assert
    assert.deepEqual(row.k, [1, 2])
    assert.deepEqual(row.v, [10, undefined])
  })
})
