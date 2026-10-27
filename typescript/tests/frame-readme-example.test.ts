import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { FrameConfig, FrameDirection, FrameDirections, FrameSession, MacKey, MsgContext, ReplayWindow } from "../src/index.ts"

// AZ-3295 AC-5: the code the README shows for frame mode. The lines between the markers are copied into the README by
// the docs task (scripts/frame/readme-examples.sh compares them); this test keeps them compiling and correct. The
// import line above is the README's `import { ... } from "packbin"`.
describe("frame README example (AZ-3295 AC-5)", () => {
  it("loads, seals, opens with a window and refuses the duplicate, then uses the MAC-only call", () => {
    // README-BEGIN
    // A 32-byte key shared by the nodes, an epoch (0 to 0xFFFFFF) and a tag of 4, 8 or 16 bytes.
    const key = new Uint8Array(32) // use a random key from your key store
    const node = FrameSession.load(key, 1, new FrameConfig(4, FrameDirections.Up | FrameDirections.Down))!

    // msg_id: 8 bytes that are unique per (key, epoch, direction) for every message ever sealed.
    const message = new MsgContext(Uint8Array.of(0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0), 4)
    const header = Uint8Array.of(0, 1, 0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0, 4) // authenticated, not sent

    const body = new Uint8Array(255)
    const sealed = node.seal(FrameDirection.Up, message, header, new Uint8Array(0), new TextEncoder().encode("hello, relay"), body)
    if (!sealed.ok) throw new Error("seal refused") // sealed.kind is "bad_value", "too_long" or "buffer_full"
    const frame = body.subarray(0, sealed.length) // 12 + 4 bytes here

    // The receiver keeps one ReplayWindow per sender and passes a counter that comes from authenticated bytes.
    const window = new ReplayWindow()
    const plain = new Uint8Array(255)
    const opened = node.open(FrameDirection.Up, message, header, frame, 0, plain, window, 7n)
    // opened.ok is true: plain.subarray(0, opened.plainLength) is the text and opened.slot says which key opened it;
    // otherwise opened.kind is "tag_mismatch", "duplicate", "too_old", "too_long", "buffer_full" or "bad_value"
    const again = node.open(FrameDirection.Up, message, header, frame, 0, plain, window, 7n) // { ok: false, kind: "duplicate" }

    // The MAC-only call: a 4-byte network check over a message given in parts.
    const network = MacKey.derive(key, 1, new TextEncoder().encode("net"))!
    const wave = Uint8Array.of(1, 2, 3, 4)
    const made = network.tag([wave, frame], 4)
    if (!made.ok) throw new Error("tag refused")
    const valid = network.verify([wave, frame], made.tag)

    // Close both when done: the derived keys are overwritten (best effort, see the notes below).
    node.close()
    network.close()
    // README-END

    assert.equal(sealed.length, 16)
    assert.ok(opened.ok)
    assert.equal(new TextDecoder().decode(plain.subarray(0, opened.plainLength)), "hello, relay")
    assert.equal(opened.slot, "Current")
    assert.deepEqual(again, { ok: false, kind: "duplicate" })
    assert.equal(valid, true)
  })
})
