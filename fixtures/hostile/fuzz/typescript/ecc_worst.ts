// Run: node ecc_worst.ts <repo checkout> [seed] [parts abcd]   (AZ-2666 probe (b), TypeScript; python3 >= 3.9 on PATH or $PYTHON)
// Part A times 254-byte buffers at n = 32 built for the most work (16 wrong bytes: the longest path that repairs;
// 17 wrong: full Chien search then a near-miss root count; random; the default t = 0), through ecc.repair and
// BinaryPacker.unpackRepair, median and slowest, with the field operations of each path counted from the code.
// Part B runs every n = 1..32 and N = n..255 with four inputs each, and part C 200,000 random short buffers, both
// compared with the reference decoder (scripts/ecc/eccfmt.py, one python3 batch).
import { spawnSync } from "node:child_process"
import { readFileSync, rmSync, writeFileSync } from "node:fs"
import os from "node:os"
import path from "node:path"
import { pathToFileURL } from "node:url"

const repo = path.resolve(process.argv[2] ?? ".")
const seed = Number(process.argv[3] ?? 2666)
const src = (f: string) => pathToFileURL(path.join(repo, "typescript", "src", f)).href
const pb: any = await import(src("index.ts"))
const ecc: any = await import(src("ecc.ts"))
const hardStop = setTimeout(() => {
  console.log("HARD STOP after 115 s")
  process.exit(3)
}, 115_000)

let state = seed >>> 0 || 1
function rnd(): number {
  state = (state + 0x6d2b79f5) >>> 0
  let t = state
  t = Math.imul(t ^ (t >>> 15), t | 1)
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}
const int = (lo: number, hi: number) => lo + Math.floor(rnd() * (hi - lo + 1))
const randBytes = (n: number) => Uint8Array.from({ length: n }, () => int(0, 255))
const hex = (b: Uint8Array) => (b.length ? Buffer.from(b).toString("hex") : "-")
const load = () => os.loadavg().map((x) => x.toFixed(2)).join(" ")

function corrupt(word: Uint8Array, k: number, positions?: number[]): Uint8Array {
  const w = word.slice()
  const pos = positions ?? []
  if (!positions) {
    const s = new Set<number>()
    while (s.size < k) s.add(int(0, w.length - 1))
    pos.push(...s)
  }
  for (const p of pos) w[p]! ^= int(1, 255)
  return w
}
function codeword(n: number, size: number): Uint8Array {
  const clear = randBytes(size - n)
  if (clear.length) clear[0] = 1
  return ecc.protect(clear, n)
}

function timed(fn: () => unknown, reps: number): [number, number] {
  const times: number[] = []
  for (let i = 0; i < reps; i++) {
    const t0 = performance.now()
    fn()
    times.push(performance.now() - t0)
  }
  times.sort((a, b) => a - b)
  return [times[times.length >> 1]!, times[times.length - 1]!]
}

// Field operations of one repair call, counted from ecc.ts: syndromes n x N each pass (Horner over the word),
// Berlekamp-Massey up to n x (l + 1), Chien N x (deg + 1), omega n x (deg + 1), Forney deg x (n + deg + 3).
function ops(n: number, size: number, deg: number, repaired: boolean, intact: boolean, t: number): number {
  let total = n * size
  if (intact || t === 0) return total
  total += n * (n / 2 + 1)
  if (deg === 0 || deg > t) return total
  total += size * (deg + 1)
  if (!repaired) return total
  return total + n * (deg + 1) + deg * (n + deg + 3) + n * size
}

const driver = `
import sys, importlib.util
spec = importlib.util.spec_from_file_location("ref_eccfmt", sys.argv[1] + "/scripts/ecc/eccfmt.py")
ef = importlib.util.module_from_spec(spec); spec.loader.exec_module(ef)
out = []
for line in sys.stdin:
    p = line.split()
    if not p: continue
    n, t = int(p[0]), int(p[1])
    buf = b"" if p[2] == "-" else bytes.fromhex(p[2])
    try:
        c, k = ef.decode(buf, n, t); out.append("ok %s %d" % (c.hex() or "-", k))
    except ef.EccError as e:
        out.append("refused " + e.kind)
sys.stdout.write("\\n".join(out) + "\\n")
`
function reference(lines: string[]): string[] {
  const r = spawnSync(process.env.PYTHON ?? "python3", ["-I", "-B", "-c", driver, repo], {
    input: lines.join("\n") + "\n",
    maxBuffer: 1 << 30,
    timeout: 100_000,
  })
  if (r.status !== 0) throw new Error(`reference failed: ${r.stderr?.toString().slice(0, 400)}`)
  return r.stdout.toString().split("\n").slice(0, lines.length)
}
function pkg(buf: Uint8Array, n: number, t: number): string {
  const r = ecc.repair(buf, n, t)
  if (r.ok) return `ok ${hex(r.clear)} ${r.repaired}`
  if (r.kind) return `refused ${r.kind}`
  return r.field === "parity" ? "refused short" : `refused ?${JSON.stringify(r)}`
}

