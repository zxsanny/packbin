import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  dict,
  flags,
  group,
  i16,
  i32,
  list,
  scheme,
  u8,
  u16,
  utf8,
} from "../src/index.ts"

type Row = Record<string, unknown>

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..")
const hex = (b: Uint8Array): string => Buffer.from(b).toString("hex")

function unpackRow(layout: Scheme<Row>, wire: string): Row {
  let got: Row | undefined
  const result = BinaryPacker.unpack(Buffer.from(wire, "hex"), layout.on((row) => {
    got = row as Row
  }))
  assert.deepEqual(result, { ok: true }, wire)
  return got!
}

const dictOfNumbers = () => scheme<Row>(1, u8(0, (x) => x.a), dict((x) => x.m, u8(0, (x) => x.v)))

const dictOfDicts = () =>
  scheme<Row>(1, u8(0, (x) => x.a), dict((x) => x.m, dict((x) => x.n, u8(0, (x) => x.v))))

const dictOfGroups = () =>
  scheme<Row>(
    1,
    u8(0, (x) => x.a),
    dict((x) => x.m, group((x) => x.p, [u8(0, (x) => x.a), u8(1, (x) => x.b)])),
  )

const PROTO_WIRE = "0101010009005f5f70726f746f5f5f010001006109"

describe("dict entries are not members of the row", () => {
  it("AC-1 both key orders pack the same bytes", () => {
    // Arrange
    const layout = dictOfNumbers()

    // Act
    const first = hex(BinaryPacker.pack(layout, { a: 1, m: { a: 9 } }))
    const second = hex(BinaryPacker.pack(layout, { m: { a: 9 }, a: 1 }))

    // Assert
    assert.deepEqual([first, second], ["0101010001006109", "0101010001006109"])
  })

  it("AC-2 a key named like the dictionary keeps its entry", () => {
    // Arrange
    const layout = dictOfNumbers()

    // Act
    const named = hex(BinaryPacker.pack(layout, { a: 1, m: { m: 9 } }))
    const other = hex(BinaryPacker.pack(layout, { a: 1, m: { v: 9 } }))

    // Assert
    assert.deepEqual([named, other], ["0101010001006d09", "0101010001007609"])
  })

  it("AC-3 a key does not supply a missing member", () => {
    // Arrange
    const layout = dictOfNumbers()

    // Act
    const same = () => BinaryPacker.pack(layout, { m: { a: 9 } })
    const other = () => BinaryPacker.pack(layout, { m: { b: 9 } })

    // Assert
    assert.throws(same, new RangeError("missing a"))
    assert.throws(other, new RangeError("missing a"))
  })

  it("AC-4 nested dictionaries keep to themselves", () => {
    // Arrange
    const layout = dictOfDicts()

    // Act
    const wire = hex(BinaryPacker.pack(layout, { a: 1, m: { x: { a: 9 } } }))

    // Assert
    assert.equal(wire, "01010100010078010001006109")
  })

  it("AC-5 a decoded __proto__ entry repacks identically", () => {
    // Arrange
    const layout = dictOfDicts()

    // Act
    const row = unpackRow(layout, PROTO_WIRE)
    const again = hex(BinaryPacker.pack(layout, row))

    // Assert
    assert.equal(row.a, 1)
    assert.ok(Object.hasOwn(row.m as object, "__proto__"))
    assert.equal(again, PROTO_WIRE)
  })

  it("AC-5 a __proto__ entry of a row built from JSON packs as an entry", () => {
    // Arrange
    const layout = dictOfDicts()
    const row = JSON.parse('{"m":{"__proto__":{"a":9}},"a":1}') as Row

    // Act
    const wire = hex(BinaryPacker.pack(layout, row))

    // Assert
    assert.equal(wire, PROTO_WIRE)
  })

  it("a __proto__ key at the top of a row does not supply a member", () => {
    // Arrange
    const layout = scheme<Row>(1, u8(0, (x) => x.a), u8(1, (x) => x.b))
    const row = JSON.parse('{"a":1,"__proto__":{"b":2}}') as Row

    // Act
    const pack = () => BinaryPacker.pack(layout, row)

    // Assert
    assert.throws(pack, new RangeError("missing b"))
  })
})

