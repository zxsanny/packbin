// The plain types of frame mode, named as in the other packages (contract pack-session 3.0.0, owner decision D1).
// A name that is both a const and a type is an enumeration the TypeScript way: `FrameDirection.Up` is a value and
// `FrameDirection` is the type of the three values.

/** The direction of a frame: the nonce and the keys depend on it. */
export const FrameDirection = { Up: 1, Down: 2, Group: 3 } as const
export type FrameDirection = (typeof FrameDirection)[keyof typeof FrameDirection]

/** The directions a frame session loads keys for: bits that are or-ed, for example `FrameDirections.Up | FrameDirections.Down`. */
export const FrameDirections = { None: 0, Up: 1, Down: 2, Group: 4, All: 7 } as const
export type FrameDirections = number

/** Which loaded key opened a frame. */
export const FrameSlot = { Current: "Current", Previous: "Previous" } as const
export type FrameSlot = (typeof FrameSlot)[keyof typeof FrameSlot]

/** What a replay window says about a counter. */
export const Freshness = { Fresh: "Fresh", Duplicate: "Duplicate", TooOld: "TooOld" } as const
export type Freshness = (typeof Freshness)[keyof typeof Freshness]

/** What a frame session is loaded with besides the key. A `tagLength` other than 4, 8 or 16 makes load fail. */
export class FrameConfig {
  readonly tagLength: number
  readonly directions: FrameDirections

  constructor(tagLength: number, directions: FrameDirections) {
    this.tagLength = tagLength
    this.directions = directions
  }
}

/** What open reports for a frame that opened: `ok` tells it from an error value. */
export class FrameOpened {
  readonly ok: true = true
  readonly slot: FrameSlot
  readonly clearLength: number
  readonly plainLength: number

  constructor(slot: FrameSlot, clearLength: number, plainLength: number) {
    this.slot = slot
    this.clearLength = clearLength
    this.plainLength = plainLength
  }
}

/** What seal reports on success: the number of body bytes written to the caller's buffer. */
export type FrameSealed = { ok: true; length: number }

const ids = new WeakMap<MsgContext, Uint8Array>()

/**
 * What the caller supplies per message: the 8-byte `msg_id` and the 4-bit `kind` (0 to 15).
 *
 * **For one (key, epoch, direction), a `msg_id` is never sealed twice with different contents.** Reuse breaks the
 * confidentiality of both messages, and packbin cannot check it. A new epoch derives new keys and nonces. meshbell builds
 * the id as source (2 bytes), id field (2 bytes) and creation wave (4 bytes), so it is unique by construction.
 *
 * The id is copied at construction. A value built from bytes that are not 8 long, or a `kind` outside 0 to 15, is
 * refused by seal and open as a bad value.
 */
export class MsgContext {
  static readonly IdSize = 8
  readonly kind: number

  constructor(msgId: Uint8Array, kind: number) {
    if (msgId instanceof Uint8Array && msgId.length === MsgContext.IdSize) ids.set(this, Uint8Array.from(msgId))
    this.kind = kind
  }
}

/** The id bytes of a context, or undefined for a value that is not a context or was built from a wrong-sized id. Internal: not exported from index.ts. */
export function msgIdOf(message: unknown): Uint8Array | undefined {
  return message instanceof MsgContext ? ids.get(message) : undefined
}
