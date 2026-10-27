import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { describe, it } from "node:test"
import { FrameConfig, FrameSession, MsgContext } from "../src/index.ts"
import { access } from "../src/frame-access.ts"
import { tagsEqual } from "../src/frame-crypto.ts"
import { bytes, caseOf, contextOf, hex, kindName, loadFixture, loadSession, SENTINEL } from "./support/frame-vectors.ts"

// AZ-3295: the tag compare over every byte, the wipe on close, the overlap of the caller's buffers.

const KEY = new Uint8Array(32).fill(0x42)
const NONE = new Uint8Array(0)

describe("tag compare (AZ-3295)", () => {
  it("separates equal, first-byte and last-byte differences and a different length", () => {
    // Arrange
    const tag = Uint8Array.of(1, 2, 3, 4, 5, 6, 7, 8)
    const first = Uint8Array.from(tag)
    first[0]! ^= 0x80
    const last = Uint8Array.from(tag)
    last[7]! ^= 1

    // Act and assert
    assert.equal(tagsEqual(tag, Uint8Array.from(tag)), true)
    assert.equal(tagsEqual(tag, first), false)
    assert.equal(tagsEqual(tag, last), false)
    assert.equal(tagsEqual(tag, tag.subarray(0, 7)), false)
    assert.equal(tagsEqual(NONE, NONE), true)
  })

  it("the compare function has no return, break or conditional exit inside its loop", () => {
    // Arrange
    const source = readFileSync(new URL("../src/frame-crypto.ts", import.meta.url), "utf8")
    const start = source.indexOf("export function tagsEqual")
    const body = source.slice(start, source.indexOf("\n}\n", start))
    const loop = body.slice(body.indexOf("for ("))

    // Act and assert
    assert.ok(start >= 0)
    assert.doesNotMatch(loop.slice(0, loop.lastIndexOf("return difference")), /return|break|continue|\bif\b/)
    assert.equal(body.split("return ").length - 1, 2)
  })
})

describe("wipe on close (AZ-3295)", () => {
  it("a closed session has zeroed keys and refuses every call", () => {
    // Arrange
    const session = FrameSession.load(KEY, 9, new FrameConfig(8, 7))!
    assert.equal(session.setPrevious(KEY, 8), true)
    const arrays = access.keyArrays!(session)
    const message = new MsgContext(new Uint8Array(8), 1)
    const body = new Uint8Array(32)
    assert.ok(session.seal(1, message, NONE, NONE, new Uint8Array(4), body).ok)
    assert.equal(arrays.length, 12)
    assert.ok(arrays.some((a) => a.some((b) => b !== 0)))

    // Act
    session.close()
    const output = new Uint8Array(32).fill(SENTINEL)
    const sealed = session.seal(1, message, NONE, NONE, new Uint8Array(4), output)
    const opened = session.open(1, message, NONE, body, 0, output)
    const previous = session.setPrevious(KEY, 1)
    session.close()

    // Assert
    assert.ok(arrays.every((a) => a.every((b) => b === 0)))
    assert.equal(kindName(sealed), "BadValue")
    assert.equal(kindName(opened), "BadValue")
    assert.ok(output.every((b) => b === SENTINEL))
    assert.equal(previous, false)
  })

  it("replacing the previous slot zeroes the old one", () => {
    // Arrange
    const session = FrameSession.load(KEY, 9, new FrameConfig(4, 1))!
    assert.equal(session.setPrevious(KEY, 1), true)
    const old = access.keyArrays!(session).slice(2)

    // Act
    assert.equal(session.setPrevious(KEY, 2), true)

    // Assert
    assert.equal(old.length, 2)
    assert.ok(old.every((a) => a.every((b) => b === 0)))
    assert.ok(access.keyArrays!(session).slice(2).some((a) => a.some((b) => b !== 0)))
  })

  it("the session and the key release through Symbol.dispose where the runtime has it", () => {
    // Arrange
    assert.equal(typeof Symbol.dispose, "symbol")
    const session = FrameSession.load(KEY, 1, new FrameConfig(4, 7))!
    const arrays = access.keyArrays!(session)

    // Act
    ;(session as unknown as Record<symbol, () => void>)[Symbol.dispose]!()

    // Assert
    assert.ok(arrays.every((a) => a.every((b) => b === 0)))
  })

  it("the caller's key is read and not kept or changed", () => {
    // Arrange
    const key = Uint8Array.from(KEY)

    // Act
    const session = FrameSession.load(key, 1, new FrameConfig(4, 7))!
    session.close()

    // Assert
    assert.deepEqual(key, KEY)
  })
})

describe("overlap of the caller's buffers (AZ-3295)", () => {
  const rows = loadFixture()
  const rowOf = (name: string) => rows.find((r) => caseOf(r) === name)!
  const layouts = ["plain in place", "plain at start", "clear and plain in place", "ad inside"] as const

  for (const name of ["E1.seal", "E3.seal"]) {
    for (const layout of layouts) {
      it(`${name}: seal gives the vector body with the layout "${layout}" in the output, and a refusal writes nothing`, () => {
        // Arrange
        const row = rowOf(name)
        const session = loadSession(row)!
        const [ad, clear, plain, body] = ["ad", "clear", "plain", "body"].map((n) => bytes(row, n)) as [Uint8Array, Uint8Array, Uint8Array, Uint8Array]
        const output = new Uint8Array(300).fill(SENTINEL)
        const [adAt, clearAt, plainAt] =
          layout === "plain in place" ? [undefined, undefined, clear.length]
          : layout === "plain at start" ? [undefined, undefined, 0]
          : layout === "clear and plain in place" ? [undefined, 0, clear.length]
          : [3, undefined, undefined]
        const input = (value: Uint8Array, at: number | undefined): Uint8Array => {
          if (at === undefined) return value
          output.set(value, at)
          return output.subarray(at, at + value.length)
        }
        const adInput = input(ad, adAt)
        const clearInput = input(clear, clearAt)
        const plainInput = input(plain, plainAt)
        const before = Uint8Array.from(output)
        const direction = Number(row.get("dir"))

        // Act
        const refused = session.seal(direction, contextOf(row), adInput, clearInput, plainInput, output.subarray(0, body.length - 1))
        const unchanged = hex(output) === hex(before)
        const sealed = session.seal(direction, contextOf(row), adInput, clearInput, plainInput, output)

        // Assert
        assert.equal(kindName(refused), "BufferFull")
        assert.equal(unchanged, true)
        assert.ok(sealed.ok)
        assert.equal(sealed.length, body.length)
        assert.equal(hex(output.subarray(0, sealed.length)), hex(body))
        assert.ok(output.subarray(sealed.length).every((b) => b === SENTINEL))
      })
    }
  }

  for (const name of ["E1.open", "E3.open"]) {
    it(`${name}: open gives the vector plain when plain overlaps the body`, () => {
      // Arrange
      const row = rowOf(name)
      const session = loadSession(row)!
      const clearLength = Number(row.get("clear_len"))
      const body = bytes(row, "body")
      const expected = hex(bytes(row, "plain"))

      // Act and assert
      for (const at of [0, clearLength]) {
        const buffer = new Uint8Array(300)
        buffer.set(body)
        const opened = session.open(Number(row.get("dir")), contextOf(row), bytes(row, "ad"), buffer.subarray(0, body.length), clearLength, buffer.subarray(at))
        assert.ok(opened.ok)
        assert.equal(hex(buffer.subarray(at, at + opened.plainLength)), expected)
      }
    })
  }
})
