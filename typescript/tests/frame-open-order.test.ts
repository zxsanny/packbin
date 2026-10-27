import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { FrameConfig, FrameDirection, FrameDirections, FrameSession, FrameSlot, MsgContext, ReplayWindow } from "../src/index.ts"
import { access } from "../src/frame-access.ts"
import { contextFor, hex, kindName, SENTINEL, sessionFor, worked, type Example } from "./support/frame-vectors.ts"

// AZ-3295 AC-3 (contract "Open, the order is normative"): a forged tag, a duplicate, a counter 64 or more below the top and a
// frame under the previous key give TagMismatch, Duplicate (no MAC computed), TooOld (no MAC computed) and Ok with slot
// Previous; the output buffer and the window are unchanged on every refusal. Then the tamper rows of AZ-3233's list.

const E1 = worked().find((e) => e.name === "E1")!
const macs = (session: FrameSession): number => access.macComputations!(session)
const state = (w: ReplayWindow): string => `${w.top}:${w.bits}`

function open(session: FrameSession, e: Example, body: Uint8Array, window: ReplayWindow, counter: bigint, plain: Uint8Array) {
  return session.open(e.direction, contextFor(e), e.ad, body, e.clearLength, plain, window, counter)
}

describe("open order and state (AZ-3295 AC-3)", () => {
  it("a forged tag is TagMismatch, one MAC is computed, and the buffer and the window stay as they were", () => {
    // Arrange
    const session = sessionFor(E1)
    const window = new ReplayWindow(100n, 1n)
    const plain = new Uint8Array(300).fill(SENTINEL)
    const forged = Uint8Array.from(E1.body)
    forged[forged.length - 1]! ^= 1

    // Act
    const result = open(session, E1, forged, window, 101n, plain)

    // Assert
    assert.deepEqual(result, { ok: false, kind: "tag_mismatch" })
    assert.equal(macs(session), 1)
    assert.ok(plain.every((b) => b === SENTINEL))
    assert.equal(state(window), "100:1")
  })

  it("a duplicate counter is Duplicate with no MAC computed", () => {
    // Arrange
    const session = sessionFor(E1)
    const window = new ReplayWindow()
    const plain = new Uint8Array(300)
    assert.equal(open(session, E1, E1.body, window, 100n, plain).ok, true)
    const before = macs(session)
    const state0 = state(window)
    const sentinel = new Uint8Array(300).fill(SENTINEL)

    // Act
    const result = open(session, E1, E1.body, window, 100n, sentinel)

    // Assert
    assert.deepEqual(result, { ok: false, kind: "duplicate" })
    assert.equal(macs(session), before)
    assert.ok(sentinel.every((b) => b === SENTINEL))
    assert.equal(state(window), state0)
  })

  it("a counter 64 or more below the top is TooOld with no MAC computed", () => {
    // Arrange
    const session = sessionFor(E1)
    const window = new ReplayWindow(100n, 1n)
    const plain = new Uint8Array(300).fill(SENTINEL)

    // Act
    const atTheEdge = open(session, E1, E1.body, window, 36n, plain)
    const wayOld = open(session, E1, E1.body, window, 0n, plain)

    // Assert
    assert.deepEqual(atTheEdge, { ok: false, kind: "too_old" })
    assert.deepEqual(wayOld, { ok: false, kind: "too_old" })
    assert.equal(macs(session), 0)
    assert.ok(plain.every((b) => b === SENTINEL))
    assert.equal(state(window), "100:1")
  })

  it("a frame under the previous key is Ok with slot Previous and commits into the same window", () => {
    // Arrange
    const keyA = new Uint8Array(32).fill(0xaa)
    const keyB = new Uint8Array(32).fill(0xbb)
    const config = new FrameConfig(8, FrameDirections.All)
    const message = new MsgContext(Uint8Array.of(1, 2, 3, 4, 5, 6, 7, 8), 3)
    const ad = Uint8Array.of(9, 9)
    const text = new TextEncoder().encode("hello")
    const sealerA = FrameSession.load(keyA, 6, config)!
    const sealerB = FrameSession.load(keyB, 7, config)!
    const underA = new Uint8Array(40)
    const underB = new Uint8Array(40)
    const lengthA = (sealerA.seal(FrameDirection.Down, message, ad, new Uint8Array(0), text, underA) as { length: number }).length
    const lengthB = (sealerB.seal(FrameDirection.Down, message, ad, new Uint8Array(0), text, underB) as { length: number }).length
    const session = FrameSession.load(keyB, 7, config)!
    assert.equal(session.setPrevious(keyA, 6), true)
    const window = new ReplayWindow()
    const output = new Uint8Array(40)

    // Act
    const a = session.open(FrameDirection.Down, message, ad, underA.subarray(0, lengthA), 0, output, window, 1n)
    const textA = Uint8Array.from(output.subarray(0, a.ok ? a.plainLength : 0))
    const b = session.open(FrameDirection.Down, message, ad, underB.subarray(0, lengthB), 0, output, window, 2n)

    // Assert
    assert.ok(a.ok && a.slot === FrameSlot.Previous)
    assert.deepEqual(textA, text)
    assert.ok(b.ok && b.slot === FrameSlot.Current)
    assert.deepEqual(output.subarray(0, 5), text)
    assert.equal(state(window), "2:3")
  })
})

