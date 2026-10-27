// Run: node --expose-gc text_amp.ts <repo checkout>   (AZ-2666 probe (c), TypeScript)
// Compact text amplification and cost in the TypeScript package: packet size, decoded UTF-8 size against 6N + 8,
// time of one unpack (median), and the heap and RSS growth of one unpack (after gc). Cases: the densest text at the
// 65,535-byte limit, the same with one 4-byte character, 65,536 bytes (refused), 2,097,151 bytes of mode switches
// only (no output), LOCK toggles, a raw payload of 2,097,151 bytes (refused by length), lists of many limit-sized
// texts, a baseline of nested u8 lists, dicts of 1,000 to 65,535 keys (and a duplicate last key), tiny strings.
import os from "node:os"
import path from "node:path"
import { pathToFileURL } from "node:url"

const repo = path.resolve(process.argv[2] ?? ".")
const src = (f: string) => pathToFileURL(path.join(repo, "typescript", "src", f)).href
const pb: any = await import(src("index.ts"))
const T: any = await import(src("text-tables.ts"))
const text: any = await import(src("text.ts"))
const gc: () => void = (globalThis as any).gc ?? (() => {})
const hardStop = setTimeout(() => {
  console.log("HARD STOP after 115 s")
  process.exit(3)
}, 115_000)
const load = () => os.loadavg().map((x) => x.toFixed(2)).join(" ")

const LENGTHS = [T.LENGTHS_UA, T.LENGTHS_RU, T.LENGTHS_EN, T.LENGTHS_NUM] as number[][]
const CODES = LENGTHS.map((lengths) => {
  const order = lengths.map((_, i) => i).sort((a, b) => lengths[a]! - lengths[b]! || a - b)
  const codes = new Array<number>(lengths.length)
  let code = 0
  let prev = 0
  for (const i of order) {
    code <<= lengths[i]! - prev
    codes[i] = code
    code++
    prev = lengths[i]!
  }
  return codes.map((c, i) => [c, lengths[i]!] as [number, number])
})
const ALPHA = [T.UA, T.RU, T.EN] as number[][]
const letters = (m: number) => (m === 3 ? 15 : ALPHA[m]!.length)
const swAt = (m: number, target: number) => (m === 3 ? 15 + target : letters(m) + 32 + (target < m ? target : target - 1))
const capAt = (m: number) => letters(m) + 35
const lockAt = (m: number) => letters(m) + 36
const escAt = (m: number) => (m === 3 ? 18 : letters(m) + 37)
const charAt = (m: number, ch: string) => {
  const cp = ch.codePointAt(0)!
  if (m === 3) return T.NUMSET.indexOf(cp)
  const i = ALPHA[m]!.indexOf(cp)
  return i >= 0 ? i : letters(m) + T.SHARED.indexOf(cp)
}

function varint(n: number): Uint8Array {
  const out: number[] = []
  for (;;) {
    const b = n & 0x7f
    n = Math.floor(n / 128)
    if (n) out.push(b | 0x80)
    else {
      out.push(b)
      return Uint8Array.from(out)
    }
  }
}
const cat = (...parts: Uint8Array[]) => catAll(parts)
function catAll(parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((s, p) => s + p.length, 0))
  let o = 0
  for (const p of parts) {
    out.set(p, o)
    o += p.length
  }
  return out
}
// A compact field: count, then pad, start mode and the symbols (each [code, length]).
function stream(start: number, symbols: [number, number][]): Uint8Array {
  const bits = symbols.reduce((s, [, l]) => s + l, 0)
  const total = 6 + bits
  const nbytes = (total + 7) >> 3
  const pad = nbytes * 8 - total
  const out = new Uint8Array(nbytes)
  let pos = 0
  const put = (v: number, l: number) => {
    for (let k = l - 1; k >= 0; k--) {
      if ((v >>> k) & 1) out[pos >> 3]! |= 0x80 >> (pos & 7)
      pos++
    }
  }
  put(pad, 3)
  put(start, 3)
  for (const [c, l] of symbols) put(c, l)
  return cat(varint(nbytes), out)
}

