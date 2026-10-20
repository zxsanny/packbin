import Dispatch
import Foundation
import Packbin
import Testing

/// AC-1 and AC-2 of AZ-2735 (CS-S3, TW-1): the text tables are constants and the codec keeps no shared mutable
/// state (scenario CS-18). Eight threads pack and unpack different texts at once with one built scheme: 150 `enc`
/// rows of fixtures/text/vectors.txt (each thread from its own row on, so the eight windows cover the file and
/// overlap), one long row, and 100 random texts of the thread's own seed, whose reference is the same pack run on
/// one thread. A shared buffer shows up as a wrong byte or a wrong text. Threads, not tasks: a start gate that
/// blocks would deadlock a cooperative pool smaller than eight, and a thread that hangs fails the join instead
/// of the suite.
@Suite struct TextConcurrencyTests {
    @Test
    func packAndUnpack_eightThreadsOnOneTextScheme_giveReferenceBytesAndOwnInput() throws {
        // Arrange
        let scheme = try stringThenByte()
        let workers = 8
        let jobs = try (0..<workers).map { try TextJob(worker: $0, rows: try textRows("enc"), scheme: scheme) }
        let gate = StartGate(parties: workers)
        let results = TallyBox()
        let finished = DispatchGroup()
        let limit = bound(1)
        for job in jobs {
            finished.enter()
            let thread = Thread {
                gate.arriveAndWait()
                results.add(work(job, scheme))
                finished.leave()
            }
            thread.stackSize = 8 << 20
            thread.start()
        }
        let allStarted = gate.waitUntilArrived(within: 30)

        // Act
        let start = DispatchTime.now().uptimeNanoseconds
        gate.open()
        let joined = finished.wait(timeout: .now() + 60) == .success
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9

        // Assert
        let tallies = results.all
        let mismatches = tallies.flatMap(\.mismatches)
        let errors = tallies.flatMap(\.errors)
        print("TextConcurrencyTests: \(tallies.map(\.texts)) texts on \(workers) threads in \(elapsed) s (each thread \(tallies.map(\.seconds).max() ?? 0) s at most), \(mismatches.count) mismatches, \(errors.count) errors")
        #expect(allStarted && joined, "all threads started: \(allStarted), all finished within the time limit: \(joined)")
        #expect(tallies.count == workers && tallies.allSatisfy { $0.texts >= 200 })
        #expect(mismatches.isEmpty, "\(mismatches.prefix(10))")
        #expect(errors.isEmpty, "\(errors.prefix(10))")
        expectWithinUnlessSanitized(elapsed, limit)
    }
}

/// What one thread packs: the texts and, for each, the packet a single thread gives (the type byte, the field
/// and the thread's tag byte).
private struct TextJob: Sendable {
    let worker: Int
    let texts: [String]
    let packets: [[UInt8]]

    var tag: UInt8 { TextJob.tag(worker) }
    static func tag(_ worker: Int) -> UInt8 { UInt8(0xA0 + worker) }

    /// The rows of the thread: 150 of the rows up to 1,000 bytes, from the row its turn gives, and one of the two
    /// long rows (16,383 and 16,382 bytes). A thread takes about 0.15 s in a debug build, so 8 threads fit one
    /// second on 2 cores.
    init(worker: Int, rows: [TextRow], scheme: Scheme) throws {
        let long = rows.filter { $0.textBytes.count > 1_000 }
        let short = rows.filter { $0.textBytes.count <= 1_000 }
        let turned = (worker * 43) % short.count
        let ordered = Array((short[turned...] + short[..<turned]).prefix(150)) + [long[worker % long.count]]
        var random = SeededRandom(state: UInt64(35_000 + worker))
        var randoms: [String] = []
        for _ in 0..<100 { randoms.append(randomUnicodeText(&random, longest: 60)) }
        self.worker = worker
        self.texts = ordered.map(\.text) + randoms
        self.packets = try ordered.map { [1] + $0.field + [TextJob.tag(worker)] }
            + randoms.map { try pack(scheme, ["s": $0, "t": TextJob.tag(worker)]) }
    }
}

/// The mismatches and failures of one thread.
private struct WorkerTally: Sendable {
    var texts = 0
    var seconds = 0.0
    var mismatches: [String] = []
    var errors: [String] = []
}

/// Packs and unpacks every text of `job`, which runs on its own thread.
private func work(_ job: TextJob, _ scheme: Scheme) -> WorkerTally {
    var tally = WorkerTally()
    let start = DispatchTime.now().uptimeNanoseconds
    for (index, text) in job.texts.enumerated() {
        let label = "thread \(job.worker) text \(index) \(hex(Array(Array(text.utf8).prefix(24))))"
        do {
            let packet = try pack(scheme, ["s": text, "t": job.tag])
            tally.texts += 1
            if packet != job.packets[index] {
                tally.mismatches.append("\(label): packed to \(hex(Array(packet.prefix(24)))), not \(hex(Array(job.packets[index].prefix(24))))")
            }
            let back = try unpackMap(packet, scheme)
            if utf8Of(back["s"]) != Array(text.utf8) || back["t"] as? UInt8 != job.tag {
                tally.mismatches.append("\(label): unpacked to \(describeMap(back))")
            }
        } catch {
            tally.errors.append("\(label): \(error)")
        }
    }
    tally.seconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9
    return tally
}

/// Holds the threads at the gate until every one has arrived, then releases them together.
private final class StartGate: @unchecked Sendable {
    private let condition = NSCondition()
    private let parties: Int
    private var arrived = 0
    private var isOpen = false

    init(parties: Int) { self.parties = parties }

    /// A thread counts itself in and waits for the gate to open.
    func arriveAndWait() {
        condition.lock()
        defer { condition.unlock() }
        arrived += 1
        condition.broadcast()
        while !isOpen { condition.wait() }
    }

    /// Waits until every thread has arrived; false when `seconds` pass first.
    func waitUntilArrived(within seconds: Double) -> Bool {
        condition.lock()
        defer { condition.unlock() }
        let deadline = Date(timeIntervalSinceNow: seconds)
        while arrived < parties, condition.wait(until: deadline) {}
        return arrived == parties
    }

    func open() {
        condition.lock()
        isOpen = true
        condition.broadcast()
        condition.unlock()
    }
}

/// The tallies the threads hand in.
private final class TallyBox: @unchecked Sendable {
    private let lock = NSLock()
    private var tallies: [WorkerTally] = []

    func add(_ tally: WorkerTally) {
        lock.lock()
        tallies.append(tally)
        lock.unlock()
    }

    var all: [WorkerTally] {
        lock.lock()
        defer { lock.unlock() }
        return tallies
    }
}
