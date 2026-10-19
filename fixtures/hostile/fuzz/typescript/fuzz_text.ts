// Run: node fuzz_text.ts <repo checkout> [seed] [seconds]   (AZ-2666 probe (a), TypeScript, compact text; Node 22.18+, python3 >= 3.9 on PATH or $PYTHON)
// Seeded grammar-built, random and mutated string fields against the TypeScript compact text decoder. Each field goes
// through decodeText, through a bounds-checked copy of text.ts and through scripts/text/textfmt.py; a different answer
// is a mismatch. The field is then read through BinaryPacker.unpack as a lone string, in a list and as a dict key;
// any exception escaping is a finding. Shared setup is fuzz_common.ts next to this file.
import { readFileSync, rmSync, writeFileSync } from "node:fs"
import os from "node:os"
import path from "node:path"
import { pathToFileURL } from "node:url"
import {
  Stats, T, budget, cat, finish, hex, int, mutate, note, packets, pb, pick, randBytes, reference, repo, rnd, src, start,
  text, textSeeds, varint,
} from "./fuzz_common.ts"

// A copy of text.ts in the OS temp directory (never in the checkout) where every array read `x[i]!` is bounds-checked:
// a typed array read outside its length gives `undefined` silently, so the copy throws instead. Fields are fed with
// the buffer ending where the field ends, so a read past the payload is a read past the buffer.
function guardedCopy(): string {
  let code = readFileSync(path.join(repo, "typescript", "src", "text.ts"), "utf8")
  code = code.replace(/from "\.\/text-tables\.ts"/, `from ${JSON.stringify(src("text-tables.ts"))}`)
  let before = ""
  while (before !== code) {
    before = code
    code = code.replace(/(\w+)\[([^\[\]]+)\]!(?!=)/, (_m, arr, idx) => `__at(${arr}, ${idx}, "${arr}")`)
    code = code.replace(/__at\(([^()]*)\)\[([^\[\]]+)\]!(?!=)/, (_m, inner, idx) => `__at(__at(${inner}), ${idx}, "nested")`)
  }
  code += `
function __at(arr: any, i: number, name: string): any {
  if (!Number.isInteger(i) || i < 0 || i >= arr.length) throw new RangeError(name + " index " + i + " outside 0.." + (arr.length - 1))
  return arr[i]
}
`
  const file = path.join(os.tmpdir(), `packbin-text-guarded-${process.pid}.ts`)
  writeFileSync(file, code)
  return file
}
const guardedFile = guardedCopy()
const guarded: any = await import(pathToFileURL(guardedFile).href)
rmSync(guardedFile, { force: true })
try {
  guarded.decodeText(Uint8Array.of(1), -1) // positive control: an index of -1 must throw in the copy
  console.log("guard control: the bounds-checked copy did not throw on index -1; its figure below proves nothing")
} catch {
  // expected
}
const guardedReads = (readFileSync(path.join(repo, "typescript", "src", "text.ts"), "utf8").match(/\]!(?!=)/g) ?? []).length

// The frozen code tables, rebuilt from text-tables.ts in the contract's symbol order.
const ALPHA = [T.UA, T.RU, T.EN] as number[][]
const UPPER = [T.UA_UPPER, T.RU_UPPER, T.EN_UPPER] as number[][]
const LENGTHS = [T.LENGTHS_UA, T.LENGTHS_RU, T.LENGTHS_EN, T.LENGTHS_NUM] as number[][]
type Sym = { code: number; len: number; kind: "char" | "sw" | "cap" | "lock" | "esc"; up: boolean; target: number }
function symbolOf(m: number, i: number, code: number, len: number): Sym {
  const sy: Sym = { code, len, kind: "char", up: false, target: -1 }
  if (m === 3) {
    if (i >= 15 && i < 18) Object.assign(sy, { kind: "sw", target: i - 15 })
    else if (i === 18) sy.kind = "esc"
    return sy
  }
  const letters = ALPHA[m]!.length
  const sw = letters + T.SHARED.length
  if (i < letters) sy.up = UPPER[m]![i] !== 0
  else if (i >= sw && i < sw + 3) Object.assign(sy, { kind: "sw", target: i - sw < m ? i - sw : i - sw + 1 })
  else if (i === sw + 3) sy.kind = "cap"
  else if (i === sw + 4) sy.kind = "lock"
  else if (i === sw + 5) sy.kind = "esc"
  return sy
}
const TABLES: Sym[][] = LENGTHS.map((lengths, m) => {
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
  return lengths.map((len, i) => symbolOf(m, i, codes[i]!, len))
})