describe("open order, more (AZ-3295)", () => {
  it("a fresh valid body commits its counter and a fresh tampered body does not", () => {
    // Arrange
    const session = sessionFor(E1)
    const window = new ReplayWindow()
    const plain = new Uint8Array(300)
    assert.equal(open(session, E1, E1.body, window, 100n, plain).ok, true)
    const before = macs(session)
    const tampered = Uint8Array.from(E1.body)
    tampered[0]! ^= 1

    // Act
    const bad = open(session, E1, tampered, window, 101n, plain)
    const afterBad = state(window)
    const good = open(session, E1, E1.body, window, 37n, plain)
    const again = open(session, E1, E1.body, window, 37n, plain)

    // Assert
    assert.equal(kindName(bad), "TagMismatch")
    assert.equal(afterBad, "100:1")
    assert.equal(macs(session), before + 2)
    assert.equal(good.ok, true)
    assert.equal(window.bits, 1n | (1n << 63n))
    assert.equal(kindName(again), "Duplicate")
    assert.equal(macs(session), before + 2)
  })

  it("an open without a window is not replay checked", () => {
    // Arrange
    const session = sessionFor(E1)
    const plain = new Uint8Array(300)
    const args = [E1.direction, contextFor(E1), E1.ad, E1.body, E1.clearLength, plain] as const

    // Act
    const first = session.open(...args)
    const second = session.open(...args)

    // Assert
    assert.equal(first.ok, true)
    assert.equal(second.ok, true)
  })

  it("with no previous slot, or after clearing it, an old frame is TagMismatch and the cleared keys are zero", () => {
    // Arrange
    const keyA = new Uint8Array(32).fill(0xaa)
    const keyB = new Uint8Array(32).fill(0xbb)
    const config = new FrameConfig(4, FrameDirections.Up)
    const message = new MsgContext(new Uint8Array(8), 0)
    const body = new Uint8Array(20)
    const sealed = FrameSession.load(keyA, 6, config)!.seal(1, message, new Uint8Array(0), new Uint8Array(0), Uint8Array.of(1, 2, 3), body)
    const frame = body.subarray(0, (sealed as { length: number }).length)
    const session = FrameSession.load(keyB, 7, config)!
    const output = new Uint8Array(20)

    // Act
    const without = session.open(1, message, new Uint8Array(0), frame, 0, output)
    assert.equal(session.setPrevious(keyA, 6), true)
    const previousKeys = access.keyArrays!(session).slice(2)
    const withPrevious = session.open(1, message, new Uint8Array(0), frame, 0, output)
    session.clearPrevious()
    const cleared = session.open(1, message, new Uint8Array(0), frame, 0, output)

    // Assert
    assert.equal(kindName(without), "TagMismatch")
    assert.ok(withPrevious.ok && withPrevious.slot === FrameSlot.Previous)
    assert.equal(kindName(cleared), "TagMismatch")
    assert.equal(previousKeys.length, 2)
    assert.ok(previousKeys.every((key) => key.every((b) => b === 0)))
  })

  it("seal never uses the previous key, and a refused previous key is false", () => {
    // Arrange
    const keyA = new Uint8Array(32).fill(0xaa)
    const keyB = new Uint8Array(32).fill(0xbb)
    const config = new FrameConfig(4, FrameDirections.Up)
    const message = new MsgContext(new Uint8Array(8), 0)
    const plainSession = FrameSession.load(keyB, 7, config)!
    const withPrevious = FrameSession.load(keyB, 7, config)!
    assert.equal(withPrevious.setPrevious(keyA, 6), true)
    const one = new Uint8Array(20)
    const two = new Uint8Array(20)

    // Act
    plainSession.seal(1, message, new Uint8Array(0), new Uint8Array(0), Uint8Array.of(1), one)
    withPrevious.seal(1, message, new Uint8Array(0), new Uint8Array(0), Uint8Array.of(1), two)

    // Assert
    assert.equal(hex(one), hex(two))
    assert.equal(withPrevious.setPrevious(keyA, 0x1000000), false)
    assert.equal(withPrevious.setPrevious(new Uint8Array(31), 1), false)
  })
})

