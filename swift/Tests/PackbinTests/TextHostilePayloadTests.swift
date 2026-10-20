import Dispatch
import Packbin
import Testing

/// AC-3 of AZ-2736 (CS-10, TW-3): hostile payloads of the compact text format. Random bytes, damaged valid
/// packets, raw-mode payloads, longest runs and bad counts, read as the string field of a one-field packet:
/// none traps or hangs (a trap ends the process), each is a text or a refusal naming the field, and a text is at
/// most 6 bytes per payload byte plus 8 (compact-text.md, Invariants). Seeded, so a failure replays.
@Suite struct TextHostilePayloadTests {
    @Test func unpack_thirtyThousandHostileTextPayloads_neverTrapOrHangAndStayWithinSixBytesPerBytePlusEight() throws {
        // Arrange
        let scheme = try loneString()
        var random = SeededRandom(state: 2736)
        let seeds = try validFields(scheme, &random)
        let rough = try roughFields()
        var fields = rough
        for i in 0..<30_000 { fields.append(hostileField(i, seeds, rough, &random)) }
        let all = fields

        // Act
        let found = finishing(within: hangSeconds) { () -> HostileTally in
            var tally = HostileTally()
            for field in all { read(field, scheme, &tally) }
            return tally
        }

        // Assert
        let tally = found ?? HostileTally()
        print("TextHostilePayloadTests: \(found == nil ? "HUNG" : tally.summary)")
        #expect(found != nil, "the payloads were not all read within \(hangSeconds) s")
        #expect(tally.inputs >= 30_000)
        #expect(tally.decoded >= 3_000 && tally.refused >= 3_000, "both outcomes are reached: \(tally.summary)")
        #expect(tally.failures.isEmpty, "\(tally.failures.prefix(10))")
    }

    @Test func unpack_longestRunsOfOneByteInEveryStartMode_stayWithinTheBoundOrAreRefused() throws {
        // Arrange
        let scheme = try loneString()
        var fields: [[UInt8]] = []
        for mode in 0..<4 {
            for fill in [UInt8(0x00), 0xFF] {
                for length in [1, 2, 9_999, 19_998, 40_000, 65_535, 70_000] {
                    fields.append(runField(mode: mode, fill: fill, length: length))
                }
            }
        }
        let all = fields

        // Act
        let found = finishing(within: hangSeconds) { () -> HostileTally in
            var tally = HostileTally()
            for field in all { read(field, scheme, &tally) }
            return tally
        }

        // Assert
        let tally = found ?? HostileTally()
        print("TextHostilePayloadTests: longest runs: \(found == nil ? "HUNG" : tally.summary)")
        #expect(found != nil, "the runs were not all read within \(hangSeconds) s")
        #expect(tally.inputs == 56 && tally.decoded >= 2 && tally.failures.isEmpty, "\(tally.failures.prefix(10))")
    }

    @Test func unpack_longestRunOfTheRussianLetterO_isNearTheWorstCaseAndWithinTheBound() throws {
        // Arrange: the Russian о is the worst symbol of the frozen tables, a 3-bit code for 2 UTF-8 bytes
        let scheme = try loneString()
        let text = String(repeating: "\u{043E}", count: 30_000)
        let field = Array(try pack(scheme, ["s": text]).dropFirst())
        let (payload, _) = try #require(textCountOf(field))

        // Act
        let back = utf8Of(try unpackMap([1] + field, scheme)["s"])

        // Assert
        let bytes = text.utf8.count
        print("TextHostilePayloadTests: 30000 letters U+043E: a payload of \(payload) bytes gives \(back?.count ?? -1) text bytes")
        #expect(back == Array(text.utf8))
        #expect(Double(bytes) / Double(payload) > 5 && bytes <= 6 * payload + 8)
    }
}

/// The seconds a run may take before it counts as hung: the thread sanitizer runs a thread about ten times
/// slower (`threadSanitized`), the plain runs take 4 s. This catches a hang; the speed of one unpack is checked
/// against the load-aware bound.
private let hangSeconds: Double = threadSanitized ? 900 : 120

/// What the reads of a hostile run found.
private struct HostileTally {
    var inputs = 0
    var decoded = 0
    var refused = 0
    var slowest = 0.0
    var widest = 0.0
    var factor = 1.0
    var failures: [String] = []

    var summary: String {
        "\(inputs) payloads: \(decoded) decoded (at most \(widest) text bytes per payload byte), \(refused) refused, slowest \(slowest) s (load factor \(factor)), \(failures.count) failures"
    }
}

