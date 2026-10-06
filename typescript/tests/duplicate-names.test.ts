import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  dict,
  eq,
  flags,
  group,
  list,
  repeat,
  scheme,
  times,
  u8,
  u16,
  when,
  type Field,
} from "../src/index.ts"

type Row = Record<string, unknown>

const hex = (bytes: Uint8Array): string => Buffer.from(bytes).toString("hex")

function refusal(build: () => unknown): string {
  let message = ""
  assert.throws(build, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

// Both entry points must refuse: `scheme()` and `new Scheme()` share one constructor check.
function refusedByBoth(fields: () => Field[], name: string): void {
  const viaScheme = refusal(() => scheme<Row>(1, ...fields()))
  const viaNew = refusal(() => new Scheme<Row>(1, fields()))
  assert.match(viaScheme, new RegExp(`\\b${name}\\b`))
  assert.equal(viaNew, viaScheme)
}

describe("a member name declared twice in one scope", () => {
  it("AC-1 the same name twice at one level is refused", () => {
    // Arrange
    const fields = (): Field[] => [u8(0, (x: Row) => x.a), u8(1, (x: Row) => x.a)]

    // Act and Assert
    refusedByBoth(fields, "a")
  })

  it("AC-2 two times bodies sharing a name are refused", () => {
    // Arrange
    const fields = (): Field[] => [
      u8(0, (x: Row) => x.n),
      times(1, 0, [u8(1, (x: Row) => x.v)]),
      u8(2, (x: Row) => x.m),
      times(3, 2, [u8(3, (x: Row) => x.v)]),
    ]

    // Act and Assert
    refusedByBoth(fields, "v")
  })

  it("AC-3 a repeat member named like a top-level field is refused", () => {
    // Arrange
    const fields = (): Field[] => [u8(0, (x: Row) => x.k), repeat(1, [u8(1, (x: Row) => x.k)])]

    // Act and Assert
    refusedByBoth(fields, "k")
  })

  it("AC-4 a flags member named like a top-level field is refused", () => {
    // Arrange
    const fields = (): Field[] => [u8(0, (x: Row) => x.a), flags(1, [u8(1, (x: Row) => x.a)])]

    // Act and Assert
    refusedByBoth(fields, "a")
  })

  it("a name twice inside one unanchored group is refused", () => {
    // Arrange
    const fields = (): Field[] => [group((x: Row) => x.g, [u8(0, (x: Row) => x.a), u8(1, (x: Row) => x.a)])]

    // Act and Assert
    refusedByBoth(fields, "a")
  })

  it("an anchored group member named like an outer member is refused", () => {
    // Arrange
    const fields = (): Field[] => [u8(0, (x: Row) => x.a), group(1, (x: Row) => x.g, [u8(1, (x: Row) => x.a)])]

    // Act and Assert
    refusedByBoth(fields, "a")
  })

  it("AC-5 alternate when branches keep sharing a name", () => {
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

  it("AC-5 alternate when branches inside a repeat round keep sharing a name", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      repeat(0, [
        u8(0, (x) => x.k),
        when(1, eq(0, 0), [u8(1, (x) => x.s)]),
        when(2, eq(0, 1), [u16(2, (x) => x.s)]),
      ]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { k: [0, 1], s: [7, 300] }))

    // Assert
    assert.equal(wire, "010007012c01")
  })

  it("a name outside every when and once inside one still builds (option B)", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.kind),
      u8(1, (x) => x.shape),
      when(2, eq(0, 1), [u16(2, (x) => x.shape)]),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { kind: 1, shape: 7 }))

    // Assert
    assert.equal(wire, "0101070700")
  })

  it("a name twice outside every when is refused after a when that shares it", () => {
    // Arrange
    const fields = (): Field[] => [
      u8(0, (x: Row) => x.kind),
      when(1, eq(0, 0), [u8(1, (x: Row) => x.shape)]),
      u8(2, (x: Row) => x.shape),
      u8(3, (x: Row) => x.shape),
    ]

    // Act and Assert
    refusedByBoth(fields, "shape")
  })
})

