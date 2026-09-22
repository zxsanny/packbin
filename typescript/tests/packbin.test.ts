import { readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  packet,
  u8,
  u16,
  i16,
  i32,
  flags,
  when,
  eq,
  repeat,
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

  it("NFR 100000 pack-then-unpack round trips ≤ 1s", () => {
    const start = performance.now()
    for (let i = 0; i < 100_000; i++) {
      const bytes = pack(position, positionValue)
      const got = unpack(position, bytes)
      assert.equal(got.ok, true)
    }
    const elapsed = performance.now() - start
    assert.ok(elapsed <= 1000, `elapsed ${elapsed}ms`)
  })
})