function partA(): void {
  const n = 32
  const size = 254
  const handlers = [pb.scheme(1, pb.repeat(0, [pb.u8(0, (r: any) => r.v)])).withLimits({ parity: n }).on(() => {})]
  const word = codeword(n, size)
  const cases: [string, Uint8Array, number][] = [
    ["intact, t=16", word, 16],
    ["16 wrong (max repair), t=16", corrupt(word, 16), 16],
    ["16 wrong in the parity, t=16", corrupt(word, 16, Array.from({ length: 16 }, (_, i) => size - 16 + i)), 16],
    ["17 wrong (near miss), t=16", corrupt(word, 17), 16],
    ["random bytes, t=16", randBytes(size), 16],
    ["1 wrong, t=16", corrupt(word, 1), 16],
    ["16 wrong, default t=0", corrupt(word, 16), 0],
    ["random bytes, default t=0", randBytes(size), 0],
  ]
  console.log(`part A: n=${n}, N=${size}, load ${load()}`)
  let worst = 0
  for (const [name, buf, t] of cases) {
    const r = ecc.repair(buf, n, t)
    const intact = r.ok && r.repaired === 0
    // the degree is the repaired count when it repairs; for a refusal at t=16 random input gives degree 16 (BM)
    const deg = r.ok ? r.repaired : t === 0 ? 0 : 16
    const count = ops(n, size, deg, r.ok && r.repaired > 0, intact, t)
    for (let i = 0; i < 200; i++) ecc.repair(buf, n, t) // warm the JIT
    const [med, slow] = timed(() => ecc.repair(buf, n, t), 3000)
    const [pmed, pslow] = timed(() => pb.BinaryPacker.unpackRepair(buf, t, ...handlers), 3000)
    worst = Math.max(worst, slow, pslow)
    const verdict = r.ok ? `repaired ${r.repaired}` : "refused"
    console.log(
      `  ${name.padEnd(36)} ${verdict.padEnd(12)} ops ~${String(count).padStart(6)} (${(count / (255 * 32)).toFixed(2)} x 255*32)  repair median ${(med * 1000).toFixed(1)} us slowest ${(slow * 1000).toFixed(1)} us; unpack median ${(pmed * 1000).toFixed(1)} us slowest ${(pslow * 1000).toFixed(1)} us`,
    )
  }
  console.log(`  slowest single call in part A: ${worst.toFixed(3)} ms, load ${load()}`)
}

function partB(): void {
  const t0 = performance.now()
  const lines: string[] = []
  const got: string[] = []
  let exceptions = 0
  let slow: [number, string] = [0, ""]
  let written = 0
  for (let n = 1; n <= 32; n++) {
    for (let size = n; size <= 255; size++) {
      for (let kind = 0; kind < 4; kind++) {
        const t = kind !== 3 ? n >> 1 : int(0, n >> 1)
        let buf: Uint8Array
        if (size > 254 || kind === 0) buf = randBytes(size)
        else {
          const k = [Math.max(1, t), t + 1, int(1, Math.max(1, n))][kind - 1]!
          buf = corrupt(codeword(n, size), Math.min(k, size))
        }
        const original = hex(buf)
        const a = performance.now()
        try {
          got.push(pkg(buf, n, t))
        } catch (e: any) {
          exceptions++
          got.push("exception")
        }
        const dt = performance.now() - a
        if (dt > slow[0]) slow = [dt, `n=${n} N=${size} t=${t} kind=${kind}`]
        if (hex(buf) !== original) written++
        lines.push(`${n} ${t} ${hex(buf)}`)
      }
    }
  }
  const want = reference(lines)
  let mismatch = 0
  const examples: string[] = []
  for (let i = 0; i < lines.length; i++) {
    if (got[i] !== want[i]) {
      mismatch++
      if (examples.length < 10) examples.push(`pkg=${got[i]!.slice(0, 40)} ref=${want[i]!.slice(0, 40)} ${lines[i]!.slice(0, 300)}`)
    }
  }
  console.log(
    `part B: n 1..32 x N n..255 x 4 inputs: calls ${lines.length}, mismatches vs reference ${mismatch}, foreign exceptions ${exceptions}, input written ${written}, slowest ${slow[0].toFixed(3)} ms (${slow[1]}), ${((performance.now() - t0) / 1000).toFixed(1)} s, load ${load()}`,
  )
  for (const e of examples) console.log("  " + e)
}

