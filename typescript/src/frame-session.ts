import { chacha20Xor } from "./crypto.ts"
import { access } from "./frame-access.ts"
import { epochOk, hmacParts, isBytes, KEY_SIZE, tagsEqual, wipe } from "./frame-crypto.ts"
import {
  badValue,
  bufferFull,
  duplicate,
  MAX_BODY,
  tagMismatch,
  tooLong,
  tooOld,
  type FrameErr,
} from "./frame-errors.ts"
import { FrameKeys } from "./frame-keys.ts"
import { FrameConfig, FrameOpened, FrameSlot, Freshness, MsgContext, msgIdOf, type FrameSealed } from "./frame-types.ts"
import { isCounter, ReplayWindow } from "./replay-window.ts"

const ALL_DIRECTIONS = 7
const FIRST_BLOCK = 0

/**
 * Frame mode of the session (`pack-session.md` 3.0.0): sealed, authenticated frames for links that lose, reorder and
 * duplicate messages. A frame body is `clear ‖ ciphertext ‖ tag`: ChaCha20 under a key per (key, epoch, direction), a
 * nonce built from the caller's `msg_id`, the `kind`, the direction and the epoch, and a tag that is the first 4, 8 or 16
 * bytes of HMAC-SHA256 over the nonce, the associated data, the clear part and the ciphertext. It is the only session of
 * the package (ADR-009).
 *
 * `seal` is deterministic and never changes the session. `open` reads the previous slot, which `setPrevious` and
 * `clearPrevious` replace, and `close` overwrites the keys. Every call runs to completion on the calling thread and
 * calls no code of the caller, and an object is not shared between workers, so there is no interleaving of one session's
 * calls to guard against: a call after `close` is refused as a bad value.
 *
 * Limits of a JavaScript runtime (the wipe and the compare are best effort): the key arrays this object owns are
 * overwritten by `close` (there is no finalizer, so an unclosed session is wiped by nothing), but the engine's garbage
 * collector may have moved a typed array's bytes before the wipe, the HMAC and HKDF code of `@noble/hashes` keeps its
 * own copies of the key blocks that it releases by dropping them, the caller's key is not touched, and the JIT may be
 * allowed to drop a store it can prove unused (V8 does not do so for `fill` on a typed array, but the language does not
 * promise it). The tag compare folds every byte with no early exit and no secret-dependent branch, and the language
 * promises no constant time.
 */
export class FrameSession {
  static readonly KeySize = KEY_SIZE
  static readonly MaxBody = MAX_BODY

  readonly tagLength: number
  readonly #directions: number
  readonly #current: FrameKeys
  #previous: FrameKeys | undefined
  #closed = false
  #macComputations = 0

  private constructor(tagLength: number, directions: number, current: FrameKeys) {
    this.tagLength = tagLength
    this.#directions = directions
    this.#current = current
  }