const one = pb.scheme(1, pb.utf8(0, (r: any) => r.s))
const list = pb.scheme(1, pb.list((r: any) => r.xs, pb.utf8(0, (s: any) => s)))
const dict = pb.scheme(1, pb.dict((r: any) => r.d, pb.u8(0, (v: any) => v)))
const listU8 = pb.scheme(1, pb.list((r: any) => r.xs, pb.list((x: any) => x, pb.u8(0, (v: any) => v))))

function measure(name: string, s: any, packet: Uint8Array, reps = 5): void {
  let row: any = null
  const h = s.on((r: any) => (row = r))
  let res: any
  const times: number[] = []
  for (let i = 0; i < reps; i++) {
    const t0 = performance.now()
    res = pb.BinaryPacker.unpack(packet, h)
    times.push(performance.now() - t0)
  }
  row = null
  res = null
  gc()
  const before = process.memoryUsage()
  res = pb.BinaryPacker.unpack(packet, h)
  const after = process.memoryUsage()
  let decoded = 0
  if (res.ok && row) {
    const vals: unknown[] = [row.s, ...(row.xs ?? []), ...Object.keys(row.d ?? {})]
    for (const v of vals) if (typeof v === "string") decoded += Buffer.byteLength(v, "utf8")
  }
  const heap = after.heapUsed - before.heapUsed
  const rss = after.rss - before.rss
  times.sort((a, b) => a - b)
  const status = res.ok ? "ok" : `refused ${JSON.stringify(res).slice(0, 40)}`
  console.log(
    `  ${name.padEnd(50)} packet ${String(packet.length).padStart(9)} B  decoded ${String(decoded).padStart(9)} B (${(decoded / packet.length).toFixed(2)}/B, bound ${6 * packet.length + 8})  ${status.padEnd(44)} median ${times[times.length >> 1]!.toFixed(2).padStart(9)} ms  max ${times[times.length - 1]!.toFixed(2).padStart(9)} ms  heap +${(heap / 1e6).toFixed(2)} MB (${(heap / packet.length).toFixed(1)}/B) rss +${(rss / 1e6).toFixed(1)} MB`,
  )
  row = null
  res = null
}

console.log(`node ${process.version}, load ${load()}, gc ${(globalThis as any).gc ? "exposed" : "not exposed (run with --expose-gc)"}`)
const o = CODES[1]![charAt(1, "о")]!
const sp = CODES[1]![charAt(1, " ")]!
const dense = stream(1, [...Array.from({ length: 32767 }, () => o), sp])
measure("largest text: 32,767 x 'о' + ' ' (65,535 B)", one, cat(Uint8Array.of(1), dense))
const emoji: [number, number][] = [CODES[1]![escAt(1)]!, ...[...Buffer.from("😀", "utf8")].map((b) => [b, 8] as [number, number])]
const astral = stream(1, [...emoji, ...Array.from({ length: 32765 }, () => o), sp])
measure("largest text with one 4-byte char", one, cat(Uint8Array.of(1), astral))
measure("65,536 B of 'о' (refused: length)", one, cat(Uint8Array.of(1), stream(1, Array.from({ length: 32768 }, () => o))))

