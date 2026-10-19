// AZ-2666 audit probe, mode text-fuzz: random and mutated string fields through unpack of five schemes.

import Foundation
import Packbin

func textSeeds(_ fix: String) -> [[UInt8]] {
    var out: [[UInt8]] = []
    for r in rows(fix + "/text/vectors.txt") {
        if (r[0] == "enc" || r[0] == "alt" || r[0] == "bad") && r.count >= 4 { out.append(hex(r[3])) }
        if r[0] == "bad" && r.count == 3 { out.append([]) }
    }
    return out
}

func genField(_ r: inout Rng, _ seeds: [[UInt8]]) -> [UInt8] {
    let pick = r.below(10)
    if pick < 4 && !seeds.isEmpty {
        var b = seeds[r.below(seeds.count)]
        if r.chance(85) { mutate(&r, &b) }
        return b
    }
    var payload: [UInt8] = []
    let len = r.chance(10) ? 1 + r.below(2000) : 1 + r.below(64)
    if pick < 8 {
        let pad = r.below(8)
        let mode = r.chance(90) ? r.below(4) : r.below(8)
        payload.append(UInt8(pad << 5 | mode << 2 | r.below(4)))
        let style = r.below(4)
        for _ in 1..<max(len, 1) {
            payload.append(style == 0 ? 0xFF : style == 1 ? 0x00 : style == 2 ? UInt8(0xF0 | r.below(16)) : r.byte())
        }
        if pad != 0 && r.chance(70) { payload[payload.count - 1] &= ~UInt8((1 << pad) - 1) }
    } else {
        payload.append(r.chance(90) ? 0x10 : r.byte())
        for _ in 1..<max(len, 1) { payload.append(r.chance(70) ? UInt8(0x20 + r.below(0x5F)) : r.byte()) }
    }
    var count = payload.count
    if r.chance(5) { count = max(0, count + r.below(5) - 2) }
    var f: [UInt8]
    if r.chance(3) {
        f = [UInt8(count & 0x7F) | 0x80, UInt8((count >> 7) & 0x7F) | 0x80, 0]
    } else {
        f = varint(count)
    }
    return f + payload
}

/// The payload length of a field with a minimal count, or nil.
func payloadLength(_ f: [UInt8]) -> Int? {
    var n = 0
    for k in 0..<3 {
        guard k < f.count else { return nil }
        n |= Int(f[k] & 0x7F) << (7 * k)
        if f[k] & 0x80 == 0 { return k > 0 && f[k] == 0 ? nil : n }
    }
    return nil
}

func textFuzz(_ fix: String, _ seed: UInt64, _ budget: Double) throws -> Int32 {
    let seeds = textSeeds(fix)
    var r = Rng(seed)
    let schemes = [
        try Scheme(1, .utf8(0, "s")),
        try Scheme(2, .utf8(0, "p"), .u8(1, "k")),
        try Scheme(3, .list("l", .utf8(0, "e"))),
        try Scheme(4, .dict("d", .u8(0, "e"))),
        try Scheme(5, .dict("e", .utf8(0, "v"))),
    ]
    var calls = 0, ok = 0, maxText = 0
    var kinds: [String: Int] = [:]
    var maxRatio = 0.0
    var slow = Slowest()
    let t0 = now()
    while seconds(t0) < budget {
        for _ in 0..<128 {
            let f = genField(&r, seeds)
            let type = r.chance(95) ? 1 + r.below(5) : Int(r.byte())
            var pkt: [UInt8] = [UInt8(truncatingIfNeeded: type)]
            switch type {
            case 1: pkt += f
            case 2: pkt += f + [r.byte()]
            case 3, 4, 5:
                let items = r.chance(90) ? r.below(10) : r.below(65536)
                pkt += [UInt8(items & 0xFF), UInt8(items >> 8)]
                let same = genField(&r, seeds)
                for _ in 0..<min(items, 12) {
                    pkt += r.chance(30) ? same : genField(&r, seeds)
                    if type == 4 { pkt.append(r.byte()) }
                    if type == 5 { pkt += genField(&r, seeds) }
                }
            default: pkt += f
            }
            if r.chance(10) { mutate(&r, &pkt) }
            let a = now()
            do {
                let row = try unpackMap(pkt, schemes)
                ok += 1
                if pkt.first == 1, let s = row["s"] as? String, let n = payloadLength(Array(pkt.dropFirst())) {
                    let u = s.utf8.count
                    if u > 65_535 || u > 6 * n + 8 { note("expansion_bound", pkt) }
                    maxText = max(maxText, u)
                    if n > 0 { maxRatio = max(maxRatio, Double(u) / Double(n)) }
                }
            } catch let e as PackbinError {
                kinds[e.kind.rawValue, default: 0] += 1
            }
            slow.see(seconds(a), pkt.count)
            calls += 1
        }
    }
    print("mode=text-fuzz seed=\(seed) seconds=\(String(format: "%.1f", seconds(t0)))")
    print("unpack_calls=\(calls) accepted=\(ok) max_text=\(maxText) max_bytes_per_payload_byte=\(String(format: "%.3f", maxRatio))")
    print("refusals=\(kinds.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: ","))")
    print("slowest_unpack_us=\(String(format: "%.1f", slow.t * 1e6)) (packet \(slow.size) B)")
    print("peak_rss_kb=\(peakRSSKB()) failures=\(failures) traps=0")
    print("result=\(failures == 0 ? "PASS" : "FAIL")")
    return failures == 0 ? 0 : 1
}
