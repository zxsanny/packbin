// AZ-2666 audit probe: helpers shared by the modes (random numbers, timing, fixtures, mutation, the
// reference ECC encoder, canonical codes, dict packets, expectations). See main.swift.

import Foundation
import Packbin

var failures = 0

func note(_ what: String, _ input: [UInt8]) {
    failures += 1
    if failures <= 20 {
        print("FAIL \(what) input=\(input.map { String(format: "%02x", $0) }.joined())")
    }
}

struct Rng {
    var s: UInt64
    init(_ seed: UInt64) { s = seed &* 0x9E37_79B9_7F4A_7C15 &+ 1 }
    mutating func next() -> UInt64 {
        s ^= s >> 12
        s ^= s << 25
        s ^= s >> 27
        return s &* 2_685_821_657_736_338_717
    }
    mutating func below(_ n: Int) -> Int { n <= 0 ? 0 : Int(next() % UInt64(n)) }
    mutating func byte() -> UInt8 { UInt8(truncatingIfNeeded: next() >> 24) }
    mutating func chance(_ pct: Int) -> Bool { below(100) < pct }
}

func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
func seconds(_ t0: UInt64) -> Double { Double(now() - t0) / 1e9 }

func peakRSSKB() -> Int {
    var u = rusage()
    getrusage(RUSAGE_SELF, &u)
    #if os(macOS)
    return Int(u.ru_maxrss) / 1024
    #else
    return Int(u.ru_maxrss)
    #endif
}

func hex(_ h: String) -> [UInt8] {
    if h == "-" { return [] }
    var out: [UInt8] = []
    var i = h.startIndex
    while i < h.endIndex, let j = h.index(i, offsetBy: 2, limitedBy: h.endIndex) {
        out.append(UInt8(h[i..<j], radix: 16) ?? 0)
        i = j
    }
    return out
}

func rows(_ path: String) -> [[String]] {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        print("cannot read \(path)")
        exit(2)
    }
    return text.split(separator: "\n").compactMap { line in
        if line.isEmpty || line.hasPrefix("#") { return nil }
        return line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    }
}

func varint(_ n: Int) -> [UInt8] {
    var n = n
    var out: [UInt8] = []
    while n >= 128 {
        out.append(UInt8(n & 0x7F) | 0x80)
        n >>= 7
    }
    out.append(UInt8(n))
    return out
}

func mutate(_ r: inout Rng, _ b: inout [UInt8]) {
    for _ in 0..<(1 + r.below(6)) {
        switch r.below(8) {
        case 0: if !b.isEmpty { b[r.below(b.count)] ^= UInt8(1 << r.below(8)) }
        case 1: if !b.isEmpty { b[r.below(b.count)] = r.byte() }
        case 2: b.insert(r.byte(), at: r.below(b.count + 1))
        case 3: if !b.isEmpty { b.remove(at: r.below(b.count)) }
        case 4: b = Array(b.prefix(r.below(b.count + 1)))
        case 5: for _ in 0..<r.below(16) { b.append(r.chance(50) ? 0xFF : r.byte()) }
        case 6: if !b.isEmpty { b[r.below(b.count)] = r.chance(50) ? 0x00 : 0xFF }
        default: if b.count > 1 { b[1] = r.byte() }
        }
    }
}

struct Slowest {
    var t = 0.0
    var size = 0
    mutating func see(_ dt: Double, _ n: Int) { if dt > t { t = dt; size = n } }
}

func stats(_ name: String, _ t: [Double]) {
    let s = t.sorted()
    print("\(name) calls=\(s.count) min_us=\(String(format: "%.2f", s[0] * 1e6)) median_us=\(String(format: "%.2f", s[s.count / 2] * 1e6)) p99_us=\(String(format: "%.2f", s[s.count * 99 / 100] * 1e6)) max_us=\(String(format: "%.2f", s[s.count - 1] * 1e6))")
}

// ---------------------------------------------------------------- ECC reference encoder of the contract

struct GF {
    var exp = [Int](repeating: 0, count: 512)
    var log = [Int](repeating: 0, count: 256)
    init() {
        var x = 1
        for i in 0..<255 {
            exp[i] = x
            log[x] = i
            x <<= 1
            if x & 0x100 != 0 { x ^= 0x11D }
        }
        for i in 255..<512 { exp[i] = exp[i - 255] }
    }
    func mul(_ a: Int, _ b: Int) -> Int { a == 0 || b == 0 ? 0 : exp[log[a] + log[b]] }
}

let gf = GF()

/// `clear` and its n parity bytes, as the contract's "Encode" step writes them.
func protectRef(_ clear: [UInt8], _ n: Int) -> [UInt8] {
    var g = [1]
    for i in 0..<n {
        var next = [Int](repeating: 0, count: g.count + 1)
        for (j, c) in g.enumerated() {
            next[j] ^= c
            next[j + 1] ^= gf.mul(c, gf.exp[i])
        }
        g = next
    }
    var rem = [clear.count] + clear.map(Int.init) + [Int](repeating: 0, count: n)
    for i in 0...clear.count where rem[i] != 0 {
        let c = rem[i]
        for j in 1...max(n, 1) where n > 0 { rem[i + j] ^= gf.mul(g[j], c) }
    }
    return clear + rem[(clear.count + 1)...].map { UInt8($0) }
}

func pickN(_ r: inout Rng) -> Int {
    let common = [1, 2, 3, 4, 8, 16, 31, 32, 32, 32]
    return r.chance(60) ? common[r.below(10)] : 1 + r.below(32)
}

// ---------------------------------------------------------------- text tables and packets

/// Canonical codes of a table of code lengths (the contract's code assignment).
func canonical(_ lengths: [Int]) -> [Int] {
    let order = lengths.indices.sorted { (lengths[$0], $0) < (lengths[$1], $1) }
    var code = [Int](repeating: 0, count: lengths.count)
    var next = 0, prev = 0
    for i in order {
        next <<= lengths[i] - prev
        code[i] = next
        next += 1
        prev = lengths[i]
    }
    return code
}

func dictPacket(_ keys: [[UInt8]]) -> [UInt8] {
    var pkt: [UInt8] = [4, UInt8(keys.count & 0xFF), UInt8(keys.count >> 8)]
    for k in keys { pkt += varint(k.count + 1) + [0x10] + k + [1] }
    return pkt
}

// ---------------------------------------------------------------- expectations

func expect(_ c: Bool, _ what: String) {
    print("\(c ? "ok  " : "FAIL") \(what)")
    if !c { failures += 1 }
}

func kind(_ body: () throws -> Any) -> String {
    do { _ = try body(); return "ok" } catch let e as PackbinError { return e.kind.rawValue } catch { return "other" }
}
