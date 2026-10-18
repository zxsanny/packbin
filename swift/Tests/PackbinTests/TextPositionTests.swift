import Foundation
import Packbin
import Testing

/// The field of the text `hello` as the vectors file gives it (`enc.hand.hello`), and of `capitals` as the
/// contract's worked example gives it (`textfmt.py enc`).
private func fieldOf(_ text: String) throws -> [UInt8] {
    if text == capitals { return bytes("0c83e6f54849fd8f96849cffe0") }
    let row = try #require(try textRows("enc").first { $0.textBytes == Array(text.utf8) })
    return row.field
}

private let hello = "привіт"
private let capitals = "Привіт, Світе!"

/// AC-3 and AC-5 (AZ-2654): every string position writes the compact field, and the count header is a
/// LEB128 varint of the payload length.
@Suite struct TextPositionTests {
    @Test func pack_stringsInAListAndARepeat_areFieldsOneAfterAnother() throws {
        // Arrange
        let a = try fieldOf(hello)
        let b = try fieldOf(capitals)
        let list = try Scheme(1, .list("l", .utf8(0, "e")))
        let rounds = try Scheme(1, .repeat(0, .utf8(0, "s")))

        // Act
        let listed = try pack(list, ["l": [hello, capitals]])
        let repeated = try pack(rounds, ["s": [hello, capitals]])

        // Assert
        #expect(listed == [1, 2, 0] + a + b)
        #expect(repeated == [1] + a + b)
        #expect(sameValue(try unpackMap(listed, list), ["l": [hello, capitals]]))
        #expect(sameValue(try unpackMap(repeated, rounds), ["s": [hello, capitals]]))
    }

    @Test func pack_loneStringUnderTimes_isTheSameFieldInEveryRound() throws {
        // Arrange
        let a = try fieldOf(hello)
        let scheme = try Scheme(1, .u8(0, "n"), .times(1, count: 0, .utf8(1, "s")))

        // Act
        let packet = try pack(scheme, ["n": 3, "s": hello])

        // Assert
        #expect(packet == [1, 3] + a + a + a)
        #expect(sameValue(try unpackMap(packet, scheme)["s"] as Any, [hello, hello, hello]))
    }

    @Test func pack_dictKeyAndValue_areFields() throws {
        // Arrange
        let key = try fieldOf(hello)
        let value = try fieldOf(capitals)
        let scheme = try Scheme(1, .dict("d", .utf8(0, "v")))

        // Act
        let packet = try pack(scheme, ["d": [hello: capitals]])

        // Assert
        #expect(packet == [1, 1, 0] + key + value)
        #expect(sameValue(try unpackMap(packet, scheme), ["d": [hello: capitals]]))
    }

    @Test func pack_optionalStringUnderFlags_absentAddsNothingAndEmptyAddsOneByte() throws {
        // Arrange
        let scheme = try Scheme(1, .flags(0, .u8(0, "a"), .utf8(1, "s")))
        let a = try fieldOf(hello)

        // Act
        let absent = try pack(scheme, ["a": 7])
        let empty = try pack(scheme, ["a": 7, "s": ""])
        let present = try pack(scheme, ["a": 7, "s": hello])

        // Assert: the flag byte is the second byte; the string bit is the second bit
        #expect(absent == [1, 0b01, 7])
        #expect(empty == [1, 0b11, 7, 0])
        #expect(present == [1, 0b11, 7] + a)
        let back = try unpackMap(empty, scheme)
        #expect(back["a"] as? UInt8 == 7 && utf8Of(back["s"]) == [])
        #expect(try unpackMap(absent, scheme)["s"] == nil)
    }

    @Test(arguments: [(126, 1, 127), (127, 2, 128), (16_382, 2, 16_383), (16_383, 3, 16_384)])
    func pack_textThatDoesNotCompress_hasAVarintCountOfOneTwoOrThreeBytes(_ shape: (length: Int, header: Int, payload: Int)) throws {
        // Arrange: the letter q costs more than 8 bits, so the raw payload (0x10 and the bytes) is written
        let scheme = try loneString()
        let text = String(repeating: "q", count: shape.length)

        // Act
        let packet = try pack(scheme, ["s": text])

        // Assert
        #expect(packet.count == 1 + shape.header + shape.payload)
        #expect(Array(packet[1..<(1 + shape.header)]) == leb128(shape.payload))
        #expect(packet[1 + shape.header] == 0x10)
        #expect(sameValue(try unpackMap(packet, scheme), ["s": text]))
    }

    @Test func pack_textOf65535And65536Bytes_isAcceptedAndRefusedNamingTheField() throws {
        // Arrange
        let scheme = try loneString()

        // Act
        let full = try pack(scheme, ["s": String(repeating: "q", count: 65_535)])
        let over = packbinError { try pack(scheme, ["s": String(repeating: "q", count: 65_536)]) }

        // Assert
        #expect(full.count == 1 + 3 + 65_536 && Array(full[1...3]) == leb128(65_536))
        #expect(over?.kind == .packError && over?.field == 0 && over?.name == "s" && over?.reason == "s: utf-8 length 65536")
    }

    @Test func pack_maxBytes_boundsThePacketIncludingTheCountHeader() throws {
        // Arrange: 126 letters q are a 127-byte payload and a 1-byte count: 1 + 1 + 127 = 129 bytes
        let text = String(repeating: "q", count: 126)
        let exact = try loneString().withLimits(maxBytes: 129)
        let tight = try loneString().withLimits(maxBytes: 128)

        // Act
        let packet = try pack(exact, ["s": text])
        let error = packbinError { try pack(tight, ["s": text]) }

        // Assert
        #expect(packet.count == 129)
        #expect(error?.kind == .packError && error?.name == "s" && error?.reason == bytesText("s", 129, 128))
    }

