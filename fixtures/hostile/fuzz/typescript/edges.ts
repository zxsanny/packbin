// Run: node edges.ts <repo checkout>   (AZ-2666 probe (d), TypeScript)
// The AC-1 and AC-2 edge cases a random run is unlikely to hit, one line each: PASS, FAIL or INFO. Text: varint
// boundaries, a count far above the bytes present, the 65,535 boundary (compact and raw), ESC cut at every byte, pad,
// mode, CAP and LOCK rules, duplicate dictionary keys in three byte forms, "__proto__" as a key. ECC: 254/255 bytes,
// shorter than n, exactly n, the caller's buffer and the check order of a dispatch.
import os from "node:os"
import path from "node:path"
import { pathToFileURL } from "node:url"

const repo = path.resolve(process.argv[2] ?? ".")
const src = (f: string) => pathToFileURL(path.join(repo, "typescript", "src", f)).href
const pb: any = await import(src("index.ts"))
const T: any = await import(src("text-tables.ts"))
const text: any = await import(src("text.ts"))
const ecc: any = await import(src("ecc.ts"))
const hardStop = setTimeout(() => {
  console.log("HARD STOP after 100 s")
  process.exit(3)
}, 100_000)

let fails = 0
const check = (name: string, ok: boolean, detail = "") => {
  if (!ok) fails++
  console.log(`${ok ? "PASS" : "FAIL"} ${name}${detail ? ": " + detail : ""}`)
}
const info = (name: string, detail: string) => console.log(`INFO ${name}: ${detail}`)

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
const SW = (m: number, t: number) => CODES[m]![m === 3 ? 15 + t : letters(m) + 32 + (t < m ? t : t - 1)]!
const CAP = (m: number) => CODES[m]![letters(m) + 35]!
const LOCK = (m: number) => CODES[m]![letters(m) + 36]!
const ESC = (m: number) => CODES[m]![m === 3 ? 18 : letters(m) + 37]!
const sym = (m: number, ch: string) => {
  const cp = ch.codePointAt(0)!
  if (m === 3) return CODES[m]![T.NUMSET.indexOf(cp)]!
  const i = ALPHA[m]!.indexOf(cp)
  return CODES[m]![i >= 0 ? i : letters(m) + T.SHARED.indexOf(cp)]!
}
const bytesOf = (s: string): [number, number][] => [...Buffer.from(s, "utf8")].map((b) => [b, 8])
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
function cat(...parts: Uint8Array[]): Uint8Array {
  const out = new Uint8Array(parts.reduce((s, p) => s + p.length, 0))
  let o = 0
  for (const p of parts) {
    out.set(p, o)
    o += p.length
  }
  return out
}
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
const B = (...xs: number[]) => Uint8Array.from(xs)
function kindOf(buf: Uint8Array): string {
  try {
    const r = text.decodeText(buf, 0)
    return r.ok ? `ok:${Buffer.byteLength(r.value, "utf8")}:${r.next}` : r.kind
  } catch (e: any) {
    return `EXC ${e?.name}: ${e?.message}`
  }
}
const rep = <X>(n: number, x: X): X[] => Array.from({ length: n }, () => x)