  static {
    access.currentKeys = (session) => session.#current
    access.keyArrays = (session) => [...session.#current.arrays(), ...(session.#previous?.arrays() ?? [])]
    access.macComputations = (session) => session.#macComputations
  }

  get epoch(): number {
    return this.#current.epoch
  }

  /**
   * Derives the keys of each loaded direction from a 32-byte key and an epoch of at most 0xFFFFFF. Returns null (the
   * contract's BadValue) for a key that is not 32 bytes, an epoch above 0xFFFFFF or not an integer, a tag length that is
   * not 4, 8 or 16, or a direction bit outside `FrameDirections.All`. With `FrameDirections.None` it returns a session
   * that refuses every seal and open as a bad value. The key is read, not kept.
   */
  static load(key: Uint8Array, epoch: number, config: FrameConfig): FrameSession | null {
    if (typeof config !== "object" || config === null) return null
    const { tagLength, directions } = config
    if (!isBytes(key) || key.length !== KEY_SIZE || !epochOk(epoch)) return null
    if (tagLength !== 4 && tagLength !== 8 && tagLength !== 16) return null
    if (!Number.isInteger(directions) || directions < 0 || directions > ALL_DIRECTIONS) return null
    return new FrameSession(tagLength, directions, FrameKeys.derive(key, epoch, directions))
  }

  /**
   * Keeps a previous (key, epoch) that `open` tries when the current key's tag does not match: the key just replaced,
   * for frames sealed before the change. Seal never uses it. False (the contract's BadValue) for a key that is not 32
   * bytes, an epoch above 0xFFFFFF or a closed session. A frame that opens under it commits into the same replay window,
   * so keep it only for the changeover and call `clearPrevious` when that ends.
   */
  setPrevious(key: Uint8Array, epoch: number): boolean {
    if (this.#closed || !isBytes(key) || key.length !== KEY_SIZE || !epochOk(epoch)) return false
    const replaced = this.#previous
    this.#previous = FrameKeys.derive(key, epoch, this.#directions)
    replaced?.wipe()
    return true
  }

  /** Drops the previous (key, epoch) and overwrites its keys. */
  clearPrevious(): void {
    const replaced = this.#previous
    this.#previous = undefined
    replaced?.wipe()
  }

  /**
   * Seals `clear ‖ plain` into `output` as `clear ‖ ciphertext ‖ tag` and gives the body length. The same inputs give the
   * same bytes; the session does not change and the previous key is not used. A direction not loaded, a `kind` that is
   * not an integer from 0 to 15, a message that is not a `MsgContext` of an 8-byte id, an argument that is not a
   * `Uint8Array` or a closed session is a bad value; `ad` above 255 bytes, or `clear + plain + tag` above 255, is too
   * long; an `output` shorter than the body is buffer full. On any refusal nothing is written. The body is built apart and
   * copied to `output` last, so `ad`, `clear` and `plain` may be views of it (sealing in place gives the same bytes).
   *
   * **For one (key, epoch, direction), never seal two different messages with the same `msg_id`.** Reuse breaks the
   * confidentiality of both messages, and the library cannot check it (see `MsgContext`). A new epoch derives new keys
   * and nonces.
   */
  seal(
    direction: number,
    message: unknown,
    ad: Uint8Array,
    clear: Uint8Array,
    plain: Uint8Array,
    output: Uint8Array,
  ): FrameSealed | FrameErr {
    const kind = kindOf(message)
    const id = this.#callId(direction, message, kind)
    if (id === undefined || !isBytes(ad) || !isBytes(clear) || !isBytes(plain) || !isBytes(output)) {
      return badValue("direction not loaded, kind not 0 to 15, no msg_id, a non-byte argument or closed session")
    }
    if (ad.length > MAX_BODY) return tooLong(ad.length)
    const length = clear.length + plain.length + this.tagLength
    if (length > MAX_BODY) return tooLong(length)
    if (output.length < length) return bufferFull(length)

    const keys = this.#current
    const nonce = makeNonce(id, kind as number, direction, keys.epoch)
    const body = new Uint8Array(length)
    body.set(clear)
    const cipher = chacha20Xor(keys.enc(direction), nonce, FIRST_BLOCK, plain)
    body.set(cipher, clear.length)
    const full = this.#tag(keys.mac(direction), nonce, ad, clear, cipher)
    body.set(full.subarray(0, this.tagLength), clear.length + plain.length)
    wipe(full)
    output.set(body)
    return { ok: true, length }
  }

  /**
   * Opens `body` (`clear ‖ ciphertext ‖ tag`, the first `clearLength` bytes clear) in the contract's order: argument
   * checks, the replay window (when given, with the message's counter: duplicate or too old before any hashing), the tag
   * with the current key and then once with the previous key (tag mismatch), decryption into `plain`, and only then the
   * window commit. `plain` and the window are untouched unless the result is a `FrameOpened`.
   *
   * A direction not loaded, a `kind` that is not an integer from 0 to 15, a `clearLength` that is not a non-negative
   * integer, a counter that is not a bigint from 0 to 2^64 - 1 (when a window is given), an argument that is not a
   * `Uint8Array` or a closed session is a bad value; `ad`, `body` or `clearLength` above 255 is too long (before any
   * hashing); a body shorter than `clearLength + tag` is a short packet; a `plain` shorter than the plaintext is buffer
   * full. The frame and `ad` are copied once before hashing, so the tag is checked and the text decrypted from the same
   * bytes even when `body` is a receive buffer that changes later, and `plain` may overlap `body`.
   *
   * The counter must come from bytes the tag covers, never from an unauthenticated wire field: it is not part of the tag.
   */
  open(
    direction: number,
    message: unknown,
    ad: Uint8Array,
    body: Uint8Array,
    clearLength: number,
    plain: Uint8Array,
    window?: ReplayWindow | null,
    counter: bigint = 0n,
  ): FrameOpened | FrameErr {
    const kind = kindOf(message)
    const id = this.#callId(direction, message, kind)
    const noWindow = window === undefined || window === null
    const counterOk = noWindow || (window instanceof ReplayWindow && isCounter(counter))
    if (
      id === undefined ||
      !isBytes(ad) ||
      !isBytes(body) ||
      !isBytes(plain) ||
      !Number.isInteger(clearLength) ||
      clearLength < 0 ||
      !counterOk
    ) {
      return badValue("direction not loaded, kind not 0 to 15, no msg_id, bad clear length or counter, a non-byte argument or closed session")
    }
    if (ad.length > MAX_BODY) return tooLong(ad.length)
    if (body.length > MAX_BODY) return tooLong(body.length)
    if (clearLength > MAX_BODY) return tooLong(clearLength)
    const framing = clearLength + this.tagLength
    if (body.length < framing) return { ok: false, field: "body", needed: framing, left: body.length }
    const plainLength = body.length - framing
    if (plain.length < plainLength) return bufferFull(plainLength)

    if (!noWindow) {
      const freshness = window.check(counter)
      if (freshness === Freshness.Duplicate) return duplicate()
      if (freshness === Freshness.TooOld) return tooOld()
    }

    const frame = Uint8Array.from(body)
    const adCopy = Uint8Array.from(ad)
    const clear = frame.subarray(0, clearLength)
    const cipher = frame.subarray(clearLength, clearLength + plainLength)
    const tag = frame.subarray(clearLength + plainLength)
    let keys = this.#current
    let slot: FrameSlot = FrameSlot.Current
    if (!this.#matches(keys, direction, id, kind as number, adCopy, clear, cipher, tag)) {
      const previous = this.#previous
      if (previous === undefined || !this.#matches(previous, direction, id, kind as number, adCopy, clear, cipher, tag)) {
        return tagMismatch()
      }
      keys = previous
      slot = FrameSlot.Previous
    }

    const text = chacha20Xor(keys.enc(direction), makeNonce(id, kind as number, direction, keys.epoch), FIRST_BLOCK, cipher)
    plain.set(text)
    wipe(text)
    if (!noWindow) window.commit(counter)
    return new FrameOpened(slot, clearLength, plainLength)
  }

  /** Overwrites the keys of both slots (best effort, see the type's doc comment). Every later call is refused as a bad value. Calling it again does nothing more. */
  close(): void {
    this.#closed = true
    this.#current.wipe()
    this.#previous?.wipe()
  }

  // The message's id when the call is allowed (session open, direction loaded, a valid context with a kind of 0 to 15).
  // `kind` is the value the caller read once with `kindOf`, so validation and the nonce use the same one.
  #callId(direction: number, message: unknown, kind: unknown): Uint8Array | undefined {
    if (this.#closed) return undefined
    if (!Number.isInteger(direction) || direction < 1 || direction > 3) return undefined
    if ((this.#directions & (1 << (direction - 1))) === 0) return undefined
    const id = msgIdOf(message)
    if (id === undefined) return undefined
    return typeof kind === "number" && Number.isInteger(kind) && kind >= 0 && kind <= 15 ? id : undefined
  }

  // The full HMAC over M = N ‖ len(ad) ‖ ad ‖ len(clear) ‖ clear ‖ ciphertext, hashed piece by piece with no joined copy.
  #tag(macKey: Uint8Array, nonce: Uint8Array, ad: Uint8Array, clear: Uint8Array, cipher: Uint8Array): Uint8Array {
    this.#macComputations++
    return hmacParts(macKey, [nonce, Uint8Array.of(ad.length), ad, Uint8Array.of(clear.length), clear, cipher])
  }

  #matches(
    keys: FrameKeys,
    direction: number,
    id: Uint8Array,
    kind: number,
    ad: Uint8Array,
    clear: Uint8Array,
    cipher: Uint8Array,
    tag: Uint8Array,
  ): boolean {
    const full = this.#tag(keys.mac(direction), makeNonce(id, kind, direction, keys.epoch), ad, clear, cipher)
    const equal = tagsEqual(full.subarray(0, tag.length), tag)
    wipe(full)
    return equal
  }
}

// Symbol.dispose where the runtime has it (Node 20 and later). It is not in the declared type: a consumer whose `lib` is
// ES2022 would fail to type-check a `[Symbol.dispose]` member in the emitted declarations (AZ-2103 AC-2).
const disposeSymbol = (Symbol as unknown as { dispose?: symbol }).dispose
if (typeof disposeSymbol === "symbol") {
  Object.defineProperty(FrameSession.prototype, disposeSymbol, {
    value: function (this: FrameSession): void {
      this.close()
    },
    configurable: true,
    writable: true,
  })
}

// The kind of a context, read once per call (a subclass may define it as a getter that answers differently each time).
function kindOf(message: unknown): unknown {
  return message instanceof MsgContext ? message.kind : undefined
}

// msg_id (8) ‖ ((kind << 4) | direction) (1) ‖ epoch as 24 bits (3).
function makeNonce(id: Uint8Array, kind: number, direction: number, epoch: number): Uint8Array {
  const nonce = new Uint8Array(12)
  nonce.set(id)
  nonce[8] = (kind << 4) | direction
  nonce[9] = epoch & 0xff
  nonce[10] = (epoch >>> 8) & 0xff
  nonce[11] = (epoch >>> 16) & 0xff
  return nonce
}
