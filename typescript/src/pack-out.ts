// The bytes one pack call writes, type byte included, and the most it may write (`maxBytes`). The
// buffer grows by doubling but never past `maxBytes`, so an append that fits costs one comparison and
// memory follows the budget, not the rounds a row asks for.
export class PackOut {
  readonly maxBytes: number
  #buf: Uint8Array
  #length = 1

  constructor(maxBytes: number, typeByte: number) {
    this.maxBytes = maxBytes
    this.#buf = new Uint8Array(Math.min(maxBytes, 64))
    this.#buf[0] = typeByte
  }

  get length(): number {
    return this.#length
  }

  // Refuses, naming the member, the append that would make the packet longer than `maxBytes`; nothing
  // of it is written then.
  append(name: string, bytes: ArrayLike<number>): void {
    const need = this.#length + bytes.length
    if (need > this.#buf.length) this.#grow(name, need)
    this.#buf.set(bytes, this.#length)
    this.#length = need
  }

  // One byte, refused as `append` refuses.
  byte(name: string, value: number): void {
    if (this.#length === this.#buf.length) this.#grow(name, this.#length + 1)
    this.#buf[this.#length++] = value
  }

  // A byte already written, set again (a combined flag byte gains its bits as its members are reached).
  patch(at: number, byte: number): void {
    this.#buf[at] = byte
  }

  bytes(): Uint8Array {
    return this.#buf.slice(0, this.#length)
  }

  #grow(name: string, need: number): void {
    if (need > this.maxBytes) {
      throw new RangeError(`${name}: the packet would be ${need} bytes, above the limit of ${this.maxBytes} bytes`)
    }
    const next = new Uint8Array(Math.min(this.maxBytes, Math.max(need, this.#buf.length * 2)))
    next.set(this.#buf.subarray(0, this.#length))
    this.#buf = next
  }
}