function textEdges(): void {
  for (const n of [127, 128, 16383, 16384, 2097151]) check(`varint ${n} (${varint(n).length} B), buffer cut after it: short`, kindOf(varint(n)) === "short")
  check("varint 4 bytes refused", kindOf(B(0x80, 0x80, 0x80, 0x01)) === "varint")
  check("varint 3 bytes all continuation refused", kindOf(B(0x80, 0x80, 0x80)) === "varint")
  check("varint non-minimal 80 00 refused", kindOf(B(0x80, 0x00)) === "varint")
  check("varint non-minimal 80 80 00 refused", kindOf(B(0x80, 0x80, 0x00)) === "varint")
  check("varint cut inside (80) short", kindOf(B(0x80)) === "short")
  const t0 = performance.now()
  const k = kindOf(cat(varint(2097151), B(0, 1, 2)))
  const dt = performance.now() - t0
  check("count 2,097,151 with 3 bytes present: short, nothing sized from the count", k === "short" && dt < 10, `${(dt * 1000).toFixed(0)} us`)
  check("empty buffer short", kindOf(B()) === "short")
  check("count 0 is the empty text", kindOf(B(0)) === "ok:0:1")
  for (const mode of [5, 6, 7]) check(`start mode ${mode} refused`, kindOf(B(1, mode << 2)) === "mode")
  for (const first of [0x11, 0x12, 0x13, 0x30, 0xf0]) check(`raw first byte ${first.toString(16)} refused`, kindOf(B(2, first, 0x41)) === "raw")
  check("pad 7 in a 1-byte payload refused", kindOf(B(1, 0xe0)) === "pad")
  check("pad 3 in a 1-byte payload refused", kindOf(B(1, 0x60)) === "pad")
  check("pad 2 in a 1-byte payload is the empty text", kindOf(B(1, 0x40)) === "ok:0:2")
  const o = sym(1, "о")
  const sp = sym(1, " ")
  check("compact 65,535 bytes accepted", kindOf(stream(1, [...rep(32767, o), sp])).startsWith("ok:65535"))
  check("compact 65,536 bytes refused: length", kindOf(stream(1, rep(32768, o))) === "length")
  const e4: [number, number][] = [ESC(1), ...bytesOf("😀")]
  check("compact 65,532 + one 4-byte ESC = 65,536 refused: length", kindOf(stream(1, [...rep(32766, o), ...e4])) === "length")
  check("compact 65,531 + one 4-byte ESC = 65,535 accepted", kindOf(stream(1, [...rep(32765, o), sp, ...e4])).startsWith("ok:65535"))
  const body = new Uint8Array(65536).fill(0x61)
  check("raw 65,535 bytes accepted", kindOf(cat(varint(65536), B(0x10), body.subarray(0, 65535))).startsWith("ok:65535"))
  check("raw 65,536 bytes refused: length", kindOf(cat(varint(65537), B(0x10), body)) === "length")
  const badTail = body.slice()
  badTail[65535] = 0xff
  info("raw 65,536 bytes ending in an invalid byte", `refused as '${kindOf(cat(varint(65537), B(0x10), badTail))}' (length is checked before the UTF-8 decode)`)
  check("raw bad UTF-8 refused", kindOf(B(3, 0x10, 0xc3, 0x28)) === "utf8")
  check("raw surrogate refused", kindOf(B(4, 0x10, 0xed, 0xa0, 0x80)) === "utf8")
  check("raw above U+10FFFF refused", kindOf(B(5, 0x10, 0xf4, 0x90, 0x80, 0x80)) === "utf8")
  const bom = text.decodeText(B(4, 0x10, 0xef, 0xbb, 0xbf), 0)
  check("raw BOM kept", bom.ok && bom.value === "﻿")
  const full = bytesOf("😀")
  for (let cut = 0; cut < 4; cut++) check(`ESC with ${cut} of 4 bytes then the end: esc`, kindOf(stream(0, [ESC(0), ...full.slice(0, cut)])) === "esc")
  for (const lead of [0x80, 0xbf, 0xf8, 0xff]) check(`ESC lead ${lead.toString(16)}: utf8`, kindOf(stream(0, [ESC(0), [lead, 8]])) === "utf8")
  for (const [seq, what] of [
    [[0xc0, 0x80], "overlong 2"], [[0xe0, 0x9f, 0xbf], "overlong 3"], [[0xf0, 0x8f, 0xbf, 0xbf], "overlong 4"],
    [[0xed, 0xa0, 0x80], "surrogate"], [[0xf4, 0x90, 0x80, 0x80], "above 10FFFF"], [[0xf5, 0x80, 0x80, 0x80], "lead f5"],
    [[0xc3, 0x41], "bad continuation"],
  ] as [number[], string][]) {
    check(`ESC ${what}: utf8`, kindOf(stream(0, [ESC(0), ...seq.map((b) => [b, 8] as [number, number])])) === "utf8")
  }
  check("ESC U+10FFFF accepted", kindOf(stream(0, [ESC(0), ...bytesOf("\u{10ffff}")])).startsWith("ok:4"))
  const a = sym(0, "а")
  const ap = sym(0, "'")
  check("CAP at the end: cap", kindOf(stream(0, [CAP(0)])) === "cap")
  check("CAP then apostrophe: cap", kindOf(stream(0, [CAP(0), ap])) === "cap")
  check("CAP CAP: cap", kindOf(stream(0, [CAP(0), CAP(0), a])) === "cap")
  check("CAP then LOCK: cap", kindOf(stream(0, [CAP(0), LOCK(0), a])) === "cap")
  check("LOCK then CAP: cap", kindOf(stream(0, [LOCK(0), CAP(0), a])) === "cap")
  check("CAP then switch: cap", kindOf(stream(0, [CAP(0), SW(0, 2), sym(2, "a")])) === "cap")
  check("CAP then ESC: cap", kindOf(stream(0, [CAP(0), ESC(0), [0x41, 8]])) === "cap")
  check("CAP then space: cap", kindOf(stream(0, [CAP(0), sym(0, " ")])) === "cap")
  const r = text.decodeText(stream(0, [LOCK(0), a, SW(0, 3), sym(3, "1"), SW(3, 0), a, ap]), 0)
  check("LOCK survives the number mode", r.ok && r.value === "А1А'", JSON.stringify(r.value))
  const [lc, ll] = LOCK(0)
  check("a code cut by the end of the payload: code", kindOf(stream(0, [[lc >>> (ll - 10), 10]])) === "code")
  const f = stream(0, [a, a])
  const pad = f[1]! >> 5
  const g = f.slice()
  g[g.length - 1]! |= 1
  check(`pad bit set (pad ${pad}): pad`, pad > 0 && kindOf(g) === "pad")
  // duplicate keys written in three byte forms
  const d = pb.scheme(1, pb.dict((r: any) => r.d, pb.u8(0, (v: any) => v)))
  const compact = pb.BinaryPacker.pack(pb.scheme(1, pb.utf8(0, (r: any) => r.s)), { s: "ключ" }).subarray(1)
  const kb = new Uint8Array(Buffer.from("ключ", "utf8"))
  const raw = cat(varint(1 + kb.length), B(0x10), kb)
  const escaped = stream(0, [ESC(0), ...bytesOf("к"), ...[..."люч"].map((c) => sym(0, c))])
  for (const [name, k1, k2] of [["compact + raw", compact, raw], ["raw + escaped", raw, escaped], ["compact + escaped", compact, escaped]] as [string, Uint8Array, Uint8Array][]) {
    const res = pb.BinaryPacker.unpack(cat(B(1, 2, 0), k1, B(5), k2, B(6)), d.on(() => {}))
    check(`duplicate key, ${name}: refused`, !res.ok && res.needed === 0, JSON.stringify(res))
  }
  const nfc = new Uint8Array(Buffer.from("é", "utf8"))
  const nfd = new Uint8Array(Buffer.from("é", "utf8"))
  const res = pb.BinaryPacker.unpack(cat(B(1, 2, 0), varint(1 + nfc.length), B(0x10), nfc, B(5), varint(1 + nfd.length), B(0x10), nfd, B(6)), d.on(() => {}))
  info("keys NFC 'é' and NFD 'e+U+0301'", res.ok ? "accepted as two keys (no normalization; Swift F47 differs)" : "refused")
  let row: any = null
  const proto = new Uint8Array(Buffer.from("__proto__", "utf8"))
  const pr = pb.BinaryPacker.unpack(cat(B(1, 1, 0), varint(1 + proto.length), B(0x10), proto, B(7)), d.on((x: any) => (row = x)))
  check("'__proto__' key is an own entry, not the prototype", pr.ok && Object.getPrototypeOf(row.d) === Object.prototype && Object.hasOwn(row.d, "__proto__") && row.d["__proto__"] === 7)
}

