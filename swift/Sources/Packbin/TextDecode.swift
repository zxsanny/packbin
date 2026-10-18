/// The decoder of the compact text format. It reads only the payload it is given, allocates nothing sized
/// from a number in the input (the text is built in a buffer of at most 6N + 8 bytes for a payload of N,
/// and never more than 65 539), and stops at the first rule broken.

/// The most UTF-8 bytes a text may hold.
let maxTextBytes = 65_535

extension TextCodec {
    /// The text of the payload of `count` bytes (at least 1) at `base` in `buf`, or nil when a rule of the
    /// contract is broken.
    func decode(_ buf: UnsafeBufferPointer<UInt8>, _ base: Int, _ count: Int) -> String? {
        let p = buf.baseAddress! + base
        let head = p[0]
        let startMode = Int(head >> 2 & 7)
        if startMode == 4 {
            guard head == 0x10, count - 1 <= maxTextBytes, validUTF8(p + 1, count - 1) else { return nil }
            return String(unsafeUninitializedCapacity: count - 1) { out in
                if count > 1 { out.baseAddress!.update(from: p + 1, count: count - 1) }
                return count - 1
            }
        }
        guard startMode < 4 else { return nil }
        let pad = Int(head >> 5)
        let total = 8 * count - pad
        guard total >= 6, p[count - 1] & UInt8((1 << pad) - 1) == 0 else { return nil }

        var ok = true
        let text = String(unsafeUninitializedCapacity: min(6 * count + 8, maxTextBytes + 4)) { out in
            let capacity = out.count
            let o = out.baseAddress!
            var written = 0
            var mode = startMode
            var lock = false
            var pending = false
            var position = 6
            while position < total {
                let v = peek(p, count, position)
                var l = 1
                while l < 16 && v >= limit[mode * 17 + l] { l += 1 }
                if l > total - position {
                    ok = false
                    return 0
                }
                let rank = Int(offset[mode * 17 + l]) + Int(v >> UInt32(16 - l)) - Int(first[mode * 17 + l])
                let symbol = mode * 128 + Int(sorted[mode * 128 + rank])
                position += l
                var c: UInt32
                switch kind[symbol] {
                case TextSymbol.switchMode:
                    if pending { ok = false; return 0 }
                    mode = Int(argument[symbol])
                    continue
                case TextSymbol.capital:
                    if lock || pending { ok = false; return 0 }
                    pending = true
                    continue
                case TextSymbol.lock:
                    if pending { ok = false; return 0 }
                    lock.toggle()
                    continue
                case TextSymbol.escape:
                    if pending { ok = false; return 0 }
                    guard let scalar = escaped(p, count, total, &position) else {
                        ok = false
                        return 0
                    }
                    c = scalar
                case TextSymbol.letter:
                    c = argument[symbol]
                    let upper = capital[symbol]
                    if pending {
                        if upper == 0 { ok = false; return 0 }
                        c = upper
                        pending = false
                    } else if lock && upper != 0 {
                        c = upper
                    }
                default:
                    if pending { ok = false; return 0 }
                    c = argument[symbol]
                }
                let width = c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4
                if written + width > maxTextBytes || written + width > capacity {
                    ok = false
                    return 0
                }
                switch width {
                case 1:
                    o[written] = UInt8(truncatingIfNeeded: c)
                case 2:
                    o[written] = UInt8(truncatingIfNeeded: 0xC0 | c >> 6)
                    o[written + 1] = UInt8(truncatingIfNeeded: 0x80 | c & 0x3F)
                case 3:
                    o[written] = UInt8(truncatingIfNeeded: 0xE0 | c >> 12)
                    o[written + 1] = UInt8(truncatingIfNeeded: 0x80 | c >> 6 & 0x3F)
                    o[written + 2] = UInt8(truncatingIfNeeded: 0x80 | c & 0x3F)
                default:
                    o[written] = UInt8(truncatingIfNeeded: 0xF0 | c >> 18)
                    o[written + 1] = UInt8(truncatingIfNeeded: 0x80 | c >> 12 & 0x3F)
                    o[written + 2] = UInt8(truncatingIfNeeded: 0x80 | c >> 6 & 0x3F)
                    o[written + 3] = UInt8(truncatingIfNeeded: 0x80 | c & 0x3F)
                }
                written += width
            }
            if pending { ok = false; return 0 }
            return written
        }
        return ok ? text : nil
    }

