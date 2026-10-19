import assert from "node:assert/strict"
import { createHash } from "node:crypto"
import { spawnSync } from "node:child_process"
import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import { describe, it } from "node:test"
import { assertWithin, assertWithinMs, bound } from "./support/timing.ts"
import {
  BinaryPacker,
  Scheme,
  dict,
  flags,
  list,
  repeat,
  scheme,
  times,
  u8,
  utf8,
  type DispatchResult,
} from "../src/index.ts"
import { TextCache, decodeText, encodeText } from "../src/text.ts"
import * as tables from "../src/text-tables.ts"
import { random } from "./support/random.ts"
import { fieldOf, hexOf, refPacketHex, rowOf, vectorRows } from "./support/text-vectors.ts"

type Row = Record<string, unknown>

const root = fileURLToPath(new URL("../../", import.meta.url))
const one = scheme<{ s: string }>(1, utf8(0, (r) => r.s))
const withTail = scheme<{ s: string; b: number }>(1, utf8(0, (r) => r.s), u8(1, (r) => r.b))
const bytes = (h: string): Uint8Array => new Uint8Array(Buffer.from(h, "hex"))
const packed = (s: string): string => hexOf(BinaryPacker.pack(one, { s }))

function unpackText(packet: Uint8Array): { result: DispatchResult; called: number; text?: string } {
  let called = 0
  let text: string | undefined
  const result = BinaryPacker.unpack(packet, one.on((r) => {
    called++
    text = r.s
  }))
  return { result, called, text }
}

function refusal(run: () => unknown): string {
  let message = ""
  assert.throws(run, (e: unknown) => {
    assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
    message = e.message
    return true
  })
  return message
}

describe("compact text tables", () => {
  const json = JSON.parse(readFileSync(`${root}fixtures/text/tables.json`, "utf8")) as {
    alphabets: Record<string, string>
    upper: Record<string, string[]>
    shared: string
    numset: string
    modes: Record<string, { lengths: number[] }>
  }
  const points = (s: string): number[] => Array.from(s, (c) => c.codePointAt(0)!)

  it("the constants equal fixtures/text/tables.json", () => {
    // Arrange
    const sha = createHash("sha256").update(readFileSync(`${root}fixtures/text/tables.json`)).digest("hex")

    // Act / Assert
    assert.equal(tables.TABLES_SHA256, sha)
    assert.deepEqual([...tables.UA], points(json.alphabets.ua!))
    assert.deepEqual([...tables.RU], points(json.alphabets.ru!))
    assert.deepEqual([...tables.EN], points(json.alphabets.en!))
    assert.deepEqual([...tables.UA_UPPER], json.upper.ua!.map((u) => (u ? u.codePointAt(0)! : 0)))
    assert.deepEqual([...tables.RU_UPPER], json.upper.ru!.map((u) => (u ? u.codePointAt(0)! : 0)))
    assert.deepEqual([...tables.EN_UPPER], json.upper.en!.map((u) => (u ? u.codePointAt(0)! : 0)))
    assert.deepEqual([...tables.SHARED], points(json.shared))
    assert.deepEqual([...tables.NUMSET], points(json.numset))
    assert.deepEqual([...tables.LENGTHS_UA], json.modes.ua!.lengths)
    assert.deepEqual([...tables.LENGTHS_RU], json.modes.ru!.lengths)
    assert.deepEqual([...tables.LENGTHS_EN], json.modes.en!.lengths)
    assert.deepEqual([...tables.LENGTHS_NUM], json.modes.num!.lengths)
  })

  it("text-tables.ts is exactly the emitter output", () => {
    // Act
    const run = spawnSync(
      "python3",
      [`${root}scripts/text/emit_tables.py`, "typescript", "--check", `${root}typescript/src/text-tables.ts`],
      { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], timeout: 60_000 },
    )

    // Assert
    assert.equal(run.status, 0, `${run.stdout}${run.stderr}`)
  })
})

