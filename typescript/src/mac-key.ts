import { hkdfSha256 } from "./crypto.ts"
import { access } from "./frame-access.ts"
import { epochOk, hmacParts, isBytes, KEY_SIZE, salt, tagsEqual, wipe } from "./frame-crypto.ts"
import { badValue, type BadValueErr } from "./frame-errors.ts"

/** What `MacKey.tag` reports on success. */
export type MacTag = { ok: true; tag: Uint8Array }

function lengthAllowed(length: number): boolean {
  return length === 4 || length === 8 || length === 16 || length === 32
}

/**
 * The MAC-only call of frame mode: a tag without encryption, for a per-hop network check and for key fingerprints.
 * `K_label = HKDF(key, "packbin-frame" ‖ epoch, 0x00 ‖ label)` and `tag = first n bytes of HMAC(K_label, message)`, with
 * `n` of 4, 8, 16 or 32. The message is one array or an array of parts, hashed piece by piece with no joined copy; the tag
 * does not depend on how it is split.
 *
 * This object holds the 32-byte `K_label` (the HMAC code of `@noble/hashes` keeps its own pad state, which it drops after
 * each call), and `close` overwrites it, best effort: the engine may have copied it (see `FrameSession`). Verification
 * compares every byte with no early exit; the language promises no constant time.
 */
export class MacKey {
  readonly epoch: number
  readonly #key: Uint8Array
  #closed = false

  private constructor(key: Uint8Array, epoch: number) {
    this.#key = key
    this.epoch = epoch
  }

  static {
    access.macKeyBytes = (key) => key.#key
  }

  /** The key of a label. Returns null (the contract's BadValue) for a key that is not 32 bytes, an epoch above 0xFFFFFF or a label that is not 1 to 32 bytes. */
  static derive(key: Uint8Array, epoch: number, label: Uint8Array): MacKey | null {
    if (!isBytes(key) || !isBytes(label) || key.length !== KEY_SIZE || !epochOk(epoch)) return null
    if (label.length < 1 || label.length > 32) return null
    const info = new Uint8Array(1 + label.length)
    info.set(label, 1)
    return new MacKey(hkdfSha256(key, salt(epoch), info, 32), epoch)
  }

  /** The first `length` bytes of the HMAC of the message. A length other than 4, 8, 16 or 32, a message that is not bytes or parts of bytes, or a closed key is a bad value. */
  tag(message: Uint8Array | readonly Uint8Array[], length: number): MacTag | BadValueErr {
    const parts = partsOf(message)
    if (this.#closed || parts === undefined || !lengthAllowed(length)) {
      return badValue("tag length not 4, 8, 16 or 32, message not bytes, or closed key")
    }
    const full = hmacParts(this.#key, parts)
    const tag = full.slice(0, length)
    wipe(full)
    return { ok: true, tag }
  }

  /** True when `tag` (4, 8, 16 or 32 bytes) is the tag of the message. False for any other length, a bad message and a closed key. */
  verify(message: Uint8Array | readonly Uint8Array[], tag: Uint8Array): boolean {
    const parts = partsOf(message)
    if (this.#closed || parts === undefined || !isBytes(tag) || !lengthAllowed(tag.length)) return false
    const full = hmacParts(this.#key, parts)
    const equal = tagsEqual(full.subarray(0, tag.length), tag)
    wipe(full)
    return equal
  }

  /** Overwrites the key (best effort). Every later call is refused. */
  close(): void {
    this.#closed = true
    wipe(this.#key)
  }

  declare [Symbol.dispose]: () => void
}

if (typeof Symbol.dispose === "symbol") {
  Object.defineProperty(MacKey.prototype, Symbol.dispose, {
    value: function (this: MacKey): void {
      this.close()
    },
    configurable: true,
    writable: true,
  })
}

function partsOf(message: Uint8Array | readonly Uint8Array[]): readonly Uint8Array[] | undefined {
  if (isBytes(message)) return [message]
  if (!Array.isArray(message)) return undefined
  for (let i = 0; i < message.length; i++) if (!isBytes(message[i])) return undefined
  return message
}
