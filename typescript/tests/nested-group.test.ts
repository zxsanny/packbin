import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  dict,
  eq,
  flagByte,
  flags,
  group,
  i16,
  i32,
  list,
  repeat,
  scheme,
  times,
  u2,
  u8,
  u16,
  when,
  type Field,
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

function refusal(build: () => unknown): string {
  let message = ""
  assert.throws(build, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

describe("flags inside a group are packed", () => {
  it("flags inside a nested group are packed", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.a),
      group((x) => x.g, [u8(0, (x) => x.b), flags(1, [u8(1, (x) => x.c)])]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { a: 1, g: { b: 2, c: 3 } }))
    const row = unpackRow(layout, wire)

    // Assert
    assert.equal(wire, "0101020103")
    assert.deepEqual(row, { a: 1, b: 2, c: 3 })
    assert.equal(hex(BinaryPacker.pack(layout, { a: 1, g: { b: 2 } })), "01010200")
  })

  it("flags inside an anchored group are packed", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.a),
      group(1, (x) => x.g, [u8(1, (x) => x.b), flags(2, [u8(2, (x) => x.c)])]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { a: 1, b: 2, c: 3 }))
    const row = unpackRow(layout, wire)

    // Assert
    assert.equal(wire, "0101020103")
    assert.deepEqual(row, { a: 1, b: 2, c: 3 })
    assert.equal(hex(BinaryPacker.pack(layout, { a: 1, b: 2 })), "01010200")
  })

  it("a split flag byte inside a group finds its bits in the group", () => {
    // Arrange
    const fb = flagByte("m")
    const layout = scheme<Row>(
      1,
      group((x) => x.g, [fb, fb.bit(u8(0, (x) => x.c)), fb.bit(u16(1, (x) => x.d))]),
    )

    // Act
    const both = hex(BinaryPacker.pack(layout, { g: { c: 3, d: 4 } }))
    const one = hex(BinaryPacker.pack(layout, { g: { d: 4 } }))

    // Assert
    assert.equal(both, "0103030400")
    assert.equal(one, "01020400")
    assert.deepEqual(unpackRow(layout, both), { c: 3, d: 4 })
  })

  it("flags nested under a flag bit of a group are packed", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      flags(0, [group(0, (x) => x.g, [flags(0, [u8(0, (x) => x.n)])])]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { g: { n: 5 } }))

    // Assert
    assert.equal(wire, "01010105")
    assert.deepEqual(unpackRow(layout, wire), { n: 5 })
  })

  it("a flag byte read in a group sees only the bits of its own group", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      flags(0, [u8(0, (x) => x.a)]),
      group((x) => x.g, [flags(0, [u8(0, (x) => x.b)])]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { g: { b: 2 } }))

    // Assert
    assert.equal(wire, "01000102")
  })
})

