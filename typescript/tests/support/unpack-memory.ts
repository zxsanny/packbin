import { BinaryPacker, Scheme, group, list, times, u32, u8 } from "../../src/index.ts"

// AZ-2415 in a process of its own, so its peak memory is its own. Usage: unpack-memory.ts <f10|wide> [maxSlots].
// Builds the packet bytes directly (no pack call), unpacks them with the scheme's default limits (or with
// maxSlots raised) and prints the outcome, the unpack time and the peak RSS.
//   f10  : list of group { u8 n; times(n) { 64 u8 names } }, 65 535 items, n = 1 each: 4 259 778 bytes and
//          4 194 240 slots (the F10 shape of the loop 21 security report)
//   wide : u32 n; times(n) { 65 u8 names }, n = 65 535: 4 259 780 bytes and 4 259 775 slots
const [, , shape = "f10", raised] = process.argv
type Row = Record<string, unknown>

const limits = raised === undefined ? {} : { maxSlots: Number(raised) }
const names = (n: number) => Array.from({ length: n }, (_, i) => u8(1 + i, new Function("x", `return x.k${i}`) as (x: Row) => unknown))
let layout: Scheme<Row>
let packet: Uint8Array
if (shape === "f10") {
  const item = group((x: Row) => x.item, [u8(0, (x: Row) => x.n), times(1, 0, names(64))])
  layout = new Scheme<Row>(1, [list((x: Row) => x.items, item)], limits)
  packet = new Uint8Array(3 + 65 * 65_535).fill(1)
  packet.set([1, 0xff, 0xff])
} else {
  layout = new Scheme<Row>(1, [u32(0, (x: Row) => x.n), times(1, 0, names(65))], limits)
  packet = new Uint8Array(5 + 65 * 65_535).fill(1)
  packet.set([1, 0xff, 0xff, 0, 0])
}
const idle = process.resourceUsage().maxRSS
const started = performance.now()
let rows = 0
const result = BinaryPacker.unpack(packet, layout.on(() => { rows++ }))
const ms = performance.now() - started
// maxRSS is in kilobytes on every platform (libuv scales the macOS bytes).
const peak = process.resourceUsage().maxRSS
console.log(JSON.stringify({
  shape, packetBytes: packet.length, maxSlots: layout.maxSlots, result, rows,
  ms: Math.round(ms), idleMB: +(idle / 1024).toFixed(1), peakMB: +(peak / 1024).toFixed(1), unpackPeakMB: +((peak - idle) / 1024).toFixed(1),
}))
