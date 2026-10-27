import assert from "node:assert/strict"
import { describe, it } from "node:test"
import * as packbin from "../src/index.ts"

// AZ-3295 AC-4: the public API lists the D1 names of the other packages, and the internal modules stay internal.

const D1 = [
  "FrameSession",
  "FrameConfig",
  "FrameDirection",
  "FrameDirections",
  "FrameSlot",
  "FrameOpened",
  "MsgContext",
  "ReplayWindow",
  "Freshness",
  "MacKey",
]

describe("frame mode public API (AZ-3295 AC-4)", () => {
  it("the package entry exports every D1 name", () => {
    // Act
    const names = Object.keys(packbin)

    // Assert
    assert.deepEqual(D1.filter((name) => !names.includes(name)), [])
  })

  it("the enumerations hold the contract's values", () => {
    // Assert
    assert.deepEqual({ ...packbin.FrameDirection }, { Up: 1, Down: 2, Group: 3 })
    assert.deepEqual({ ...packbin.FrameDirections }, { None: 0, Up: 1, Down: 2, Group: 4, All: 7 })
    assert.deepEqual(Object.keys(packbin.FrameSlot), ["Current", "Previous"])
    assert.deepEqual(Object.keys(packbin.Freshness), ["Fresh", "Duplicate", "TooOld"])
  })

  it("the classes expose the operations of the contract", () => {
    // Assert
    for (const method of ["seal", "open", "setPrevious", "clearPrevious", "close"]) {
      assert.equal(typeof packbin.FrameSession.prototype[method as "seal"], "function", method)
    }
    for (const method of ["check", "commit"]) assert.equal(typeof packbin.ReplayWindow.prototype[method as "check"], "function", method)
    for (const method of ["tag", "verify", "close"]) assert.equal(typeof packbin.MacKey.prototype[method as "tag"], "function", method)
    assert.equal(typeof packbin.FrameSession.load, "function")
    assert.equal(typeof packbin.MacKey.derive, "function")
  })

  it("no crypto name and no test access is exported", () => {
    // Arrange
    const internal = ["access", "tagsEqual", "hmacParts", "wipe", "salt", "msgIdOf", "FrameKeys", "sha256", "hmacSha256", "hkdfSha256", "chacha20Xor", "chacha20Block"]

    // Act
    const names = Object.keys(packbin)

    // Assert
    assert.deepEqual(names.filter((name) => internal.includes(name)), [])
  })
})
