import { spawnSync } from "node:child_process"
import { existsSync, readFileSync } from "node:fs"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"
import assert from "node:assert/strict"
import { describe, it } from "node:test"
import {
  BinaryPacker,
  Scheme,
  packet,
  u8,
  u16,
  i16,
  i32,
  flags,
  typeNum,
  pack,
} from "../src/index.ts"

const here = dirname(fileURLToPath(import.meta.url))
const root = join(here, "../..")
const goldenHex = readFileSync(join(root, "fixtures/golden.hex"), "utf8").trim()

class MarkerRow {
  sid = 0
}

const MarkerRowScheme = Scheme.of<MarkerRow>(typeNum(32), u8("sid"))

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

describe("scheme", () => {
  it("AC-1 pack takes the scheme", () => {
    const row = new MarkerRow()
    row.sid = 23
    const bytes = BinaryPacker.pack(MarkerRowScheme, row)
    assert.equal(toHex(bytes), "2017")
    assert.deepEqual(Array.from(bytes), [0x20, 0x17])
  })

  it("AC-2 unpack takes the same scheme", () => {
    const back = BinaryPacker.unpack(
      MarkerRowScheme,
      Uint8Array.from(Buffer.from("2017", "hex")),
    )
    assert.equal(back.ok, true)
    if (!back.ok) return
    assert.equal(back.value.sid, 23)
    assert.equal("type" in back.value, false)
    assert.equal(Object.prototype.hasOwnProperty.call(back.value, "type"), false)
  })

  it("AC-3 scheme argument is required", () => {
    const fixtureDir = join(here, "compile-fail")
    assert.equal(existsSync(join(fixtureDir, "pack-without-scheme.ts")), true)
    assert.equal(existsSync(join(fixtureDir, "tsconfig.json")), true)
    const tscJs = join(here, "../node_modules/typescript/lib/tsc.js")
    assert.equal(existsSync(tscJs), true, "typescript must be installed under typescript/")
    const result = spawnSync(process.execPath, [tscJs, "-p", fixtureDir], {
      encoding: "utf8",
    })
    assert.notEqual(
      result.status,
      0,
      `expected tsc failure, exit=${result.status}\n${result.stdout}\n${result.stderr}`,
    )
  })

  it("AC-4 wrong type byte", () => {
    const back = BinaryPacker.unpack(
      MarkerRowScheme,
      Uint8Array.from(Buffer.from("2117", "hex")),
    )
    assert.equal(back.ok, false)
    if (back.ok) return
    assert.equal("expected" in back, true)
    if (!("expected" in back)) return
    assert.equal(back.expected, 32)
    assert.equal(back.actual, 33)
    assert.equal(
      Object.keys(back).filter(
        (k) => k !== "ok" && k !== "expected" && k !== "actual",
      ).length,
      0,
    )
  })

  it("AC-5 untyped path", () => {
    const bytes = pack(position, positionValue)
    const fixture = Buffer.from(goldenHex, "hex")
    assert.equal(mismatchedBytes(bytes, fixture), 0)
  })

  it("AC-6 row stays data", () => {
    const source = readFileSync(join(here, "scheme.test.ts"), "utf8")
    const start = source.indexOf("class MarkerRow")
    assert.ok(start >= 0)
    const end = source.indexOf("}", start)
    const body = source.slice(start, end)
    assert.ok(body.includes("sid"))
    assert.equal(/scheme/i.test(body), false)
    assert.equal(/Pack/.test(body), false)
    assert.equal(/interface/i.test(body), false)
  })
})
