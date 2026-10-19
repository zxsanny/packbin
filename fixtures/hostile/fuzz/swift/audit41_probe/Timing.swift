// AZ-2666 audit probe, timing and amplification modes: ecc-worst, text-amp, text-long and dictkey
// (F47 and its fix).

import Foundation
import Packbin

func eccWorst(_ iterations: Int) throws -> Int32 {
    var r = Rng(41)
    let n = 32
    let s = try Scheme(0x40, .bytes(0, "b", size: 221)).withLimits(parity: n)
    var full: [Double] = [], random: [Double] = [], e17: [Double] = [], detect: [Double] = [], intact: [Double] = []
    var good = 0, refused = 0
    for _ in 0..<iterations {
        var clear: [UInt8] = [0x40]
        for _ in 0..<221 { clear.append(r.byte()) }
        let word = protectRef(clear, n)
        var pos = Array(0..<254)
        for i in 0..<17 { pos.swapAt(i, i + r.below(254 - i)) }
        var buf = word
        for e in 0..<16 { buf[pos[e]] ^= UInt8(1 + r.below(255)) }
        var a = now()
        if let (_, c) = try? unpackMapRepair(buf, limit: 16, [s]), c == 16 { good += 1 }
        full.append(seconds(a))
        let rnd = (0..<254).map { _ in r.byte() }
        a = now()
        if (try? unpackMapRepair(rnd, limit: 16, [s])) == nil { refused += 1 }
        random.append(seconds(a))
        buf = word
        for e in 0..<17 { buf[pos[e]] ^= UInt8(1 + r.below(255)) }
        a = now()
        _ = try? unpackMapRepair(buf, limit: 16, [s])
        e17.append(seconds(a))
        a = now()
        _ = try? unpackMapRepair(buf, limit: 0, [s])
        detect.append(seconds(a))
        a = now()
        _ = try? unpackMapRepair(word, limit: 16, [s])
        intact.append(seconds(a))
    }
    print("mode=ecc-worst n=32 N=254 iterations=\(iterations) (each call includes the 222-byte walk)")
    stats("t16_16_errors_repaired", full)
    stats("t16_random_buffer_refused", random)
    stats("t16_17_errors_refused", e17)
    stats("t0_damaged_detect_only", detect)
    stats("t16_intact", intact)
    print("outcomes repaired16=\(good) random_refused=\(refused)")
    print("peak_rss_kb=\(peakRSSKB()) traps=0")
    print("result=\(good == iterations ? "PASS" : "FAIL")")
    return good == iterations ? 0 : 1
}

// The ru table of tables.json (TextTables.swift), for the Russian "o" (index 15) and space (33).
let ruLengths = [4, 6, 5, 6, 5, 4, 8, 7, 6, 5, 7, 5, 5, 5, 4, 3, 6, 5, 5, 4, 6, 10, 7, 9, 6, 7, 8, 12, 6, 6, 7, 8, 6, 3, 16,
                 16, 16, 16, 16, 16, 16, 16, 16, 16, 7, 6, 9, 12, 10, 7, 15, 16, 16, 11, 16, 16, 16, 15, 16, 16, 16, 16,
                 16, 16, 16, 16, 8, 14, 6, 16, 11]

func ruPayload(_ os: Int, _ spaces: Int) -> [UInt8] {
    let codes = canonical(ruLengths)
    var bits: [Bool] = []
    func put(_ c: Int, _ l: Int) { for i in stride(from: l - 1, through: 0, by: -1) { bits.append((c >> i) & 1 == 1) } }
    for _ in 0..<os { put(codes[15], ruLengths[15]) }
    for _ in 0..<spaces { put(codes[33], ruLengths[33]) }
    let total = 6 + bits.count
    let nb = (total + 7) / 8
    var p = [UInt8](repeating: 0, count: nb)
    p[0] = UInt8((nb * 8 - total) << 5 | 1 << 2)
    for (i, b) in bits.enumerated() where b { p[(6 + i) / 8] |= UInt8(0x80 >> ((6 + i) % 8)) }
    return p
}

func textAmp() throws -> Int32 {
    let one = try Scheme(1, .utf8(0, "s"))
    let p = ruPayload(32767, 1)
    let over = ruPayload(32768, 0)
    var ok = true
    for (name, q) in [("largest", p), ("one_more", over)] {
        let pkt = [1] + varint(q.count) + q
        var times: [Double] = []
        var len = -1
        for _ in 0..<200 {
            let a = now()
            if let row = try? unpackMap(pkt, one) { len = (row["s"] as? String)?.utf8.count ?? -1 }
            times.append(seconds(a))
        }
        print("\(name) payload=\(q.count) text=\(len) ratio=\(String(format: "%.3f", Double(max(len, 0)) / Double(q.count)))")
        stats("\(name)_unpack", times)
        ok = ok && (name == "largest" ? len == 65_535 : len == -1)
    }
    let list = try Scheme(3, .list("l", .utf8(0, "e")))
    var pkt: [UInt8] = [3, 85, 0]
    for _ in 0..<85 { pkt += varint(p.count) + p }
    var times: [Double] = []
    var count = 0
    for _ in 0..<20 {
        let a = now()
        if let row = try? unpackMap(pkt, list) { count = (row["l"] as? [Any])?.count ?? 0 }
        times.append(seconds(a))
    }
    print("packet_85_max_texts bytes=\(pkt.count) texts=\(count) decoded_bytes=\(count * 65_535)")
    stats("packet_85_max_texts", times)
    print("peak_rss_kb=\(peakRSSKB()) traps=0")
    ok = ok && count == 85
    print("result=\(ok ? "PASS" : "FAIL")")
    return ok ? 0 : 1
}

