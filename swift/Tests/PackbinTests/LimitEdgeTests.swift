import Packbin
import Testing

/// S6 (SW-5): rows at 65 535 rounds, 1 048 576 slots and 16 MiB pack and unpack, one past is refused
/// naming the member (outcomes from TypeScript at HEAD); AC-3: a raised `maxSlots` unpacks the old
/// worst packet (F10) that the default refuses; AC-2: a maximal count with a short input is refused
/// with `needed` 0 at once, as no storage is made from a count before its rounds are charged.
@Suite(.serialized) struct LimitEdgeTests {
    private func f10Item() -> [String: Any] {
        var item: [String: Any] = ["n": 1]
        for i in 0..<64 { item["k\(i)"] = 1 }
        return item
    }

    @Test(.enabled(if: !threadSanitized, "one thread, no shared state: the thread sanitizer adds nothing and runs it about ten times slower"))
    func packAndUnpack_exactly1048576Slots_packAndUnpackAndOneRoundMoreIsRefused() throws {
        // Arrange: 16 384 items of one 64-slot round each
        let (scheme, packet) = try f10(items: 16_384)
        let (_, over) = try f10(items: 16_385)

        // Act
        let wire = try pack(scheme, ["items": [Any](repeating: f10Item(), count: 16_384)])
        let back = try unpackMap(wire, scheme)
        let refused = packError(scheme, ["items": [Any](repeating: f10Item(), count: 16_385)])
        let refusedUnpack = unpackError(over, scheme)

        // Assert
        #expect(wire == packet && wire.count == 1_064_963)
        #expect((back["items"] as? [Any])?.count == 16_384)
        #expect(isPackRefusal(refused, "k0", slotsText("k0", 1_048_640, 1_048_576)))
        #expect(isRefusedRound(refusedUnpack, "k0", left: 64))
    }

    /// list xs of 65 535 bytes(256), then bytes tail(253): 3 + 16 776 960 + 253 = 16 777 216 bytes.
    @Test(.enabled(if: !threadSanitized, "one thread, no shared state: the thread sanitizer adds nothing and runs it about ten times slower"))
    func packAndUnpack_exactly16MiB_packsAndUnpacksAndOneByteMoreIsRefused() throws {
        // Arrange
        let scheme = { (tail: Int) in try Scheme(1, .list("xs", .bytes(0, "x", size: 256)), .bytes(0, "tail", size: tail)) }
        let xs = [Any](repeating: [UInt8](repeating: 7, count: 256), count: 65_535)

        // Act
        let wire = try pack(try scheme(253), ["xs": xs, "tail": [UInt8](repeating: 0, count: 253)])
        let back = try unpackMap(wire, try scheme(253))
        let error = packError(try scheme(254), ["xs": xs, "tail": [UInt8](repeating: 0, count: 254)])

        // Assert
        #expect(wire.count == 16_777_216 && hex(Array(wire.prefix(16))) == "01ffff07070707070707070707070707")
        #expect((back["xs"] as? [Any])?.count == 65_535)
        #expect(isPackRefusal(error, "tail", bytesText("tail", 16_777_217, 16_777_216)))
    }

    @Test(.enabled(if: !threadSanitized, "one thread, no shared state: the thread sanitizer adds nothing and runs it about ten times slower"))
    func unpack_oldWorstPacket_isRefusedAtTheDefaultAndUnpacksWithMaxSlotsRaised() throws {
        // Arrange
        let (scheme, packet) = try f10()
        let raised = try scheme.withLimits(maxSlots: 4_194_304)

        // Act
        let refused = unpackError(packet, scheme)
        let row = try unpackMap(packet, raised)

        // Assert: refused at item 16 385, after 16 384 items hold 1 048 576 slots
        #expect(packet.count == 4_259_778)
        #expect(isRefusedRound(refused, "k0", left: 3_194_814))
        let items = row["items"] as? [Any] ?? []
        #expect(items.count == 65_535 && canon((items.last as? [String: Any])?["n"]) == "UInt8(1)")
    }

