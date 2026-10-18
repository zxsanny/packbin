import Packbin
import Testing

/// AZ-2686 AC-2 to AC-5: every row kind of fixtures/ecc/vectors.txt (message-ecc.md), through the public calls.
/// A row is raw bytes, so a message goes through `rawScheme`: its type byte is the first byte of the clear message.
/// The `enc.empty` rows (a clear message of no bytes) cannot be packed: a packet always has its type byte.
@Suite struct EccVectorTests {
    @Test(arguments: try eccRows("enc").filter { $0.args[1] != "-" })
    func pack_encRow_appendsExactlyTheVectorParity(_ row: EccRow) throws {
        // Arrange
        let clear = row.data(1)
        let scheme = try rawScheme(for: clear, parity: row.number(0))

        // Act
        let packed = try pack(scheme, rawRow(clear))

        // Assert
        #expect(hex(packed) == hex(row.data(2)))
    }

    @Test(arguments: try eccRows("fix"))
    func unpackRepair_fixRow_givesTheClearMessageAndTheCount(_ row: EccRow) throws {
        // Arrange
        let (n, t, count) = (row.number(0), row.number(1), row.number(4))
        let clear = row.data(3)
        let scheme = try rawScheme(for: clear, parity: n)

        // Act
        let got = try unpackMapRepair(row.data(2), limit: t, scheme)

        // Assert
        #expect(got.repaired == count)
        #expect(describeMap(got.row) == describeMap(rawRow(clear)), "\(row.id)")
    }

    @Test func unpackRepair_everyBadRow_isRefusedAsTheRowSaysWithNoRow() throws {
        // Arrange
        let rows = try eccRows("bad")
        var wrong: [String] = []

        // Act
        for row in rows {
            let (n, t, received, kind) = (row.number(0), row.number(1), row.data(2), row.args[3])
            let scheme = try Scheme(0, [Field]()).withLimits(parity: n)
            let error = packbinError { try unpackMapRepair(received, limit: t, scheme) }
            let fits: Bool
            switch kind {
            case "short":
                fits = error?.kind == .short && error?.name == "parity" && error?.needed == n && error?.left == received.count
            case "too_long":
                fits = error?.kind == .tooLong && error?.left == received.count && received.count > 254
            default:
                fits = error?.kind == .uncorrectable && error?.name == "" && error?.field == nil
            }
            if !fits { wrong.append("\(row.id): \(String(describing: error))") }
        }

        // Assert
        #expect(rows.count >= 1_000)
        #expect(wrong.isEmpty, "\(wrong.count) rows: \(wrong.prefix(5))")
    }

    @Test(arguments: try eccRows("lim"))
    func pack_limRow_succeedsOrIsRefusedNamingTheLengthAndTheLimit(_ row: EccRow) throws {
        // Arrange
        let (n, length) = (row.number(0), row.number(1))
        let clear = [UInt8](repeating: 0, count: length)
        let scheme = try rawScheme(for: clear, parity: n)

        // Act
        let error = packbinError { try pack(scheme, rawRow(clear)) }
        let size = (try? pack(scheme, rawRow(clear)).count) ?? 0

        // Assert
        if row.args[2] == "ok" {
            #expect(error == nil && size == length + n)
        } else {
            #expect(error?.kind == .packError && size == 0)
            #expect(error?.reason.contains(String(length)) == true && error?.reason.contains(String(254 - n)) == true,
                    "\(String(describing: error?.reason))")
        }
    }

    @Test(arguments: try eccRows("par"))
    func withLimits_parRow_isNotBuiltNamingTheCountAnd32(_ row: EccRow) throws {
        // Arrange
        let n = row.number(0)
        let base = try Scheme(1, [Field]())

        // Act
        let error = packbinError { try base.withLimits(parity: n) }

        // Assert
        #expect(error?.kind == .schemeError && error?.name == "parity")
        #expect(error?.reason.contains(String(n)) == true && error?.reason.contains("32") == true)
    }

    @Test(arguments: try eccRows("lmt"))
    func unpackRepair_lmtRow_refusesTheLimitBeforeAnyByteIsRead(_ row: EccRow) throws {
        // Arrange
        let (n, t) = (row.number(0), row.number(1))
        let scheme = try positionScheme(parity: n)
        let message = try pack(scheme, goldenMap())

        // Act
        let error = packbinError { try unpackMapRepair(message, limit: t, scheme) }
        let garbage = packbinError { try unpackMapRepair([], limit: t, scheme) }

        // Assert
        #expect(error?.kind == .schemeError && error?.name == "limit")
        #expect(garbage?.kind == .schemeError, "an empty buffer must not be read first")
    }

    @Test func rows_coverEveryKindOfTheFile() throws {
        // Assert: the loader finds the rows of each kind, so a changed file does not leave a test empty
        let counts = try ["enc", "fix", "bad", "lim", "par", "lmt"].map { try eccRows($0).count }
        #expect(counts[0] >= 40 && counts[1] >= 140 && counts[2] >= 1_000)
        #expect(counts[3] == 7 && counts[4] == 3 && counts[5] == 4)
    }
}