describe("compact text vectors", () => {
  const enc = vectorRows.filter((r) => r.kind === "enc")
  const alt = vectorRows.filter((r) => r.kind === "alt")
  const bad = vectorRows.filter((r) => r.kind === "bad")

  it("the file has every row kind", () => {
    assert.ok(enc.length >= 300 && alt.length >= 10 && bad.length >= 30)
    assert.equal(vectorRows.filter((r) => r.kind === "ref").length, 4)
    assert.ok(vectorRows.filter((r) => r.kind === "flip").length >= 20)
  })

  it("AC-1 every enc row packs to exactly its bytes", () => {
    // Arrange
    const mismatches: string[] = []

    // Act
    for (const row of enc) {
      if (row.kind !== "enc") continue
      if (packed(row.text) !== `01${hexOf(row.field)}`) mismatches.push(row.id)
    }

    // Assert
    assert.deepEqual(mismatches, [])
  })

  it("AC-2 every enc and alt row unpacks to its text and uses every byte", () => {
    // Arrange
    const mismatches: string[] = []

    // Act
    for (const row of [...enc, ...alt]) {
      if (row.kind !== "enc" && row.kind !== "alt") continue
      const got = unpackText(bytes(`01${hexOf(row.field)}`))
      if (!got.result.ok || got.called !== 1 || got.text !== row.text) mismatches.push(row.id)
    }

    // Assert
    assert.deepEqual(mismatches, [])
  })

  it("AC-4 every bad row is refused naming the field, with the contract's kind and no values", () => {
    // Arrange
    const mismatches: string[] = []

    // Act
    for (const row of bad) {
      if (row.kind !== "bad") continue
      const direct = decodeText(row.buffer, 0)
      const got = unpackText(bytes(`01${hexOf(row.buffer)}`))
      const named = !got.result.ok && "field" in got.result && got.result.field === "s"
      if (direct.ok || direct.kind !== row.refusal || !named || got.called !== 0) mismatches.push(row.id)
    }

    // Assert
    assert.deepEqual(mismatches, [])
  })

  it("AC-4 every flip row: each bit of the payload gives a string or an error, and the byte after is intact", () => {
    // Arrange
    let flipped = 0
    const failures: string[] = []

    // Act
    for (const row of vectorRows) {
      if (row.kind !== "flip") continue
      const field = rowOf("enc", row.target).field
      const header = field[0]! & 0x80 ? (field[1]! & 0x80 ? 3 : 2) : 1
      for (let bit = 0; bit < 8 * (field.length - header); bit++) {
        const damaged = Uint8Array.from([1, ...field, 0x5a])
        damaged[1 + header + (bit >> 3)]! ^= 0x80 >> (bit & 7)
        let tail: number | undefined
        let result: DispatchResult
        try {
          result = BinaryPacker.unpack(damaged, withTail.on((r) => {
            tail = r.b
          }))
        } catch (e) {
          failures.push(`${row.id} bit ${bit} threw ${String(e)}`)
          continue
        }
        flipped++
        if (result.ok ? tail !== 0x5a : !("field" in result) || result.field !== "s") failures.push(`${row.id} bit ${bit}`)
      }
    }

    // Assert
    assert.deepEqual(failures, [])
    assert.ok(flipped > 1000, `${flipped} flipped packets`)
  })
})

