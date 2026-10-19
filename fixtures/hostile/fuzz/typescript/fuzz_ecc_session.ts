// Run: node fuzz_ecc_session.ts <repo checkout> [seed] [seconds per part]   (AZ-2666 probe (a), TypeScript, ECC + session; Node 22.18+, python3 >= 3.9 on PATH or $PYTHON)
// ECC: random buffers, code words with k wrong bytes, cut or extended words, fixtures/ecc/vectors.txt rows and protected
// corpus packets go through ecc.repair and scripts/ecc/eccfmt.py (a different answer is a mismatch), then through
// BinaryPacker.unpackRepair with two schemes that share n; the caller's buffer must stay unchanged. Session: hostile
// payloads on an open session; caller mistakes must be RangeErrors, nothing may throw, and the sender's next payload
// must still be read. Shared setup is fuzz_common.ts next to this file.
import {
  Stats, budget, cat, ecc, eccSeeds, finish, hex, int, mutate, note, packets, pb, pick, randBytes, reference, rnd, start,
} from "./fuzz_common.ts"

const eccSchemes = new Map<number, any[]>()
// Two schemes that share n: a repeat of u8 (type 1), and a string then a list of strings (type 2).
function eccHandlers(n: number): any[] {
  let h = eccSchemes.get(n)
  if (!h) {
    const s1 = pb.scheme(1, pb.repeat(0, [pb.u8(0, (r: any) => r.v)])).withLimits({ parity: n })
    const s2 = pb.scheme(2, pb.utf8(0, (r: any) => r.s), pb.list((r: any) => r.xs, pb.utf8(0, (s: any) => s))).withLimits({ parity: n })
    h = [s1.on(() => {}), s2.on(() => {})]
    eccSchemes.set(n, h)
  }
  return h
}

function flipSome(word: Uint8Array, k: number): Uint8Array {
  const w = word.slice()
  const pos = new Set<number>()
  while (pos.size < k) pos.add(int(0, w.length - 1))
  for (const p of pos) w[p]! ^= int(1, 255)
  return w
}

function eccInput(n: number): [Uint8Array, string] {
  const r = rnd()
  if (r < 0.1) return [mutate(ecc.protect(pick(packets).subarray(0, 254 - n), n)), "corpus packet protected, mutated"]
  const size = pick([n, n + 1, n + 2, 254, 253, 255, 256, int(n, 254), int(n, 254)])
  if (r < 0.25) return [randBytes(size), "random"]
  const clear = randBytes(Math.max(0, Math.min(254 - n, size - n)))
  if (clear.length && rnd() < 0.7) clear[0] = 1 // the repeat-of-u8 scheme reads any clear bytes that start with its type
  const w = Uint8Array.from(ecc.protect(clear, n) as Uint8Array)
  if (r < 0.85) {
    const k = pick([1, n >> 1, (n >> 1) + 1, (n >> 1) + 2, n - (n >> 1), n, int(1, Math.max(1, n)), int(1, Math.max(1, w.length))])
    const kk = Math.max(1, Math.min(k, w.length))
    return [flipSome(w, kk), `codeword+${kk}`]
  }
  if (r < 0.92) return [rnd() < 0.5 ? w.subarray(0, Math.max(0, w.length - 1)).slice() : cat(w, Uint8Array.of(0, 0)), "cut/extended"]
  return [mutate(w), "mutated"]
}

function nextCase(): [number, number, Uint8Array, string] | null {
  if (rnd() < 0.15) {
    const [n, t, received] = pick(eccSeeds)
    if (n === 0) return null
    return rnd() < 0.7 ? [n, t, mutate(received), "ecc vector mutated"] : [n, t, received.slice(), "ecc vector"]
  }
  const n = pick([1, 2, 3, 4, 8, 16, 31, 32, int(1, 32)])
  const t = pick([0, n >> 1, int(0, n >> 1)])
  const [buf, how] = eccInput(n)
  return [n, t, buf, how]
}

function pkgRepair(buf: Uint8Array, n: number, t: number): string {
  const r = ecc.repair(buf, n, t)
  if (r.ok) return `ok ${hex(r.clear)} ${r.repaired}`
  if (r.kind === "uncorrectable" || r.kind === "too_long") return `refused ${r.kind}`
  if (r.field === "parity") return "refused short"
  return `refused ?${JSON.stringify(r)}`
}