    /// The 16 bits of the payload `p` of `count` bytes from bit `position`; bits past the end read as 0.
    @inline(__always)
    private func peek(_ p: UnsafePointer<UInt8>, _ count: Int, _ position: Int) -> UInt32 {
        let at = position >> 3
        var v: UInt32
        if at + 2 < count {
            v = UInt32(p[at]) << 16 | UInt32(p[at + 1]) << 8 | UInt32(p[at + 2])
        } else {
            v = UInt32(p[at]) << 16
            if at + 1 < count { v |= UInt32(p[at + 1]) << 8 }
        }
        return v >> UInt32(8 - position & 7) & 0xFFFF
    }

    /// The code point of the 1 to 4 UTF-8 bytes (8 bits each, no alignment) at bit `position`, which moves
    /// past them; nil when they are cut short or are not well-formed UTF-8.
    private func escaped(_ p: UnsafePointer<UInt8>, _ count: Int, _ total: Int, _ position: inout Int) -> UInt32? {
        @inline(__always) func byte(_ at: Int) -> UInt32? { at + 8 > total ? nil : peek(p, count, at) >> 8 }
        guard let b0 = byte(position) else { return nil }
        let n = b0 < 0x80 ? 1 : b0 >> 5 == 6 ? 2 : b0 >> 4 == 14 ? 3 : b0 >> 3 == 30 ? 4 : 0
        guard n > 0 else { return nil }
        var b1: UInt32 = 0
        var b2: UInt32 = 0
        var b3: UInt32 = 0
        if n > 1 {
            guard let x = byte(position + 8) else { return nil }
            b1 = x
        }
        if n > 2 {
            guard let x = byte(position + 16) else { return nil }
            b2 = x
        }
        if n > 3 {
            guard let x = byte(position + 24) else { return nil }
            b3 = x
        }
        position += 8 * n
        switch n {
        case 1:
            return b0
        case 2:
            guard b0 >= 0xC2, b1 & 0xC0 == 0x80 else { return nil }
            return (b0 & 0x1F) << 6 | b1 & 0x3F
        case 3:
            let low: UInt32 = b0 == 0xE0 ? 0xA0 : 0x80
            let high: UInt32 = b0 == 0xED ? 0x9F : 0xBF
            guard b1 >= low, b1 <= high, b2 & 0xC0 == 0x80 else { return nil }
            return (b0 & 0x0F) << 12 | (b1 & 0x3F) << 6 | b2 & 0x3F
        default:
            let low: UInt32 = b0 == 0xF0 ? 0x90 : 0x80
            let high: UInt32 = b0 == 0xF4 ? 0x8F : 0xBF
            guard b0 <= 0xF4, b1 >= low, b1 <= high, b2 & 0xC0 == 0x80, b3 & 0xC0 == 0x80 else { return nil }
            return (b0 & 0x07) << 18 | (b1 & 0x3F) << 12 | (b2 & 0x3F) << 6 | b3 & 0x3F
        }
    }

    /// Whether the `count` bytes at `p` are well-formed UTF-8: no stray or missing continuation byte, no
    /// overlong form, no surrogate and nothing above U+10FFFF.
    private func validUTF8(_ p: UnsafePointer<UInt8>, _ count: Int) -> Bool {
        var i = 0
        while i < count {
            let b0 = p[i]
            if b0 < 0x80 {
                i += 1
                continue
            }
            let n = b0 >= 0xF0 ? 4 : b0 >= 0xE0 ? 3 : 2
            guard b0 >= 0xC2, b0 <= 0xF4, i + n <= count else { return false }
            let b1 = p[i + 1]
            let low: UInt8 = b0 == 0xE0 ? 0xA0 : b0 == 0xF0 ? 0x90 : 0x80
            let high: UInt8 = b0 == 0xED ? 0x9F : b0 == 0xF4 ? 0x8F : 0xBF
            guard b1 >= low, b1 <= high else { return false }
            if n > 2 && p[i + 2] & 0xC0 != 0x80 { return false }
            if n > 3 && p[i + 3] & 0xC0 != 0x80 { return false }
            i += n
        }
        return true
    }
}