/// The longest payload a count allows (2,097,151 bytes) of LOCK symbols only (ua index 70, an even number):
/// it decodes to the empty text, so the length limit never stops the decoder.
let uaLengths = [4, 6, 5, 7, 14, 5, 4, 7, 7, 6, 4, 5, 8, 7, 6, 5, 5, 4, 4, 6, 5, 5, 4, 5, 9, 7, 7, 7, 7, 8, 6, 7, 5, 10, 3,
                 16, 16, 16, 16, 16, 14, 15, 16, 16, 16, 7, 5, 10, 13, 10, 8, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16,
                 16, 16, 15, 15, 15, 15, 9, 8, 7, 15, 12]

func textLong() throws -> Int32 {
    let codes = canonical(uaLengths)
    let code = codes[70], len = uaLengths[70]
    let payload = 2_097_151
    var symbols = (payload * 8 - 6) / len
    symbols -= symbols % 2
    let total = 6 + symbols * len
    let nb = (total + 7) / 8
    var p = [UInt8](repeating: 0, count: nb)
    p[0] = UInt8((nb * 8 - total) << 5)
    var bit = 6
    for _ in 0..<symbols {
        for i in stride(from: len - 1, through: 0, by: -1) {
            if (code >> i) & 1 == 1 { p[bit / 8] |= UInt8(0x80 >> (bit % 8)) }
            bit += 1
        }
    }
    let pkt = [10] + varint(p.count) + p
    let scheme = try Scheme(10, .utf8(0, "s"))
    var times: [Double] = []
    var text = "?"
    for _ in 0..<20 {
        let a = now()
        text = (try? unpackMap(pkt, scheme))?["s"] as? String ?? "refused"
        times.append(seconds(a))
    }
    print("mode=text-long payload=\(p.count) lock_symbols=\(symbols) text_bytes=\(text == "refused" ? -1 : text.utf8.count)")
    stats("lock_only_2MiB_payload", times)
    print("peak_rss_kb=\(peakRSSKB()) traps=0")
    print("result=\(text.isEmpty ? "PASS" : "FAIL")")
    return text.isEmpty ? 0 : 1
}

// ---------------------------------------------------------------- dict keys (F47 and its fix)

/// The UTF-8 bytes of a key of `shape`, about `bytes` long, made distinct by `index`.
func keyBytes(_ shapeName: String, _ index: Int, _ bytes: Int) -> [UInt8] {
    // "<shape>-tail": the distinct digits go last, so two keys agree up to their last bytes and a
    // comparison of two keys normalizes both whole.
    let tail = shapeName.hasSuffix("-tail")
    let shape = tail ? String(shapeName.dropLast(5)) : shapeName
    let digits = String(format: "%05d", index)
    var s = tail ? "" : digits
    let unit: String
    switch shape {
    case "tibetan":  // U+0F73: class 0, decomposes to U+0F71 U+0F72 (classes 129, 130)
        unit = "\u{0F73}"
    case "tibetan-mix":  // U+0F73, U+0F75, U+0F81 in turn: classes 129/130, 129/132, 129/130 after decomposition
        unit = "\u{0F73}\u{0F75}\u{0F81}"
    case "marks30":  // the most the fix allows: 30 marks of classes 230 and 220 in turn, then a letter
        unit = String(String.UnicodeScalarView((0..<30).map { Unicode.Scalar($0 % 2 == 0 ? 0x301 : 0x316)! })) + "a"
    case "dialytika":  // U+0344 (class 230, decomposes to two marks) and U+0316 in turn, 30, then a letter
        unit = String(String.UnicodeScalarView((0..<30).map { Unicode.Scalar($0 % 2 == 0 ? 0x344 : 0x316)! })) + "a"
    case "marks-unbounded":  // control: refused by the fix
        unit = "\u{0301}\u{0316}"
    default:  // ascii control
        unit = "abcdefgh"
    }
    while s.utf8.count + unit.utf8.count + (tail ? 5 : 0) <= bytes { s += unit }
    if tail { s += digits }
    return Array(s.utf8)
}

func dictKey(_ shape: String, _ keys: Int, _ bytes: Int) throws -> Int32 {
    let scheme = try Scheme(4, .dict("d", .u8(0, "e")))
    let pkt = dictPacket((0..<keys).map { keyBytes(shape, $0, bytes) })
    let a = now()
    var outcome = "accepted"
    do {
        let row = try unpackMap(pkt, scheme)
        outcome = "accepted keys=\((row["d"] as? [String: Any])?.count ?? -1)"
    } catch let e as PackbinError {
        outcome = "refused \(e.kind.rawValue)"
    }
    let dt = seconds(a)
    print("mode=dictkey shape=\(shape) keys=\(keys) key_bytes=\(bytes) packet_bytes=\(pkt.count) \(outcome) seconds=\(String(format: "%.3f", dt)) peak_rss_kb=\(peakRSSKB()) traps=0")
    print("result=PASS")
    return 0
}