describe("member names flattening would overwrite", () => {
  it("nested member shadowing an outer member is a scheme error", () => {
    // Arrange
    const build = () => scheme<Row>(1, u8(0, (x) => x.sid), group((x) => x.g, [u8(0, (x) => x.sid)]))

    // Act
    const message = refusal(build)

    // Assert
    assert.match(message, /\bsid\b/)
  })

  it("group name equal to child name is a scheme error", () => {
    // Arrange
    const build = () => scheme<Row>(
      1,
      flags(0, [group((x) => x.session, [u16(0, (x) => x.session)])]),
    )

    // Act
    const message = refusal(build)

    // Assert
    assert.match(message, /\bsession\b/)
  })

  it("new Scheme refuses a shadowed member like scheme()", () => {
    // Arrange
    const fields = (): Field[] => [
      u8(0, (x: Row) => x.sid),
      group((x: Row) => x.g, [u8(0, (x: Row) => x.sid)]),
    ]

    // Act
    const viaScheme = refusal(() => scheme<Row>(1, ...fields()))
    const viaNew = refusal(() => new Scheme<Row>(1, fields()))

    // Assert
    assert.equal(viaNew, viaScheme)
  })

  it("an outer member declared after the group still collides with it", () => {
    // Arrange
    const build = () => scheme<Row>(1, group((x) => x.g, [u8(0, (x) => x.sid)]), u8(0, (x) => x.sid))

    // Act
    const message = refusal(build)

    // Assert
    assert.match(message, /\bsid\b/)
  })

  it("two unanchored groups sharing a member name is a scheme error", () => {
    // Arrange
    const build = () => scheme<Row>(
      1,
      group((x) => x.first, [u8(0, (x) => x.n)]),
      group((x) => x.second, [u8(0, (x) => x.n)]),
    )

    // Act
    const message = refusal(build)

    // Assert
    assert.match(message, /\bn\b/)
  })

  it("a group inside a group shares no member with the group around it", () => {
    // Arrange
    const build = () => scheme<Row>(
      1,
      group((x) => x.outer, [
        u8(0, (x) => x.n),
        group((x) => x.inner, [u8(0, (x) => x.n)]),
      ]),
    )

    // Act
    const message = refusal(build)

    // Assert
    assert.match(message, /\bn\b/)
  })

  it("a member of a group inside a round collides with the same name outside it", () => {
    // Arrange
    const build = () => scheme<Row>(
      1,
      u8(0, (x) => x.k),
      repeat(1, [group((x) => x.g, [u8(0, (x) => x.k)])]),
    )

    // Act
    const message = refusal(build)

    // Assert
    assert.match(message, /\bk\b/)
  })

  it("a u2 slot named like a member of a group is a scheme error", () => {
    // Arrange
    const build = () => scheme<Row>(
      1,
      u2(0, (x) => x.a, 1, (x) => x.b),
      group((x) => x.g, [u8(0, (x) => x.b)]),
    )

    // Act
    const message = refusal(build)

    // Assert
    assert.match(message, /\bb\b/)
  })

  it("a list named like a member of a group is a scheme error", () => {
    // Arrange
    const build = () => scheme<Row>(
      1,
      list((x) => x.l, u8(0, (x) => x.e)),
      group((x) => x.g, [u8(0, (x) => x.l)]),
    )

    // Act
    const message = refusal(build)

    // Assert
    assert.match(message, /\bl\b/)
  })

  it("a dict named like a member of a group is a scheme error", () => {
    // Arrange
    const build = () => scheme<Row>(
      1,
      dict((x) => x.d, u8(0, (x) => x.e)),
      group((x) => x.g, [u8(0, (x) => x.d)]),
    )

    // Act
    const message = refusal(build)

    // Assert
    assert.match(message, /\bd\b/)
  })

  it("a member inside a when collides with the same name in a group", () => {
    // Arrange
    const build = () => scheme<Row>(
      1,
      u8(0, (x) => x.k),
      when(1, eq(0, 1), [u8(1, (x) => x.v)]),
      group((x) => x.g, [u8(0, (x) => x.v)]),
    )

    // Act
    const message = refusal(build)

    // Assert
    assert.match(message, /\bv\b/)
  })

  it("a member under flags collides with the same name in a group", () => {
    // Arrange
    const build = () => scheme<Row>(
      1,
      flags(0, [u8(0, (x) => x.v)]),
      group((x) => x.g, [u8(0, (x) => x.v)]),
    )

    // Act
    const message = refusal(build)

    // Assert
    assert.match(message, /\bv\b/)
  })

  it("alternate when branches may share a member", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.kind),
      when(1, eq(0, 0), [u8(1, (x) => x.shape)]),
      when(2, eq(0, 1), [u16(2, (x) => x.shape)]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { kind: 1, shape: 300 }))

    // Assert
    assert.equal(wire, "01012c01")
  })

  it("an anchored group shares the scope around it", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.a),
      group(1, (x) => x.g, [u8(1, (x) => x.a)]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { a: 7 }))

    // Assert
    assert.equal(wire, "010707")
  })

  it("members of different groups with distinct names build", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.a),
      group((x) => x.first, [u8(0, (x) => x.b)]),
      group((x) => x.second, [u8(0, (x) => x.c)]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { a: 1, b: 2, c: 3 }))

    // Assert
    assert.equal(wire, "01010203")
  })
})

describe("a flag byte is never a member of the row", () => {
  const position = scheme<Row>(
    0x40,
    u16(0, (x) => x.sid),
    i32(1, (x) => x.lat),
    i32(2, (x) => x.lon),
    u8(3, (x) => x.profile),
    flags(4, [u16(4, (x) => x.heading), u8(5, (x) => x.speed), i16(6, (x) => x.altitude)]),
  )

  it("unpacked row has no flag byte member", () => {
    // Arrange
    const wire = "4001000065cd1d00a3e1110100"

    // Act
    const row = unpackRow(position, wire)

    // Assert
    assert.deepEqual(Object.keys(row).sort(), ["lat", "lon", "profile", "sid"])
  })

  it("unpacked row keeps the motion members when their bits are set", () => {
    // Arrange
    const wire = "4001000065cd1d00a3e111010305000a"

    // Act
    const row = unpackRow(position, wire)

    // Assert
    assert.deepEqual(Object.keys(row).sort(), ["heading", "lat", "lon", "profile", "sid", "speed"])
  })

  it("a split flag byte adds no member named after it", () => {
    // Arrange
    const motion = flagByte("motion")
    const layout = scheme<Row>(1, u8(0, (x) => x.a), motion, motion.bit(u8(1, (x) => x.b)))

    // Act
    const clear = unpackRow(layout, "010700")
    const set = unpackRow(layout, "01070101")

    // Assert
    assert.deepEqual(clear, { a: 7 })
    assert.deepEqual(set, { a: 7, b: 1 })
  })

  it("a flag byte inside a times body adds no member", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.n),
      times(1, 0, [flags(1, [u8(1, (x) => x.v)])]),
    )

    // Act
    const row = unpackRow(layout, "0102010500")

    // Assert
    assert.equal("" in row, false)
    assert.deepEqual(Object.keys(row).sort(), ["n", "v"])
  })

  it("a flag byte inside a repeat body adds no member", () => {
    // Arrange
    const layout = scheme<Row>(1, repeat(0, [flags(0, [u8(0, (x) => x.v)])]))

    // Act
    const row = unpackRow(layout, "01010500")

    // Assert
    assert.equal("" in row, false)
    assert.deepEqual(Object.keys(row), ["v"])
  })
})