describe("compact text in every string position", () => {
  const field = (id: string): string => fieldOf(id)
  const hello = field("enc.hand.hello")
  const world = field("enc.hand.hello_world")
  const empty = field("enc.hand.empty")
  const unpackRow = (layout: Scheme<Row>, packet: string): { ok: boolean; row?: Row } => {
    let row: Row | undefined
    const result = BinaryPacker.unpack(bytes(packet), layout.on((r) => {
      row = r as Row
    }))
    return { ok: result.ok, row }
  }

  it("AC-3 the user and nested ring packets pack and unpack", () => {
    // Arrange
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
    const userRow = {
      username: "zxsanny",
      roles: ["user", "dispatcher"],
      access: { store: ["read", "write"], channel: ["read"], map: ["read", "gps_fix", "set", "edit"] },
    }
    const nestedRow = { access: { store: [{ op: "read" }, { op: "write" }], map: [{ op: "gps_fix" }] } }

    // Act
    const userWire = hexOf(BinaryPacker.pack(user, userRow))
    const nestedWire = hexOf(BinaryPacker.pack(nested, nestedRow))

    // Assert
    assert.equal(userWire, refPacketHex("ref.user"))
    assert.equal(nestedWire, refPacketHex("ref.nested"))
    assert.deepEqual(unpackRow(user, userWire).row, userRow)
    assert.deepEqual(unpackRow(nested, nestedWire).row, nestedRow)
  })

  it("AC-3 the other ring packets round-trip to the same bytes", () => {
    // Arrange
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

    // Act / Assert
    for (const [id, layout] of [["ref.user_ua", user], ["ref.nested_mixed", nested]] as const) {
      const wire = refPacketHex(id)
      const got = unpackRow(layout, wire)
      assert.equal(got.ok, true, id)
      assert.equal(hexOf(BinaryPacker.pack(layout, got.row!)), wire, id)
    }
  })

  it("AC-3 a list element, a dictionary value list, a repeat string and a times string use the codec", () => {
    // Arrange
    const asList = scheme<Row>(1, list((x) => x.xs, utf8(0, (s) => s)))
    const asRepeat = scheme<Row>(1, repeat(0, [utf8(0, (x) => x.n)]))
    const asTimes = scheme<Row>(1, u8(0, (x) => x.c), times(1, 0, [utf8(1, (x) => x.n)]))
    const asDict = scheme<Row>(1, dict((x) => x.m, list((v) => v, utf8(0, (s) => s))))

    // Act
    const listWire = hexOf(BinaryPacker.pack(asList, { xs: ["привіт", "hello, world", ""] }))
    const repeatWire = hexOf(BinaryPacker.pack(asRepeat, { n: ["привіт", ""] }))
    const timesWire = hexOf(BinaryPacker.pack(asTimes, { c: 2, n: ["привіт", ""] }))
    const dictWire = hexOf(BinaryPacker.pack(asDict, { m: { "привіт": ["hello, world"] } }))

    // Assert
    assert.equal(listWire, `01${"0300"}${hello}${world}${empty}`)
    assert.equal(repeatWire, `01${hello}${empty}`)
    assert.equal(timesWire, `0102${hello}${empty}`)
    assert.equal(dictWire, `01${"0100"}${hello}${"0100"}${world}`)
    assert.deepEqual(unpackRow(asList, listWire).row, { xs: ["привіт", "hello, world", ""] })
    assert.deepEqual(unpackRow(asRepeat, repeatWire).row, { n: ["привіт", ""] })
    assert.deepEqual(unpackRow(asTimes, timesWire).row, { c: 2, n: ["привіт", ""] })
    assert.deepEqual(unpackRow(asDict, dictWire).row, { m: { "привіт": ["hello, world"] } })
  })

  it("AC-3 an optional string under flags: absent adds 0 bytes, empty adds 1", () => {
    // Arrange
    const layout = scheme<Row>(1, flags(0, [utf8(0, (x) => x.note), u8(1, (x) => x.x)]))

    // Act
    const present = hexOf(BinaryPacker.pack(layout, { note: "привіт", x: 3 }))
    const absent = hexOf(BinaryPacker.pack(layout, { x: 3 }))
    const blank = hexOf(BinaryPacker.pack(layout, { note: "", x: 3 }))

    // Assert
    assert.equal(present, `0103${hello}03`)
    assert.equal(absent, "010203")
    assert.equal(blank.length - absent.length, 2)
    assert.equal(blank, `0103${empty}03`)
    assert.deepEqual(unpackRow(layout, present).row, { note: "привіт", x: 3 })
    assert.deepEqual(unpackRow(layout, absent).row, { x: 3 })
    assert.deepEqual(unpackRow(layout, blank).row, { note: "", x: 3 })
  })

  it("AC-5 65 535 bytes are accepted, 65 536 are refused naming the field", () => {
    // Arrange
    const longest = "a".repeat(65_535)

    // Act
    const wire = BinaryPacker.pack(one, { s: longest })
    const got = unpackText(wire)
    const over = refusal(() => BinaryPacker.pack(one, { s: "a".repeat(65_536) }))
    const overBytes = refusal(() => BinaryPacker.pack(one, { s: `${"é".repeat(32_768)}` }))

    // Assert
    assert.deepEqual(got.result, { ok: true })
    assert.equal(got.text, longest)
    assert.match(over, /^s: utf-8 length 65536$/)
    assert.match(overBytes, /^s: utf-8 length 65536$/)
  })

  it("AC-5 the text limit holds for the longest raw text too", () => {
    // Arrange
    const text = `${"中".repeat(21_844)}abc`
    assert.equal(Buffer.byteLength(text), 65_535)

    // Act
    const wire = BinaryPacker.pack(one, { s: text })

    // Assert
    assert.equal(wire.length, 1 + 3 + 65_536)
    assert.deepEqual(wire.subarray(0, 5), Uint8Array.of(1, 0x80, 0x80, 0x04, 0x10))
    assert.equal(unpackText(wire).text, text)
  })

  it("AC-5 the count header is 1 byte at a payload of 127 and 2 bytes at 128", () => {
    // Arrange
    const at127 = "中".repeat(42)
    const at128 = `${at127}x`

    // Act
    const small = BinaryPacker.pack(one, { s: at127 })
    const large = BinaryPacker.pack(one, { s: at128 })

    // Assert
    assert.deepEqual(small.subarray(1, 3), Uint8Array.of(127, 0x10))
    assert.equal(small.length, 1 + 1 + 127)
    assert.deepEqual(large.subarray(1, 4), Uint8Array.of(0x80, 0x01, 0x10))
    assert.equal(large.length, 1 + 2 + 128)
    assert.equal(unpackText(small).text, at127)
    assert.equal(unpackText(large).text, at128)
  })

  it("AC-5 maxBytes still bounds the packet: the packet at the limit packs, one byte more is refused", () => {
    // Arrange
    const exact = new Scheme<{ s: string }>(1, [utf8(0, (r) => r.s)], { maxBytes: 7 })

    // Act
    const wire = BinaryPacker.pack(exact, { s: "привіт" })
    const message = refusal(() => BinaryPacker.pack(exact.withLimits({ maxBytes: 6 }), { s: "привіт" }))

    // Assert
    assert.equal(hexOf(wire), `01${hello}`)
    assert.equal(message, "s: the packet would be 7 bytes, above the limit of 6 bytes")
  })

  it("AC-7 dictionary keys inserted in two orders pack to the same bytes, sorted by UTF-8 bytes", () => {
    // Arrange
    const layout = scheme<Row>(1, dict((x) => x.m, u8(0, (x) => x.v)))
    const keys = ["яблуко", "apple", "Zebra", "банан", "", "é", "😀"]
    const forward: Record<string, number> = {}
    const backward: Record<string, number> = {}
    keys.forEach((k, i) => {
      forward[k] = i
    })
    ;[...keys].reverse().forEach((k) => {
      backward[k] = keys.indexOf(k)
    })

    // Act
    const first = BinaryPacker.pack(layout, { m: forward })
    const second = BinaryPacker.pack(layout, { m: backward })
    const back = unpackRow(layout, hexOf(first)).row!.m as Record<string, number>

    // Assert
    assert.equal(hexOf(first), hexOf(second))
    const byUtf8 = [...keys].sort((a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b)))
    assert.deepEqual(Object.keys(back), byUtf8)
    assert.deepEqual(back, forward)
  })

  it("AC-7 a repeated decoded key is refused", () => {
    // Arrange
    const layout = scheme<Row>(1, dict((x) => x.m, u8(0, (x) => x.v)))
    const key = field("enc.hand.hello")

    // Act
    const got = unpackRow(layout, `010200${key}01${key}02`)

    // Assert
    assert.equal(got.ok, false)
    assert.equal(got.row, undefined)
  })

  it("AC-8 100 000 round trips of a 20-character Ukrainian string take at most 2.5 seconds", () => {
    // Arrange
    // 1024 different texts, so the repeated-text shortcut of a lone string under times never answers.
    const texts = Array.from({ length: 1024 }, (_, i) => `Привіт, як справи ${String(i % 100).padStart(2, "0")}`.slice(0, 20))
    assert.ok(texts.every((t) => Array.from(t).length === 20))
    const limit = bound(2.5)
    const started = performance.now()

    // Act
    let wrong = 0
    for (let i = 0; i < 100_000; i++) {
      const text = texts[i % texts.length]!
      if (unpackText(BinaryPacker.pack(one, { s: text })).text !== text) wrong++
    }
    const seconds = (performance.now() - started) / 1000
    console.log(`AC-8 100000 round trips: ${seconds.toFixed(2)} s`)

    // Assert
    assert.equal(wrong, 0)
    assertWithin(seconds, limit, "AC-8 100000 round trips")
  })
})


