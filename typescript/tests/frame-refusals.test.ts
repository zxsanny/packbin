import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { FrameConfig, FrameDirection, FrameDirections, FrameSession, MsgContext, ReplayWindow } from "../src/index.ts"
import { access } from "../src/frame-access.ts"
import { kindName, SENTINEL } from "./support/frame-vectors.ts"
import { random } from "./support/random.ts"

// AZ-3295: the refusals of load, seal and open (contract "Configuration", "Seal", "Open") and a bounded hostile corpus.

const KEY = Uint8Array.from({ length: 32 }, (_, i) => i)
const ID = Uint8Array.of(1, 2, 3, 4, 5, 6, 7, 8)
const NONE = new Uint8Array(0)
const session = (tag = 4, dirs: number = FrameDirections.All) => FrameSession.load(KEY, 5, new FrameConfig(tag, dirs))!
const sentinels = (n: number) => new Uint8Array(n).fill(SENTINEL)
const untouched = (buffer: Uint8Array) => buffer.every((b) => b === SENTINEL)
const ctx = (kind = 1) => new MsgContext(ID, kind)
const seal = (s: FrameSession, d: number, kind: number, ad: number, clear: number, plain: number, output: Uint8Array) =>
  s.seal(d, ctx(kind), new Uint8Array(ad), new Uint8Array(clear), new Uint8Array(plain), output)

describe("load refusals (AZ-3295)", () => {
  it("returns null for what the contract calls BadValue and a session for the edge values", () => {
    // Act and assert
    assert.equal(FrameSession.load(KEY, 0x1000000, new FrameConfig(4, 7)), null)
    assert.notEqual(FrameSession.load(KEY, 0xffffff, new FrameConfig(4, 7)), null)
    for (const tag of [0, 1, 5, 12, 17, 32, -4, 4.5, NaN]) assert.equal(FrameSession.load(KEY, 1, new FrameConfig(tag, 7)), null, `tag ${tag}`)
    for (const epoch of [-1, 1.5, NaN, Infinity]) assert.equal(FrameSession.load(KEY, epoch, new FrameConfig(4, 7)), null, `epoch ${epoch}`)
    assert.equal(FrameSession.load(KEY.subarray(0, 31), 1, new FrameConfig(4, 7)), null)
    assert.equal(FrameSession.load(new Uint8Array(33), 1, new FrameConfig(4, 7)), null)
    assert.equal(FrameSession.load(KEY, 1, new FrameConfig(4, 8)), null)
    assert.equal(FrameSession.load(KEY, 1, new FrameConfig(4, 7 | 8)), null)
    assert.equal(FrameSession.load(KEY, 1, new FrameConfig(4, -1)), null)
    assert.equal(FrameSession.load(KEY, 1, new FrameConfig(4, 1.5)), null)
    assert.equal(FrameSession.load(KEY, 1, null as unknown as FrameConfig), null)
    assert.equal(FrameSession.load([...KEY] as unknown as Uint8Array, 1, new FrameConfig(4, 7)), null)
  })

  for (const tag of [4, 8, 16]) {
    it(`a session with no direction (tag ${tag}) refuses every seal and open, and a bad key, epoch or tag still fails to load`, () => {
      // Arrange
      const none = FrameSession.load(KEY, 0, new FrameConfig(tag, FrameDirections.None))!
      const all = FrameSession.load(KEY, 0, new FrameConfig(tag, FrameDirections.All))!

      // Act and assert
      assert.notEqual(none, null)
      for (const direction of [1, 2, 3]) {
        const body = new Uint8Array(32)
        const sealed = all.seal(direction, ctx(), NONE, NONE, new Uint8Array(4), body)
        assert.ok(sealed.ok)
        const output = sentinels(64)
        const plain = sentinels(64)
        const window = new ReplayWindow(5n, 1n)
        assert.equal(kindName(none.seal(direction, ctx(), NONE, NONE, new Uint8Array(4), output)), "BadValue")
        assert.equal(kindName(none.open(direction, ctx(), NONE, body.subarray(0, sealed.length), 0, plain, window, 6n)), "BadValue")
        assert.ok(untouched(output) && untouched(plain))
        assert.equal(`${window.top}:${window.bits}`, "5:1")
      }
      const noDirections = new FrameConfig(4, FrameDirections.None)
      assert.equal(FrameSession.load(KEY.subarray(0, 31), 0, noDirections), null)
      assert.equal(FrameSession.load(KEY, 0x1000000, noDirections), null)
      assert.equal(FrameSession.load(KEY, 0, new FrameConfig(5, FrameDirections.None)), null)
      assert.equal(FrameSession.load(KEY, 0, new FrameConfig(4, 8)), null)
    })
  }
})

