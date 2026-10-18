/// The encoder of the compact text format: the optimal parse of the contract (fewest bits, then the
/// smallest first-symbol index at every step), found by dynamic programming from the end over the 8
/// states (mode, capital lock). Costs are integers. The loops index raw pointers, so a text of 65 535
/// characters is parsed in a few milliseconds, and in a debug build in well under a second.

/// The edges of a character below `textTableRange`, per state (mode * 2 + lock): `first` and `second` are
/// the symbols of its letter, capital or shared edge (-1: the state has none, `second` -1: one symbol),
/// `bits` their code lengths, `cost` the cheaper of that edge and the escape edge.
struct TextEdgeTables: @unchecked Sendable {
    let first: UnsafePointer<Int16>
    let second: UnsafePointer<Int16>
    let bits: UnsafePointer<Int32>
    let cost: UnsafePointer<Int32>
    /// The bits of the `ESC` symbol in each state, before the 8 bits of each UTF-8 byte.
    let escapeBits: UnsafePointer<Int32>
    /// 1 for a capital of a letter of any text mode.
    let isCapital: UnsafePointer<UInt8>

    init(_ codec: TextCodec) {
        var first = [Int16](repeating: -1, count: textTableRange * 8)
        var second = [Int16](repeating: -1, count: textTableRange * 8)
        var bits = [Int32](repeating: 0, count: textTableRange * 8)
        var cost = [Int32](repeating: 0, count: textTableRange * 8)
        var capital = [UInt8](repeating: 0, count: textTableRange)
        for c in 0..<textTableRange {
            for m in 0..<3 where codec.upperLetter[m * textTableRange + c] >= 0 { capital[c] = 1 }
            for s in 0..<8 {
                let mode = s >> 1
                let lock = s & 1
                let at = c * 8 + s
                let base = mode * 128
                var f = -1
                var g = -1
                var b: Int32 = 0
                if mode == 3 {
                    let j = Int(codec.numberIndex[c])
                    if j >= 0 {
                        f = j
                        b = Int32(codec.length[base + j])
                    }
                } else {
                    let lower = Int(codec.lowerLetter[mode * textTableRange + c])
                    let upper = Int(codec.upperLetter[mode * textTableRange + c])
                    let shared = Int(codec.sharedIndex[c])
                    if lower >= 0 {
                        if lock == 0 || codec.capital[base + lower] == 0 {
                            f = lower
                            b = Int32(codec.length[base + lower])
                        }
                    } else if upper >= 0 {
                        if lock == 1 {
                            f = upper
                            b = Int32(codec.length[base + upper])
                        } else {
                            let cap = TextCodec.capitalSymbol(mode)
                            f = cap
                            g = upper
                            b = Int32(codec.length[base + cap]) + Int32(codec.length[base + upper])
                        }
                    } else if shared >= 0 {
                        f = codec.letters[mode] + shared
                        b = Int32(codec.length[base + f])
                    }
                }
                let escape = Int32(codec.length[base + TextCodec.escapeSymbol(mode)]) + 8 * (c < 0x80 ? 1 : 2)
                first[at] = Int16(f)
                second[at] = Int16(g)
                bits[at] = b
                cost[at] = f >= 0 && b < escape ? b : escape
            }
        }
        self.first = immortal(first)
        self.second = immortal(second)
        self.bits = immortal(bits)
        self.cost = immortal(cost)
        self.isCapital = immortal(capital)
        escapeBits = immortal((0..<8).map { Int32(codec.length[$0 / 2 * 128 + TextCodec.escapeSymbol($0 / 2)]) })
    }
}

let textEdges = TextEdgeTables(textCodec)

/// A bit sink over bytes already allocated, most significant bit first.
private struct BitWriter {
    let bytes: UnsafeMutablePointer<UInt8>
    var index = 0
    var acc: UInt64 = 0
    var count = 0