/// Unpacks `field` as the only field of a packet and checks the outcome: a refusal naming the field (or trailing
/// bytes), or a text within the bound that packs and unpacks again.
private func read(_ field: [UInt8], _ scheme: Scheme, _ tally: inout HostileTally) {
    let at = tally.inputs
    let shown = hex(Array(field.prefix(24))) + (field.count > 24 ? "... (\(field.count) bytes)" : "")
    tally.inputs += 1
    let limit = bound(unpackNominal, maxAge: 1)
    let (outcome, seconds) = timed { Result { try unpackMap([1] + field, scheme) } }
    tally.slowest = max(tally.slowest, seconds)
    let (inTime, decided) = limit.judge(seconds)
    tally.factor = decided.factor
    if !inTime { tally.failures.append("#\(at) \(shown): \(decided.describe(seconds))") }
    switch outcome {
    case let .failure(error):
        let named = (error as? PackbinError).map { $0.kind == .trailing || ($0.kind == .short && $0.field == 0 && $0.name == "s") }
        if named != true { tally.failures.append("#\(at) \(shown): refused as \(error)") }
        tally.refused += 1
    case let .success(map):
        tally.decoded += 1
        guard map.count == 1, let text = map["s"] as? String else {
            tally.failures.append("#\(at) \(shown): row \(describeMap(map))")
            return
        }
        guard let (payload, header) = textCountOf(field), header + payload == field.count else {
            tally.failures.append("#\(at) \(shown): a text from a field whose count is not its payload length")
            return
        }
        tally.widest = max(tally.widest, Double(text.utf8.count) / Double(max(payload, 1)))
        if text.utf8.count > 6 * payload + 8 || text.utf8.count > 65_535 {
            tally.failures.append("#\(at) \(shown): \(text.utf8.count) bytes from a payload of \(payload)")
        }
        do {
            let again = utf8Of(try unpackMap(try pack(scheme, ["s": text]), scheme)["s"])
            if again != Array(text.utf8) { tally.failures.append("#\(at) \(shown): the text does not pack and unpack again") }
        } catch {
            tally.failures.append("#\(at) \(shown): the text does not pack and unpack again: \(error)")
        }
    }
}

/// The valid fields to damage: the `enc` and `alt` rows of the vectors file and the fields of 400 random texts.
private func validFields(_ scheme: Scheme, _ random: inout SeededRandom) throws -> [[UInt8]] {
    var fields = try (textRows("enc") + textRows("alt")).map(\.field)
    for _ in 0..<400 { fields.append(Array(try pack(scheme, ["s": randomUnicodeText(&random, longest: 80)]).dropFirst())) }
    return fields.filter { textCountOf($0) != nil }
}

/// The seeds that are no field to a decoder: the `bad` rows of the vectors file and the inputs of the hostile
/// corpus (fixtures/hostile/fuzz/corpus.txt) without their type byte. Each is read as it is, and damaged.
private func roughFields() throws -> [[UInt8]] {
    try textRows("bad").map(\.field) + fuzzCorpus().map { Array($0.packet.dropFirst()) }
}

private func randomBytes(_ count: Int, _ random: inout SeededRandom) -> [UInt8] {
    (0..<count).map { _ in UInt8(truncatingIfNeeded: random.next()) }
}

private func specialByte(_ random: inout SeededRandom) -> UInt8 {
    let pool: [UInt8] = [0x00, 0x01, 0x03, 0x10, 0x7F, 0x80, 0xC0, 0xF0, 0xFE, 0xFF]
    return random.next() % 2 == 0 ? pool[Int(random.next() % UInt64(pool.count))] : UInt8(truncatingIfNeeded: random.next())
}

/// The field of `length` bytes of `fill` in the start mode `mode` with no pad, for the longest runs.
private func runField(mode: Int, fill: UInt8, length: Int) -> [UInt8] {
    var payload = [UInt8](repeating: fill, count: length)
    payload[0] = UInt8(mode << 2)
    return textCountHeader(length) + payload
}