    @Test func pack_dictKeysInTwoInsertionOrders_giveTheSameBytesSortedByUTF8() throws {
        // Arrange
        let scheme = try Scheme(1, .dict("d", .u8(0, "v")))
        let keys = ["я", "б", "Я", "а"]
        var forward: [String: Int] = [:]
        for (i, k) in keys.enumerated() { forward[k] = i }
        var backward: [String: Int] = [:]
        for (i, k) in keys.enumerated().reversed() { backward[k] = i }

        // Act
        let a = try pack(scheme, ["d": forward])
        let b = try pack(scheme, ["d": backward])
        let back = try unpackMap(a, scheme)

        // Assert: Я (d0 af) < а (d0 b0) < б (d0 b1) < я (d1 8f)
        var expected: [UInt8] = [1, 4, 0]
        for k in ["Я", "а", "б", "я"] { expected += try keyField(k) + [UInt8(keys.firstIndex(of: k)!)] }
        #expect(a == b)
        #expect(a == expected)
        #expect((back["d"] as? [String: Any])?.count == 4)
    }

    @Test func unpack_dictKeyGivenTwice_isRefusedNamingTheDictionary() throws {
        // Arrange
        let scheme = try Scheme(1, .dict("d", .u8(0, "v")))
        let key = try keyField("я")
        let packet: [UInt8] = [1, 2, 0] + key + [1] + key + [2]

        // Act
        let error = packbinError { try unpackMap(packet, scheme) }

        // Assert
        #expect(error?.kind == .short && error?.name == "d" && error?.reason == "dict key given twice")
    }

    /// The field the encoder writes for a one-letter key (the raw payload when the compact one is not smaller).
    private func keyField(_ key: String) throws -> [UInt8] {
        let scheme = try loneString()
        return Array(try pack(scheme, ["s": key]).dropFirst())
    }
}

/// The LEB128 bytes of `n`.
private func leb128(_ n: Int) -> [UInt8] {
    var out: [UInt8] = []
    var rest = n
    while rest >= 0x80 {
        out.append(UInt8(rest & 0x7f) | 0x80)
        rest >>= 7
    }
    return out + [UInt8(rest)]
}

/// The tables of `Sources/Packbin/TextTables.swift` are the emitter's output for fixtures/text/tables.json.
@Suite struct TextTablesDriftTests {
    @Test func tablesFile_holdsEveryNumberOfTablesJSON() throws {
        // Arrange
        let source = try repositoryFile("swift/Sources/Packbin/TextTables.swift")
        let json = try #require(try JSONSerialization.jsonObject(
            with: Data(contentsOf: repositoryRoot.appendingPathComponent("fixtures/text/tables.json"))) as? [String: Any])
        let alphabets = try #require(json["alphabets"] as? [String: String])
        let uppers = try #require(json["upper"] as? [String: [String]])
        let modes = try #require(json["modes"] as? [String: [String: Any]])
        func scalars(_ s: String) -> [Int] { s.unicodeScalars.map { Int($0.value) } }
        var expected: [String: [Int]] = ["textShared": scalars(try #require(json["shared"] as? String)),
                                         "textNumset": scalars(try #require(json["numset"] as? String))]
        for (name, camel) in [("ua", "Ua"), ("ru", "Ru"), ("en", "En"), ("num", "Num")] {
            expected["textLengths\(camel)"] = (modes[name]?["lengths"] as? [Int]) ?? []
            if name != "num" {
                expected["text\(camel)"] = scalars(try #require(alphabets[name]))
                expected["text\(camel)Upper"] = (uppers[name] ?? []).map { scalars($0).first ?? 0 }
            }
        }

        // Act
        let found = Dictionary(uniqueKeysWithValues: expected.keys.map { ($0, numbers(of: $0, in: source)) })

        // Assert
        for (name, want) in expected { #expect(found[name] == want, "\(name)") }
        #expect(expected.count == 12 && !(found.values.contains { $0.isEmpty }))
    }

    @Test(.enabled(if: pythonRuns(), "python3 is not on this host"))
    func tablesFile_equalsTheEmitterOutput() throws {
        // Arrange
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", repositoryRoot.appendingPathComponent("scripts/text/emit_tables.py").path, "swift",
                             "--check", repositoryRoot.appendingPathComponent("swift/Sources/Packbin/TextTables.swift").path]
        process.standardInput = FileHandle.nullDevice

        // Act
        try process.run()
        process.waitUntilExit()

        // Assert
        #expect(process.terminationStatus == 0)
    }
}

/// The integers of the array `name` in the generated source.
private func numbers(of name: String, in source: String) -> [Int] {
    guard let start = source.range(of: "let \(name): ["),
          let open = source.range(of: "= [", range: start.lowerBound..<source.endIndex),
          let close = source.range(of: "]", range: open.upperBound..<source.endIndex) else { return [] }
    return source[open.upperBound..<close.lowerBound].split(whereSeparator: { $0 == "," || $0.isWhitespace }).compactMap { Int($0) }
}

private func pythonRuns() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["python3", "-c", "import sys"]
    process.standardInput = FileHandle.nullDevice
    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        return false
    }
}
