import Packbin
import Testing

/// AC-1 to AC-4 and AC-6 (AZ-2654): every row of fixtures/text/vectors.txt, the compact text format of
/// compact-text.md, packed and unpacked by the Swift package.
@Suite struct TextVectorTests {
    @Test(arguments: try textRows("enc"))
    func pack_encRow_givesExactlyTheRowsBytes(_ row: TextRow) throws {
        // Arrange
        let scheme = try loneString()

        // Act
        let packet = try pack(scheme, ["s": row.text])

        // Assert
        #expect(hex(packet) == "01" + hex(row.field))
    }

    @Test(arguments: try textRows("enc") + textRows("alt"))
    func unpack_encOrAltRow_givesTheTextAndUsesEveryByte(_ row: TextRow) throws {
        // Arrange
        let scheme = try loneString()

        // Act
        let text = try unpackMap([1] + row.field, scheme)["s"]

        // Assert: compared as UTF-8 bytes, since String == is canonical equivalence
        #expect(utf8Of(text) == row.textBytes)
    }

    @Test(arguments: try textRows("bad"))
    func unpack_badRow_isRefusedNamingTheFieldWithNoRow(_ row: TextRow) throws {
        // Arrange
        let scheme = try loneString()

        // Act
        let error = unpackRefusal([1] + row.field, scheme)

        // Assert
        #expect(error?.name == "s" && error?.field == 0, "\(row.id): \(String(describing: error))")
    }

    @Test(arguments: try textRows("flip"))
    func unpack_flippedPayloadBit_givesAStringOrAnErrorAndLeavesTheNextByte(_ row: TextRow) throws {
        // Arrange
        let source = try #require(try textRows("enc").first { $0.id == row.rest[0] })
        let field = source.field
        let header = field[0] < 0x80 ? 1 : 2
        let scheme = try stringThenByte()

        // Act and Assert
        for byte in header..<field.count {
            for bit in 0..<8 {
                var damaged = field
                damaged[byte] ^= UInt8(1 << bit)
                let packet = [1] + damaged + [0x5a]
                if let error = unpackRefusal(packet, scheme) {
                    #expect(error.name == "s", "\(row.id) byte \(byte) bit \(bit): \(error)")
                } else {
                    let map = try unpackMap(packet, scheme)
                    #expect(map["t"] as? UInt8 == 0x5a && map["s"] is String, "\(row.id) byte \(byte) bit \(bit)")
                }
            }
        }
    }

    @Test(arguments: ["ref.user", "ref.user_ua", "ref.nested", "ref.nested_mixed"])
    func packAndUnpack_ringPacket_givesTheRefRowBytesAndTheRow(_ id: String) throws {
        // Arrange
        let ref = try #require(try textRows("ref").first { $0.id == id })
        let (scheme, row) = try #require(try refCase(id))

        // Act
        let packet = try pack(scheme, row)
        let back = try unpackMap(ref.field, scheme)

        // Assert
        #expect(hex(packet) == hex(ref.field))
        #expect(sameValue(back, row))
    }

    @Test func rows_coverEveryKindTheTestsRun() throws {
        // Assert: the loader finds the rows of each kind, so a changed file does not leave a test empty
        #expect(try textRows("enc").count >= 300 && textRows("alt").count >= 5 && textRows("bad").count >= 30)
        #expect(try textRows("ref").count == 4 && textRows("flip").count >= 20)
    }
}
