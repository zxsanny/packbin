import { existsSync, readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  packet,
  u8,
  u16,
  u32,
  i16,
  i32,
  flags,
  when,
  eq,
  repeat,
  group,
  sized,
  u2,
  bits,
  utf8,
  list,
  dict,
  be,
  pack,
  unpack,
} from "../src/index.ts"

const root = join(dirname(fileURLToPath(import.meta.url)), "../..")
const goldenHex = readFileSync(join(root, "fixtures/golden.hex"), "utf8").trim()
const expectedHex = "4001000065cd1d00a3e1110100"

const position = packet([
  u8("type"),
  u16("sid"),
  i32("lat"),
  i32("lon"),
  u8("profile"),
  flags("motion", [u16("heading"), u8("speed"), i16("altitude")]),
])

const positionValue = {
  type: 0x40,
  sid: 1,
  lat: 500_000_000,
  lon: 300_000_000,
  profile: 1,
}

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

function motionFieldCount(got: Record<string, unknown>): number {
  let n = 0
  for (const k of ["heading", "speed", "altitude"]) {
    if (got[k] !== undefined && got[k] !== null) n++
  }
  return n
}

describe("packbin", () => {
  it("AC-1 position pack", () => {
    const bytes = pack(position, positionValue)
    assert.equal(toHex(bytes), expectedHex)
    assert.equal(mismatchedBytes(bytes, Buffer.from(expectedHex, "hex")), 0)
    assert.equal(bytes.length, 13)
    const again = pack(position, positionValue)
    assert.equal(mismatchedBytes(bytes, again), 0)
  })

  it("AC-2 position unpack", () => {
    const bytes = Buffer.from(expectedHex, "hex")
    const got = unpack(position, bytes)
    assert.equal(got.ok, true)
    if (!got.ok) return
    assert.equal(got.type, 0x40)
    assert.equal(got.sid, 1)
    assert.equal(got.lat, 500_000_000)
    assert.equal(got.lon, 300_000_000)
    assert.equal(got.profile, 1)
    assert.equal(motionFieldCount(got), 0)
  })

  it("AC-3 bytes match fixtures/golden.hex", () => {
    const bytes = pack(position, positionValue)
    const fixture = Buffer.from(goldenHex, "hex")
    assert.equal(mismatchedBytes(bytes, fixture), 0)
  })

  it("AC-4 flags width, present 0, absence", () => {
    const list = packet([
      flags("opts", [
        u8("b0"),
        u8("b1"),
        u8("b2"),
        u8("b3"),
        u8("b4"),
        u16("extra"),
      ]),
    ])
    const clear = pack(list, {})
    assert.equal(clear.length, 1)
    assert.equal(clear[0], 0x00)

    const set = pack(list, { extra: 0x1234 })
    assert.equal(set.length, 3)
    assert.equal(set[0], 0x20)
    assert.equal(set.length - clear.length, 2)

    const zero = pack(list, { extra: 0 })
    assert.equal(zero.length, 3)
    assert.equal(zero[0], 0x20)
    assert.equal(zero[1], 0)
    assert.equal(zero[2], 0)

    const absent = pack(list, {})
    assert.equal(absent.length, 1)
    assert.equal(absent[0], 0x00)
    assert.notEqual(toHex(absent), toHex(zero))
  })

  it("AC-5 short buffer then position pack still matches", () => {
    const list = packet([
      flags("opts", [
        u8("b0"),
        u8("b1"),
        u8("b2"),
        u8("b3"),
        u8("b4"),
        u16("extra"),
      ]),
    ])
    const shortBuf = Uint8Array.of(0x20, 0x34)
    const got = unpack(list, shortBuf)
    assert.equal(got.ok, false)
    if (got.ok) return
    assert.equal(got.field, "extra")
    assert.equal(got.needed, 2)
    assert.equal(got.left, 1)

    const bytes = pack(position, positionValue)
    assert.equal(toHex(bytes), expectedHex)
  })

  it("IT-06 when group width", () => {
    const list = packet([
      u8("profile"),
      when(eq("profile", 0), [u8("shape")]),
    ])
    const miss = pack(list, { profile: 1 })
    assert.equal(miss.length, 1)
    const hit = pack(list, { profile: 0, shape: 9 })
    assert.equal(hit.length, 2)
    assert.equal(hit.length - miss.length, 1)
  })

  it("IT-07 repeat on group boundary", () => {
    const list = packet([u8("type"), repeat([u8("a"), u8("b")])])
    const complete = unpack(list, Uint8Array.of(1, 2, 3))
    assert.equal(complete.ok, true)
    if (!complete.ok) return
    assert.ok(Array.isArray(complete.a))
    assert.equal((complete.a as number[]).length, 1)

    const leftover = unpack(list, Uint8Array.of(1, 2, 3, 4))
    assert.equal(leftover.ok, false)
  })

  it("IT-09 trailing bytes", () => {
    const bytes = Buffer.from(expectedHex + "ff", "hex")
    const got = unpack(position, bytes)
    assert.equal(got.ok, false)
  })

  it("flag empty group mark", () => {
    const empty = packet([flags("f", [group("mark", [])])])
    const setBit = pack(empty, { mark: true })
    assert.equal(toHex(setBit), "01")
    const clear = pack(empty, {})
    assert.equal(toHex(clear), "00")
  })

  it("flag five u8 then u16 b5", () => {
    const one = packet([
      flags("f", [u8("a"), u8("b"), u8("c"), u8("d"), u8("e"), u16("b5")]),
    ])
    assert.equal(pack(one, { a: 1 }).length, 2)
    const wide = pack(one, { b5: 1 })
    assert.equal(wide[0], 0x20)
    assert.equal(wide.length - pack(one, {}).length, 2)
  })

  it("flag session group login ts", () => {
    const two = packet([
      flags("f", [group("session", [u16("login"), u32("ts")])]),
    ])
    const raw = pack(two, { login: 7, ts: 1000 })
    assert.equal(toHex(raw.subarray(1)), "0700e8030000")
    const absent = pack(two, {})
    assert.equal(toHex(absent), "00")
    const got = unpack(two, absent)
    assert.equal(got.ok, true)
    if (!got.ok) return
    assert.equal("login" in got, false)
    assert.equal("ts" in got, false)
  })

  it("flag group u8 zero packs", () => {
    const zero = packet([flags("f", [group("g", [u8("b")])])])
    const stored = pack(zero, { b: 0 })
    assert.equal(toHex(stored), "0100")
  })

  it("flag session group short read", () => {
    const two = packet([
      flags("f", [group("session", [u16("login"), u32("ts")])]),
    ])
    const short = unpack(two, Uint8Array.of(0x01, 0x07))
    assert.equal(short.ok, false)
    if (short.ok) return
    assert.equal(short.field, "login")
    assert.equal(short.needed, 2)
    assert.equal(short.left, 1)
  })

  it("sized payload by count field", () => {
    const layout = packet([u16("n"), sized("payload", "n")])
    const raw = pack(layout, {
      n: 3,
      payload: Uint8Array.from(Buffer.from("756176", "hex")),
    })
    assert.equal(toHex(raw), "0300756176")
    const empty = pack(layout, { n: 0, payload: new Uint8Array(0) })
    assert.equal(toHex(empty), "0000")
    const emptyGot = unpack(layout, empty)
    assert.equal(emptyGot.ok, true)
    if (!emptyGot.ok) return
    assert.equal((emptyGot.payload as Uint8Array).length, 0)
    const short = unpack(layout, Uint8Array.from(Buffer.from("030075", "hex")))
    assert.equal(short.ok, false)
    if (short.ok) return
    assert.equal(short.field, "payload")
    assert.equal(short.needed, 3)
    assert.equal(short.left, 1)
  })

  it("u2 and bits", () => {
    const kinds = packet([u2("a", "b", "c", "d")])
    const raw = pack(kinds, { a: 0, b: 1, c: 2, d: 3 })
    assert.equal(toHex(raw), "e4")
    const got = unpack(kinds, raw)
    assert.equal(got.ok, true)
    if (!got.ok) return
    assert.deepEqual([got.a, got.b, got.c, got.d], [0, 1, 2, 3])
    const one = pack(packet([u2("a")]), { a: 1 })
    assert.equal(toHex(one), "01")

    const layout = packet([u8("n"), bits("segs", "n")])
    const eight = pack(layout, { n: 8, segs: [1, 1, 1, 1, 1, 1, 1, 1] })
    assert.equal(toHex(eight.subarray(1)), "ff")
    const nine = pack(layout, {
      n: 9,
      segs: [1, 1, 1, 1, 1, 1, 1, 1, 1],
    })
    assert.equal(nine.length - 1, 2)
    assert.equal(nine[1], 0xff)
    assert.equal(nine[2]! & 0xfe, 0)
    const short = unpack(layout, Uint8Array.of(9, 0x01))
    assert.equal(short.ok, false)
    if (short.ok) return
    assert.equal(short.field, "segs")
    assert.equal(short.needed, 2)
    assert.equal(short.left, 1)
  })

  it("utf8 string count is the payload", () => {
    const layout = packet([utf8("name")])
    const raw = pack(layout, { name: "zxsanny" })
    assert.equal(toHex(raw), "07007a7873616e6e79")
    assert.equal(raw.length, 9)
    const got = unpack(layout, raw)
    assert.equal(got.ok, true)
    if (!got.ok) return
    assert.equal(got.name, "zxsanny")

    const empty = pack(layout, { name: "" })
    assert.equal(toHex(empty), "0000")
    const emptyGot = unpack(layout, empty)
    assert.equal(emptyGot.ok, true)
    if (!emptyGot.ok) return
    assert.equal(emptyGot.name, "")

    let produced: Uint8Array | null = null
    assert.throws(() => {
      produced = pack(layout, { name: "a".repeat(65536) })
    })
    assert.equal(produced, null)

    const short = unpack(layout, Uint8Array.of(0x07, 0x00, 0x7a, 0x78))
    assert.equal(short.ok, false)
    if (short.ok) return
    assert.equal(short.field, "name")
    assert.equal(short.needed, 7)
    assert.equal(short.left, 2)
    assert.equal("name" in short, false)
  })

  it("counted list leaves the next field", () => {
    const two = packet([list("xs", u16("n"))])
    const raw = pack(two, { xs: [1, 2] })
    assert.equal(toHex(raw), "020001000200")
    const got = unpack(two, raw)
    assert.equal(got.ok, true)
    if (!got.ok) return
    assert.deepEqual(got.xs, [1, 2])

    const beOne = packet([list("xs", be(u16("n")))])
    assert.equal(toHex(pack(beOne, { xs: [1] })), "01000001")

    const followed = packet([list("xs", u8("n")), u8("y")])
    const both = pack(followed, { xs: [1], y: 2 })
    assert.equal(toHex(both), "01000102")
    const back = unpack(followed, both)
    assert.equal(back.ok, true)
    if (!back.ok) return
    assert.deepEqual(back.xs, [1])
    assert.equal(back.y, 2)

    assert.equal(toHex(pack(two, { xs: [] })), "0000")
    let produced: Uint8Array | null = null
    assert.throws(() => {
      produced = pack(two, { xs: Array(65536).fill(1) })
    })
    assert.equal(produced, null)
  })

  it("dictionary field orders keys and nests lists", () => {
    const userHex =
      "07007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465"
    const layout = packet([
      utf8("username"),
      list("roles", utf8("role")),
      dict("access", list("actions", utf8("action"))),
    ])
    const userValue = {
      username: "zxsanny",
      roles: ["user", "dispatcher"],
      access: {
        channel: ["read"],
        map: ["read", "gps_fix", "set", "edit"],
        store: ["read", "write"],
      },
    }

    const raw = pack(layout, userValue)
    assert.equal(toHex(raw), userHex)
    const got = unpack(layout, raw)
    assert.equal(got.ok, true)
    if (!got.ok) return
    assert.equal(got.username, "zxsanny")
    assert.deepEqual(got.roles, ["user", "dispatcher"])
    const access = got.access as Record<string, string[]>
    assert.deepEqual(access.channel, ["read"])
    assert.deepEqual(access.map, ["read", "gps_fix", "set", "edit"])
    assert.deepEqual(access.store, ["read", "write"])
    assert.equal(Object.keys(access).length, 3)

    const reordered = pack(layout, {
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

    const empties = packet([
      utf8("name"),
      list("xs", utf8("x")),
      dict("d", utf8("v")),
    ])
    assert.equal(toHex(pack(empties, { name: "", xs: [], d: {} })), "000000000000")

    const dup = packet([dict("access", utf8("v"))])
    const bad = unpack(dup, Buffer.from("0200010061010078010061010079", "hex"))
    assert.equal(bad.ok, false)
    if (bad.ok) return
    assert.equal(Object.keys(bad).filter((k) => k !== "ok" && k !== "field" && k !== "needed" && k !== "left").length, 0)

    const a = pack(layout, userValue)
    const b = pack(layout, userValue)
    assert.equal(mismatchedBytes(a, b), 0)

    let left: Uint8Array | null = null
    let right: Uint8Array | null = null
    return Promise.all([
      Promise.resolve().then(() => {
        left = pack(layout, userValue)
      }),
      Promise.resolve().then(() => {
        right = pack(layout, userValue)
      }),
    ]).then(() => {
      assert.ok(left)
      assert.ok(right)
      assert.equal(mismatchedBytes(left!, right!), 0)
    }).then(() => {
      let produced: Uint8Array | null = null
      const huge: Record<string, string> = {}
      for (let i = 0; i < 65536; i++) huge[`k${i}`] = "v"
      assert.throws(() => {
        produced = pack(packet([dict("d", utf8("v"))]), { d: huge })
      })
      assert.equal(produced, null)
    })
  })

  it("NFR 100000 pack-then-unpack round trips ≤ 1s", () => {
    const start = performance.now()
    for (let i = 0; i < 100_000; i++) {
      const bytes = pack(position, positionValue)
      const got = unpack(position, bytes)
      assert.equal(got.ok, true)
    }
    const elapsed = performance.now() - start
    assertNoGpu()
    assert.ok(elapsed <= 1000, `elapsed ${elapsed}ms`)
  })

  it("packs a class instance and flattens a nested group", () => {
    class Row {
      type = 0x40
      sid = 1
      lat = 500_000_000
      lon = 300_000_000
      profile = 1
      heading: number | null = null
    }
    assert.equal(Buffer.from(pack(position, new Row())).toString("hex"), expectedHex)
    class Session {
      login = 7
      ts = 1000
    }
    class Holder {
      session: Session | null = new Session()
    }
    const layout = packet([flags("f", [group("session", [u16("login"), u32("ts")])])])
    assert.equal(Buffer.from(pack(layout, new Holder())).toString("hex"), "010700e8030000")
    assert.equal(Buffer.from(pack(layout, { session: null })).toString("hex"), "00")
    const back = unpack(layout, pack(layout, new Holder()), Holder)
    assert.equal(back.ok, true)
    if (!back.ok) return
    assert.equal(back.value instanceof Holder, true)
    assert.equal(back.value.session instanceof Session, true)
    assert.equal(back.value.session?.login, 7)
    assert.equal(back.value.session?.ts, 1000)
    const clear = unpack(layout, pack(layout, { session: null }), Holder)
    assert.equal(clear.ok, true)
    if (!clear.ok) return
    assert.equal(clear.value.session, null)
    const row = unpack(position, pack(position, new Row()), Row)
    assert.equal(row.ok, true)
    if (!row.ok) return
    assert.equal(row.value instanceof Row, true)
    assert.equal(row.value.lat, 500_000_000)
    assert.equal(row.value.heading, null)
  })
})

function assertNoGpu() {
  if (!existsSync("/proc/self/maps")) return
  const blob = readFileSync("/proc/self/maps", "utf8").toLowerCase()
  for (const bad of ["libcuda", "libnvidia", "libvulkan", "libopencl", "metal.framework"]) {
    assert.equal(blob.includes(bad), false, bad)
  }
}
