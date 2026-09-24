import { existsSync, readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  scheme,
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
  pack,
  unpack,
} from "../src/index.ts"

const root = join(dirname(fileURLToPath(import.meta.url)), "../..")
const goldenHex = readFileSync(join(root, "fixtures/golden.hex"), "utf8").trim()
const expectedHex = "4001000065cd1d00a3e1110100"

const position = scheme(
  0x40,
  u16("sid"),
  i32("lat"),
  i32("lon"),
  u8("profile"),
  flags("motion", [u16("heading"), u8("speed"), i16("altitude")]),
)

const positionValue = {
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
    assert.equal("type" in got.value, false)
    assert.equal(got.value.sid, 1)
    assert.equal(got.value.lat, 500_000_000)
    assert.equal(got.value.lon, 300_000_000)
    assert.equal(got.value.profile, 1)
    assert.equal(motionFieldCount(got.value), 0)
  })

  it("AC-3 bytes match fixtures/golden.hex", () => {
    const bytes = pack(position, positionValue)
    const fixture = Buffer.from(goldenHex, "hex")
    assert.equal(mismatchedBytes(bytes, fixture), 0)
  })

  it("AC-4 flags width, present 0, absence", () => {
    const list = scheme(
      1,
      flags("opts", [
        u8("b0"),
        u8("b1"),
        u8("b2"),
        u8("b3"),
        u8("b4"),
        u16("extra"),
      ]),
    )
    const clear = pack(list, {})
    assert.equal(clear.length, 2)
    assert.equal(clear[0], 0x01)
    assert.equal(clear[1], 0x00)

    const set = pack(list, { extra: 0x1234 })
    assert.equal(set.length, 4)
    assert.equal(set[0], 0x01)
    assert.equal(set[1], 0x20)
    assert.equal(set.length - clear.length, 2)

    const zero = pack(list, { extra: 0 })
    assert.equal(zero.length, 4)
    assert.equal(zero[0], 0x01)
    assert.equal(zero[1], 0x20)
    assert.equal(zero[2], 0)
    assert.equal(zero[3], 0)

    const absent = pack(list, {})
    assert.equal(absent.length, 2)
    assert.equal(absent[0], 0x01)
    assert.equal(absent[1], 0x00)
    assert.notEqual(toHex(absent), toHex(zero))
  })

  it("AC-5 short buffer then position pack still matches", () => {
    const list = scheme(
      1,
      flags("opts", [
        u8("b0"),
        u8("b1"),
        u8("b2"),
        u8("b3"),
        u8("b4"),
        u16("extra"),
      ]),
    )
    const shortBuf = Uint8Array.of(0x01, 0x20, 0x34)
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
    const list = scheme(1, u8("profile"), when(eq("profile", 0), [u8("shape")]))
    const miss = pack(list, { profile: 1 })
    assert.equal(miss.length, 2)
    const hit = pack(list, { profile: 0, shape: 9 })
    assert.equal(hit.length, 3)
    assert.equal(hit.length - miss.length, 1)
  })

  it("IT-07 repeat on group boundary", () => {
    const list = scheme(1, u8("type"), repeat([u8("a"), u8("b")]))
    const complete = unpack(list, Uint8Array.of(1, 1, 2, 3))
    assert.equal(complete.ok, true)
    if (!complete.ok) return
    assert.ok(Array.isArray(complete.value.a))
    assert.equal((complete.value.a as number[]).length, 1)

    const leftover = unpack(list, Uint8Array.of(1, 1, 2, 3, 4))
    assert.equal(leftover.ok, false)
  })

  it("IT-09 trailing bytes", () => {
    const bytes = Buffer.from(expectedHex + "ff", "hex")
    const got = unpack(position, bytes)
    assert.equal(got.ok, false)
  })

  it("flag empty group mark", () => {
    const empty = scheme(1, flags("f", [group("mark", [])]))
    const setBit = pack(empty, { mark: true })
    assert.equal(toHex(setBit), "0101")
    const clear = pack(empty, {})
    assert.equal(toHex(clear), "0100")
  })

  it("flag five u8 then u16 b5", () => {
    const one = scheme(
      1,
      flags("f", [u8("a"), u8("b"), u8("c"), u8("d"), u8("e"), u16("b5")]),
    )
    assert.equal(pack(one, { a: 1 }).length, 3)
    const wide = pack(one, { b5: 1 })
    assert.equal(wide[0], 0x01)
    assert.equal(wide[1], 0x20)
    assert.equal(wide.length - pack(one, {}).length, 2)
  })

  it("flag session group login ts", () => {
    const two = scheme(1, flags("f", [group("session", [u16("login"), u32("ts")])]))
    const raw = pack(two, { login: 7, ts: 1000 })
    assert.equal(toHex(raw.subarray(2)), "0700e8030000")
    const absent = pack(two, {})
    assert.equal(toHex(absent), "0100")
    const got = unpack(two, absent)
    assert.equal(got.ok, true)
    if (!got.ok) return
    assert.equal("login" in got.value, false)
    assert.equal("ts" in got.value, false)
  })

  it("flag group u8 zero packs", () => {
    const zero = scheme(1, flags("f", [group("g", [u8("b")])]))
    const stored = pack(zero, { b: 0 })
    assert.equal(toHex(stored), "010100")
  })

  it("flag session group short read", () => {
    const two = scheme(1, flags("f", [group("session", [u16("login"), u32("ts")])]))
    const short = unpack(two, Uint8Array.of(0x01, 0x01, 0x07))
    assert.equal(short.ok, false)
    if (short.ok) return
    assert.equal(short.field, "login")
    assert.equal(short.needed, 2)
    assert.equal(short.left, 1)
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
    const layout = scheme(1, flags("f", [group("session", [u16("login"), u32("ts")])]))
    assert.equal(Buffer.from(pack(layout, new Holder())).toString("hex"), "01010700e8030000")
    assert.equal(Buffer.from(pack(layout, { session: null })).toString("hex"), "0100")
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

  it("type number outside 0..255 throws at construction", () => {
    assert.throws(() => scheme(256, u8("sid")))
    assert.throws(() => scheme(-1, u8("sid")))
  })
})

function assertNoGpu() {
  if (!existsSync("/proc/self/maps")) return
  const blob = readFileSync("/proc/self/maps", "utf8").toLowerCase()
  for (const bad of [
    "libcuda",
    "libnvidia",
    "libvulkan",
    "libopencl",
    "metal.framework",
  ]) {
    assert.equal(blob.includes(bad), false, bad)
  }
}