describe("list and dict elements have a member namespace of their own", () => {
  it("AC-6 an element named like a top-level field builds and packs", () => {
    // Arrange
    const layout = scheme<Row>(1, u8(0, (x) => x.a), list((x) => x.xs, u8(0, (x) => x.a)))

    // Act
    const wire = hex(BinaryPacker.pack(layout, { a: 7, xs: [1, 2] }))

    // Assert
    assert.equal(wire, "010702000102")
  })

  it("AC-6 a group element member named like a top-level field builds and packs", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      u8(0, (x) => x.a),
      list((x) => x.pts, group((x) => x.p, [u8(0, (x) => x.a), u8(1, (x) => x.b)])),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { a: 7, pts: [{ a: 1, b: 2 }] }))

    // Assert
    assert.equal(wire, "010701000102")
  })

  it("AC-6 the group-versus-outside refusal keeps its message", () => {
    // Arrange
    const build = () => scheme<Row>(1, u8(0, (x) => x.sid), group((x) => x.g, [u8(0, (x) => x.sid)]))

    // Act
    const message = refusal(build)

    // Assert
    assert.equal(
      message,
      "member sid: declared inside a group and outside it; a group's members are flattened into the row, so one would overwrite the other",
    )
  })

  it("two elements may use the same member names", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      list((x) => x.xs, group((x) => x.p, [u8(0, (x) => x.a)])),
      dict((x) => x.ys, group((x) => x.q, [u8(0, (x) => x.a)])),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { xs: [{ a: 1 }], ys: { k: { a: 2 } } }))

    // Assert
    assert.equal(wire, "01010001" + "010001006b02")
  })

  it("TS-F2 a nested group inside a list group element sharing a member is refused", () => {
    // Arrange
    const fields = (): Field[] => [
      list((x: Row) => x.pts, group((x: Row) => x.g, [u8(0, (x: Row) => x.a), group((x: Row) => x.h, [u8(0, (x: Row) => x.a)])])),
    ]

    // Act
    const message = refusal(() => scheme<Row>(1, ...fields()))

    // Assert
    assert.match(message, /\ba\b.*group/)
  })

  it("TS-F2 the same refusal holds in a dict group element", () => {
    // Arrange
    const fields = (): Field[] => [
      dict((x: Row) => x.m, group((x: Row) => x.g, [u8(0, (x: Row) => x.a), group((x: Row) => x.h, [u8(0, (x: Row) => x.a)])])),
    ]

    // Act and Assert
    refusedByBoth(fields, "a")
  })

  it("TS-F2 a name twice at the top of a group element is refused", () => {
    // Arrange
    const fields = (): Field[] => [
      list((x: Row) => x.pts, group((x: Row) => x.g, [u8(0, (x: Row) => x.a), u8(1, (x: Row) => x.a)])),
    ]

    // Act and Assert
    refusedByBoth(fields, "a")
  })

  it("TS-F2 a name twice in a flags element is refused", () => {
    // Arrange
    const fields = (): Field[] => [
      list((x: Row) => x.xs, flags(0, [u8(0, (x: Row) => x.a), u8(1, (x: Row) => x.a)])),
    ]

    // Act and Assert
    refusedByBoth(fields, "a")
  })

  it("TS-F2 a group element inside a group element has a scope of its own", () => {
    // Arrange
    const layout = scheme<Row>(
      1,
      list((x) => x.outer, group((x) => x.g, [u8(0, (x) => x.a), list((x) => x.inner, group((x) => x.h, [u8(0, (x) => x.a)]))])),
    )

    // Act
    const wire = hex(BinaryPacker.pack(layout, { outer: [{ a: 1, inner: [{ a: 2 }] }] }))

    // Assert
    assert.equal(wire, "010100" + "01" + "0100" + "02")
  })
})
