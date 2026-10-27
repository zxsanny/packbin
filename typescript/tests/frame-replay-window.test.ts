import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { Freshness, ReplayWindow } from "../src/index.ts"

// AZ-3295: the replay window, 64-bit exact (bigint), against the contract's rules; the 17-step table is also in the vector file.

const MAX = (1n << 64n) - 1n
const state = (w: ReplayWindow): [bigint, bigint] => [w.top, w.bits]

describe("replay window (AZ-3295)", () => {
  it("the window slides and forgets like the contract table", () => {
    // Arrange
    const window = new ReplayWindow()

    // Act
    for (const n of [10n, 12n, 9n, 200n]) window.commit(n)

    // Assert
    assert.deepEqual(state(window), [200n, 1n])
    assert.equal(window.check(136n), Freshness.TooOld)
    assert.equal(window.check(137n), Freshness.Fresh)
    assert.equal(window.check(200n), Freshness.Duplicate)
    assert.equal(window.check(201n), Freshness.Fresh)
  })

  it("a shift of 64 or more empties the old bits and an empty window is fresh for everything", () => {
    // Arrange
    const window = new ReplayWindow(5n, 0n)

    // Act
    const same = window.check(5n)
    const zero = window.check(0n)
    window.commit(MAX - 1n)
    window.commit(MAX)

    // Assert
    assert.equal(same, Freshness.Fresh)
    assert.equal(zero, Freshness.Fresh)
    assert.deepEqual(state(window), [MAX, 3n])
    assert.equal(window.check(MAX - 1n), Freshness.Duplicate)
    assert.equal(window.check(MAX - 64n), Freshness.TooOld)
    assert.equal(window.check(MAX - 63n), Freshness.Fresh)
    window.commit(0n)
    assert.deepEqual(state(window), [MAX, 3n])
  })

  it("bit 63 is kept by a shift of one and lost by a shift of 64, and nothing above 64 bits is kept", () => {
    // Arrange
    const window = new ReplayWindow(100n, 1n << 63n | 1n)

    // Act
    window.commit(101n)
    const kept = window.bits
    window.commit(165n)

    // Assert
    assert.equal(kept, (1n << 63n | 1n) << 1n & MAX | 1n)
    assert.deepEqual(state(window), [165n, 1n])
  })

  it("check never changes the state, and a counter or stored state outside 64 bits is refused", () => {
    // Arrange
    const window = new ReplayWindow(7n, 5n)

    // Act
    window.check(7n)
    window.check(3n)

    // Assert
    assert.deepEqual(state(window), [7n, 5n])
    for (const bad of [-1n, 1n << 64n, 3 as unknown as bigint, "3" as unknown as bigint]) {
      assert.throws(() => window.check(bad), RangeError)
      assert.throws(() => window.commit(bad), RangeError)
      assert.throws(() => new ReplayWindow(bad, 1n), RangeError)
      assert.throws(() => new ReplayWindow(1n, bad), RangeError)
    }
    assert.deepEqual(state(window), [7n, 5n])
  })
})
