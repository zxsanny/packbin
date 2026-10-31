import Packbin
import Testing

/// AZ-3505 AC-7: every row kind of fixtures/ecc/percent-vectors.txt (message-ecc.md 1.1.0), through the public calls.
/// A clear message of no bytes cannot be packed (a packet always has its type byte), so those rows check the formula.
@Suite struct EccPercentVectorTests {
    @Test(arguments: try percentRows("pct"))
    func pack_pctRow_appendsTheCountOfTheRow(_ row: EccRow) throws {
        // Arrange
        let (p, length, n) = (row.number(0), row.number(1), row.number(2))
        let packable = length >= 1 && (p == 0 || length <= expectedLargest(p))

        // Act
        let size = packable ? try pack(try rawScheme(for: patternClear(length, seed: 1), percent: p),
                                       rawRow(patternClear(length, seed: 1))).count : length + n

        // Assert
        #expect(expectedCount(p, length) == n)
        #expect(size == length + n)
    }

    @Test(arguments: try percentRows("encp").filter { $0.args[1] != "-" })
    func pack_encpRow_appendsExactlyTheVectorParity(_ row: EccRow) throws {
        // Arrange
        let clear = row.data(1)
        let scheme = try rawScheme(for: clear, percent: row.number(0))

        // Act
        let packed = try pack(scheme, rawRow(clear))

        // Assert
        #expect(hex(packed) == hex(row.data(2)))
    }

    @Test(arguments: try percentRows("inv"))
    func unpackRepair_invRow_findsTheClearLengthOrRefusesAsUncorrectable(_ row: EccRow) throws {
        // Arrange
        let (p, sent) = (row.number(0), row.number(1))
        let length = Int(row.args[2])
        let clear = [UInt8](repeating: 0, count: max(length ?? 1, 1))
        let scheme = try rawScheme(for: clear, percent: p)
        let received = length.map { $0 >= 1 ? (try? pack(scheme, rawRow(clear))) ?? [] : [] }
            ?? [UInt8](repeating: 0, count: sent)

        // Act
        let error = packbinError { try unpackMapRepair(received, limit: 0, scheme) }

        // Assert
        if length == nil {
            #expect(error?.kind == .uncorrectable && error?.field == nil)
        } else if let length, length >= 1 {
            #expect(received.count == sent && error == nil, "\(row.id): \(String(describing: error))")
        } else {
            #expect(error?.kind != .uncorrectable, "an empty message has the length 0")
        }
    }

    @Test(arguments: try percentRows("limp"))
    func pack_limpRow_succeedsOrIsRefusedNamingTheLengthAndTheLimit(_ row: EccRow) throws {
        // Arrange
        let (p, length) = (row.number(0), row.number(1))
        let clear = [UInt8](repeating: 0, count: length)
        let scheme = try rawScheme(for: clear, percent: p)

        // Act
        let error = packbinError { try pack(scheme, rawRow(clear)) }

        // Assert
        if row.args[2] == "ok" {
            #expect(error == nil)
        } else {
            #expect(error?.kind == .packError)
            #expect(error?.reason.contains(String(length)) == true
                && error?.reason.contains(String(expectedLargest(p))) == true, "\(String(describing: error?.reason))")
        }
    }

    @Test(arguments: try percentRows("fixp").filter { $0.args[3] != "-" })
    func unpackRepair_fixpRow_givesTheClearMessageAndTheCount(_ row: EccRow) throws {
        // Arrange
        let (p, t, count) = (row.number(0), row.number(1), row.number(4))
        let clear = row.data(3)
        let scheme = try rawScheme(for: clear, percent: p)

        // Act
        let got = try unpackMapRepair(row.data(2), limit: t, scheme)

        // Assert
        #expect(got.repaired == count)
        #expect(describeMap(got.row) == describeMap(rawRow(clear)), "\(row.id)")
    }

    @Test func unpackRepair_everyBadpRow_isRefusedAsTheRowSaysWithNoRow() throws {
        // Arrange
        let rows = try percentRows("badp")
        var wrong: [String] = []

        // Act
        for row in rows {
            let (p, t, received, kind) = (row.number(0), row.number(1), row.data(2), row.args[3])
            let scheme = try Scheme(0, [Field]()).withLimits(parityPercent: p)
            let error = packbinError { try unpackMapRepair(received, limit: t, scheme) }
            let want: PackbinError.Kind = kind == "too_long" ? .tooLong : .uncorrectable
            if error?.kind != want || error?.field != nil { wrong.append("\(row.id): \(String(describing: error))") }
        }

        // Assert
        #expect(rows.count >= 100)
        #expect(wrong.isEmpty, "\(wrong.count) rows: \(wrong.prefix(5))")
    }

    @Test(arguments: try percentRows("parp"))
    func withLimits_parpRow_isNotBuiltNamingThePercentageAnd100(_ row: EccRow) throws {
        // Arrange
        let (p, n) = (row.number(0), row.number(1))
        let base = try Scheme(1, [Field]())

        // Act
        let error = packbinError { try base.withLimits(parity: n, parityPercent: p) }

        // Assert
        #expect(error?.kind == .schemeError && error?.name == "parity")
        #expect(error?.reason.contains(String(p)) == true && error?.reason.contains("100") == true)
    }

    @Test(arguments: try percentRows("lmtp"))
    func unpackRepair_lmtpRow_refusesTheLimitBeforeAnyByteIsRead(_ row: EccRow) throws {
        // Arrange
        let t = row.number(0)
        let scheme = try positionMapScheme().withLimits(parityPercent: 25)
        let message = try pack(scheme, goldenMap())

        // Act
        let error = packbinError { try unpackMapRepair(message, limit: t, scheme) }
        let garbage = packbinError { try unpackMapRepair([], limit: t, scheme) }

        // Assert
        #expect(error?.kind == .schemeError && error?.name == "limit")
        #expect(garbage?.kind == .schemeError, "an empty buffer must not be read first")
    }

    @Test func rows_coverEveryKindOfTheFile() throws {
        // Assert
        let kinds = ["pct", "encp", "inv", "limp", "fixp", "badp", "parp", "lmtp"]
        let counts = try kinds.map { try percentRows($0).count }
        #expect(zip(counts, [336, 39, 408, 12, 110, 118, 6, 3]).allSatisfy { $0 >= $1 }, "\(counts)")
    }
}