    @inline(__always)
    mutating func put(_ value: UInt32, _ bits: Int) {
        acc = acc << UInt64(bits) | UInt64(value)
        count += bits
        while count >= 8 {
            bytes[index] = UInt8(truncatingIfNeeded: acc >> UInt64(count - 8))
            index += 1
            count -= 8
        }
    }

    /// The last byte, filled up with zero bits.
    mutating func finish() {
        if count > 0 { bytes[index] = UInt8(truncatingIfNeeded: acc << UInt64(8 - count)) }
    }
}

extension TextCodec {
    /// The field of `text` (at most 65 535 UTF-8 bytes): the varint count, then the payload, compact when
    /// that is strictly smaller than the raw payload.
    func encode(_ text: String) -> [UInt8] {
        if text.utf8.isEmpty { return [0] }
        var copy = text
        return copy.withUTF8 { encodeBytes($0) }
    }

    private func encodeBytes(_ utf8: UnsafeBufferPointer<UInt8>) -> [UInt8] {
        let rawLength = utf8.count
        let scalars = UnsafeMutablePointer<UInt32>.allocate(capacity: rawLength)
        defer { scalars.deallocate() }
        var n = 0
        var hasCapital = false
        var i = 0
        while i < rawLength {
            let b0 = UInt32(utf8[i])
            var c = b0
            if b0 >= 0xF0 {
                c = (b0 & 0x07) << 18 | UInt32(utf8[i + 1] & 0x3F) << 12 | UInt32(utf8[i + 2] & 0x3F) << 6 | UInt32(utf8[i + 3] & 0x3F)
                i += 4
            } else if b0 >= 0xE0 {
                c = (b0 & 0x0F) << 12 | UInt32(utf8[i + 1] & 0x3F) << 6 | UInt32(utf8[i + 2] & 0x3F)
                i += 3
            } else if b0 >= 0xC0 {
                c = (b0 & 0x1F) << 6 | UInt32(utf8[i + 1] & 0x3F)
                i += 2
            } else {
                i += 1
            }
            if Int(c) < textTableRange && textEdges.isCapital[Int(c)] != 0 { hasCapital = true }
            scalars[n] = c
            n += 1
        }
        let f = UnsafeMutablePointer<Int32>.allocate(capacity: 8 * (n + 1))
        defer { f.deallocate() }
        parse(scalars, n, f, hasCapital)

        var start = 0
        for m in 1..<4 where f[m * 2] < f[start * 2] { start = m }
        let bits = 6 + Int(f[start * 2])
        let size = (bits + 7) / 8
        let compact = size < 1 + rawLength
        let payload = compact ? size : 1 + rawLength
        let headerLength = payload < 0x80 ? 1 : payload < 0x4000 ? 2 : 3
        return [UInt8](unsafeUninitializedCapacity: headerLength + payload) { out, filled in
            var rest = payload
            for k in 0..<headerLength {
                out[k] = UInt8(truncatingIfNeeded: rest) & 0x7F | (k + 1 < headerLength ? 0x80 : 0)
                rest >>= 7
            }
            let body = out.baseAddress! + headerLength
            if compact {
                var writer = BitWriter(bytes: body)
                writer.put(UInt32((8 * size - bits) << 3 | start), 6)
                write(scalars, n, f, start, hasCapital, &writer)
                writer.finish()
            } else {
                body[0] = 0x10
                (body + 1).update(from: utf8.baseAddress!, count: rawLength)
            }
            filled = headerLength + payload
        }
    }