const BAD_UTF8 = [
  [0xc0, 0x80], [0xc1, 0xbf], [0xe0, 0x80, 0x80], [0xe0, 0x9f, 0xbf], [0xed, 0xa0, 0x80], [0xed, 0xbf, 0xbf],
  [0xf0, 0x80, 0x80, 0x80], [0xf0, 0x8f, 0xbf, 0xbf], [0xf4, 0x90, 0x80, 0x80], [0xf5, 0x80, 0x80, 0x80],
  [0xf7, 0xbf, 0xbf, 0xbf], [0xf8], [0xff], [0x80], [0xbf], [0xc3, 0x41], [0xe2, 0x82, 0x41], [0xf0, 0x9f, 0x98, 0x41],
  [0xc3], [0xe2, 0x82],
]
// 1 to 4 bytes after an ESC: mostly a valid scalar, sometimes a hostile sequence.
function utf8Piece(): number[] {
  if (rnd() < 0.75) {
    for (;;) {
      const band = pick([[0, 0x7f], [0x80, 0x7ff], [0x800, 0xffff], [0x10000, 0x10ffff]] as const)
      const cp = int(band[0], band[1])
      if (cp < 0xd800 || cp > 0xdfff) return [...Buffer.from(String.fromCodePoint(cp), "utf8")]
    }
  }
  return pick(BAD_UTF8)
}

// A compact payload from the frozen codes: mostly legal symbol sequences (CAP and LOCK tracked) so the decoder goes
// deep, with hostile ESC bytes, wrong pads, wrong modes and random symbols mixed in.
function genStream(): Uint8Array {
  const first = int(0, 3)
  let mode = first
  let lock = false
  let cap = false
  const bits: number[] = []
  const put = (code: number, len: number) => {
    for (let k = len - 1; k >= 0; k--) bits.push((code >>> k) & 1)
  }
  const nsym = pick([1, 2, 3, 8, 30, 200, 2000])
  for (let s = 0; s < nsym; s++) {
    const tab = TABLES[mode]!
    let idx = int(0, tab.length - 1)
    if (!(rnd() < 0.08 || (cap && mode === 3))) {
      while ((cap && !(tab[idx]!.kind === "char" && tab[idx]!.up)) || (tab[idx]!.kind === "cap" && (lock || cap))) {
        idx = int(0, tab.length - 1)
      }
    }
    const sy = tab[idx]!
    put(sy.code, sy.len)
    if (sy.kind === "char") cap = false
    else if (sy.kind === "sw") {
      mode = sy.target
      cap = false
    } else if (sy.kind === "cap") cap = true
    else if (sy.kind === "lock") lock = !lock
    else for (const b of utf8Piece()) put(b, 8)
  }
  if (rnd() < 0.05 && bits.length) bits.length -= int(1, Math.min(7, bits.length))
  const total = 6 + bits.length
  const nbytes = (total + 7) >> 3
  const pad = nbytes * 8 - total
  const headPad = rnd() > 0.03 ? pad : int(0, 7)
  const headMode = rnd() > 0.03 ? first : int(0, 7)
  const all = [(headPad >> 2) & 1, (headPad >> 1) & 1, headPad & 1, (headMode >> 2) & 1, (headMode >> 1) & 1, headMode & 1, ...bits]
  while (all.length < nbytes * 8) all.push(0)
  if (rnd() < 0.03 && pad) all[all.length - 1] = 1
  const out = new Uint8Array(nbytes)
  for (let i = 0; i < all.length; i++) if (all[i]) out[i >> 3]! |= 0x80 >> (i & 7)
  return out
}

function genTextField(): Uint8Array {
  const r = rnd()
  let field: Uint8Array
  if (r < 0.45) {
    const payload = genStream()
    field = cat(varint(payload.length), payload)
  } else if (r < 0.6) {
    const n = pick([1, 2, 3, 5, 17, 300])
    field = cat(varint(n), randBytes(n))
  } else if (r < 0.7) {
    let s = ""
    for (let i = int(1, 40); i > 0; i--) {
      const cp = pick([0x41, 0x430, 0x20ac, 0x1f600, int(0, 0x10ffff)])
      s += String.fromCodePoint(cp >= 0xd800 && cp <= 0xdfff ? 0x41 : cp)
    }
    const raw = new Uint8Array(Buffer.from(s, "utf8"))
    if (rnd() < 0.3) raw[int(0, raw.length - 1)] = int(0, 255)
    field = cat(varint(raw.length + 1), Uint8Array.of(0x10), raw)
  } else if (r < 0.95) field = mutate(pick(textSeeds))
  else field = mutate(pick(packets).subarray(1)) // a hostile or ring packet body read as a string
  if (rnd() < 0.2) field = cat(field, randBytes(int(1, 4)))
  return field
}