function runEcc(deadline: number): void {
  const st = new Stats("ecc repair vs reference (n 1..32, N n..256, t 0..n/2)")
  const pub = new Stats("ecc public unpackRepair (two schemes, one parity)")
  while (performance.now() < deadline) {
    const lines: string[] = []
    const got: string[] = []
    const labels: string[] = []
    for (let i = 0; i < 3000; i++) {
      const c = nextCase()
      if (!c) continue
      const [n, t, buf, how] = c
      const original = hex(buf)
      const label = `n=${n} t=${t} N=${buf.length} ${how}`
      try {
        got.push(st.timed(label, () => pkgRepair(buf, n, t)))
      } catch (e: any) {
        st.exceptions++
        got.push("exception")
        note(`ecc repair threw ${e?.name}: ${e?.message} on ${label} ${hex(buf)}`)
      }
      lines.push(`e ${n} ${t} ${hex(buf)}`)
      labels.push(label)
      try {
        const res = pub.timed(label, () => pb.BinaryPacker.unpackRepair(buf, t, ...eccHandlers(n)))
        if (res.ok) pub.accepted++
        else pub.refused++
      } catch (e: any) {
        pub.exceptions++
        note(`public ecc unpack threw ${e?.name}: ${e?.message} on ${label} ${hex(buf)}`)
      }
      if (hex(buf) !== original) note(`the caller's buffer was written on ${label}`)
    }
    const want = reference(lines)
    for (let i = 0; i < lines.length; i++) {
      if (got[i]!.startsWith("ok")) st.accepted++
      else st.refused++
      if (got[i] !== want[i]) {
        st.mismatch++
        note(`ecc mismatch pkg=${got[i]!.slice(0, 50)} ref=${want[i]!.slice(0, 50)} on ${labels[i]} ${lines[i]!.slice(0, 600)}`)
      }
    }
  }
  console.log(st.report())
  console.log(pub.report())
}

function hostilePayload(good: Uint8Array, n: number): Uint8Array {
  const r = rnd()
  if (r < 0.4) return good
  if (r < 0.7) return mutate(good)
  if (r < 0.8) return randBytes(pick([0, 1, n, 254, 255, 300]))
  return flipSome(good, Math.min(good.length, int(1, Math.max(1, n))))
}

function runSession(deadline: number): void {
  const st = new Stats("session unpackRepair with hostile payloads (next payload still read)")
  const seedBytes = Uint8Array.from({ length: 32 }, (_, i) => i + 1)
  const nonce = new Uint8Array(16)
  let lostSync = 0
  while (performance.now() < deadline) {
    const n = pick([0, 1, 2, 4, 8, 16, 32])
    const t = int(0, n >> 1)
    const sender = pb.PackSession.load(seedBytes)
    const receiver = pb.PackSession.load(seedBytes)
    sender.start(nonce)
    receiver.join(nonce)
    const s1 = pb.scheme(1, pb.utf8(0, (r: any) => r.s)).withLimits({ parity: n })
    const h = s1.on(() => {})
    const steps = int(2, 12)
    for (let step = 0; step < steps; step++) {
      const payload = hostilePayload(sender.pack(s1, { s: `привіт ${step}` }) as Uint8Array, n)
      for (const bad of ["dup", "limit"]) {
        try {
          if (bad === "dup") receiver.unpackRepair(payload, t, h, h)
          else receiver.unpackRepair(payload, (n >> 1) + 1, h)
          note(`session accepted a ${bad} call`)
        } catch (e: any) {
          if (!(e instanceof RangeError)) note(`session ${bad} call threw ${e?.name}`)
        }
      }
      try {
        const res = st.timed(`n=${n} t=${t} N=${payload.length}`, () => receiver.unpackRepair(payload, t, h))
        if (res.ok) st.accepted++
        else st.refused++
      } catch (e: any) {
        st.exceptions++
        note(`session unpack threw ${e?.name}: ${e?.message} on n=${n} ${hex(payload).slice(0, 200)}`)
      }
    }
    let row: any = null
    const res = receiver.unpackRepair(sender.pack(s1, { s: "end" }), t, s1.on((r: any) => (row = r)))
    if (!res.ok || row?.s !== "end") {
      lostSync++
      note(`session lost sync after hostile payloads (n=${n}): ${JSON.stringify(res)}`)
    }
  }
  console.log(st.report() + `, lost sync ${lostSync}`)
}

const run = start(1.5)
runEcc(performance.now() + budget)
runSession(performance.now() + budget / 2)
finish(run)
