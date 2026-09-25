import { existsSync, readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  eq,
  flags,
  group,
  i16,
  i32,
  repeat,
  scheme,
  u8,
  u16,
  u32,
  when,
} from "../src/index.ts"

const root = join(dirname(fileURLToPath(import.meta.url)), "../..")
const goldenHex = readFileSync(join(root, "fixtures/golden.hex"), "utf8").trim()
const expectedHex = "4001000065cd1d00a3e1110100"

type Position = {
  sid: number
  lat: number
  lon: number
  profile: number
  heading?: number | null
  speed?: number | null
  altitude?: number | null
}

const position = scheme<Position>(
  0x40,
  u16(0, (r) => r.sid),
  i32(1, (r) => r.lat),
  i32(2, (r) => r.lon),
  u8(3, (r) => r.profile),
  flags([
    u16(4, (r) => r.heading),
    u8(5, (r) => r.speed),
    i16(6, (r) => r.altitude),
  ]),
)

const positionValue: Position = {
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
    const bytes = BinaryPacker.pack(position, positionValue)
    assert.equal(toHex(bytes), expectedHex)
    assert.equal(mismatchedBytes(bytes, Buffer.from(expectedHex, "hex")), 0)
    assert.equal(bytes.length, 13)
    const again = BinaryPacker.pack(position, positionValue)
    assert.equal(mismatchedBytes(bytes, again), 0)
  })

  it("AC-2 position unpack", () => {
    const bytes = Buffer.from(expectedHex, "hex")
    let got: Position | undefined
    const result = BinaryPacker.unpack(bytes, position.on((value) => {
      got = value as Position
    }))
    assert.equal(result.ok, true)
    assert.ok(got)
    assert.equal("type" in got!, false)
    assert.equal(got!.sid, 1)
    assert.equal(got!.lat, 500_000_000)
    assert.equal(got!.lon, 300_000_000)
    assert.equal(got!.profile, 1)
    assert.equal(motionFieldCount(got!), 0)
  })

  it("AC-3 bytes match fixtures/golden.hex", () => {
    const bytes = BinaryPacker.pack(position, positionValue)
    const fixture = Buffer.from(goldenHex, "hex")
    assert.equal(mismatchedBytes(bytes, fixture), 0)
  })

  it("AC-4 flags width, present 0, absence", () => {
    type Wide = {
      b0?: number
      b1?: number
      b2?: number
      b3?: number
      b4?: number
      extra?: number
    }
    const list = scheme<Wide>(
      1,
      flags([
        u8(0, (r) => r.b0),
        u8(1, (r) => r.b1),
        u8(2, (r) => r.b2),
        u8(3, (r) => r.b3),
        u8(4, (r) => r.b4),
        u16(5, (r) => r.extra),
      ]),
    )
    const clear = BinaryPacker.pack(list, {})
    assert.equal(clear.length, 2)
    assert.equal(clear[0], 0x01)
    assert.equal(clear[1], 0x00)

    const set = BinaryPacker.pack(list, { extra: 0x1234 })
    assert.equal(set.length, 4)
    assert.equal(set[0], 0x01)
    assert.equal(set[1], 0x20)
    assert.equal(set.length - clear.length, 2)

    const zero = BinaryPacker.pack(list, { extra: 0 })
    assert.equal(zero.length, 4)
    assert.equal(zero[0], 0x01)
    assert.equal(zero[1], 0x20)
    assert.equal(zero[2], 0)
    assert.equal(zero[3], 0)

    const absent = BinaryPacker.pack(list, {})
    assert.equal(absent.length, 2)
    assert.equal(absent[0], 0x01)
    assert.equal(absent[1], 0x00)
    assert.notEqual(toHex(absent), toHex(zero))
  })

  it("AC-5 short buffer then position pack still matches", () => {
    type Wide = {
      b0?: number
      b1?: number
      b2?: number
      b3?: number
      b4?: number
      extra?: number
    }
    const list = scheme<Wide>(
      1,
      flags([
        u8(0, (r) => r.b0),
        u8(1, (r) => r.b1),
        u8(2, (r) => r.b2),
        u8(3, (r) => r.b3),
        u8(4, (r) => r.b4),
        u16(5, (r) => r.extra),
      ]),
    )
    const shortBuf = Uint8Array.of(0x01, 0x20, 0x34)
    let ran = false
    const got = BinaryPacker.unpack(shortBuf, list.on(() => {
      ran = true
    }))
    assert.equal(got.ok, false)
    if (got.ok) return
    assert.equal(got.field, "extra")
    assert.equal(got.needed, 2)
    assert.equal(got.left, 1)
    assert.equal(ran, false)

    const bytes = BinaryPacker.pack(position, positionValue)
    assert.equal(toHex(bytes), expectedHex)
  })

  it("IT-06 when group width", () => {
    type Row = { profile: number; shape?: number }
    const list = scheme<Row>(
      1,
      u8(0, (r) => r.profile),
      when(eq(0, 0), [u8(1, (r) => r.shape)]),
    )
    const miss = BinaryPacker.pack(list, { profile: 1 })
    assert.equal(miss.length, 2)
    const hit = BinaryPacker.pack(list, { profile: 0, shape: 9 })
    assert.equal(hit.length, 3)
    assert.equal(hit.length - miss.length, 1)
  })

  it("IT-07 repeat on group boundary", () => {
    type Row = { type: number; a?: number | number[]; b?: number | number[] }
    const list = scheme<Row>(
      1,
      u8(0, (r) => r.type),
      repeat([u8(1, (r) => r.a), u8(2, (r) => r.b)]),
    )
    let completeRow: Row | undefined
    const complete = BinaryPacker.unpack(Uint8Array.of(1, 1, 2, 3), list.on((value) => {
      completeRow = value as Row
    }))
    assert.equal(complete.ok, true)
    assert.ok(Array.isArray(completeRow!.a))
    assert.equal((completeRow!.a as number[]).length, 1)

    let leftoverRan = false
    const leftover = BinaryPacker.unpack(Uint8Array.of(1, 1, 2, 3, 4), list.on(() => {
      leftoverRan = true
    }))
    assert.equal(leftover.ok, false)
    assert.equal(leftoverRan, false)
  })

  it("IT-09 trailing bytes", () => {
    const bytes = Buffer.from(expectedHex + "ff", "hex")
    let ran = false
    const got = BinaryPacker.unpack(bytes, position.on(() => {
      ran = true
    }))
    assert.equal(got.ok, false)
    assert.equal(ran, false)
  })

  it("flag empty group mark", () => {
    type Row = { mark?: boolean }
    const empty = scheme<Row>(1, flags([group((r) => r.mark, [])]))
    const setBit = BinaryPacker.pack(empty, { mark: true })
    assert.equal(toHex(setBit), "0101")
    const clear = BinaryPacker.pack(empty, {})
    assert.equal(toHex(clear), "0100")
  })

  it("flag five u8 then u16 b5", () => {
    type Row = {
      a?: number
      b?: number
      c?: number
      d?: number
      e?: number
      b5?: number
    }
    const one = scheme<Row>(
      1,
      flags([
        u8(0, (r) => r.a),
        u8(1, (r) => r.b),
        u8(2, (r) => r.c),
        u8(3, (r) => r.d),
        u8(4, (r) => r.e),
        u16(5, (r) => r.b5),
      ]),
    )
    assert.equal(BinaryPacker.pack(one, { a: 1 }).length, 3)
    const wide = BinaryPacker.pack(one, { b5: 1 })
    assert.equal(wide[0], 0x01)
    assert.equal(wide[1], 0x20)
    assert.equal(wide.length - BinaryPacker.pack(one, {}).length, 2)
  })

  it("flag session group login ts", () => {
    type Session = { login: number; ts: number }
    type Row = { session?: Session | null; login?: number; ts?: number }
    const two = scheme<Row>(
      1,
      flags([
        group((r) => r.session, [
          u16(0, (r) => r.login),
          u32(1, (r) => r.ts),
        ]),
      ]),
    )
    const raw = BinaryPacker.pack(two, { login: 7, ts: 1000 })
    assert.equal(toHex(raw.subarray(2)), "0700e8030000")
    const absent = BinaryPacker.pack(two, {})
    assert.equal(toHex(absent), "0100")
    let got: Row | undefined
    const result = BinaryPacker.unpack(absent, two.on((value) => {
      got = value as Row
    }))
    assert.equal(result.ok, true)
    assert.equal("login" in got!, false)
    assert.equal("ts" in got!, false)
  })

  it("flag group u8 zero packs", () => {
    type Row = { g?: unknown; b?: number }
    const zero = scheme<Row>(
      1,
      flags([group((r) => r.g, [u8(0, (r) => r.b)])]),
    )
    const stored = BinaryPacker.pack(zero, { b: 0 })
    assert.equal(toHex(stored), "010100")
  })

  it("flag session group short read", () => {
    type Row = { session?: unknown; login?: number; ts?: number }
    const two = scheme<Row>(
      1,
      flags([
        group((r) => r.session, [
          u16(0, (r) => r.login),
          u32(1, (r) => r.ts),
        ]),
      ]),
    )
    let ran = false
    const short = BinaryPacker.unpack(Uint8Array.of(0x01, 0x01, 0x07), two.on(() => {
      ran = true
    }))
    assert.equal(short.ok, false)
    if (short.ok) return
    assert.equal(short.field, "login")
    assert.equal(short.needed, 2)
    assert.equal(short.left, 1)
    assert.equal(ran, false)
  })

  it("NFR 100000 pack-then-unpack round trips ≤ 1s", () => {
    const start = performance.now()
    for (let i = 0; i < 100_000; i++) {
      const bytes = BinaryPacker.pack(position, positionValue)
      let ok = false
      const got = BinaryPacker.unpack(bytes, position.on(() => {
        ok = true
      }))
      assert.equal(got.ok, true)
      assert.equal(ok, true)
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
    assert.equal(Buffer.from(BinaryPacker.pack(position, new Row())).toString("hex"), expectedHex)
    class Session {
      login = 7
      ts = 1000
    }
    class Holder {
      session: Session | null = new Session()
    }
    const layout = scheme<Holder>(
      1,
      flags([
        group((r) => r.session, [
          u16(0, (s: Session) => s.login),
          u32(1, (s: Session) => s.ts),
        ]),
      ]),
    )
    assert.equal(Buffer.from(BinaryPacker.pack(layout, new Holder())).toString("hex"), "01010700e8030000")
    assert.equal(Buffer.from(BinaryPacker.pack(layout, { session: null })).toString("hex"), "0100")
    let back: { login?: number; ts?: number } | undefined
    const backResult = BinaryPacker.unpack(
      BinaryPacker.pack(layout, new Holder()),
      layout.on((value) => {
        back = value as { login?: number; ts?: number }
      }),
    )
    assert.equal(backResult.ok, true)
    assert.equal(back!.login, 7)
    assert.equal(back!.ts, 1000)
    let clear: { login?: number; ts?: number } | undefined
    const clearResult = BinaryPacker.unpack(
      BinaryPacker.pack(layout, { session: null }),
      layout.on((value) => {
        clear = value as { login?: number; ts?: number }
      }),
    )
    assert.equal(clearResult.ok, true)
    assert.equal("login" in clear!, false)
    assert.equal("ts" in clear!, false)
    let row: Position | undefined
    const rowResult = BinaryPacker.unpack(
      BinaryPacker.pack(position, new Row()),
      position.on((value) => {
        row = value as Position
      }),
    )
    assert.equal(rowResult.ok, true)
    assert.equal(row!.lat, 500_000_000)
    assert.equal(row!.heading, undefined)
  })

  it("type number outside 0..255 throws at construction", () => {
    assert.throws(() => scheme(256, u8(0, (r: { sid: number }) => r.sid)))
    assert.throws(() => scheme(-1, u8(0, (r: { sid: number }) => r.sid)))
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
