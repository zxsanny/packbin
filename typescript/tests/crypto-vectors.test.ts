import assert from "node:assert/strict"
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { describe, it } from "node:test"
import { chacha20Block, chacha20Xor, hkdfExtract, hkdfSha256, hmacSha256, sha256 } from "../src/crypto.ts"

// AZ-3288 AC-2: every row of fixtures/crypto/vectors.txt (AZ-3201, PB-02; the row syntax is at the top of the file)
// through the internal crypto module, and copies of the file with one hex digit changed fail on that row only.

const VECTORS = new URL("../../fixtures/crypto/vectors.txt", import.meta.url)
const COUNTS: Record<string, number> = { sha256: 6, hmac256: 8, hkdf256: 3, "chacha-block": 6, "chacha-xor": 4 }

type Row = { primitive: string; id: string; fields: Map<string, string> }

function load(text: string): Row[] {
  const rows: Row[] = []
  for (const line of text.split("\n")) {
    if (line === "" || line.startsWith("#")) continue
    const [primitive, id, ...pairs] = line.split(" ")
    const fields = new Map<string, string>()
    for (const pair of pairs) {
      const at = pair.indexOf("=")
      assert.ok(at > 0, `${primitive} ${id}: "${pair}" is not key=value`)
      fields.set(pair.slice(0, at), pair.slice(at + 1))
    }
    rows.push({ primitive: primitive!, id: id!, fields })
  }
  return rows
}

function field(row: Row, name: string): string {
  const value = row.fields.get(name)
  assert.ok(value !== undefined, `${row.primitive} ${row.id}: no ${name}=`)
  return value
}

// Buffer.from stops at the first character that is not hex, so the digits are checked first.
function data(row: Row, name: string): Uint8Array {
  const value = field(row, name)
  if (value === "-") return new Uint8Array(0)
  assert.match(value, /^(?:[0-9a-f]{2})+$/, `${row.primitive} ${row.id}: ${name} is not lowercase hex`)
  return Uint8Array.from(Buffer.from(value, "hex"))
}

function number(row: Row, name: string): number {
  const value = Number(field(row, name))
  assert.ok(Number.isSafeInteger(value), `${row.primitive} ${row.id}: ${name} is not an integer`)
  return value
}

const hex = (bytes: Uint8Array) => Buffer.from(bytes).toString("hex")

function repeated(bytes: Uint8Array, times: number): Uint8Array {
  const out = new Uint8Array(bytes.length * times)
  for (let i = 0; i < times; i++) out.set(bytes, i * bytes.length)
  return out
}

const RUN: Record<string, (row: Row) => [expected: string, got: string]> = {
  sha256: (row) => {
    const message = row.fields.has("msg") ? data(row, "msg") : repeated(data(row, "byte"), number(row, "repeat"))
    return [field(row, "digest"), hex(sha256(message))]
  },
  hmac256: (row) => {
    const mac = hmacSha256(data(row, "key"), data(row, "data"))
    const keep = row.fields.has("truncate") ? number(row, "truncate") : mac.length
    return [field(row, "mac"), hex(mac.subarray(0, keep))]
  },
  hkdf256: (row) => {
    const [ikm, salt, info, length] = [data(row, "ikm"), data(row, "salt"), data(row, "info"), number(row, "len")]
    const prk = hkdfExtract(salt, ikm)
    const okm = hkdfSha256(ikm, salt, info, length)
    return [`prk=${field(row, "prk")} okm=${field(row, "okm")}`, `prk=${hex(prk)} okm=${hex(okm)}`]
  },
  "chacha-block": (row) => {
    const block = chacha20Block(data(row, "key"), data(row, "nonce"), number(row, "counter"))
    return [field(row, "block"), hex(block)]
  },
  "chacha-xor": (row) => {
    const [key, nonce, counter, plain] = [data(row, "key"), data(row, "nonce"), number(row, "counter"), data(row, "plain")]
    const before = hex(plain)
    const cipher = chacha20Xor(key, nonce, counter, plain)
    const back = chacha20Xor(key, nonce, counter, cipher)
    const notes = (hex(back) === before ? "" : " (decrypt differs)") + (hex(plain) === before ? "" : " (plain was written)")
    return [field(row, "cipher"), hex(cipher) + notes]
  },
}

// `<primitive> <id>: expected X, got Y` when the module's answer differs from the row, else undefined.
function mismatch(row: Row): string | undefined {
  const run = RUN[row.primitive]
  if (run === undefined) return `${row.primitive} ${row.id}: unknown primitive`
  const [expected, got] = run(row)
  return got === expected ? undefined : `${row.primitive} ${row.id}: expected ${expected}, got ${got}`
}

const ROWS = load(readFileSync(VECTORS, "utf8"))

describe("crypto vectors (AZ-3288)", () => {
  it("the file holds 27 rows of the five primitives, each id once per primitive", () => {
    // Arrange
    const counts: Record<string, number> = {}

    // Act
    for (const row of ROWS) counts[row.primitive] = (counts[row.primitive] ?? 0) + 1
    const ids = new Set(ROWS.map((row) => `${row.primitive} ${row.id}`))

    // Assert
    assert.equal(ROWS.length, 27)
    assert.deepEqual(counts, COUNTS)
    assert.equal(ids.size, 27)
  })

  for (const row of ROWS) {
    it(`${row.primitive} ${row.id} matches`, () => {
      // Act
      const problem = mismatch(row)

      // Assert
      assert.equal(problem, undefined)
    })
  }
})

