function rot(value: number, bits: number): number {
  return ((value << bits) | (value >>> (32 - bits))) >>> 0
}

function quarter(w: Uint32Array, a: number, b: number, c: number, d: number): void {
  w[a] = (w[a]! + w[b]!) >>> 0
  w[d] = rot(w[d]! ^ w[a]!, 16)
  w[c] = (w[c]! + w[d]!) >>> 0
  w[b] = rot(w[b]! ^ w[c]!, 12)
  w[a] = (w[a]! + w[b]!) >>> 0
  w[d] = rot(w[d]! ^ w[a]!, 8)
  w[c] = (w[c]! + w[d]!) >>> 0
  w[b] = rot(w[b]! ^ w[c]!, 7)
}

function readU32LE(buf: Uint8Array, offset: number): number {
  return (
    buf[offset]! |
    (buf[offset + 1]! << 8) |
    (buf[offset + 2]! << 16) |
    (buf[offset + 3]! << 24)
  ) >>> 0
}

function writeU32LE(buf: Uint8Array, offset: number, value: number): void {
  buf[offset] = value & 0xff
  buf[offset + 1] = (value >>> 8) & 0xff
  buf[offset + 2] = (value >>> 16) & 0xff
  buf[offset + 3] = (value >>> 24) & 0xff
}

function block(
  key: Uint8Array,
  nonce: Uint8Array,
  counter: number,
  output: Uint8Array,
): void {
  const state = new Uint32Array(16)
  state[0] = 0x61707865
  state[1] = 0x3320646e
  state[2] = 0x79622d32
  state[3] = 0x6b206574
  for (let i = 0; i < 8; i++) {
    state[4 + i] = readU32LE(key, i * 4)
  }
  state[12] = counter >>> 0
  state[13] = readU32LE(nonce, 0)
  state[14] = readU32LE(nonce, 4)
  state[15] = readU32LE(nonce, 8)

  const work = new Uint32Array(state)
  for (let i = 0; i < 10; i++) {
    quarter(work, 0, 4, 8, 12)
    quarter(work, 1, 5, 9, 13)
    quarter(work, 2, 6, 10, 14)
    quarter(work, 3, 7, 11, 15)
    quarter(work, 0, 5, 10, 15)
    quarter(work, 1, 6, 11, 12)
    quarter(work, 2, 7, 8, 13)
    quarter(work, 3, 4, 9, 14)
  }

  for (let i = 0; i < 16; i++) {
    writeU32LE(output, i * 4, (work[i]! + state[i]!) >>> 0)
  }
}

export function xorPad(key: Uint8Array, packet: bigint | number, data: Uint8Array): void {
  const nonce = new Uint8Array(12)
  const n = typeof packet === "bigint" ? packet : BigInt(packet)
  const view = new DataView(nonce.buffer)
  view.setBigUint64(0, n, true)
  xorWithNonce(key, nonce, 0, data)
}

export function xorWithNonce(
  key: Uint8Array,
  nonce: Uint8Array,
  counter: number,
  data: Uint8Array,
): void {
  const blockBytes = new Uint8Array(64)
  let offset = 0
  let c = counter >>> 0
  while (offset < data.length) {
    block(key, nonce, c, blockBytes)
    const n = Math.min(64, data.length - offset)
    for (let i = 0; i < n; i++) {
      data[offset + i]! ^= blockBytes[i]!
    }
    offset += n
    c = (c + 1) >>> 0
  }
}