function eccEdges(): void {
  const s = (n: number, t = 1) => pb.scheme(t, pb.u8(0, (r: any) => r.v)).withLimits({ parity: n })
  for (const n of [1, 2, 32]) {
    const h = s(n).on(() => {})
    let r = pb.BinaryPacker.unpack(new Uint8Array(255), h)
    check(`n=${n}: 255 bytes too_long before arithmetic`, r.kind === "too_long" && r.length === 255)
    r = pb.BinaryPacker.unpack(new Uint8Array(n - 1), h)
    check(`n=${n}: ${n - 1} bytes short naming parity`, r.field === "parity" && r.needed === n)
    r = pb.BinaryPacker.unpack(new Uint8Array(n), h)
    check(`n=${n}: exactly n zero bytes (empty clear) -> short 1`, !r.ok && r.needed === 1, JSON.stringify(r))
    const clear = new Uint8Array(254 - n)
    clear[0] = 1
    clear[1] = 7
    r = pb.BinaryPacker.unpack(ecc.protect(clear, n), h)
    check(`n=${n}: 254-byte intact message reads to trailing`, !r.ok && r.needed === 0 && r.left === 252 - n, JSON.stringify(r))
  }
  const r0 = pb.BinaryPacker.unpack(cat(B(1, 5), new Uint8Array(300)), s(0).on(() => {}))
  check("n=0: 302 bytes is not too_long (unprotected rules)", !r0.ok && r0.left === 300, JSON.stringify(r0))
  const n = 8
  const h = s(n).on(() => {})
  const good = pb.BinaryPacker.pack(s(n), { v: 9 }) as Uint8Array
  const bad = good.slice()
  bad[0]! ^= 0x55
  bad[bad.length - 1]! ^= 0x11
  const before = Buffer.from(bad).toString("hex")
  let row: any = null
  const rr = pb.BinaryPacker.unpackRepair(bad, 4, s(n).on((x: any) => (row = x)))
  check("repair of 2 bytes returns the row, count 2", rr.ok && rr.repaired === 2 && row?.v === 9, JSON.stringify(rr))
  check("the caller's buffer is unchanged after a repair", Buffer.from(bad).toString("hex") === before)
  pb.BinaryPacker.unpackRepair(bad.buffer, 4, h)
  check("an ArrayBuffer of the caller is unchanged", Buffer.from(bad).toString("hex") === before)
  const h1 = s(4, 1).on(() => {})
  const h1b = s(4, 1).on(() => {})
  const h2 = s(2, 2).on(() => {})
  for (const [name, handlers, lim, want] of [
    ["duplicate + mix: duplicate named first", [h1, h1b, h2], 0, "duplicate"],
    ["mix + bad limit: mix named first", [h1, h2], 9, "declare"],
    ["bad limit", [h1], 3, "limit"],
    ["negative limit", [h1], -1, "limit"],
    ["fractional limit", [h1], 1.5, "limit"],
    ["NaN limit", [h1], NaN, "limit"],
  ] as [string, any[], number, string][]) {
    try {
      pb.BinaryPacker.unpackRepair(B(1), lim, ...handlers)
      check(name, false, "accepted")
    } catch (e: any) {
      check(name, e instanceof RangeError && String(e.message).includes(want), `${e?.name}: ${e?.message}`)
    }
  }
  try {
    ;(pb.BinaryPacker.unpack as any)(B(1))
    check("empty handler list refused", false, "accepted")
  } catch (e: any) {
    info("empty handler list (JavaScript caller)", `${e?.name}: ${e?.message}`)
  }
}

console.log(`node ${process.version}, load ${os.loadavg().map((x) => x.toFixed(2)).join(" ")}`)
textEdges()
eccEdges()
console.log(`${fails} FAIL, load ${os.loadavg().map((x) => x.toFixed(2)).join(" ")}`)
clearTimeout(hardStop)
process.exitCode = fails ? 1 : 0