describe("seal and open refusals (AZ-3295)", () => {
  for (const direction of [0, 4, 255, 1.5, NaN, -1]) {
    it(`direction ${direction} is BadValue for seal and open and writes nothing`, () => {
      // Arrange
      const s = session()
      const output = sentinels(64)

      // Act
      const sealed = seal(s, direction, 1, 0, 0, 4, output)
      const opened = s.open(direction, ctx(), NONE, new Uint8Array(16), 0, output)

      // Assert
      assert.equal(kindName(sealed), "BadValue")
      assert.equal(kindName(opened), "BadValue")
      assert.ok(untouched(output))
    })
  }

  it("a direction not loaded, a kind outside 0 to 15, no msg_id and a non-integer clear length are BadValue", () => {
    // Arrange
    const s = session(4, FrameDirections.Up)
    const output = sentinels(64)
    const wrongId = new MsgContext(new Uint8Array(7), 1)

    // Act
    const results = [
      seal(s, FrameDirection.Down, 1, 0, 0, 4, output),
      seal(s, FrameDirection.Up, 16, 0, 0, 4, output),
      seal(s, FrameDirection.Up, -1, 0, 0, 4, output),
      seal(s, FrameDirection.Up, 1.5, 0, 0, 4, output),
      s.seal(FrameDirection.Up, wrongId, NONE, NONE, new Uint8Array(4), output),
      s.seal(FrameDirection.Up, {} as unknown as MsgContext, NONE, NONE, new Uint8Array(4), output),
      s.seal(FrameDirection.Up, undefined, NONE, NONE, new Uint8Array(4), output),
      s.seal(FrameDirection.Up, ctx(), [] as unknown as Uint8Array, NONE, NONE, output),
      s.open(FrameDirection.Up, ctx(16), NONE, new Uint8Array(16), 0, output),
      s.open(FrameDirection.Group, ctx(), NONE, new Uint8Array(16), 0, output),
      s.open(FrameDirection.Up, ctx(), NONE, new Uint8Array(16), -1, output),
      s.open(FrameDirection.Up, ctx(), NONE, new Uint8Array(16), 0.5, output),
      s.open(FrameDirection.Up, ctx(), NONE, new Uint8Array(16), 0, output, new ReplayWindow(), -1n),
      s.open(FrameDirection.Up, ctx(), NONE, new Uint8Array(16), 0, output, new ReplayWindow(), 1n << 64n),
      s.open(FrameDirection.Up, ctx(), NONE, new Uint8Array(16), 0, output, new ReplayWindow(), 7 as unknown as bigint),
    ]

    // Assert
    assert.deepEqual(results.map(kindName), results.map(() => "BadValue"))
    assert.ok(untouched(output))
  })

  it("a too long ad, body or clear length is TooLong before any hashing, with limit 255", () => {
    // Arrange
    const s = session()
    const output = sentinels(600)

    // Act
    const sealAd = seal(s, 1, 1, 256, 0, 4, output)
    const sealBody = seal(s, 1, 1, 0, 100, 152, output)
    const sealHuge = seal(s, 1, 1, 0, 0, 300, output)
    const openAd = s.open(1, ctx(), new Uint8Array(256), new Uint8Array(20), 0, output)
    const openBody = s.open(1, ctx(), NONE, new Uint8Array(256), 0, output)
    const openClear = s.open(1, ctx(), NONE, new Uint8Array(20), 256, output)

    // Assert
    for (const result of [sealAd, sealBody, sealHuge, openAd, openBody, openClear]) assert.equal(kindName(result), "TooLong")
    assert.deepEqual(sealBody, { ok: false, kind: "too_long", length: 256, limit: 255 })
    assert.equal(access.macComputations!(s), 0)
    assert.ok(untouched(output))
  })

  it("the longest body of 255 bytes seals and opens", () => {
    // Arrange
    const s = session()
    const output = new Uint8Array(255)
    const plain = new Uint8Array(300)

    // Act
    const sealed = seal(s, 1, 15, 255, 10, 241, output)
    const opened = s.open(1, ctx(15), new Uint8Array(255), output, 10, plain)

    // Assert
    assert.deepEqual(sealed, { ok: true, length: 255 })
    assert.ok(opened.ok && opened.plainLength === 241)
  })

  it("a short output is BufferFull and seal writes nothing; a short plain buffer is BufferFull and open writes nothing", () => {
    // Arrange
    const s = session()
    const output = sentinels(15)
    const body = new Uint8Array(16)
    const plain = sentinels(11)

    // Act
    const sealed = seal(s, 1, 1, 0, 0, 12, output)
    assert.ok(seal(s, 1, 1, 0, 0, 12, body).ok)
    const opened = s.open(1, ctx(), NONE, body, 0, plain)

    // Assert
    assert.deepEqual(sealed, { ok: false, kind: "buffer_full", needed: 16 })
    assert.ok(untouched(output))
    assert.deepEqual(opened, { ok: false, kind: "buffer_full", needed: 12 })
    assert.ok(untouched(plain))
  })

  it("a body shorter than clear plus tag is ShortPacket", () => {
    // Arrange
    const s = session(8)
    const output = sentinels(32)

    // Act
    const noTag = s.open(1, ctx(), NONE, new Uint8Array(7), 0, output)
    const shortClear = s.open(1, ctx(), NONE, new Uint8Array(10), 3, output)
    const empty = s.open(1, ctx(), NONE, NONE, 0, output)

    // Assert
    assert.deepEqual(noTag, { ok: false, field: "body", needed: 8, left: 7 })
    assert.equal((shortClear as { needed: number }).needed, 11)
    assert.equal(kindName(empty), "ShortPacket")
    assert.ok(untouched(output))
  })

  it("a duplicate and a too old counter are their own kinds and an unmatched tag is TagMismatch", () => {
    // Arrange
    const s = session()
    const window = new ReplayWindow(100n, 1n)
    const output = sentinels(32)
    const body = new Uint8Array(8)

    // Act
    const duplicate = s.open(1, ctx(), NONE, body, 0, output, window, 100n)
    const old = s.open(1, ctx(), NONE, body, 0, output, window, 30n)
    const mismatch = s.open(1, ctx(), NONE, body, 0, output, window, 101n)

    // Assert
    assert.deepEqual([duplicate, old, mismatch].map(kindName), ["Duplicate", "TooOld", "TagMismatch"])
    assert.equal(`${window.top}:${window.bits}`, "100:1")
    assert.ok(untouched(output))
  })

  it("a session of one tag length opens nothing of another", () => {
    // Arrange
    const four = session(4)
    const eight = session(8)
    const body = new Uint8Array(32)
    const sealed = seal(four, 1, 1, 0, 0, 10, body)

    // Act
    const opened = eight.open(1, ctx(), NONE, body.subarray(0, (sealed as { length: number }).length), 0, new Uint8Array(32))

    // Assert
    assert.equal(kindName(opened), "TagMismatch")
  })

  it("a message built from an id of the wrong size, or from a mutated id array, cannot move the id", () => {
    // Arrange
    const s = session()
    const id = Uint8Array.from(ID)
    const message = new MsgContext(id, 1)
    const one = new Uint8Array(32)
    const two = new Uint8Array(32)

    // Act
    seal(s, 1, 1, 0, 0, 4, one)
    id[0]! ^= 0xff
    const result = s.seal(1, message, NONE, NONE, new Uint8Array(4), two)

    // Assert
    assert.ok(result.ok)
    assert.deepEqual(one, two)
  })
})

