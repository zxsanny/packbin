import { Freshness } from "./frame-types.ts"

const MASK = (1n << 64n) - 1n
const SIZE = 64n

function checked(name: string, value: unknown): bigint {
  if (typeof value !== "bigint" || value < 0n || value > MASK) {
    throw new RangeError(`${name}: expected a bigint from 0 to 2^64 - 1`)
  }
  return value
}

/** True for a counter a window accepts: a bigint from 0 to 2^64 - 1. */
export function isCounter(value: unknown): value is bigint {
  return typeof value === "bigint" && value >= 0n && value <= MASK
}

/**
 * The replay window of frame mode: the highest counter a sender's frames reached (`top`) and which of the 64 counters up
 * to it were committed (`bits`: bit i set means counter `top - i` was committed; 0 is an empty window). The caller owns
 * one per sender and passes it, with the message's counter, to `FrameSession.open`. Both numbers are 64-bit and are
 * bigints, so counters up to 2^64 - 1 are exact.
 *
 * The counter must come from bytes the tag covers (for example the `msg_id` or the associated data), never from an
 * unauthenticated field of the wire: it is an argument of open and not part of the tag.
 */
export class ReplayWindow {
  static readonly Size = 64
  #top: bigint
  #bits: bigint

  /** A window restored from stored state. `bits` 0 is empty whatever `top` is: a caller validates stored state (bit 0 set when the bits are not 0). */
  constructor(top: bigint = 0n, bits: bigint = 0n) {
    this.#top = checked("top", top)
    this.#bits = checked("bits", bits)
  }

  get top(): bigint {
    return this.#top
  }

  get bits(): bigint {
    return this.#bits
  }

  /** What the window says about `counter`. Never changes the state. */
  check(counter: bigint): Freshness {
    const n = checked("counter", counter)
    if (this.#bits === 0n || n > this.#top) return Freshness.Fresh
    const behind = this.#top - n
    if (behind >= SIZE) return Freshness.TooOld
    return ((this.#bits >> behind) & 1n) === 1n ? Freshness.Duplicate : Freshness.Fresh
  }

  /** Records `counter`. Open calls this only after a frame opened; a counter 64 or more behind the highest is ignored. */
  commit(counter: bigint): void {
    const n = checked("counter", counter)
    if (this.#bits === 0n) {
      this.#top = n
      this.#bits = 1n
    } else if (n > this.#top) {
      const shift = n - this.#top
      this.#bits = ((shift >= SIZE ? 0n : this.#bits << shift) & MASK) | 1n
      this.#top = n
    } else {
      const behind = this.#top - n
      if (behind < SIZE) this.#bits |= 1n << behind
    }
  }
}
