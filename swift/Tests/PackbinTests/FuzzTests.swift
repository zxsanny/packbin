import Dispatch
import Foundation
import Packbin
import Testing

/// AC-2 (SW-5): unpack fuzzing. Every input, read as a packet of each fuzz scheme, of its corpus kind
/// and of all fuzz schemes at once, returns a row or a well-formed `PackbinError` within 1 second; a
/// trap ends the process, so the seed is printed before the run and every corpus input has a name. A
/// row is packed again only to look for a trap: a repack may refuse (a `flags` `times` whose bit is
/// clear with a count above 0 unpacks and then refuses to pack, as in TypeScript and Go).
///
/// The random run lasts `PACKBIN_FUZZ_SECONDS` seconds (3 when unset; CI asks 60) and replays from
/// `PACKBIN_FUZZ_SEED`.
@Suite(.serialized) struct FuzzTests {
    @Test func corpus_holdsEveryHostileUnpackAndLimitPacket() throws {
        // Arrange
        let corpus = try fuzzCorpus()
        let cases = try repositoryFile("fixtures/hostile/cases.txt").split(separator: "\n")
            .map { $0.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init) }
            .filter { $0.count == 4 && !$0[0].hasPrefix("#") && ($0[1] == "unpack" || $0[1] == "limit") }

        // Act
        let missing = cases.filter { c in !corpus.contains { $0.name == "hostile_" + c[0] && $0.kind == c[0] && hex($0.packet) == c[3] } }

        // Assert
        #expect(cases.count == 12)
        #expect(missing.isEmpty, "not in the corpus: \(missing.map { $0[0] })")
        #expect(Set(corpus.map(\.name)).count == corpus.count)
    }

    @Test func corpus_everyInputReadEveryWay_givesARowOrAWellFormedErrorWithinTheBound() throws {
        // Arrange
        let fuzz = try FuzzRun()
        let corpus = try fuzzCorpus()

        // Act
        var failures: [String] = []
        var reads = 0
        for input in corpus {
            var tally = FuzzTally()
            fuzz.check(input.packet, kind: input.kind, &tally)
            failures += tally.failures.map { "\(input.name): \($0)" }
            reads += tally.reads
        }

        // Assert
        print("FuzzTests: corpus of \(corpus.count) inputs: \(reads) unpack calls, \(failures.count) failures")
        #expect(corpus.count == 28)
        #expect(failures.isEmpty, "\(failures.prefix(10))")
    }

    @Test func random_seededRunForTheAskedSeconds_findsNoFailure() throws {
        // Arrange
        let environment = ProcessInfo.processInfo.environment
        let seconds = environment["PACKBIN_FUZZ_SECONDS"].flatMap(Double.init) ?? 3
        let seed = environment["PACKBIN_FUZZ_SEED"].flatMap { UInt64($0) } ?? DispatchTime.now().uptimeNanoseconds
        let fuzz = try FuzzRun()
        let corpus = try fuzzCorpus()
        var random = SeededRandom(state: seed)
        print("FuzzTests: seed \(seed), \(seconds) s; replay with PACKBIN_FUZZ_SEED=\(seed)")

        // Act
        let start = DispatchTime.now().uptimeNanoseconds
        let deadline = start + UInt64(max(seconds, 0) * 1e9)
        var inputs = 0
        var tally = FuzzTally()
        while DispatchTime.now().uptimeNanoseconds < deadline && tally.failures.count < 10 {
            let (packet, kind) = fuzzInput(corpus, &random)
            let before = tally.failures.count
            fuzz.check(packet, kind: kind, &tally)
            for i in before..<tally.failures.count {
                tally.failures[i] = "input \(inputs) (\(hex(Array(packet.prefix(64))))): \(tally.failures[i])"
            }
            inputs += 1
        }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9

        // Assert
        print("FuzzTests: seed \(seed): \(inputs) inputs in \(elapsed) s: \(tally.summary)")
        #expect(tally.failures.isEmpty, "seed \(seed): \(tally.failures)")
        #expect(inputs > 0 && elapsed >= seconds)
    }

    /// A mebibyte of one byte (a count of 0, 1 or 255 for every count it reads) reaches the default round
    /// and slot limits of the round schemes, and is read by each scheme within the bound (`mebibyteBound`).
    @Test(.enabled(if: !threadSanitized, "one thread, no shared state: the thread sanitizer adds nothing and runs it about ten times slower"), arguments: [UInt8(0), 1, 0xff])
    func mebibyteOfOneByte_isReadByEverySchemeWithinTheBound(fill: UInt8) throws {
        // Arrange
        let fuzz = try FuzzRun()
        let body = [UInt8](repeating: fill, count: 1 << 20)

        // Act
        var tally = FuzzTally(bound: mebibyteBound)
        fuzz.checkBody(body, &tally)

        // Assert
        print("FuzzTests: a mebibyte of \(fill): \(tally.summary)")
        #expect(tally.failures.isEmpty, "\(tally.failures)")
    }
}

/// One corpus input (fixtures/hostile/fuzz/corpus.txt).
struct FuzzInput: Sendable {
    let name: String
    let kind: String
    let packet: [UInt8]
}

func fuzzCorpus() throws -> [FuzzInput] {
    try repositoryFile("fixtures/hostile/fuzz/corpus.txt").split(separator: "\n").compactMap { line in
        let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count == 3, !parts[0].hasPrefix("#") else { return nil }
        return FuzzInput(name: parts[0], kind: parts[1], packet: bytes(parts[2]))
    }
}