describe("hostile and random inputs (AZ-3295)", () => {
  it("a random hostile corpus of 1000 opens gives only refusals, touches no buffer and no window", () => {
    // Arrange
    const next = random(0x3295_0001)
    const int = (low: number, high: number) => low + Math.floor(next() * (high - low))
    const fill = (n: number) => Uint8Array.from({ length: n }, () => int(0, 256))
    const s = session(8)
    assert.equal(s.setPrevious(KEY, 4), true)
    const kinds = new Map<string, number>()
    const window = new ReplayWindow()

    // Act and assert
    for (let i = 0; i < 1000; i++) {
      const body = fill(int(0, 301))
      const ad = fill(int(0, 300))
      const message = new MsgContext(fill(8), int(-2, 20))
      const direction = int(0, 6)
      const clearLength = int(-3, 300)
      const plain = sentinels(int(0, 300))
      const before = `${window.top}:${window.bits}`
      const opened = s.open(direction, message, ad, body, clearLength, plain, i % 2 === 0 ? window : undefined, BigInt(int(0, 200)))
      const name = kindName(opened)
      kinds.set(name, (kinds.get(name) ?? 0) + 1)
      assert.equal(opened.ok, false)
      assert.ok(untouched(plain))
      assert.equal(`${window.top}:${window.bits}`, before)
      const output = sentinels(int(0, 300))
      const sealed = s.seal(direction, message, ad, body.subarray(0, int(0, body.length + 1)), body, output)
      if (!sealed.ok) assert.ok(untouched(output))
    }
    assert.ok(kinds.size >= 4, [...kinds.keys()].join(","))
    assert.equal(kinds.get("Ok") ?? 0, 0)
  })

  it("a random round trip of valid inputs always opens with the same bytes", () => {
    // Arrange
    const next = random(0x3295_0002)
    const int = (low: number, high: number) => low + Math.floor(next() * (high - low))
    const fill = (n: number) => Uint8Array.from({ length: n }, () => int(0, 256))

    // Act and assert
    for (const tag of [4, 8, 16]) {
      const s = session(tag)
      for (let i = 0; i < 100; i++) {
        const clear = fill(int(0, 4))
        const plain = fill(int(0, 255 - tag - clear.length + 1))
        const ad = fill(int(0, 256))
        const message = new MsgContext(fill(8), int(0, 16))
        const direction = int(1, 4)
        const body = new Uint8Array(255)
        const text = new Uint8Array(255)
        const sealed = s.seal(direction, message, ad, clear, plain, body)
        assert.ok(sealed.ok)
        const opened = s.open(direction, message, ad, body.subarray(0, sealed.length), clear.length, text)
        assert.ok(opened.ok)
        assert.equal(sealed.length, clear.length + plain.length + tag)
        assert.deepEqual(body.subarray(0, clear.length), clear)
        assert.deepEqual(text.subarray(0, opened.plainLength), plain)
      }
    }
  })
})
