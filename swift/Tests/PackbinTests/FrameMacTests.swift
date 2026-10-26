import Packbin
import Testing

/// AZ-3234 AC-7 (S8; AC-G2.4): the MAC-only call on E4 and E5 and its refusals.
@Suite struct FrameMacTests {
    private struct Example {
        let key: [UInt8]
        let epoch: UInt32
        let label: [UInt8]
        let message: [UInt8]
        let tag: [UInt8]
    }

    private func examples() throws -> [Example] {
        let rows = frameRows(try repositoryFile("fixtures/frame/vectors.txt"))
        return try ["E4.mac", "E5.mac"].map { name in
            let row = try #require(rows.first { $0["case"] == name })
            return Example(key: vectorBytes(row["key"] ?? ""), epoch: UInt32(row["epoch"] ?? "") ?? 0,
                           label: vectorBytes(row["label"] ?? ""), message: vectorBytes(row["message"] ?? ""),
                           tag: vectorBytes(row["tag"] ?? ""))
        }
    }

    @Test func tag_overOneTwoAndThreeParts_everySplitGivesTheSameTag() throws {
        for example in try examples() {
            // Arrange
            let key = try MacKey.derive(key: example.key, epoch: example.epoch, label: example.label)
            let message = example.message
            var wrong = 0

            // Act
            wrong += try key.tag([message], length: 4) == example.tag ? 0 : 1
            for cut in 0...message.count {
                wrong += try key.tag([Array(message[..<cut]), Array(message[cut...])], length: 4) == example.tag ? 0 : 1
                for second in cut...message.count {
                    let parts = [Array(message[..<cut]), Array(message[cut..<second]), Array(message[second...])]
                    wrong += try key.tag(parts, length: 4) == example.tag ? 0 : 1
                    wrong += key.verify(parts, tag: example.tag) ? 0 : 1
                }
            }

            // Assert
            #expect(wrong == 0, "epoch \(example.epoch)")
            #expect(key.epoch == example.epoch)
        }
    }

    @Test func verify_aFlippedTagBitOrAnotherLength_isFalse() throws {
        for example in try examples() {
            // Arrange
            let key = try MacKey.derive(key: example.key, epoch: example.epoch, label: example.label)

            // Act
            let accepted = (0..<(example.tag.count * 8)).filter { key.verify([example.message], tag: flipped(example.tag, bit: $0)) }

            // Assert
            #expect(key.verify([example.message], tag: example.tag))
            #expect(accepted.isEmpty, "\(accepted)")
            #expect(!key.verify([example.message], tag: Array(example.tag.dropLast())))
            #expect(!key.verify([example.message], tag: []))
            #expect(!key.verify([example.message + [0]], tag: example.tag))
        }
    }

    @Test(arguments: [4, 8, 16, 32])
    func tag_eachAllowedLength_isAPrefixOfTheFullTag(length: Int) throws {
        // Arrange
        let example = try #require(try examples().first)
        let key = try MacKey.derive(key: example.key, epoch: example.epoch, label: example.label)

        // Act
        let tag = try key.tag([example.message], length: length)
        let full = try key.tag([example.message], length: 32)

        // Assert
        #expect(tag == Array(full.prefix(length)))
        #expect(key.verify([example.message], tag: tag))
    }

    @Test(arguments: [0, 1, 2, 3, 5, 7, 31, 33, 64, -4])
    func tag_aLengthOtherThan4816Or32_isBadValue(length: Int) throws {
        // Arrange
        let example = try #require(try examples().first)
        let key = try MacKey.derive(key: example.key, epoch: example.epoch, label: example.label)

        // Act
        let error = packbinError { try key.tag([example.message], length: length) }

        // Assert
        #expect(error?.kind == .badValue)
    }

    @Test func derive_aBadLabelKeyOrEpoch_isBadValue() throws {
        // Arrange
        let key = repeatedKey(0x22)

        // Act
        let none = packbinError { try MacKey.derive(key: key, epoch: 7, label: []) }
        let long = packbinError { try MacKey.derive(key: key, epoch: 7, label: [UInt8](repeating: 1, count: 33)) }
        let short = packbinError { try MacKey.derive(key: Array(key.dropLast()), epoch: 7, label: [1]) }
        let epoch = packbinError { try MacKey.derive(key: key, epoch: 0x0100_0000, label: [1]) }
        let widest = try MacKey.derive(key: key, epoch: 0x00FF_FFFF, label: [UInt8](repeating: 1, count: 32))

        // Assert
        #expect(none?.kind == .badValue && long?.kind == .badValue && short?.kind == .badValue && epoch?.kind == .badValue)
        #expect(widest.epoch == 0x00FF_FFFF)
    }

    @Test func tag_underAnotherLabelOrEpoch_isAnotherTag() throws {
        // Arrange
        let example = try #require(try examples().first)
        let base = try MacKey.derive(key: example.key, epoch: example.epoch, label: example.label)
        let label = try MacKey.derive(key: example.key, epoch: example.epoch, label: example.label + [0])
        let epoch = try MacKey.derive(key: example.key, epoch: example.epoch + 1, label: example.label)

        // Act
        let tags = try [base, label, epoch].map { try $0.tag([example.message], length: 32) }

        // Assert
        #expect(Set(tags).count == 3)
    }
}