    @Test(.enabled(if: !threadSanitized, "one thread, no shared state: the thread sanitizer adds nothing and runs it about ten times slower"))
    func packAndUnpack_wideRoundWithMaxSlotsRaised_packsAndUnpacksAndTheDefaultRefusesIt() throws {
        // Arrange
        let (scheme, row) = try wideRound()
        let raised = try scheme.withLimits(maxSlots: 4_259_775)

        // Act
        let wire = try pack(raised, row)
        let back = try unpackMap(wire, raised)
        let refused = unpackError(wire, scheme)

        // Assert
        #expect(wire.count == 4_259_780 && hex(Array(wire.prefix(16))) == "01ffff00000101010101010101010101")
        #expect((back["m64"] as? [Any?])?.count == 65_535)
        #expect(isRefusedRound(refused, "m0", left: 3_211_260))
    }

    /// Int.max rounds asked of one byte, with the round limit raised to Int.max: the first round is
    /// read, the second is refused by the slot budget before anything is made for it. A walk that made
    /// storage from the count would trap or run out of memory here.
    @Test func unpack_maximalCountWithAShortInput_isRefusedWithNeeded0WithinASecond() throws {
        // Arrange
        let layout = try Scheme(1, .i64(0, "n"), .times(1, count: 0, .u8(1, "k")))
            .withLimits(maxRounds: Int.max, maxSlots: 1)

        // Act
        let (error, seconds) = timed { unpackError(bytes("01ffffffffffffff7f07"), layout) }

        // Assert
        #expect(isRefusedRound(error, "k", left: 0))
        #expect(error?.reason == "the rounds would hold 2 slots, above the limit of 1 slots")
        #expect(seconds < 1, "took \(seconds) s")
    }

    @Test func unpack_maximalCountAtTheDefaultLimits_isRefusedWhenRound65536StartsWithinASecond() throws {
        // Arrange
        let layout = try Scheme(1, .u64(0, "n"), .times(1, count: 0, .u8(1, "k")))
        let packet = bytes("01ffffffffffffff7f") + [UInt8](repeating: 7, count: 70_000)

        // Act
        let (error, seconds) = timed { unpackError(packet, layout) }

        // Assert
        #expect(isRefusedRound(error, "k", left: 70_000 - 65_535))
        #expect(seconds < 1, "took \(seconds) s")
    }

    /// TypeScript `round-scope-cost` (AZ-2391): a round and a list item cost the names they hold, not
    /// the fields around them; two sizes in one run, best of five.
    @Test(.enabled(if: !threadSanitized, "one thread, no shared state: the thread sanitizer adds nothing and runs it about ten times slower"), arguments: ["times", "list"])
    func pack_roundCost_doesNotGrowWithTheFieldsAroundIt(shape: String) throws {
        // Arrange
        func make(_ fill: Int) throws -> (Scheme, [String: Any]) {
            var fields: [Field] = [.u32(0, "n")]
            var row: [String: Any] = shape == "times" ? ["n": 65_535, "k": rounds(65_535, 7)] : ["n": 0, "xs": rounds(65_535, 7)]
            for i in 0..<fill {
                fields.append(.u8(i + 1, "f\(i)"))
                row["f\(i)"] = 1
            }
            fields.append(shape == "times" ? .times(fill + 1, count: 0, .u8(fill + 1, "k")) : .list("xs", .u8(0, "e")))
            return (try Scheme(1, fields), row)
        }
        func best(_ scheme: Scheme, _ row: [String: Any]) throws -> (Double, Int) {
            var fastest = Double.infinity
            var count = try pack(scheme, row).count
            for _ in 0..<5 {
                let (wire, seconds) = try timed { try pack(scheme, row) }
                fastest = min(fastest, seconds)
                count = wire.count
            }
            return (fastest, count)
        }
        let (smallScheme, smallRow) = try make(100)
        let (largeScheme, largeRow) = try make(1000)
        let extra = shape == "times" ? 4 : 6

        // Act
        let (small, smallCount) = try best(smallScheme, smallRow)
        let (large, largeCount) = try best(largeScheme, largeRow)

        // Assert
        #expect(smallCount == 1 + extra + 100 + 65_535 && largeCount == 1 + extra + 1000 + 65_535)
        #expect(large <= 2 * small + 0.01, "100 fields \(small) s, 1000 fields \(large) s")
    }

    @Test func pack_roundAfterOtherFields_writesTheCountAndTheFieldsAsBefore() throws {
        // Arrange
        let layout = try Scheme(1, .u32(0, "n"), .u8(1, "f0"), .u8(2, "f1"), .times(3, count: 0, .u8(3, "k")))

        // Act
        let wire = try packHex(layout, ["n": 3, "f0": 1, "f1": 1, "k": rounds(3, 7)])

        // Assert
        #expect(wire == "0103000000" + "0101" + "070707")
    }
}
