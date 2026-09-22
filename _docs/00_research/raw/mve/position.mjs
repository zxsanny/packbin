import { Buffer } from "node:buffer"

const expected = "4001000065cd1d00a3e1110100"
const buf = Buffer.alloc(13)
const view = new DataView(buf.buffer, buf.byteOffset, buf.byteLength)
view.setUint8(0, 0x40)
view.setUint16(1, 1, true)
view.setInt32(3, 500_000_000, true)
view.setInt32(7, 300_000_000, true)
view.setUint8(11, 1)
view.setUint8(12, 0)
const hex = buf.toString("hex")
if (hex !== expected) {
  console.error("pack mismatch", hex)
  process.exit(1)
}

const back = new DataView(buf.buffer, buf.byteOffset, buf.byteLength)
const type = back.getUint8(0)
const sid = back.getUint16(1, true)
const lat = back.getInt32(3, true)
const lon = back.getInt32(7, true)
const profile = back.getUint8(11)
const flags = back.getUint8(12)
if (type !== 0x40 || sid !== 1 || lat !== 500_000_000 || lon !== 300_000_000 || profile !== 1 || flags !== 0) {
  console.error("unpack mismatch")
  process.exit(1)
}

function packOptional(bitSet, value) {
  const size = bitSet ? 4 : 2
  const out = Buffer.alloc(size)
  const v = new DataView(out.buffer, out.byteOffset, out.byteLength)
  v.setUint8(0, 0x40)
  v.setUint8(1, bitSet ? 0x01 : 0x00)
  if (bitSet) v.setUint16(2, value, true)
  return out
}

const clear = packOptional(false, 0)
const set = packOptional(true, 0x1234)
if (clear.length !== 2 || set.length !== 4) {
  console.error("flags width", clear.length, set.length)
  process.exit(1)
}

function unpackOptional(bytes) {
  if (bytes.length < 2) return { ok: false }
  const v = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  const flag = v.getUint8(1)
  if ((flag & 0x01) === 0) {
    if (bytes.length !== 2) return { ok: false }
    return { ok: true }
  }
  if (bytes.length < 4) return { ok: false }
  return { ok: true, extra: v.getUint16(2, true) }
}

const short = Buffer.from([0x40, 0x01, 0x34])
const shortResult = unpackOptional(short)
if (shortResult.ok) {
  console.error("short packet returned a value")
  process.exit(1)
}

function packWhen(profile, shape) {
  if (profile === 0) return Buffer.from([profile, shape])
  return Buffer.from([profile])
}
if (packWhen(1, 9).length !== 1 || packWhen(0, 9).length !== 2) {
  console.error("when width")
  process.exit(1)
}

function unpackRepeat(bytes) {
  if (bytes.length % 2 !== 0) return { ok: false }
  return { ok: true, groups: bytes.length / 2 }
}
if (unpackRepeat(Buffer.from([1, 2, 3, 4])).groups !== 2 || unpackRepeat(Buffer.from([1, 2, 3])).ok) {
  console.error("repeat")
  process.exit(1)
}

const start = performance.now()
for (let i = 0; i < 100_000; i++) {
  view.setUint8(0, 0x40)
  view.setUint16(1, 1, true)
  view.setInt32(3, 500_000_000, true)
  view.setInt32(7, 300_000_000, true)
  view.setUint8(11, 1)
  view.setUint8(12, 0)
  back.getUint8(0)
  back.getUint16(1, true)
  back.getInt32(3, true)
  back.getInt32(7, true)
  back.getUint8(11)
  back.getUint8(12)
}
const elapsed = performance.now() - start
if (elapsed > 1000) {
  console.error("speed", elapsed)
  process.exit(1)
}

console.log(hex)
console.log("elapsed_ms", elapsed.toFixed(1))
