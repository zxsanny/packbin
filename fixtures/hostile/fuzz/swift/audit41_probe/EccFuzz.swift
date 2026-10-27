// AZ-2666 audit probe, mode ecc-fuzz: random and mutated protected messages through the repairing unpack.

import Foundation
import Packbin

func eccFuzz(_ fix: String, _ seed: UInt64, _ budget: Double) throws -> Int32 {
    var seeds: [(Int, [UInt8])] = []
    for row in rows(fix + "/ecc/vectors.txt") where (row[0] == "fix" || row[0] == "bad") && row.count >= 5 {
        seeds.append((Int(row[2]) ?? 1, hex(row[4])))
    }
    var r = Rng(seed)
    var base: [Scheme] = []
    for n in 0...32 { base.append(try Scheme(0x40, .repeat(0, .u8(0, "k"))).withLimits(parity: n)) }
    // The reference encoder agrees with pack.
    for n in [1, 2, 4, 8, 16, 32] {
        let row: [String: Any] = ["k": [UInt8(1), UInt8(2), UInt8(3)].map { $0 as Any }]
        let packed = try pack(base[n], row)
        if packed != protectRef(Array(packed.prefix(packed.count - n)), n) { note("encoder_differs_n\(n)", packed) }
    }
    var calls = 0, repaired = 0, intact = 0, miscorrected = 0
    var kinds: [String: Int] = [:]
    var slow = Slowest()
    let t0 = now()
    while seconds(t0) < budget {
        for _ in 0..<64 {
            var n = pickN(&r)
            var t = r.chance(70) ? n / 2 : r.below(n / 2 + 1)
            var word: [UInt8] = []
            var received: [UInt8]
            var errors = 0
            let src = r.below(10)
            if src < 5 {
                let total = r.chance(20) ? 254 : n + 1 + r.below(254 - n)
                var clear: [UInt8] = [0x40]
                for _ in 0..<(total - n - 1) { clear.append(r.byte()) }
                word = protectRef(clear, n)
                received = word
                let k = r.below(4) == 0 ? r.below(n + 2) : max(0, t + r.below(3) - 1)
                for _ in 0..<k { received[r.below(received.count)] ^= UInt8(1 + r.below(255)) }
                errors = zip(word, received).filter { $0 != $1 }.count
            } else if src < 7 && !seeds.isEmpty {
                let s = seeds[r.below(seeds.count)]
                n = s.0
                t = r.chance(70) ? n / 2 : r.below(n / 2 + 1)
                received = s.1
                mutate(&r, &received)
            } else {
                let lens = [n - 1, n, 254, 255, 256, n + r.below(255 - n)]
                received = [UInt8](repeating: 0, count: max(0, lens[r.below(lens.count)]))
                let style = r.below(3)
                for i in received.indices { received[i] = style == 0 ? r.byte() : style == 1 ? 0xFF : 0x00 }
            }
            let before = received
            if r.chance(20) {
                // Argument refusals come before any byte is read.
                do { _ = try unpackMapRepair(received, limit: n / 2 + 1, [base[n]]); note("bad_limit_accepted", received) } catch {}
                do { _ = try unpackMapRepair(received, limit: 0, [base[n], base[n]]); note("duplicate_accepted", received) } catch {}
                let other = try Scheme(0x41, .repeat(0, .u8(0, "k"))).withLimits(parity: n == 32 ? 31 : n + 1)
                do { _ = try unpackMapRepair(received, limit: 0, [base[n], other]); note("mix_accepted", received) } catch {}
            }
            let a = now()
            do {
                let (row, count) = try unpackMapRepair(received, limit: t, [base[n]])
                slow.see(seconds(a), received.count)
                if count == 0 { intact += 1 } else { repaired += 1 }
                if count > t { note("repaired_above_limit", before) }
                if !word.isEmpty {
                    let got = (row["k"] as? [Any?])?.compactMap { $0 as? UInt8 } ?? []
                    let want = Array(word[1..<(word.count - n)])
                    if got != want {
                        miscorrected += 1
                        if errors <= n - t { note("miscorrected_within_detection", before) }
                    } else if count != errors {
                        note("repaired_count", before)
                    }
                }
            } catch let e as PackbinError {
                slow.see(seconds(a), received.count)
                kinds[e.kind.rawValue, default: 0] += 1
                if !word.isEmpty && errors <= t && e.kind == .uncorrectable { note("correctable_refused", before) }
            }
            if received != before { note("input_written", before) }
            calls += 1
        }
    }
    print("mode=ecc-fuzz seed=\(seed) seconds=\(String(format: "%.1f", seconds(t0)))")
    print("calls=\(calls) intact=\(intact) repaired=\(repaired) miscorrected_beyond_n_minus_t=\(miscorrected)")
    print("refusals=\(kinds.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: ","))")
    print("slowest_call_us=\(String(format: "%.1f", slow.t * 1e6)) (input \(slow.size) B)")
    print("peak_rss_kb=\(peakRSSKB()) failures=\(failures) traps=0")
    print("result=\(failures == 0 ? "PASS" : "FAIL")")
    return failures == 0 ? 0 : 1
}
