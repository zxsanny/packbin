import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  be,
  bits,
  dict,
  list,
  scheme,
  sized,
  u2,
  u8,
  u16,
  utf8,
} from "../src/index.ts"

function toHex(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("hex")
}

function mismatchedBytes(a: Uint8Array, b: Uint8Array): number {
  const n = Math.max(a.length, b.length)
  let bad = 0
  for (let i = 0; i < n; i++) {
    if ((a[i] ?? -1) !== (b[i] ?? -1)) bad++
  }
  return bad
}

describe("packbin fields", () => {
  it("sized payload by count field", () => {
    type Row = { n: number; payload: Uint8Array }
    const layout = scheme<Row>(
      1,
      u16(0, (r) => r.n),
      sized(1, (r) => r.payload, 0),
    )
    const raw = BinaryPacker.pack(layout, {
      n: 3,
      payload: Uint8Array.from(Buffer.from("756176", "hex")),
    })
    assert.equal(toHex(raw), "010300756176")
    const empty = BinaryPacker.pack(layout, { n: 0, payload: new Uint8Array(0) })
    assert.equal(toHex(empty), "010000")
    let emptyGot: Row | undefined
    const emptyResult = BinaryPacker.unpack(empty, layout.on((value) => {
      emptyGot = value as Row
    }))
    assert.equal(emptyResult.ok, true)
    assert.equal((emptyGot!.payload as Uint8Array).length, 0)
    let shortRan = false
    const short = BinaryPacker.unpack(
      Uint8Array.from(Buffer.from("01030075", "hex")),
      layout.on(() => {
        shortRan = true
      }),
    )
    assert.equal(short.ok, false)
    if (short.ok) return
    assert.equal(short.field, "payload")
    assert.equal(short.needed, 3)
    assert.equal(short.left, 1)
    assert.equal(shortRan, false)
  })

  it("u2 and bits", () => {
    type Kinds = { a: number; b: number; c: number; d: number }
    const kinds = scheme<Kinds>(
      1,
      u2(
        0,
        (r) => r.a,
        1,
        (r) => r.b,
        2,
        (r) => r.c,
        3,
        (r) => r.d,
      ),
    )
    const raw = BinaryPacker.pack(kinds, { a: 0, b: 1, c: 2, d: 3 })
    assert.equal(toHex(raw), "01e4")
    let got: Kinds | undefined
    const result = BinaryPacker.unpack(raw, kinds.on((value) => {
      got = value as Kinds
    }))
    assert.equal(result.ok, true)
    assert.deepEqual([got!.a, got!.b, got!.c, got!.d], [0, 1, 2, 3])
    const one = BinaryPacker.pack(
      scheme(1, u2(0, (r: { a: number }) => r.a)),
      { a: 1 },
    )
    assert.equal(toHex(one), "0101")

    type BitsRow = { n: number; segs: number[] }
    const layout = scheme<BitsRow>(
      1,
      u8(0, (r) => r.n),
      bits(1, (r) => r.segs, 0),
    )
    const eight = BinaryPacker.pack(layout, { n: 8, segs: [1, 1, 1, 1, 1, 1, 1, 1] })
    assert.equal(toHex(eight.subarray(2)), "ff")
    const nine = BinaryPacker.pack(layout, {
      n: 9,
      segs: [1, 1, 1, 1, 1, 1, 1, 1, 1],
    })
    assert.equal(nine.length - 2, 2)
    assert.equal(nine[2], 0xff)
    assert.equal(nine[3]! & 0xfe, 0)
    let shortRan = false
    const short = BinaryPacker.unpack(Uint8Array.of(1, 9, 0x01), layout.on(() => {
      shortRan = true
    }))
    assert.equal(short.ok, false)
    if (short.ok) return
    assert.equal(short.field, "segs")
    assert.equal(short.needed, 2)
    assert.equal(short.left, 1)
    assert.equal(shortRan, false)
  })

  it("utf8 string count is the payload", () => {
    type Row = { name: string }
    const layout = scheme<Row>(1, utf8(0, (r) => r.name))
    const raw = BinaryPacker.pack(layout, { name: "zxsanny" })
    assert.equal(toHex(raw), "0107007a7873616e6e79")
    assert.equal(raw.length, 10)
    let got: Row | undefined
    const result = BinaryPacker.unpack(raw, layout.on((value) => {
      got = value as Row
    }))
    assert.equal(result.ok, true)
    assert.equal(got!.name, "zxsanny")

    const empty = BinaryPacker.pack(layout, { name: "" })
    assert.equal(toHex(empty), "010000")
    let emptyGot: Row | undefined
    const emptyResult = BinaryPacker.unpack(empty, layout.on((value) => {
      emptyGot = value as Row
    }))
    assert.equal(emptyResult.ok, true)
    assert.equal(emptyGot!.name, "")

    let produced: Uint8Array | null = null
    assert.throws(() => {
      produced = BinaryPacker.pack(layout, { name: "a".repeat(65536) })
    })
    assert.equal(produced, null)

    let shortRan = false
    const short = BinaryPacker.unpack(
      Uint8Array.of(0x01, 0x07, 0x00, 0x7a, 0x78),
      layout.on(() => {
        shortRan = true
      }),
    )
    assert.equal(short.ok, false)
    if (short.ok) return
    assert.equal(short.field, "name")
    assert.equal(short.needed, 7)
    assert.equal(short.left, 2)
    assert.equal("name" in short, false)
    assert.equal(shortRan, false)
  })

  it("counted list leaves the next field", () => {
    type Two = { xs: number[]; y?: number }
    const two = scheme<Two>(
      1,
      list(
        (r) => r.xs,
        u16(0, (n) => n),
      ),
    )
    const raw = BinaryPacker.pack(two, { xs: [1, 2] })
    assert.equal(toHex(raw), "01020001000200")
    let got: Two | undefined
    const result = BinaryPacker.unpack(raw, two.on((value) => {
      got = value as Two
    }))
    assert.equal(result.ok, true)
    assert.deepEqual(got!.xs, [1, 2])

    const beOne = scheme<Two>(
      1,
      list(
        (r) => r.xs,
        be(u16(0, (n) => n)),
      ),
    )
    assert.equal(toHex(BinaryPacker.pack(beOne, { xs: [1] })), "0101000001")

    const followed = scheme<Two>(
      1,
      list(
        (r) => r.xs,
        u8(0, (n) => n),
      ),
      u8(0, (r) => r.y),
    )
    const both = BinaryPacker.pack(followed, { xs: [1], y: 2 })
    assert.equal(toHex(both), "0101000102")
    let back: Two | undefined
    const backResult = BinaryPacker.unpack(both, followed.on((value) => {
      back = value as Two
    }))
    assert.equal(backResult.ok, true)
    assert.deepEqual(back!.xs, [1])
    assert.equal(back!.y, 2)

    assert.equal(toHex(BinaryPacker.pack(two, { xs: [] })), "010000")
    let produced: Uint8Array | null = null
    assert.throws(() => {
      produced = BinaryPacker.pack(two, { xs: Array(65536).fill(1) })
    })
    assert.equal(produced, null)
  })

  it("dictionary field orders keys and nests lists", () => {
    const userHex =
      "0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465"
    type User = {
      username: string
      roles: string[]
      access: Record<string, string[]>
    }
    const layout = scheme<User>(
      1,
      utf8(0, (r) => r.username),
      list(
        (r) => r.roles,
        utf8(0, (s) => s),
      ),
      dict(
        (r) => r.access,
        list(
          (a) => a,
          utf8(0, (s) => s),
        ),
      ),
    )
    const userValue: User = {
      username: "zxsanny",
      roles: ["user", "dispatcher"],
      access: {
        channel: ["read"],
        map: ["read", "gps_fix", "set", "edit"],
        store: ["read", "write"],
      },
    }

    const raw = BinaryPacker.pack(layout, userValue)
    assert.equal(toHex(raw), userHex)
    let got: User | undefined
    const result = BinaryPacker.unpack(raw, layout.on((value) => {
      got = value as User
    }))
    assert.equal(result.ok, true)
    assert.equal(got!.username, "zxsanny")
    assert.deepEqual(got!.roles, ["user", "dispatcher"])
    const access = got!.access as Record<string, string[]>
    assert.deepEqual(access.channel, ["read"])
    assert.deepEqual(access.map, ["read", "gps_fix", "set", "edit"])
    assert.deepEqual(access.store, ["read", "write"])
    assert.equal(Object.keys(access).length, 3)

    const reordered = BinaryPacker.pack(layout, {
      username: "zxsanny",
      roles: ["user", "dispatcher"],
      access: {
        store: ["read", "write"],
        channel: ["read"],
        map: ["read", "gps_fix", "set", "edit"],
      },
    })
    assert.equal(toHex(reordered), userHex)
    assert.equal(mismatchedBytes(raw, reordered), 0)

    type Empties = { name: string; xs: string[]; d: Record<string, string> }
    const empties = scheme<Empties>(
      1,
      utf8(0, (r) => r.name),
      list(
        (r) => r.xs,
        utf8(0, (x) => x),
      ),
      dict(
        (r) => r.d,
        utf8(0, (v) => v),
      ),
    )
    assert.equal(toHex(BinaryPacker.pack(empties, { name: "", xs: [], d: {} })), "01000000000000")

    const dup = scheme(
      1,
      dict(
        (r: { access: Record<string, string> }) => r.access,
        utf8(0, (v) => v),
      ),
    )
    let badRan = false
    const bad = BinaryPacker.unpack(
      Buffer.from("010200010061010078010061010079", "hex"),
      dup.on(() => {
        badRan = true
      }),
    )
    assert.equal(bad.ok, false)
    if (bad.ok) return
    assert.equal(
      Object.keys(bad).filter(
        (k) => k !== "ok" && k !== "field" && k !== "needed" && k !== "left",
      ).length,
      0,
    )
    assert.equal(badRan, false)

    const a = BinaryPacker.pack(layout, userValue)
    const b = BinaryPacker.pack(layout, userValue)
    assert.equal(mismatchedBytes(a, b), 0)

    let left: Uint8Array | null = null
    let right: Uint8Array | null = null
    return Promise.all([
      Promise.resolve().then(() => {
        left = BinaryPacker.pack(layout, userValue)
      }),
      Promise.resolve().then(() => {
        right = BinaryPacker.pack(layout, userValue)
      }),
    ])
      .then(() => {
        assert.ok(left)
        assert.ok(right)
        assert.equal(mismatchedBytes(left!, right!), 0)
      })
      .then(() => {
        let produced: Uint8Array | null = null
        const huge: Record<string, string> = {}
        for (let i = 0; i < 65536; i++) huge[`k${i}`] = "v"
        assert.throws(() => {
          produced = BinaryPacker.pack(
            scheme(
              1,
              dict(
                (r: { d: Record<string, string> }) => r.d,
                utf8(0, (v) => v),
              ),
            ),
            { d: huge },
          )
        })
        assert.equal(produced, null)
      })
  })
})
