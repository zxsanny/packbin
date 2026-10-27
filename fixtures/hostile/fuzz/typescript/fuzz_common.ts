// Shared setup of the AZ-2666 TypeScript fuzz probes (fuzz_text.ts, fuzz_ecc.ts); not run on its own.
// Reads the runnable probe's command line (<repo checkout> [seed] [seconds per part]), imports the package sources from
// the checkout, and holds the seeded generator (mulberry32), the findings list, the per-part statistics, the seed
// inputs (text and ECC vectors, the hostile corpus and cases), the mutator, and the reference codecs
// (scripts/text/textfmt.py, scripts/ecc/eccfmt.py), run as one python3 batch per round.
import { spawnSync } from "node:child_process"
import { readFileSync } from "node:fs"
import os from "node:os"
import path from "node:path"
import { pathToFileURL } from "node:url"

export const repo = path.resolve(process.argv[2] ?? ".")
export const seed = Number(process.argv[3] ?? Date.now() % 1e9)
export const budget = Number(process.argv[4] ?? 25) * 1000
export const src = (f: string) => pathToFileURL(path.join(repo, "typescript", "src", f)).href
export const pb: any = await import(src("index.ts"))
export const text: any = await import(src("text.ts"))
export const ecc: any = await import(src("ecc.ts"))
export const T: any = await import(src("text-tables.ts"))