const toNum = CODES[0]![swAt(0, 3)]!
const toUa = CODES[3]![swAt(3, 0)]!
const count = 2_097_151
const pairs = Math.floor((8 * count - 6) / (toNum[1] + toUa[1]))
const rest = (8 * count - 6) % (toNum[1] + toUa[1])
const symbols: [number, number][] = []
for (let i = 0; i < pairs; i++) symbols.push(toNum, toUa)
if (rest === toNum[1]) symbols.push(toNum)
const switches = stream(0, symbols)
if (switches.length !== 3 + count) throw new Error(`switch stream is ${switches.length} bytes`)
{
  const t0 = performance.now()
  const r = text.decodeText(switches, 0)
  const dt = performance.now() - t0
  console.log(`  2,097,151 B payload of ${symbols.length} switch symbols (no output): decodeText ${dt.toFixed(1)} ms, ${((dt / count) * 1e6).toFixed(1)} ns per payload byte, ok ${r.ok} length ${r.ok ? r.value.length : "-"}`)
}
measure("same, through unpack", one, cat(Uint8Array.of(1), switches), 3)
const lock = CODES[0]![lockAt(0)]!
measure("20,000 B of LOCK toggles (no output)", one, cat(Uint8Array.of(1), stream(0, Array.from({ length: Math.floor((8 * 20000 - 6) / lock[1]) }, () => lock))), 3)

const rawBody = new Uint8Array(count - 1)
rawBody.fill(0x61)
rawBody.set(Buffer.from("😀", "utf8"), 0)
measure("raw payload of 2,097,151 B (refused: length)", one, cat(Uint8Array.of(1), varint(count), Uint8Array.of(0x10), rawBody), 3)
measure("raw payload of 65,535 UTF-8 B (accepted)", one, cat(Uint8Array.of(1), varint(65536), Uint8Array.of(0x10), rawBody.subarray(0, 65535)), 3)

const u16 = (n: number) => Uint8Array.of(n & 0xff, n >> 8)
for (const k of [16, 64, 256]) measure(`list of ${k} x 65,535-B texts`, list, catAll([Uint8Array.of(1), u16(k), ...Array.from({ length: k }, () => dense)]), 2)
for (const k of [16, 64, 256]) measure(`list of ${k} x 65,535-B texts with a 4-byte char`, list, catAll([Uint8Array.of(1), u16(k), ...Array.from({ length: k }, () => astral)]), 2)
const inner = cat(u16(65535), new Uint8Array(65535))
measure("baseline: 16 lists of 65,535 u8", listU8, catAll([Uint8Array.of(1), u16(16), ...Array.from({ length: 16 }, () => inner)]), 2)

for (const k of [1000, 10000, 65535]) {
  const d: Record<string, number> = {}
  for (let i = 0; i < k; i++) d[`k${i}`] = 1
  measure(`dict of ${k} keys 'k0'..`, dict, pb.BinaryPacker.pack(dict, { d }), 3)
}
{
  const d: Record<string, number> = {}
  for (let i = 0; i < 65535; i++) d[String(i)] = 1
  const good = pb.BinaryPacker.pack(dict, { d }) as Uint8Array
  measure("dict of 65,535 integer-like keys '0'..", dict, good, 3)
  // pack sorts the pairs by key bytes; replace the last key with the first one
  const keys = Object.keys(d).sort((a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b)))
  const first = pb.BinaryPacker.pack(one, { s: keys[0] }).subarray(1) as Uint8Array
  const last = pb.BinaryPacker.pack(one, { s: keys[keys.length - 1] }).subarray(1) as Uint8Array
  const tail = cat(last, Uint8Array.of(1))
  const at = Buffer.from(good).lastIndexOf(Buffer.from(tail))
  if (at > 0) measure("dict of 65,535 keys, last key = first (refused)", dict, cat(good.subarray(0, at), first, Uint8Array.of(1)), 3)
}
measure("list of 65,535 empty strings", list, cat(Uint8Array.of(1), u16(65535), new Uint8Array(65535)), 3)
const oneChar = pb.BinaryPacker.pack(one, { s: "я" }).subarray(1) as Uint8Array
measure("list of 65,535 one-letter strings", list, catAll([Uint8Array.of(1), u16(65535), ...Array.from({ length: 65535 }, () => oneChar)]), 3)
console.log(`max RSS of the run ${(process.resourceUsage().maxRSS / 1024).toFixed(1)} MB, load ${load()}`)
clearTimeout(hardStop)
