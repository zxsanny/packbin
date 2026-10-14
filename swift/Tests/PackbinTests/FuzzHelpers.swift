import Dispatch
import Packbin
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Whether the test process runs under the thread sanitizer, which slows an unpack down several times
/// over (`swift test --sanitize=thread`); its runtime exports `__tsan_init`. The default handle is
/// RTLD_DEFAULT: -2 on Darwin, 0 with glibc.
let threadSanitized: Bool = {
    #if canImport(Darwin)
    let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2)
    #else
    let defaultHandle: UnsafeMutableRawPointer? = nil
    #endif
    return dlsym(defaultHandle, "__tsan_init") != nil
}()

/// How long one unpack of one fuzz input may take (project AC-2), and under the thread sanitizer.
let unpackBound: Double = threadSanitized ? 10 : 1

/// How long one unpack of a mebibyte packet may take: the project bound in a release build. A debug
/// build reads such a packet several times slower (0.8 s at most on the owner's Mac with the other
/// suites running, 0.13 s in release), so it gets 3 s.
#if DEBUG
let mebibyteBound: Double = threadSanitized ? 10 : 3
#else
let mebibyteBound: Double = 1
#endif

/// What the reads of a fuzz run found: the failures, the unpack calls and the slowest of them.
struct FuzzTally {
    /// The seconds one unpack may take.
    var bound = unpackBound
    var failures: [String] = []
    var reads = 0
    var slowest = 0.0

    var summary: String { "\(reads) unpack calls, slowest \(slowest) s (bound \(bound) s), \(failures.count) failures" }
}

/// The schemes of a fuzz run and the checks each read must pass.
struct FuzzRun: Sendable {
    let schemes: [Scheme]
    let typed: [Scheme]
    let kinds: [String: [Scheme]]

    init() throws {
        schemes = try fuzzSchemes()
        typed = try fuzzTypedSchemes()
        kinds = try fuzzKindSchemes()
    }

    /// Reads `packet` with every fuzz scheme at once, with the schemes of `kind`, and as the body of a
    /// packet of every scheme, as it is and without its first byte.
    func check(_ packet: [UInt8], kind: String?, _ tally: inout FuzzTally) {
        read(packet, schemes, &tally)
        for s in kind.flatMap({ kinds[$0] }) ?? [] { read(packet, [s], &tally) }
        checkBody(packet, &tally)
        if !packet.isEmpty { checkBody(Array(packet.dropFirst()), &tally) }
    }

    /// Reads `body` after the type byte of each scheme, one scheme a call.
    func checkBody(_ body: [UInt8], _ tally: inout FuzzTally) {
        for s in schemes + typed { read([UInt8(truncatingIfNeeded: s.typeNumber)] + body, [s], &tally) }
    }

    /// One packet read typed and as a map: both give a row, or both the same well-formed error, within
    /// the bound. A row read by one scheme is packed again to look for a trap (a refusal is allowed).
    private func read(_ packet: [UInt8], _ with: [Scheme], _ tally: inout FuzzTally) {
        let (row, typedSeconds) = timed { Result { try unpack(packet, with) } }
        let (map, mapSeconds) = timed { Result { try unpackMap(packet, with) } }
        let seconds = max(typedSeconds, mapSeconds)
        tally.reads += 2
        tally.slowest = max(tally.slowest, seconds)
        if seconds > tally.bound {
            tally.failures.append("unpack of \(packet.count) bytes by types \(with.map(\.typeNumber)) took \(seconds) s")
        }
        switch (row, map) {
        case let (.success(typedRow), .success(mapRow)):
            if with.count == 1 {
                _ = try? pack(with[0], mapRow)
                _ = try? pack(with[0], typedRow)
            }
        case let (.failure(a), .failure(b)):
            guard let e = a as? PackbinError, e == b as? PackbinError else {
                tally.failures.append("unpack \(a), unpackMap \(b)")
                return
            }
            if let wrong = malformed(e, packet, with) { tally.failures.append("\(wrong): \(e)") }
        default:
            tally.failures.append("unpack \(row), unpackMap \(map)")
        }
    }

    /// What is wrong with an error unpack threw, or nil.
    private func malformed(_ e: PackbinError, _ packet: [UInt8], _ with: [Scheme]) -> String? {
        switch e.kind {
        case .schemeError, .packError:
            return "a kind unpack never throws"
        case _ where !e.description.hasPrefix("packbin: "):
            return "a message without the package prefix"
        case _ where e.needed < 0 || e.left < 0 || e.left > packet.count:
            return "a number out of range"
        case .tooMany where e.needed != 0:
            return "a round limit with bytes needed"
        case .trailing where e.left == 0 || e.needed != 0:
            return "trailing bytes that are none"
        case .unknownType where packet.first.map(Int.init) != e.actual || with.contains { $0.typeNumber == e.actual }:
            return "an unknown type that is not the first byte or is known"
        case .short where packet.isEmpty && (e.needed != 1 || e.left != 0):
            return "an empty packet that is not a one-byte short read"
        default:
            return nil
        }
    }
}

/// One random input and the corpus kind it was made from: fresh bytes, a mutated corpus input, or two
/// corpus inputs spliced; now and then a long run of one byte is added, which reaches the round limits.
func fuzzInput(_ corpus: [FuzzInput], _ random: inout SeededRandom) -> ([UInt8], String?) {
    var packet: [UInt8]
    var kind: String?
    switch random.next() % 8 {
    case 0, 1:
        packet = (0..<Int(random.next() % 49)).map { _ in interestingByte(&random) }
    case 7:
        let a = corpus[Int(random.next() % UInt64(corpus.count))]
        let b = corpus[Int(random.next() % UInt64(corpus.count))]
        packet = Array(a.packet.prefix(Int(random.next() % UInt64(a.packet.count + 1))))
            + b.packet.suffix(Int(random.next() % UInt64(b.packet.count + 1)))
        kind = a.kind
    default:
        let input = corpus[Int(random.next() % UInt64(corpus.count))]
        packet = input.packet
        kind = input.kind
        for _ in 0..<(1 + random.next() % 4) { mutate(&packet, &random) }
    }
    if random.next() % 64 == 0 {
        packet += [UInt8](repeating: interestingByte(&random), count: 256 + Int(random.next() % 8192))
    }
    return (packet, kind)
}

private func interestingByte(_ random: inout SeededRandom) -> UInt8 {
    let pool: [UInt8] = [0, 1, 2, 3, 4, 0x40, 0x7f, 0x80, 0xfe, 0xff]
    return random.next() % 2 == 0 ? pool[Int(random.next() % UInt64(pool.count))] : UInt8(truncatingIfNeeded: random.next())
}

private func mutate(_ packet: inout [UInt8], _ random: inout SeededRandom) {
    let at = packet.isEmpty ? 0 : Int(random.next() % UInt64(packet.count))
    switch random.next() % 7 {
    case 0 where !packet.isEmpty:
        packet[at] ^= UInt8(1) << UInt8(random.next() % 8)
    case 1 where !packet.isEmpty:
        packet[at] = interestingByte(&random)
    case 2:
        packet.insert(interestingByte(&random), at: at)
    case 3 where !packet.isEmpty:
        packet.remove(at: at)
    case 4 where !packet.isEmpty:
        let end = min(packet.count, at + 1 + Int(random.next() % 8))
        packet.insert(contentsOf: packet[at..<end], at: end)
    case 5:
        packet = Array(packet.prefix(at))
    default:
        let end = min(packet.count, at + [2, 4, 8][Int(random.next() % 3)])
        for i in at..<end { packet[i] = 0xff }
    }
}