// A copy of the vectors with the last hex digit of `name` changed in the first `primitive` row, and that row's id.
function changedCopy(dir: string, primitive: string, name: string): [path: string, changed: string] {
  const lines = readFileSync(VECTORS, "utf8").split("\n")
  const at = lines.findIndex((line) => line.startsWith(`${primitive} `))
  assert.ok(at >= 0, `no ${primitive} row`)
  const parts = lines[at]!.split(" ")
  const index = parts.findIndex((part) => part.startsWith(`${name}=`))
  assert.ok(index >= 0, `the first ${primitive} row has no ${name}=`)
  const value = parts[index]!
  parts[index] = value.slice(0, -1) + (value.endsWith("0") ? "1" : "0")
  lines[at] = parts.join(" ")
  const path = join(dir, "vectors.txt")
  writeFileSync(path, lines.join("\n"))
  return [path, `${primitive} ${parts[1]}`]
}

describe("crypto vectors with one changed hex digit (AZ-3288)", () => {
  const mutants: [primitive: string, name: string][] = [
    ["sha256", "digest"],
    ["hmac256", "mac"],
    ["hkdf256", "prk"],
    ["hkdf256", "okm"],
    ["chacha-block", "block"],
    ["chacha-xor", "cipher"],
  ]
  for (const [primitive, name] of mutants) {
    it(`a copy with the ${primitive} ${name} changed fails on that row only`, () => {
      // Arrange
      const dir = mkdtempSync(join(tmpdir(), "packbin-crypto-"))
      try {
        const [path, changed] = changedCopy(dir, primitive, name)

        // Act
        const failing = load(readFileSync(path, "utf8"))
          .filter((row) => mismatch(row) !== undefined)
          .map((row) => `${row.primitive} ${row.id}`)

        // Assert
        assert.deepEqual(failing, [changed])
      } finally {
        rmSync(dir, { recursive: true, force: true })
      }
    })
  }
})

describe("crypto refusals (AZ-3288)", () => {
  const key = new Uint8Array(32)
  const nonce = new Uint8Array(12)
  const last = 0xffff_ffff

  const wrong: [name: string, key: Uint8Array, nonce: Uint8Array, counter: number][] = [
    ["key of 31 bytes", new Uint8Array(31), nonce, 0],
    ["key of 33 bytes", new Uint8Array(33), nonce, 0],
    ["nonce of 8 bytes", key, new Uint8Array(8), 0],
    ["nonce of 16 bytes", key, new Uint8Array(16), 0],
    ["counter -1", key, nonce, -1],
    ["counter 2^32", key, nonce, 2 ** 32],
    ["counter 1.5", key, nonce, 1.5],
    ["counter NaN", key, nonce, NaN],
  ]
  for (const [name, k, n, counter] of wrong) {
    it(`a ${name} is refused by the block and the stream`, () => {
      // Act
      const block = () => chacha20Block(k, n, counter)
      const stream = () => chacha20Xor(k, n, counter, new Uint8Array(10))

      // Assert
      assert.throws(block, RangeError)
      assert.throws(stream, RangeError)
    })
  }

  it("a stream that would pass the last block counter is refused", () => {
    // Act
    const oneBlock = chacha20Xor(key, nonce, last, new Uint8Array(64))
    const empty = chacha20Xor(key, nonce, last, new Uint8Array(0))
    const pastTheLast = () => chacha20Xor(key, nonce, last, new Uint8Array(65))
    const twoFromTheLastButOne = chacha20Xor(key, nonce, last - 1, new Uint8Array(128))

    // Assert
    assert.deepEqual(oneBlock, chacha20Block(key, nonce, last))
    assert.equal(empty.length, 0)
    assert.throws(pastTheLast, RangeError)
    assert.deepEqual(twoFromTheLastButOne.subarray(64), chacha20Block(key, nonce, last))
  })

  it("HKDF gives at most 255 blocks and refuses a length that is not a count", () => {
    // Arrange
    const ikm = new Uint8Array(22).fill(0x0b)
    const salt = new Uint8Array(0)
    const info = new Uint8Array(0)

    // Act
    const longest = hkdfSha256(ikm, salt, info, 255 * 32)
    const none = hkdfSha256(ikm, salt, info, 0)

    // Assert
    assert.equal(longest.length, 8160)
    assert.equal(none.length, 0)
    for (const length of [255 * 32 + 1, -1, 1.5, NaN]) {
      assert.throws(() => hkdfSha256(ikm, salt, info, length), RangeError, `length ${length}`)
    }
  })
})

describe("crypto stays internal (AZ-3288 AC-1)", () => {
  it("the package entry exports no stream session (FrameSession is the one session) and no crypto name", async () => {
    // Arrange
    const internal = [
      ...["PackSession", "xorPad", "xorWithNonce"],
      ...["sha256", "hmacSha256", "hkdfExtract", "hkdfSha256", "chacha20Block", "chacha20Xor"],
    ]

    // Act
    const names = Object.keys(await import("../src/index.ts"))

    // Assert
    assert.ok(names.includes("BinaryPacker"), names.join(", "))
    assert.deepEqual(names.filter((name) => internal.includes(name) || (/session/i.test(name) && name !== "FrameSession")), [])
  })
})