/// One hostile field; the kind follows the index so every kind has its share: random bytes behind a good count
/// (5 in 20), random bytes behind a start byte of a legal mode and a pad that fits (4), a damaged valid
/// payload (6), a damaged rough seed (1), a raw-mode payload (1), a run of one byte (2) and a bad count (1).
private func hostileField(_ index: Int, _ valid: [[UInt8]], _ rough: [[UInt8]], _ random: inout SeededRandom) -> [UInt8] {
    switch index % 20 {
    case 0..<5:
        let n = 1 + Int(random.next() % 80)
        return textCountHeader(n) + randomBytes(n, &random)
    case 5..<9:
        return legalStart(mode: index % 4, &random)
    case 9..<15:
        return damagedValid(valid[Int(random.next() % UInt64(valid.count))], &random)
    case 15:
        var field = rough[Int(random.next() % UInt64(rough.count))]
        for _ in 0..<(1 + random.next() % 3) { mutate(&field, &random) }
        return field
    case 16:
        let n = 1 + Int(random.next() % 60)
        let text = randomUnicodeText(&random, longest: 30)
        var raw = [0x10] + (random.next() % 2 == 0 ? randomBytes(n, &random) : Array(text.utf8))
        if random.next() % 4 == 0 { mutate(&raw, &random) }
        return textCountHeader(raw.count) + raw
    case 17, 18:
        let fills: [UInt8] = [0x00, 0xFF, 0x55, 0xAA, 0xF0, 0x0F, 0x7F, 0x80]
        let length = index % 3_000 == 2_998 ? [40_000, 65_535, 70_000][Int(random.next() % 3)] : 1 + Int(random.next() % 600)
        return runField(mode: Int(random.next() % 4), fill: fills[Int(random.next() % 8)], length: length)
    default:
        let counts: [[UInt8]] = [[0x80, 0x00], [0x81, 0x00], [0x80, 0x80, 0x00], [0xFF, 0xFF, 0xFF, 0x01], [0x80, 0x80, 0x80, 0x80],
                                 [0xFF, 0xFF, 0x03], [0xFF, 0xFF, 0x7F], [0x80], [0xFF], [], [0x00], [0x01], [0x02], [0x80, 0x80, 0x01]]
        let count = counts[Int(random.next() % UInt64(counts.count))]
        return count + randomBytes(Int(random.next() % 40), &random)
    }
}

/// Random bytes behind a start byte whose mode is `mode`, with a pad from 0 to 7 and the pad bits of the last
/// byte cleared, so the payload passes the header rules and reaches the code walk.
private func legalStart(mode: Int, _ random: inout SeededRandom) -> [UInt8] {
    let n = 1 + Int(random.next() % 80)
    var payload = randomBytes(n, &random)
    let pad = random.next() % 3 == 0 ? Int(random.next() % 8) : 0
    payload[0] = UInt8(pad << 5 | mode << 2) | payload[0] & 0x03
    payload[n - 1] &= ~UInt8((1 << pad) - 1)
    return textCountHeader(n) + payload
}

/// A valid field with 1 to 4 changes in its payload; the count is then made again from the new length, kept
/// as it was (a stale count) or itself damaged.
private func damagedValid(_ field: [UInt8], _ random: inout SeededRandom) -> [UInt8] {
    guard let (length, header) = textCountOf(field) else { return field }
    var payload = Array(field[header..<(header + length)])
    for _ in 0..<(1 + random.next() % 4) { mutate(&payload, &random) }
    switch random.next() % 10 {
    case 0:
        var count = Array(field[0..<header])
        mutate(&count, &random)
        return count + payload
    case 1, 2, 3:
        return Array(field[0..<header]) + payload
    default:
        return textCountHeader(payload.count) + payload
    }
}

private func mutate(_ bytes: inout [UInt8], _ random: inout SeededRandom) {
    let at = bytes.isEmpty ? 0 : Int(random.next() % UInt64(bytes.count))
    switch random.next() % 7 {
    case 0 where !bytes.isEmpty:
        bytes[at] ^= UInt8(1) << UInt8(random.next() % 8)
    case 1 where !bytes.isEmpty:
        bytes[at] = specialByte(&random)
    case 2:
        bytes.insert(specialByte(&random), at: at)
    case 3 where !bytes.isEmpty:
        bytes.remove(at: at)
    case 4 where !bytes.isEmpty:
        let end = min(bytes.count, at + 1 + Int(random.next() % 8))
        bytes.insert(contentsOf: bytes[at..<end], at: end)
    case 5:
        bytes = Array(bytes.prefix(at))
    default:
        let end = min(bytes.count, at + [2, 4, 8][Int(random.next() % 3)])
        for i in at..<end { bytes[i] = 0xFF }
    }
}