// AZ-2664 (HD-1, HD-2): the encode state belongs to the pack call.
describe("AZ-2664: the text cache belongs to the pack call", () => {
  const repeated = scheme<{ n: number; s: string }>(1, u8(0, (r) => r.n), times(1, 0, [utf8(1, (r) => r.s)]))

  it("interleaved pack calls with different texts give each its own bytes", () => {
    const first = hexOf(BinaryPacker.pack(repeated, { n: 3, s: "привіт, світе" }))
    const second = hexOf(BinaryPacker.pack(repeated, { n: 3, s: "hello, world" }))

    const againSecond = hexOf(BinaryPacker.pack(repeated, { n: 3, s: "hello, world" }))
    const againFirst = hexOf(BinaryPacker.pack(repeated, { n: 3, s: "привіт, світе" }))

    assert.equal(againFirst, first)
    assert.equal(againSecond, second)
    assert.notEqual(first, second)
  })

  it("a cache is only the one a caller hands in: a call without one leaves it untouched", () => {
    const cache = new TextCache()
    encodeText("привіт", "s")
    assert.equal(cache.text, "")
    encodeText("привіт", "s", cache)
    assert.equal(cache.text, "привіт")
    assert.equal(hexOf(cache.field), hexOf(encodeText("привіт", "s")))
  })

  it("a lone 65,535-character string under 200 rounds packs within a second", () => {
    const limit = bound(1)
    const start = performance.now()
    const packet = BinaryPacker.pack(repeated, { n: 200, s: "q".repeat(65535) })
    const elapsed = performance.now() - start
    assert.ok(packet.length > 200 * 65535)
    assertWithinMs(elapsed, limit, "one 65535-character string under 200 rounds")
  })
})
