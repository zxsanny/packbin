import { BinaryPacker, scheme, times, u32, utf8 } from "../../src/index.ts"

// AZ-2354 AC-1 in a process of its own, so its peak memory is its own: a lone 65 535-byte string under a
// times count of 65 535 would be 4.29 GB. Prints the outcome, the time the pack took and the peak RSS.
const layout = scheme<Record<string, unknown>>(1, u32(0, (x) => x.n), times(1, 0, [utf8(1, (x) => x.s)]))
const row = { n: 65_535, s: "a".repeat(65_535) }
const started = performance.now()
let outcome: { error: string; message: string } | { bytes: number }
try {
  outcome = { bytes: BinaryPacker.pack(layout, row).length }
} catch (e) {
  outcome = { error: (e as Error).constructor.name, message: (e as Error).message }
}
const ms = performance.now() - started
// maxRSS is in kilobytes on every platform (libuv scales the macOS bytes).
console.log(JSON.stringify({ ...outcome, ms, peakBytes: process.resourceUsage().maxRSS * 1024 }))