describe("tamper rows (AZ-3295)", () => {
  for (const e of worked()) {
    const refused = (session: FrameSession, direction: number, message: MsgContext, ad: Uint8Array, body: Uint8Array, clearLength: number, what: string) => {
      const window = new ReplayWindow(50n, 7n)
      const plain = new Uint8Array(300).fill(SENTINEL)
      const result = session.open(direction, message, ad, body, clearLength, plain, window, 51n)
      assert.equal(kindName(result), "TagMismatch", what)
      assert.ok(plain.every((b) => b === SENTINEL), what)
      assert.equal(state(window), "50:7", what)
    }

    it(`${e.name}: the untouched example opens`, () => {
      // Arrange
      const session = sessionFor(e)
      const plain = new Uint8Array(300)

      // Act
      const result = session.open(e.direction, contextFor(e), e.ad, e.body, e.clearLength, plain)

      // Assert
      assert.ok(result.ok)
      assert.equal(hex(plain.subarray(0, result.plainLength)), hex(e.plain))
    })

    it(`${e.name}: every single bit of the body and of the ad gives TagMismatch`, () => {
      // Arrange
      const session = sessionFor(e)

      // Act and assert
      for (let bit = 0; bit < e.body.length * 8; bit++) {
        const body = Uint8Array.from(e.body)
        body[bit >> 3]! ^= 1 << (bit & 7)
        refused(session, e.direction, contextFor(e), e.ad, body, e.clearLength, `${e.name} body bit ${bit}`)
      }
      for (let bit = 0; bit < e.ad.length * 8; bit++) {
        const ad = Uint8Array.from(e.ad)
        ad[bit >> 3]! ^= 1 << (bit & 7)
        refused(session, e.direction, contextFor(e), ad, e.body, e.clearLength, `${e.name} ad bit ${bit}`)
      }
    })

    it(`${e.name}: a changed msg_id, kind, direction, epoch or key gives TagMismatch`, () => {
      // Arrange
      const session = sessionFor(e)
      const key = Uint8Array.from(e.key)
      key[0]! ^= 1

      // Act and assert
      for (let bit = 0; bit < 64; bit++) {
        const id = Uint8Array.from(e.msgId)
        id[bit >> 3]! ^= 1 << (bit & 7)
        refused(session, e.direction, new MsgContext(id, e.kind), e.ad, e.body, e.clearLength, `msg_id bit ${bit}`)
      }
      refused(session, e.direction, new MsgContext(e.msgId, e.kind ^ 1), e.ad, e.body, e.clearLength, "kind")
      for (const other of [1, 2, 3].filter((d) => d !== e.direction)) refused(session, other, contextFor(e), e.ad, e.body, e.clearLength, `direction ${other}`)
      refused(sessionFor(e, undefined, e.epoch + 1), e.direction, contextFor(e), e.ad, e.body, e.clearLength, "epoch")
      refused(sessionFor(e, key), e.direction, contextFor(e), e.ad, e.body, e.clearLength, "key")
    })

    it(`${e.name}: a wrong clear length gives TagMismatch or ShortPacket and writes nothing`, () => {
      // Arrange
      const session = sessionFor(e)

      // Act and assert
      refused(session, e.direction, contextFor(e), e.ad, e.body, e.clearLength + 1, "clear_len up")
      if (e.clearLength > 0) refused(session, e.direction, contextFor(e), e.ad, e.body, e.clearLength - 1, "clear_len down")
    })
  }
})
