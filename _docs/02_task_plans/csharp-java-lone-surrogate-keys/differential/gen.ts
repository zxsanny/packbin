import { writeFileSync } from "node:fs"
import { BinaryPacker, dict, scheme, u8 } from "/Users/zxsanny/dev/zxsanny/packbin/typescript/src/index.ts"
const L = scheme<{ d: Record<string, number> }>(1, dict((r) => r.d, u8(0, (x) => x.v)))
let seed = 4242
const next = () => { seed = (seed + 0x6d2b79f5) | 0; let t = Math.imul(seed ^ (seed >>> 15), 1 | seed); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296 }
const alpha = ["a", "b", "?", "\ud800", "\udbff", "\udc00", "\udfff", "�", "￿", "\u{10000}", "\u{1f600}", "~", ""]
const hex = (b: Uint8Array) => Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("")
const units = (s: string) => s.length === 0 ? "-" : Array.from({ length: s.length }, (_, i) => s.charCodeAt(i).toString(16).padStart(4, "0")).join("")
const lines: string[] = []
let refused = 0
for (let n = 0; n < 5000; n++) {
  const d: Record<string, number> = {}
  for (let k = 1 + Math.floor(next() * 5); k > 0; k--) {
    let key = ""
    for (let u = Math.floor(next() * 4); u > 0; u--) key += alpha[Math.floor(next() * alpha.length)]
    d[key] = 1 + Math.floor(next() * 200)
  }
  let expect: string
  try { expect = hex(BinaryPacker.pack(L as never, { d } as never)) } catch { expect = "REFUSED"; refused++ }
  lines.push([Object.keys(d).map(units).join(","), Object.values(d).join(","), expect].join("\t"))
}
writeFileSync(process.argv[2]!, lines.join("\n") + "\n")
console.log(refused, "refused of", lines.length)