function partC(): void {
  const t0 = performance.now()
  const lines: string[] = []
  const got: string[] = []
  let exceptions = 0
  for (let i = 0; i < 200_000; i++) {
    const n = [2, 3, 4, 5, 6, 8][int(0, 5)]!
    const size = int(n, 40)
    const t = n >> 1
    const buf = randBytes(size)
    try {
      got.push(pkg(buf, n, t))
    } catch {
      exceptions++
      got.push("exception")
    }
    lines.push(`${n} ${t} ${hex(buf)}`)
  }
  const want = reference(lines)
  let mismatch = 0
  let accepted = 0
  for (let i = 0; i < lines.length; i++) {
    if (got[i] !== want[i]) mismatch++
    if (got[i]!.startsWith("ok")) accepted++
  }
  console.log(
    `part C: 200,000 random short buffers (n 2..8, N n..40, t = n/2): accepted ${accepted}, mismatches vs reference ${mismatch}, foreign exceptions ${exceptions}, ${((performance.now() - t0) / 1000).toFixed(1)} s, load ${load()}`,
  )
}

// Part D: a copy of ecc.ts (in the OS temp directory, never in the checkout) where every array read `x[i]!` is
// bounds-checked and LOG[0] and inv(0) throw, run over n 1..32 and many N. A throw would mean an index outside an
// array (typed arrays read `undefined` silently) or a log/inverse of 0.
async function partD(): Promise<void> {
  let code = readFileSync(path.join(repo, "typescript", "src", "ecc.ts"), "utf8")
  let before = ""
  let reads = 0
  while (before !== code) {
    before = code
    code = code.replace(/(\w+)\[([^\[\]]+)\]!(?!=)/, (_m, arr, idx) => {
      reads++
      return `__at(${arr}, ${idx}, "${arr}")`
    })
  }
  code = code.replace("function inv(a: number): number {", 'function inv(a: number): number {\n  if (a === 0) throw new Error("inverse of 0")')
  code += `
function __at(arr: ArrayLike<number>, i: number, name: string): number {
  if (!Number.isInteger(i) || i < 0 || i >= arr.length) throw new RangeError(name + " index " + i + " outside 0.." + (arr.length - 1))
  if (name === "LOG" && i === 0) throw new RangeError("log of 0")
  return arr[i]!
}
`
  const file = path.join(os.tmpdir(), `packbin-ecc-guarded-${process.pid}.ts`)
  writeFileSync(file, code)
  try {
    const g: any = await import(pathToFileURL(file).href)
    let sane = false
    try {
      g.repair(Uint8Array.of(1, 2, 3), 2, 1)
      sane = true
    } catch (e: any) {
      console.log(`  guarded copy fails on a plain call: ${e?.message}`)
    }
    const t0 = performance.now()
    let calls = 0
    let thrown = 0
    let mismatch = 0
    for (let n = 1; n <= 32; n++) {
      for (let size = n; size <= 255; size++) {
        for (let kind = 0; kind < 3; kind++) {
          const t = n >> 1
          const buf = kind === 0 || size > 254 ? randBytes(size) : corrupt(codeword(n, size), Math.min(size, [Math.max(1, t), t + 1][kind - 1]!))
          let a = ""
          try {
            const r = g.repair(buf, n, t)
            a = r.ok ? hex(r.clear) + r.repaired : r.kind ?? r.field
          } catch (e: any) {
            thrown++
            if (thrown < 5) console.log(`  guarded repair threw at n=${n} N=${size}: ${e?.message}`)
          }
          const r2 = ecc.repair(buf, n, t)
          const b = r2.ok ? hex(r2.clear) + r2.repaired : r2.kind ?? r2.field
          if (a && a !== b) mismatch++
          calls++
        }
      }
      for (const z of [new Uint8Array(n), new Uint8Array(254)]) {
        try {
          g.repair(z, n, n >> 1)
        } catch (e: any) {
          thrown++
        }
        calls++
      }
    }
    console.log(`part D: guarded copy (${reads} array reads checked, sane ${sane}): ${calls} repairs of n 1..32 x N n..255: thrown ${thrown}, differs from the package ${mismatch}, ${((performance.now() - t0) / 1000).toFixed(1)} s, load ${load()}`)
  } finally {
    rmSync(file, { force: true })
  }
}

console.log(`seed ${seed}, node ${process.version}`)
const parts = process.argv[4] ?? "abcd"
if (parts.includes("a")) partA()
if (parts.includes("b")) partB()
if (parts.includes("c")) partC()
if (parts.includes("d")) await partD()
clearTimeout(hardStop)
