import { hkdfSha256 } from "./crypto.ts"
import { salt, wipe } from "./frame-crypto.ts"

const ENC = new TextEncoder().encode("enc")
const MAC = new TextEncoder().encode("mac")

// The keys of one (key, epoch) for the loaded directions: K_enc(d) and K_mac(d), derived once at load.
export class FrameKeys {
  readonly epoch: number
  readonly #enc: (Uint8Array | undefined)[] = [undefined, undefined, undefined]
  readonly #mac: (Uint8Array | undefined)[] = [undefined, undefined, undefined]

  private constructor(epoch: number) {
    this.epoch = epoch
  }

  enc(direction: number): Uint8Array {
    return this.#enc[direction - 1]!
  }

  mac(direction: number): Uint8Array {
    return this.#mac[direction - 1]!
  }

  static derive(key: Uint8Array, epoch: number, directions: number): FrameKeys {
    const keys = new FrameKeys(epoch)
    const saltBytes = salt(epoch)
    for (let d = 1; d <= 3; d++) {
      if ((directions & (1 << (d - 1))) === 0) continue
      keys.#enc[d - 1] = expand(key, saltBytes, d, ENC)
      keys.#mac[d - 1] = expand(key, saltBytes, d, MAC)
    }
    return keys
  }

  /** Overwrites every key array (best effort: the engine may have copied a key before this ran). */
  wipe(): void {
    for (const array of this.arrays()) wipe(array)
  }

  arrays(): Uint8Array[] {
    return [...this.#enc, ...this.#mac].filter((a): a is Uint8Array => a !== undefined)
  }
}

function expand(key: Uint8Array, saltBytes: Uint8Array, direction: number, use: Uint8Array): Uint8Array {
  const info = new Uint8Array(1 + use.length)
  info[0] = direction
  info.set(use, 1)
  return hkdfSha256(key, saltBytes, info, 32)
}