describe("dict of group keeps each entry apart from the row", () => {
  it("TS-F1 a dict group member named like a row member packs the same in both key orders", () => {
    // Arrange
    const layout = dictOfGroups()

    // Act
    const first = hex(BinaryPacker.pack(layout, { a: 9, m: { x: { a: 1, b: 2 } } }))
    const second = hex(BinaryPacker.pack(layout, { m: { x: { a: 1, b: 2 } }, a: 9 }))

    // Assert
    assert.deepEqual([first, second], ["010901000100780102", "010901000100780102"])
  })

  it("TS-F1 the unpacked row repacks to the same bytes", () => {
    // Arrange
    const layout = dictOfGroups()
    const wire = "010901000100780102"

    // Act
    const row = unpackRow(layout, wire)
    const again = hex(BinaryPacker.pack(layout, row))

    // Assert
    assert.deepEqual(row, { a: 9, m: { x: { a: 1, b: 2 } } })
    assert.equal(again, wire)
  })

  it("TS-F1 the same holds inside a group element, in both key orders", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      list((x) => x.xs, group((x) => x.g, [u8(0, (x) => x.a), dict((x) => x.m, group((x) => x.p, [u8(0, (x) => x.a), u8(1, (x) => x.b)]))])),
    )

    // Act
    const first = hex(BinaryPacker.pack(layout, { xs: [{ a: 9, m: { x: { a: 1, b: 2 } } }] }))
    const second = hex(BinaryPacker.pack(layout, { xs: [{ m: { x: { a: 1, b: 2 } }, a: 9 }] }))

    // Assert
    assert.deepEqual([first, second], ["0101000901000100780102", "0101000901000100780102"])
  })

  it("TS-F1 a dict of group inside a dict group element keeps its entries apart", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      dict((x) => x.outer, group((x) => x.g, [u8(0, (x) => x.a), dict((x) => x.m, group((x) => x.p, [u8(0, (x) => x.a)]))])),
    )

    // Act
    const first = hex(BinaryPacker.pack(layout, { outer: { k: { a: 7, m: { x: { a: 1 } } } } }))
    const second = hex(BinaryPacker.pack(layout, { outer: { k: { m: { x: { a: 1 } }, a: 7 } } }))

    // Assert
    assert.equal(first, second)
    assert.equal(first, "01010001006b07010001007801")
  })
})