const asText = (r: any) => (r.ok ? `ok ${hex(new Uint8Array(Buffer.from(r.value, "utf8")))} ${r.next}` : `refused ${r.kind}`)
const one = pb.scheme(1, pb.utf8(0, (r: any) => r.s))
const lists = pb.scheme(2, pb.list((r: any) => r.xs, pb.utf8(0, (s: any) => s)))
const dicts = pb.scheme(3, pb.dict((r: any) => r.d, pb.utf8(0, (s: any) => s)))
const textHandlers = [one.on(() => {}), lists.on(() => {}), dicts.on(() => {})]
const u16le = (n: number) => Uint8Array.of(n & 0xff, n >> 8)

// The field as a lone string, among 1 to 3 strings of a list, or as the key of a dict of 1 to 2 pairs.
function packetOf(field: Uint8Array): Uint8Array {
  const shape = int(0, 2)
  if (shape === 0) return cat(Uint8Array.of(1), field)
  if (shape === 1) {
    const k = int(1, 3)
    return cat(Uint8Array.of(2), u16le(k), field, ...Array.from({ length: k - 1 }, genTextField))
  }
  const k = int(1, 2)
  const parts: Uint8Array[] = []
  for (let j = 0; j < k; j++) parts.push(j === 0 || rnd() < 0.3 ? field : genTextField(), genTextField())
  return cat(Uint8Array.of(3), u16le(k), ...parts)
}

let guardedCalls = 0
let guardedThrows = 0
function runText(deadline: number): void {
  const st = new Stats("text decodeText vs reference")
  const pub = new Stats("text public unpack (utf8, list, dict)")
  let kindsDiffer = 0
  while (performance.now() < deadline) {
    const batch: Uint8Array[] = []
    const got: string[] = []
    for (let i = 0; i < 4000; i++) {
      const field = genTextField()
      batch.push(field)
      try {
        got.push(st.timed(hex(field.subarray(0, 40)), () => asText(text.decodeText(field, 0))))
      } catch (e: any) {
        st.exceptions++
        got.push("exception")
        note(`text decodeText threw ${e?.name}: ${e?.message} on ${hex(field).slice(0, 200)}`)
      }
      try {
        if (asText(guarded.decodeText(field.slice(), 0)) !== got[got.length - 1]) note(`guarded copy differs on ${hex(field).slice(0, 200)}`)
        guardedCalls++
      } catch (e: any) {
        guardedThrows++
        note(`guarded decodeText: ${e?.message} on ${hex(field).slice(0, 200)}`)
      }
      const packet = packetOf(field)
      try {
        const res = pub.timed(hex(packet.subarray(0, 40)), () => pb.BinaryPacker.unpack(packet, ...textHandlers))
        if (res.ok) pub.accepted++
        else pub.refused++
      } catch (e: any) {
        pub.exceptions++
        note(`public text unpack threw ${e?.name}: ${e?.message} on ${hex(packet).slice(0, 200)}`)
      }
    }
    const want = reference(batch.map((b) => `t ${hex(b)}`))
    for (let i = 0; i < batch.length; i++) {
      const g = got[i]!
      const w = want[i]!
      const gOk = g.startsWith("ok")
      if (gOk) st.accepted++
      else st.refused++
      if (gOk !== w.startsWith("ok") || (gOk && g !== w)) {
        st.mismatch++
        note(`text mismatch pkg=${g.slice(0, 60)} ref=${w.slice(0, 60)} on ${hex(batch[i]!).slice(0, 200)}`)
      } else if (!gOk && g !== w) kindsDiffer++
    }
  }
  console.log(st.report())
  console.log(`  refused by both with another kind name (informational): ${kindsDiffer}`)
  console.log(`  bounds-checked copy (${guardedReads} array reads in text.ts): calls ${guardedCalls}, out-of-bounds reads ${guardedThrows}`)
  console.log(pub.report())
}

const run = start(1)
runText(performance.now() + budget)
finish(run)
