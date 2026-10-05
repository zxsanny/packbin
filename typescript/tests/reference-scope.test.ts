import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  bits,
  bool,
  dict,
  eq,
  f32,
  flags,
  group,
  list,
  packed,
  repeat,
  scheme,
  sized,
  times,
  u2,
  u8,
  u16,
  u64,
  utf8,
  when,
  type Field,
} from "../src/index.ts"

type Row = Record<string, unknown>

const toHex = (bytes: Uint8Array): string => Buffer.from(bytes).toString("hex")

function refusal(build: () => unknown): string {
  let message = ""
  assert.throws(build, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

function unpacked(layout: Scheme<Row>, hex: string): { result: unknown; row?: Row } {
  let row: Row | undefined
  const result = BinaryPacker.unpack(Buffer.from(hex, "hex"), layout.on((r) => {
    row = r as Row
  }))
  return { result, row }
}

describe("reference scope: which field an id names", () => {
  // Inside the unanchored group ids restart at 0, so `eq(0, ...)` names `inner`, not `kind`.
  const nested = () => scheme<Row>(
    1,
    u8(0, (x) => x.kind),
    group((x) => x.g, [
      u8(0, (x) => x.inner),
      when(1, eq(0, 5), [u8(1, (x) => x.extra)]),
    ]),
  )

  it("when in nested group uses the group's ids", () => {
    const layout = nested()
    const apart = BinaryPacker.pack(layout, { kind: 5, g: { inner: 9, extra: 7 } })
    const same = BinaryPacker.pack(layout, { kind: 5, g: { inner: 5, extra: 7 } })
    assert.equal(toHex(apart), "010509")
    assert.equal(toHex(same), "01050507")
  })

  it("when in nested group is read from the group's field on unpack", () => {
    const layout = nested()
    const same = unpacked(layout, "01050507")
    const apart = unpacked(layout, "010509")
    assert.deepEqual(same.result, { ok: true })
    assert.equal(same.row!.extra, 7)
    assert.deepEqual(apart.result, { ok: true })
    assert.equal(apart.row!.extra, undefined)
  })

  it("a field object shared by two schemes binds in each scheme on its own", () => {
    const payload = sized(1, (x) => x.p, 0)
    const first = scheme<Row>(1, u8(0, (x) => x.n), payload)
    const second = scheme<Row>(2, u8(0, (x) => x.m), payload)
    const a = BinaryPacker.pack(first, { n: 2, p: Uint8Array.of(1, 2) })
    const b = BinaryPacker.pack(second, { m: 1, p: Uint8Array.of(9) })
    assert.equal(toHex(a), "01020102")
    assert.equal(toHex(b), "020109")
  })

  it("a count names a field inside an earlier when, flags or anchored group", () => {
    const viaWhen = scheme<Row>(
      1,
      u8(0, (x) => x.k),
      when(1, eq(0, 1), [u8(1, (x) => x.n)]),
      sized(2, (x) => x.p, 1),
    )
    const viaFlags = scheme<Row>(
      1,
      flags(0, [u8(0, (x) => x.n)]),
      sized(1, (x) => x.p, 0),
    )
    const viaGroup = scheme<Row>(
      1,
      group(0, (x) => x.g, [u8(0, (x) => x.n)]),
      sized(1, (x) => x.p, 0),
    )
    assert.equal(toHex(BinaryPacker.pack(viaWhen, { k: 1, n: 1, p: Uint8Array.of(7) })), "01010107")
    assert.equal(toHex(BinaryPacker.pack(viaFlags, { n: 1, p: Uint8Array.of(7) })), "01010107")
    assert.equal(toHex(BinaryPacker.pack(viaGroup, { g: { n: 1 }, p: Uint8Array.of(7) })), "010107")
  })

  it("a count names a field inside an earlier nested flags", () => {
    assert.doesNotThrow(() => scheme<Row>(
      1,
      flags(0, [group(0, (x) => x.g, [flags(0, [u8(0, (x) => x.n)]), sized(1, (x) => x.p, 0)])]),
    ))
  })

  it("a when in a repeat body names a field of the same round", () => {
    const layout = scheme<Row>(
      1,
      repeat(0, [u8(0, (x) => x.k), when(1, eq(0, 1), [u8(1, (x) => x.v)])]),
    )
    const { result, row } = unpacked(layout, "01010700")
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(row!.k, [1, 0])
    assert.deepEqual(row!.v, [7, undefined])
  })
})

describe("reference scope: which value fields a reference may name", () => {
  it("a u2 slot is an integer a count and an eq can name", () => {
    const layout = scheme<Row>(
      1,
      u2(0, (x) => x.a, 1, (x) => x.b),
      sized(2, (x) => x.p, 0),
      when(3, eq(1, 1), [u8(3, (x) => x.v)]),
    )
    const wire = BinaryPacker.pack(layout, { a: 2, b: 1, p: Uint8Array.of(7, 8), v: 9 })
    assert.equal(toHex(wire), "0106070809")
    const { result, row } = unpacked(layout, "0106070809")
    assert.deepEqual(result, { ok: true })
    assert.deepEqual([row!.a, row!.b, row!.v], [2, 1, 9])
    assert.equal(toHex(row!.p as Uint8Array), "0708")
  })

  // The group never runs: the field value is bytes or a list, which no eq value equals.
  const NAMED: { kind: string; layout: () => Scheme<Row>; hex: string; name: string }[] = [
    {
      kind: "sized",
      layout: () => scheme<Row>(
        1,
        u8(0, (x) => x.n),
        sized(1, (x) => x.p, 0),
        when(2, eq(1, 1), [u8(2, (x) => x.v)]),
      ),
      hex: "010105",
      name: "p",
    },
    {
      kind: "bits",
      layout: () => scheme<Row>(
        1,
        u8(0, (x) => x.n),
        bits(1, (x) => x.b, 0),
        when(2, eq(1, 1), [u8(2, (x) => x.v)]),
      ),
      hex: "010101",
      name: "b",
    },
    {
      kind: "packed",
      layout: () => scheme<Row>(
        1,
        u8(0, (x) => x.n),
        packed(2, 1, (x) => x.k, 0),
        when(2, eq(1, 1), [u8(2, (x) => x.v)]),
      ),
      hex: "010101",
      name: "k",
    },
  ]

  for (const c of NAMED) {
    it(`an eq may name a ${c.kind} field`, () => {
      const { result, row } = unpacked(c.layout(), c.hex)
      assert.deepEqual(result, { ok: true })
      assert.ok(row![c.name] !== undefined)
      assert.equal(row!.v, undefined)
    })
  }
})

describe("reference scope: references the scheme must refuse", () => {
  it("when naming a later field is a scheme error", () => {
    const message = refusal(() => scheme<Row>(
      1,
      when(0, eq(1, 5), [u8(0, (x) => x.a)]),
      u8(1, (x) => x.k),
    ))
    assert.match(message, /^when 0: eq names field id 1, which is not declared earlier in the same scope$/)
  })

  it("unknown reference id is a scheme error", () => {
    const message = refusal(() => scheme<Row>(
      1,
      u8(0, (x) => x.k),
      when(1, eq(9, 5), [u8(1, (x) => x.a)]),
    ))
    assert.match(message, /^when 1: eq names field id 9, which is not declared earlier in the same scope$/)
  })

  it("count naming itself in an element is a scheme error", () => {
    const message = refusal(() => scheme<Row>(
      1,
      u8(0, (x) => x.n),
      list((x) => x.xs, sized(0, (x) => x.p, 0)),
    ))
    assert.match(message, /^sized 0: count names field id 0, which is not declared earlier in the same scope$/)
  })

  it("count naming itself in a dict element is a scheme error", () => {
    const message = refusal(() => scheme<Row>(
      1,
      u8(0, (x) => x.n),
      dict((x) => x.d, sized(0, (x) => x.p, 0)),
    ))
    assert.match(message, /^sized 0: count names field id 0, which is not declared earlier in the same scope$/)
  })

  it("count naming a field inside an earlier times is a scheme error", () => {
    const message = refusal(() => scheme<Row>(
      1,
      u8(0, (x) => x.c),
      times(1, 0, [u8(1, (x) => x.n)]),
      sized(2, (x) => x.p, 1),
    ))
    assert.match(message, /^sized 2: count names field id 1, which is not declared earlier in the same scope$/)
  })

  it("when in a times body naming a field outside it is a scheme error", () => {
    const message = refusal(() => scheme<Row>(
      1,
      u8(0, (x) => x.n),
      times(1, 0, [when(1, eq(0, 1), [u8(1, (x) => x.v)])]),
    ))
    assert.match(message, /^when 1: eq names field id 0, which is not declared earlier in the same scope$/)
  })

  it("when in an unanchored group naming a field outside it is a scheme error", () => {
    const message = refusal(() => scheme<Row>(
      1,
      u8(0, (x) => x.k),
      u8(1, (x) => x.j),
      group((x) => x.g, [u8(0, (x) => x.a), when(1, eq(1, 1), [u8(1, (x) => x.b)])]),
    ))
    assert.match(message, /^when 1: eq names field id 1, which is not declared earlier in the same scope$/)
  })

  it("when naming its own body is a scheme error", () => {
    const message = refusal(() => scheme<Row>(1, when(0, eq(0, 1), [u8(0, (x) => x.a)])))
    assert.match(message, /^when 0: eq names field id 0, which is not declared earlier in the same scope$/)
  })

  it("count naming a bool is a scheme error", () => {
    const message = refusal(() => scheme<Row>(
      1,
      flags(0, [bool(0, (x) => x.on)]),
      times(1, 0, [u8(1, (x) => x.v)]),
    ))
    assert.match(message, /^times 1: count names field id 0 \(on\), which is not an integer$/)
  })

  it("count naming a float is a scheme error", () => {
    const message = refusal(() => scheme<Row>(
      1,
      f32(0, (x) => x.n),
      sized(1, (x) => x.p, 0),
    ))
    assert.match(message, /^sized 1: count names field id 0 \(n\), which is not an integer$/)
  })

  it("new Scheme refuses a bad reference like scheme()", () => {
    const fields = (): Field[] => [
      u8(0, (x: Row) => x.k),
      when(1, eq(9, 5), [u8(1, (x: Row) => x.a)]),
    ]
    const viaScheme = refusal(() => scheme<Row>(1, ...fields()))
    const viaNew = refusal(() => new Scheme<Row>(1, fields()))
    assert.equal(viaNew, viaScheme)
  })
})

describe("reference scope: eq compares integers by value", () => {
  const withU64 = (want: number | bigint) => scheme<Row>(
    1,
    u64(0, (x) => x.k),
    when(1, eq(0, want), [u8(1, (x) => x.v)]),
  )

  it("u64 when matches on unpack", () => {
    const layout = withU64(1)
    const wire = BinaryPacker.pack(layout, { k: 1, v: 9 })
    assert.equal(toHex(wire), "01010000000000000009")
    const { result, row } = unpacked(layout, toHex(wire))
    assert.deepEqual(result, { ok: true })
    assert.equal(row!.k, 1n)
    assert.equal(row!.v, 9)
  })

  it("bigint eq value matches number field value", () => {
    const wire = BinaryPacker.pack(withU64(1n), { k: 1, v: 9 })
    assert.equal(toHex(wire), "01010000000000000009")
  })

  it("number eq value matches bigint field value", () => {
    const wire = BinaryPacker.pack(withU64(1), { k: 1n, v: 9 })
    assert.equal(toHex(wire), "01010000000000000009")
  })

  it("a u64 value that differs from eq leaves the group out", () => {
    const layout = withU64(1)
    assert.equal(toHex(BinaryPacker.pack(layout, { k: 2, v: 9 })), "010200000000000000")
    const { result, row } = unpacked(layout, "010200000000000000")
    assert.deepEqual(result, { ok: true })
    assert.equal(row!.k, 2n)
  })

  // Only a number and a bigint compare by value; any other pair needs the same value.
  const WANTS: { name: string; want: unknown }[] = [
    { name: "true", want: true },
    { name: '"1"', want: "1" },
    { name: "[1]", want: [1] },
    { name: "null", want: null },
  ]

  for (const c of WANTS) {
    it(`eq ${c.name} does not match the number 1`, () => {
      const layout = scheme<Row>(1, u8(0, (x) => x.k), when(1, eq(0, c.want), [u8(1, (x) => x.v)]))
      assert.equal(toHex(BinaryPacker.pack(layout, { k: 1, v: 9 })), "0101")
      const { result, row } = unpacked(layout, "0101")
      assert.deepEqual(result, { ok: true })
      assert.equal(row!.v, undefined)
    })
  }

  const SEEN: { name: string; layout: () => Scheme<Row>; row: Row; hex: string }[] = [
    {
      name: "true",
      layout: () => scheme<Row>(
        1,
        flags(0, [bool(0, (x) => x.on)]),
        when(1, eq(0, 1), [u8(1, (x) => x.v)]),
      ),
      row: { on: true, v: 9 },
      hex: "0101",
    },
    {
      name: '"1"',
      layout: () => scheme<Row>(1, utf8(0, (x) => x.s), when(1, eq(0, 1), [u8(1, (x) => x.v)])),
      row: { s: "1", v: 9 },
      hex: "010100" + "31",
    },
    {
      name: "[1]",
      layout: () => scheme<Row>(
        1,
        u8(0, (x) => x.n),
        bits(1, (x) => x.b, 0),
        when(2, eq(1, 1), [u8(2, (x) => x.v)]),
      ),
      row: { n: 1, b: [1], v: 9 },
      hex: "010101",
    },
    {
      name: "an absent value",
      layout: () => scheme<Row>(
        1,
        flags(0, [u8(0, (x) => x.n)]),
        when(1, eq(0, null), [u8(1, (x) => x.v)]),
      ),
      row: { v: 9 },
      hex: "0100",
    },
  ]

  for (const c of SEEN) {
    it(`the field value ${c.name} does not match eq 1 or null`, () => {
      const layout = c.layout()
      assert.equal(toHex(BinaryPacker.pack(layout, c.row)), c.hex)
      const { result, row } = unpacked(layout, c.hex)
      assert.deepEqual(result, { ok: true })
      assert.equal(row!.v, undefined)
    })
  }

  it("a bool eq value still needs true", () => {
    const layout = scheme<Row>(
      1,
      flags(0, [bool(0, (x) => x.on)]),
      when(1, eq(0, true), [u16(1, (x) => x.v)]),
    )
    assert.equal(toHex(BinaryPacker.pack(layout, { on: true, v: 3 })), "01010300")
    assert.equal(toHex(BinaryPacker.pack(layout, { on: false })), "0100")
  })
})

describe("reference scope: an unbound reference", () => {
  const bound = () => scheme<Row>(1, u8(0, (x) => x.k), when(1, eq(0, 1), [u8(1, (x) => x.v)]))
  // A field a Scheme never saw: its reference was not resolved.
  const unbound = () => when(1, eq(0, 1), [u8(1, (x) => x.v)])

  it("fails loudly on pack", () => {
    const layout = bound()
    ;(layout.fields as Field[])[1] = unbound()
    assert.throws(() => BinaryPacker.pack(layout, { k: 1, v: 9 }), /^RangeError: when: reference is not bound$/)
  })

  it("fails loudly on unpack", () => {
    const layout = bound()
    ;(layout.fields as Field[])[1] = unbound()
    assert.throws(() => unpacked(layout, "0101" + "09"), /^RangeError: when: reference is not bound$/)
  })
})