describe("declared groups still flatten", () => {
  const unanchored = () => scheme<Row>(1, u8(0, (x) => x.a), group((x) => x.g, [u8(0, (x) => x.b)]))
  const withInner = () =>
    scheme<Row>(
      1,
      u8(0, (x) => x.a),
      group((x) => x.g, [u8(0, (x) => x.b), group((x) => x.h, [u8(0, (x) => x.c)])]),
    )

  it("AC-6 an unanchored group given as an object is merged", () => {
    // Arrange
    const layout = unanchored()

    // Act
    const wire = hex(BinaryPacker.pack(layout, { a: 1, g: { b: 2 } }))

    // Assert
    assert.equal(wire, "010102")
  })

  it("AC-6 a class instance with the same members is merged", () => {
    // Arrange
    class Inner {
      b = 2
    }
    const layout = unanchored()

    // Act
    const wire = hex(BinaryPacker.pack(layout, { a: 1, g: new Inner() }))

    // Assert
    assert.equal(wire, "010102")
  })

  it("AC-6 a nested group is merged too", () => {
    // Arrange
    const layout = withInner()

    // Act
    const wire = hex(BinaryPacker.pack(layout, { a: 1, g: { b: 2, h: { c: 3 } } }))

    // Assert
    assert.equal(wire, "01010203")
  })

  it("an anchored group given as an object keeps packing the same bytes", () => {
    // Arrange
    const layout = scheme<Row>(1, u8(0, (x) => x.a), group(1, (x) => x.g, [u8(1, (x) => x.b)]))

    // Act
    const nested = hex(BinaryPacker.pack(layout, { a: 1, g: { b: 2 } }))
    const flat = hex(BinaryPacker.pack(layout, { a: 1, b: 2 }))

    // Assert
    assert.deepEqual([nested, flat], ["010102", "010102"])
  })

  it("a group under flags given as an object is merged", () => {
    // Arrange
    const layout = scheme<Row>(1, flags(0, [group(0, (x) => x.g, [u8(0, (x) => x.b)])]))

    // Act
    const wire = hex(BinaryPacker.pack(layout, { g: { b: 2 } }))

    // Assert
    assert.equal(wire, "010102")
  })

  it("a key of a group object that the group does not declare stays out of the row", () => {
    // Arrange
    const layout = unanchored()

    // Act
    const wire = hex(BinaryPacker.pack(layout, { a: 1, g: { a: 9, b: 2 } }))

    // Assert
    assert.equal(wire, "010102")
  })

  it("a member given both flat and inside its group object takes the group object's value, in both key orders", () => {
    // Arrange
    const layout = unanchored()

    // Act
    const flatFirst = hex(BinaryPacker.pack(layout, { a: 1, b: 3, g: { b: 2 } }))
    const nestedFirst = hex(BinaryPacker.pack(layout, { g: { b: 2 }, a: 1, b: 3 }))

    // Assert
    assert.deepEqual([flatFirst, nestedFirst], ["010102", "010102"])
  })

  it("an undeclared nested object does not supply a member", () => {
    // Arrange
    const layout = unanchored()

    // Act
    const pack = () => BinaryPacker.pack(layout, { g: { b: 2 }, other: { a: 1 } })

    // Assert
    assert.throws(pack, new RangeError("missing a"))
  })
})

describe("fixtures that use dictionaries are unchanged", () => {
  it("AC-7 the position golden bytes are unchanged", () => {
    // Arrange
    const golden = readFileSync(join(root, "fixtures/golden.hex"), "utf8").trim()
    const position = scheme<Row>(
      0x40,
      u16(0, (x) => x.sid),
      i32(1, (x) => x.lat),
      i32(2, (x) => x.lon),
      u8(3, (x) => x.profile),
      flags(4, [u16(4, (x) => x.heading), u8(5, (x) => x.speed), i16(6, (x) => x.altitude)]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(position, { sid: 1, lat: 500_000_000, lon: 300_000_000, profile: 1 }))

    // Assert
    assert.equal(wire, golden)
  })

  it("AC-7 the user and nested handoff packets are unchanged", () => {
    // Arrange
    const userHex =
      "0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465"
    const nestedHex =
      "01020003006d61700100010002006f7007006770735f666978050073746f72650200010002006f70040072656164010002006f7005007772697465"
    const user = scheme<Row>(
      1,
      utf8(0, (x) => x.username),
      list((x) => x.roles, utf8(0, (s) => s)),
      dict((x) => x.access, list((a) => a, utf8(0, (s) => s))),
    )
    const nested = scheme<Row>(
      1,
      dict((x) => x.access, list((rows) => rows, dict((row) => row, utf8(0, (s) => s)))),
    )

    // Act
    const userWire = hex(BinaryPacker.pack(user, {
      username: "zxsanny",
      roles: ["user", "dispatcher"],
      access: { channel: ["read"], map: ["read", "gps_fix", "set", "edit"], store: ["read", "write"] },
    }))
    const nestedWire = hex(BinaryPacker.pack(nested, {
      access: { map: [{ op: "gps_fix" }], store: [{ op: "read" }, { op: "write" }] },
    }))

    // Assert
    assert.deepEqual([userWire, nestedWire], [userHex, nestedHex])
  })
})