    /// Fills `f` with the cheapest cost of finishing from each character and state: 8 lanes a character
    /// (state = mode * 2 + lock), n + 1 rows, the last 0. A lane is the cheapest edge that consumes the
    /// character, plus what follows, closed over the control edges. A text with no capital never gains from
    /// the capital lock (a parse that locks is the same parse without the LOCK symbols, which costs fewer
    /// bits), so its odd lanes are not computed.
    private func parse(_ scalars: UnsafePointer<UInt32>, _ n: Int, _ f: UnsafeMutablePointer<Int32>, _ wide: Bool) {
        let step = wide ? 1 : 2
        let edges = textEdges
        let e = UnsafeMutablePointer<Int32>.allocate(capacity: 8)
        defer { e.deallocate() }
        for s in 0..<8 { f[8 * n + s] = 0 }
        var i = n - 1
        while i >= 0 {
            let c = scalars[i]
            let row = f + 8 * i
            let next = row + 8
            var s = 0
            if Int(c) < textTableRange {
                let cost = edges.cost + Int(c) * 8
                while s < 8 {
                    e[s] = cost[s] &+ next[s]
                    s += step
                }
            } else {
                let extra: Int32 = c < 0x800 ? 16 : c < 0x10000 ? 24 : 32
                while s < 8 {
                    e[s] = edges.escapeBits[s] &+ extra &+ next[s]
                    s += step
                }
            }
            s = 0
            while s < 8 {
                let from = reach + s * 8
                var best = from[0] &+ e[0]
                var t = step
                while t < 8 {
                    let v = from[t] &+ e[t]
                    if v < best { best = v }
                    t += step
                }
                row[s] = best
                s += step
            }
            i -= 1
        }
    }

    /// Walks the optimal parse from the start state and writes its symbols.
    private func write(_ scalars: UnsafePointer<UInt32>, _ n: Int, _ f: UnsafePointer<Int32>, _ start: Int,
                       _ wide: Bool, _ writer: inout BitWriter) {
        let edges = textEdges
        var state = start * 2
        var i = 0
        while i < n {
            let mode = state >> 1
            let lock = state & 1
            let row = f + 8 * i
            let want = row[state]
            let after = row[8 + state]
            let c = scalars[i]
            let escape = TextCodec.escapeSymbol(mode)
            let escapeBits = edges.escapeBits[state] + (c < 0x80 ? 8 : c < 0x800 ? 16 : c < 0x10000 ? 24 : 32)
            // The edge with the smallest first symbol among those on an optimal path.
            var best = Int.max
            var target = -1
            var raw = false
            var second = -1
            if Int(c) < textTableRange {
                let at = Int(c) * 8 + state
                let first = Int(edges.first[at])
                if first >= 0 && edges.bits[at] &+ after == want {
                    best = first
                    second = Int(edges.second[at])
                }
            }
            if escape < best && escapeBits &+ after == want {
                best = escape
                second = -1
                raw = true
            }
            for t in 0..<4 where t != mode {
                let sym = TextCodec.switchSymbol(mode, t)
                if sym < best && Int32(length[mode * 128 + sym]) &+ row[t * 2 + lock] == want {
                    best = sym
                    target = t * 2 + lock
                }
            }
            if wide && mode < 3 {
                let sym = TextCodec.lockSymbol(mode)
                if sym < best && Int32(length[mode * 128 + sym]) &+ row[mode * 2 + 1 - lock] == want {
                    best = sym
                    target = mode * 2 + 1 - lock
                }
            }
            writer.put(code[mode * 128 + best], Int(length[mode * 128 + best]))
            if target >= 0 {
                state = target
                continue
            }
            if second >= 0 { writer.put(code[mode * 128 + second], Int(length[mode * 128 + second])) }
            if raw { putUTF8(c, &writer) }
            i += 1
        }
    }

    /// The UTF-8 bytes of the code point `c`, 8 bits each.
    private func putUTF8(_ c: UInt32, _ writer: inout BitWriter) {
        if c < 0x80 {
            writer.put(c, 8)
        } else if c < 0x800 {
            writer.put(0xC0 | c >> 6, 8)
            writer.put(0x80 | c & 0x3F, 8)
        } else if c < 0x10000 {
            writer.put(0xE0 | c >> 12, 8)
            writer.put(0x80 | c >> 6 & 0x3F, 8)
            writer.put(0x80 | c & 0x3F, 8)
        } else {
            writer.put(0xF0 | c >> 18, 8)
            writer.put(0x80 | c >> 12 & 0x3F, 8)
            writer.put(0x80 | c >> 6 & 0x3F, 8)
            writer.put(0x80 | c & 0x3F, 8)
        }
    }
}
