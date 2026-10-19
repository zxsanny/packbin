import Dispatch
import Foundation
import Testing

/// Load-aware wall-clock bounds (AZ-2723). A host that other work loads makes a fixed bound fail, so a bound is
/// its nominal seconds times the load factor: how many times slower than an idle host a fixed integer loop runs
/// right now, in this process, never below 1 and never above `maxLoadFactor`. The nominal bound and the work
/// stay as the spec fixed them; a real slowdown of the timed code still fails, because the reference loop does
/// not change with it (the quadratic dict key check of F51, 170 times over, fails even at the cap).

/// The smallest of 40 runs of the reference loop on the owner's Mac (Apple M-series, 10 cores) in a debug and in a
/// release test build (about 30 ms each); other work and preemption only add time, so the smallest run is the idle one.
#if DEBUG
let referenceSeconds = 0.0307
private let referenceIterations = 250_000
#else
let referenceSeconds = 0.0290
private let referenceIterations = 15_000_000
#endif

/// The largest factor a bound grows by.
let maxLoadFactor = 8.0

private nonisolated(unsafe) var referenceSink: UInt64 = 0

/// Integer work the optimizer cannot remove or fold: a xorshift chain seeded from the clock, its sum stored
/// in a global.
@inline(never) private func referenceLoop() -> Double {
    let start = DispatchTime.now().uptimeNanoseconds
    var x = start | 1
    var sum: UInt64 = 0
    for _ in 0..<referenceIterations {
        x ^= x &<< 13
        x ^= x &>> 7
        x ^= x &<< 17
        sum &+= x
    }
    referenceSink = sum
    return Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9
}

/// The seconds the fastest of three reference loops takes now.
func referenceLoopSeconds() -> Double { min(referenceLoop(), referenceLoop(), referenceLoop()) }

private final class LoadCache: @unchecked Sendable {
    private let lock = NSLock()
    private var factor = 1.0
    private var measuredAt: UInt64 = 0

    func current(maxAge: Double) -> Double {
        lock.lock()
        defer { lock.unlock() }
        let now = DispatchTime.now().uptimeNanoseconds
        if measuredAt != 0 && Double(now - measuredAt) / 1e9 <= maxAge { return factor }
        factor = min(maxLoadFactor, max(1, referenceLoopSeconds() / referenceSeconds))
        measuredAt = DispatchTime.now().uptimeNanoseconds
        return factor
    }
}

private let loadCache = LoadCache()

/// The load factor, measured now. A caller that times thousands of short calls passes `maxAge` (seconds) to
/// reuse a factor measured that recently; the default measures anew, right before the timed section.
func loadFactor(maxAge: Double = 0) -> Double { loadCache.current(maxAge: maxAge) }

/// A wall-clock bound: `nominal` seconds times the load factor taken when the bound was made.
struct LoadBound: Sendable {
    let nominal: Double
    let factor: Double
    var seconds: Double { nominal * factor }

    func holds(_ elapsed: Double) -> Bool { elapsed <= seconds }

    /// Whether `elapsed` is within the bound, and the bound that decided. When the first factor does not
    /// cover it, the load factor is taken again after the timed section (the load may have risen during it,
    /// and the reference loop before it may have caught a quiet slice) and the larger factor counts.
    func judge(_ elapsed: Double) -> (ok: Bool, limit: LoadBound) {
        if holds(elapsed) { return (true, self) }
        let later = LoadBound(nominal: nominal, factor: max(factor, loadFactor()))
        return (later.holds(elapsed), later)
    }

    /// The failure text: the nominal bound, the factor and the elapsed time.
    func describe(_ elapsed: Double) -> String {
        "took \(elapsed) s, above the bound of \(seconds) s (nominal \(nominal) s x load factor \(factor))"
    }
}

/// The bound for `nominal` seconds: call it right before the timed section.
func bound(_ nominal: Double, maxAge: Double = 0) -> LoadBound {
    LoadBound(nominal: nominal, factor: loadFactor(maxAge: maxAge))
}

/// Asserts `elapsed` is within `limit`.
func expectWithin(_ elapsed: Double, _ limit: LoadBound, sourceLocation: SourceLocation = #_sourceLocation) {
    let (ok, decided) = limit.judge(elapsed)
    #expect(ok, Comment(rawValue: decided.describe(elapsed)), sourceLocation: sourceLocation)
}

/// Asserts `elapsed` is within `limit`, except under the thread sanitizer, which slows a refusal that walks
/// 65 535 rounds down by 40 times in the Linux container: there only the outcome is asserted, not the time (the
/// plain debug and release runs hold the bound).
func expectWithinUnlessSanitized(_ elapsed: Double, _ limit: LoadBound, sourceLocation: SourceLocation = #_sourceLocation) {
    let (ok, decided) = limit.judge(elapsed)
    #expect(threadSanitized || ok, Comment(rawValue: decided.describe(elapsed)), sourceLocation: sourceLocation)
}