let state = seed >>> 0 || 1
export function rnd(): number {
  state = (state + 0x6d2b79f5) >>> 0
  let t = state
  t = Math.imul(t ^ (t >>> 15), t | 1)
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61)
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296
}
export const int = (lo: number, hi: number) => lo + Math.floor(rnd() * (hi - lo + 1))
export const pick = <X>(xs: readonly X[]): X => xs[Math.floor(rnd() * xs.length)]!
export const randBytes = (n: number) => Uint8Array.from({ length: n }, () => int(0, 255))
export const hex = (b: Uint8Array) => (b.length ? Buffer.from(b).toString("hex") : "-")
export function cat(...parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((s, p) => s + p.length, 0))
  let o = 0
  for (const p of parts) {
    out.set(p, o)
    o += p.length
  }
  return out
}
export function varint(n: number): Uint8Array {
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

export const findings: string[] = []
export const note = (m: string) => {
  if (findings.length < 40) findings.push(m)
}

export class Stats {
  calls = 0
  accepted = 0
  refused = 0
  mismatch = 0
  exceptions = 0
  times: number[] = []
  slowest: [number, string] = [0, ""]
  name: string
  constructor(name: string) {
    this.name = name
  }
  timed<R>(label: string, fn: () => R): R {
    const t0 = performance.now()
    try {
      return fn()
    } finally {
      const dt = performance.now() - t0
      this.calls++
      this.times.push(dt)
      if (dt > this.slowest[0]) this.slowest = [dt, label]
    }
  }
  report(): string {
    const s = [...this.times].sort((a, b) => a - b)
    const med = s.length ? s[s.length >> 1]! : 0
    return `${this.name}: calls ${this.calls}, accepted ${this.accepted}, refused ${this.refused}, mismatches vs reference ${this.mismatch}, foreign exceptions ${this.exceptions}, median ${(med * 1000).toFixed(1)} us, slowest ${this.slowest[0].toFixed(3)} ms (${this.slowest[1].slice(0, 90)})`
  }
}

// One python3 run decodes a batch with the reference codecs: "t <hex>" -> "ok <utf8 hex> <next>" | "refused <kind>";
// "e <n> <t> <hex>" -> "ok <clear hex> <count>" | "refused <kind>".
const driver = `
import sys, importlib.util
repo = sys.argv[1]
def load(name, p):
    spec = importlib.util.spec_from_file_location(name, p)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m
tf = load("ref_textfmt", repo + "/scripts/text/textfmt.py")
ef = load("ref_eccfmt", repo + "/scripts/ecc/eccfmt.py")
tables = tf.Tables.load(repo + "/fixtures/text/tables.json")
out = []
for line in sys.stdin:
    p = line.split()
    if not p:
        continue
    if p[0] == "t":
        buf = b"" if p[1] == "-" else bytes.fromhex(p[1])
        try:
            s, nxt = tf.decode(buf, 0, tables)
            out.append("ok %s %d" % (s.encode("utf-8").hex() or "-", nxt))
        except tf.Refusal as r:
            out.append("refused " + r.kind)
    else:
        n, t = int(p[1]), int(p[2])
        buf = b"" if p[3] == "-" else bytes.fromhex(p[3])
        try:
            c, k = ef.decode(buf, n, t)
            out.append("ok %s %d" % (c.hex() or "-", k))
        except ef.EccError as e:
            out.append("refused " + e.kind)
sys.stdout.write("\\n".join(out) + "\\n")
`
export function reference(lines: string[]): string[] {
  const py = process.env.PYTHON ?? "python3"
  const r = spawnSync(py, ["-I", "-B", "-c", driver, repo], { input: lines.join("\n") + "\n", maxBuffer: 1 << 30, timeout: 120_000 })
  if (r.status !== 0) throw new Error(`reference failed: ${r.error ?? ""} ${r.stderr?.toString().slice(0, 500)}`)
  return r.stdout.toString().split("\n").slice(0, lines.length)
}

const rowsOf = (rel: string) =>
  readFileSync(path.join(repo, rel), "utf8").split("\n").filter((l) => l && !l.startsWith("#")).map((l) => l.trim().split(/\s+/))
const bytesOf = (h: string) => new Uint8Array(Buffer.from(h, "hex"))
export const textSeeds: Uint8Array[] = [] // every field of fixtures/text/vectors.txt
for (const p of rowsOf("fixtures/text/vectors.txt")) {
  if (p[0] === "enc" || p[0] === "alt") textSeeds.push(bytesOf(p[3]!))
  else if (p[0] === "bad") textSeeds.push(bytesOf(p[3] ?? ""))
}
export const eccSeeds: [number, number, Uint8Array][] = [] // (n, t, received) from fixtures/ecc/vectors.txt
for (const p of rowsOf("fixtures/ecc/vectors.txt")) {
  if ((p[0] === "fix" || p[0] === "bad") && p[4] !== "-" && p[4]!.length <= 600) eccSeeds.push([Number(p[2]), Number(p[3]), bytesOf(p[4]!)])
  else if (p[0] === "enc" && p[4] !== "-") eccSeeds.push([Number(p[2]), 0, bytesOf(p[4]!)])
}
export const packets: Uint8Array[] = [] // fixtures/hostile/fuzz/corpus.txt and fixtures/hostile/cases.txt
for (const p of rowsOf("fixtures/hostile/fuzz/corpus.txt")) packets.push(bytesOf(p[2]!))
for (const p of rowsOf("fixtures/hostile/cases.txt")) if (p.length >= 4 && p[3] !== "-") packets.push(bytesOf(p[3]!))

// Bit flips, byte changes, inserts, deletes, cuts, extensions and a rewritten count header.
export function mutate(data: Uint8Array): Uint8Array {
  let buf = [...data]
  const rounds = pick([1, 1, 2, 3, 8])
  for (let r = 0; r < rounds; r++) {
    const op = int(0, 6)
    if (op === 0 && buf.length) buf[int(0, buf.length - 1)]! ^= 1 << int(0, 7)
    else if (op === 1 && buf.length) buf[int(0, buf.length - 1)] = int(0, 255)
    else if (op === 2) buf.splice(int(0, buf.length), 0, int(0, 255))
    else if (op === 3 && buf.length) buf.splice(int(0, buf.length - 1), 1)
    else if (op === 4 && buf.length) buf = buf.slice(0, int(0, buf.length - 1))
    else if (op === 5) buf.push(...randBytes(int(1, 8)))
    else if (op === 6 && buf.length) {
      let off = 0
      while (off < 3 && off < buf.length && buf[off]! & 0x80) off++
      off = Math.min(off + 1, buf.length)
      const n = pick([0, 1, 127, 128, 16383, 16384, 65536, 2097151, int(0, (1 << 21) - 1)])
      buf = [...varint(n), ...buf.slice(off)]
    }
  }
  return Uint8Array.from(buf)
}

const load = () => os.loadavg().map((x) => x.toFixed(2)).join(" ")

// Prints the header and starts the hard stop (a hang ends the run instead of holding a core).
export function start(parts: number): { t0: number; stop: ReturnType<typeof setTimeout> } {
  console.log(`seed ${seed}, budget ${budget / 1000} s per part, node ${process.version}, load ${load()}`)
  const stop = setTimeout(() => {
    console.log("HARD STOP: the run passed its time limit (a hang?)")
    process.exit(3)
  }, budget * parts * 1.5 + 60_000)
  return { t0: performance.now(), stop }
}

export function finish(run: { t0: number; stop: ReturnType<typeof setTimeout> }): void {
  console.log(`total ${((performance.now() - run.t0) / 1000).toFixed(1)} s, load ${load()}`)
  clearTimeout(run.stop)
  if (findings.length) {
    console.log(`FINDINGS (${findings.length} shown):`)
    for (const f of findings) console.log("  " + f)
    process.exitCode = 1
  } else console.log("no findings: no exception escaped, every result equals the reference")
}
