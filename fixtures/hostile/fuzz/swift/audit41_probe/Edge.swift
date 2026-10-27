// AZ-2666 audit probe, mode edge: the AC-1 and AC-2 edge cases a random run is unlikely to hit.

import Foundation
import Packbin

func edge(_ fix: String) throws -> Int32 {
    _ = fix
    // ECC sweep: n = 1..32, N = 0..256, three contents, t = 0 and n / 2.
    var sweep = 0
    for n in 1...32 {
        let s = try Scheme(0x40, .repeat(0, .u8(0, "k"))).withLimits(parity: n)
        for size in 0...256 {
            for fill in 0..<3 {
                let b = (0..<size).map { i in fill == 0 ? UInt8(0) : fill == 1 ? 0xFF : UInt8(truncatingIfNeeded: i * 37 + n) }
                for t in [0, n / 2] {
                    let k = kind { try unpackMapRepair(b, limit: t, [s]) }
                    sweep += 1
                    if size > 254 && k != "too_long" { failures += 1; print("FAIL n=\(n) N=\(size) \(k)") }
                    if size < n && size <= 254 && k != "short_packet" { failures += 1; print("FAIL short n=\(n) N=\(size) \(k)") }
                }
            }
        }
    }
    expect(true, "ECC sweep n 1..32, N 0..256: \(sweep) calls, no trap")
    // Codewords of every n = 1..32 and N = n + 1..254 with t, t + 1 and n - t + 1 wrong bytes at distinct
    // positions (the first and the last byte included).
    var rr = Rng(7)
    var codewordCalls = 0, codewordBad = 0
    for n in 1...32 {
        let t = n / 2
        let s = try Scheme(0x40, .repeat(0, .u8(0, "k"))).withLimits(parity: n)
        for size in (n + 1)...254 {
            var clear: [UInt8] = [0x40]
            for _ in 0..<(size - n - 1) { clear.append(rr.byte()) }
            let w = protectRef(clear, n)
            for k in [t, t + 1, n - t + 1] where k <= size {
                var pos = Array(0..<size)
                if size >= 2 { pos.swapAt(1, size - 1) }
                if k > 2 { for i in 2..<k { pos.swapAt(i, i + rr.below(size - i)) } }
                var b = w
                for e in 0..<k { b[pos[e]] ^= UInt8(1 + rr.below(255)) }
                codewordCalls += 1
                do {
                    let (row, count) = try unpackMapRepair(b, limit: t, [s])
                    let got = (row["k"] as? [Any?])?.compactMap { $0 as? UInt8 } ?? []
                    if k <= t && (count != k || got != Array(clear.dropFirst())) { codewordBad += 1 }
                    if k > t && k <= n - t { codewordBad += 1 }
                } catch let e as PackbinError {
                    if k <= t { codewordBad += 1 }
                    if k > t && k <= n - t && e.kind != .uncorrectable { codewordBad += 1 }
                }
            }
        }
    }
    print("edge_ecc_codeword_sweep calls=\(codewordCalls) bad=\(codewordBad)")
    expect(codewordBad == 0, "n 1..32, N n+1..254: t wrong bytes repaired, t+1..n-t refused (uncorrectable)")

    let s4 = try Scheme(0x40, .repeat(0, .u8(0, "k"))).withLimits(parity: 4)
    let s2 = try Scheme(0x41, .repeat(0, .u8(0, "k"))).withLimits(parity: 2)
    do {
        _ = try unpackMapRepair([0x40, 1, 2], limit: 0, [s4])
        expect(false, "3 bytes under n = 4")
    } catch let e as PackbinError {
        expect(e.kind == .short && e.name == "parity" && e.needed == 4 && e.left == 3, "3 bytes under n = 4: short naming parity, needed 4, left 3")
    }
    expect(kind { try unpackMapRepair([UInt8](repeating: 0, count: 255), limit: 0, [s4]) } == "too_long", "255 bytes: too_long")
    expect(kind { try unpackMapRepair([0x40], limit: 3, [s4]) } == "scheme_error", "limit 3 for n = 4: scheme_error before reading")
    expect(kind { try unpackMapRepair([0x40], limit: 0, [s4, s2]) } == "scheme_error", "parity mix: scheme_error")
    expect(kind { try unpackMapRepair([0x40], limit: 0, [s4, s4]) } == "scheme_error", "duplicate type: scheme_error")
    expect(kind { try unpackMapRepair([0x40], limit: 0, []) } == "scheme_error", "no scheme: scheme_error")
    expect(kind { try Scheme(1, .u8(0, "a")).withLimits(parity: 33) } == "scheme_error", "parity 33: scheme_error")
    // Text limits.
    let one = try Scheme(1, .utf8(0, "s"))
    let raw = [UInt8](repeating: 0x61, count: 65_535)
    expect(kind { try unpackMap([1] + varint(65_536) + [0x10] + raw, one) } == "ok", "raw 65,535 bytes accepted")
    expect(kind { try unpackMap([1] + varint(65_537) + [0x10] + raw + [0x61], one) } == "short_packet", "raw 65,536 bytes refused")
    print("note raw_prefix_alone=\(kind { try unpackMap([1, 1, 0x10], one) }) header_only_payload=\(kind { try unpackMap([1, 1, 0x48], one) })")
    // ESC cut short at the end, every cut of a 4-byte sequence.
    let enLengths = [4, 7, 6, 5, 3, 6, 6, 5, 4, 10, 7, 5, 5, 4, 4, 6, 11, 5, 4, 4, 6, 7, 6, 10, 5, 10, 7, 3, 15, 15, 15, 15, 15,
                     15, 15, 15, 15, 15, 9, 5, 12, 14, 10, 8, 15, 15, 15, 12, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
                     14, 15, 8, 6, 15, 14]
    let enCodes = canonical(enLengths)
    var cutAccepted = 0
    for cut in 1...31 {
        var bits: [Bool] = []
        func put(_ c: Int, _ l: Int) { for i in stride(from: l - 1, through: 0, by: -1) { bits.append((c >> i) & 1 == 1) } }
        put(enCodes[64], enLengths[64])
        put(0xF09F_9880 >> cut, 32 - cut)
        let total = 6 + bits.count
        let nb = (total + 7) / 8
        var q = [UInt8](repeating: 0, count: nb)
        q[0] = UInt8((nb * 8 - total) << 5 | 2 << 2)
        for (i, bit) in bits.enumerated() where bit { q[(6 + i) / 8] |= UInt8(0x80 >> ((6 + i) % 8)) }
        if kind({ try unpackMap([1] + varint(q.count) + q, one) }) == "ok" { cutAccepted += 1 }
    }
    expect(cutAccepted == 0, "ESC cut short by 1..31 bits at the payload end: refused, no trap")
    // Duplicate keys: one text in two byte forms; NFC and NFD; the stream-safe boundary.
    let dict = try Scheme(4, .dict("d", .u8(0, "e")))
    expect(kind { try unpackMap([4, 2, 0, 0x05, 0xc3, 0xff, 0x34, 0x63, 0xc0, 1, 0x03, 0x10, 0xd1, 0x8f, 2], dict) } != "ok",
           "one key in compact and raw form: refused")
    let nfc = Array("\u{00E9}".utf8), nfd = Array("e\u{0301}".utf8)
    expect(kind { try unpackMap(dictPacket([nfc, nfd]), dict) } != "ok", "NFC and NFD of one key: refused (owner ruling)")
    let m30 = Array(("a" + String(repeating: "\u{0301}", count: 30)).utf8)
    let m31 = Array(("a" + String(repeating: "\u{0301}", count: 31)).utf8)
    expect(kind { try unpackMap(dictPacket([m30]), dict) } == "ok", "30 marks in a run: accepted")
    expect(kind { try unpackMap(dictPacket([m31]), dict) } != "ok", "31 marks in a run: refused")
    let tib = Array(("a" + String(repeating: "\u{0F73}", count: 31)).utf8)
    print("note tibetan_0F73_x31_key=\(kind { try unpackMap(dictPacket([tib]), dict) }) (U+0F73 has class 0; its decomposition is two non-starters)")
    print("failures=\(failures) traps=0")
    print("result=\(failures == 0 ? "PASS" : "FAIL")")
    return failures == 0 ? 0 : 1
}
