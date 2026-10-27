import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { FrameConfig, FrameDirection, FrameSession, MacKey, MsgContext, ReplayWindow } from "../src/index.ts"
import { kindName } from "./support/frame-vectors.ts"

// Review fixes L3, L4 and I3: a direction mask is checked as a number (not as ToInt32), null means no window, a sparse
// message array is refused, and the kind of a context is read once per call.

const KEY = Uint8Array.from({ length: 32 }, (_, i) => i)
const ID = Uint8Array.of(1, 2, 3, 4, 5, 6, 7, 8)
const NONE = new Uint8Array(0)
const load = (directions: number) => FrameSession.load(KEY, 1, new FrameConfig(8, directions))
const all = () => load(7)!

describe("direction mask (L3)", () => {
  it("refuses a mask that is not an integer from 0 to 7, including the values ToInt32 would fold", () => {
    // Act and assert
    for (const mask of [2 ** 32, 2 ** 32 + 3, 8, -1, 1.5, NaN, 2 ** 31, Infinity]) {
      assert.equal(load(mask), null, `mask ${mask}`)
    }
    for (const mask of [0, 1, 2, 3, 4, 7]) assert.notEqual(load(mask), null, `mask ${mask}`)
  })

  it("refuses a direction that is not an integer from 1 to 3 as a bad value, however it folds as a 32-bit number", () => {
    // Arrange
    const session = load(1)!
    const output = new Uint8Array(32)

    // Act and assert
    for (const direction of [2 ** 32 + 1, 0, 4, 1.5, NaN, -1]) {
      assert.equal(kindName(session.seal(direction, new MsgContext(ID, 1), NONE, NONE, NONE, output)), "BadValue", `direction ${direction}`)
    }
    assert.equal(kindName(session.seal(2, new MsgContext(ID, 1), NONE, NONE, NONE, output)), "BadValue")
    assert.equal(session.seal(1, new MsgContext(ID, 1), NONE, NONE, NONE, output).ok, true)
  })
})

describe("window argument of open (L4)", () => {
  const sealed = () => {
    const session = all()
    const body = new Uint8Array(16)
    const result = session.seal(FrameDirection.Up, new MsgContext(ID, 2), NONE, NONE, Uint8Array.of(9, 8), body)
    assert.ok(result.ok)
    return { session, body: body.subarray(0, result.length) }
  }

  it("null and undefined both mean no window", () => {
    // Arrange
    const { session, body } = sealed()

    // Act
    const withNull = session.open(FrameDirection.Up, new MsgContext(ID, 2), NONE, body, 0, new Uint8Array(2), null)
    const withUndefined = session.open(FrameDirection.Up, new MsgContext(ID, 2), NONE, body, 0, new Uint8Array(2), undefined)

    // Assert
    assert.equal(withNull.ok, true)
    assert.equal(withUndefined.ok, true)
  })

  it("an object that is not a ReplayWindow is a bad value, with nothing written and no throw", () => {
    // Arrange
    const { session, body } = sealed()
    const fake = { check: () => "Fresh", commit: () => assert.fail("a fake window must not be committed") }

    // Act and assert
    for (const bad of [fake, {}, 0, "window", 7n, []]) {
      const plain = new Uint8Array(2).fill(0xee)
      const result = session.open(FrameDirection.Up, new MsgContext(ID, 2), NONE, body, 0, plain, bad as unknown as ReplayWindow, 1n)
      assert.equal(kindName(result), "BadValue")
      assert.deepEqual([...plain], [0xee, 0xee])
    }
  })

  it("a real window still decides duplicates", () => {
    // Arrange
    const { session, body } = sealed()
    const window = new ReplayWindow()

    // Act
    const first = session.open(FrameDirection.Up, new MsgContext(ID, 2), NONE, body, 0, new Uint8Array(2), window, 5n)
    const second = session.open(FrameDirection.Up, new MsgContext(ID, 2), NONE, body, 0, new Uint8Array(2), window, 5n)

    // Assert
    assert.equal(first.ok, true)
    assert.equal(kindName(second), "Duplicate")
  })
})

describe("sparse message array of the MAC-only call (L4)", () => {
  it("tag is a bad value and verify is false, with no throw", () => {
    // Arrange
    const mac = MacKey.derive(KEY, 1, Uint8Array.of(1))!
    const sparse = [Uint8Array.of(1), , Uint8Array.of(2)] as unknown as Uint8Array[]
    const goodTag = mac.tag([Uint8Array.of(1), Uint8Array.of(2)], 8)
    assert.ok(goodTag.ok)

    // Act and assert
    assert.equal(kindName(mac.tag(sparse, 8)), "BadValue")
    assert.equal(mac.verify(sparse, goodTag.tag), false)
    assert.equal(kindName(mac.tag(new Array(2) as unknown as Uint8Array[], 8)), "BadValue")
    assert.equal(mac.verify([Uint8Array.of(1), Uint8Array.of(2)], goodTag.tag), true)
  })
})

describe("kind read once per call (I3)", () => {
  // The kind is an own property, so a flip-flop getter is installed on the instance: it answers `first` on the first read
  // and `later` on every read after it.
  function flipping(first: number, later: number): { message: MsgContext; reads: () => number } {
    const message = new MsgContext(ID, 0)
    let reads = 0
    Object.defineProperty(message, "kind", { get: () => (++reads === 1 ? first : later) })
    return { message, reads: () => reads }
  }

  it("seal and open use one value for the check and the nonce, so a flipping getter cannot split them", () => {
    // Arrange
    const session = all()
    const plain = Uint8Array.of(1, 2, 3)
    const reference = new Uint8Array(32)
    const expected = session.seal(FrameDirection.Up, new MsgContext(ID, 1), NONE, NONE, plain, reference)
    assert.ok(expected.ok)
    const sealing = flipping(1, 2)

    // Act
    const output = new Uint8Array(32)
    const sealed = session.seal(FrameDirection.Up, sealing.message, NONE, NONE, plain, output)

    // Assert
    assert.ok(sealed.ok)
    assert.equal(sealing.reads(), 1)
    assert.deepEqual([...output.subarray(0, sealed.length)], [...reference.subarray(0, expected.length)])
    const opening = flipping(1, 2)
    const opened = session.open(FrameDirection.Up, opening.message, NONE, reference.subarray(0, expected.length), 0, new Uint8Array(3))
    assert.equal(opened.ok, true)
    assert.equal(opening.reads(), 1)
  })

  it("a getter that is valid once and out of range after it is sealed under the first value only", () => {
    // Arrange
    const session = all()
    const expected = new Uint8Array(32)
    const reference = session.seal(FrameDirection.Down, new MsgContext(ID, 3), NONE, NONE, NONE, expected)
    assert.ok(reference.ok)
    const late = flipping(3, 99)

    // Act
    const output = new Uint8Array(32)
    const sealed = session.seal(FrameDirection.Down, late.message, NONE, NONE, NONE, output)

    // Assert
    assert.ok(sealed.ok)
    assert.deepEqual([...output.subarray(0, sealed.length)], [...expected.subarray(0, reference.length)])
  })
})
