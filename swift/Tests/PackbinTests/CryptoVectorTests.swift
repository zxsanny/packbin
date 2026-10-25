import Foundation
@_spi(Vectors) import Packbin
import Testing

/// The rows of `fixtures/crypto/vectors.txt` the primitives do not match, each as `<primitive> <source>: <what>`;
/// `ran` counts the rows run. The primitives are the ones the package calls: the platform's SHA-256, HMAC-SHA256
/// and HKDF-SHA256 (`FramePrimitives`) and the in-package ChaCha20.
func primitiveFailures(_ text: String, ran: inout Int) -> [String] {
    var failures: [String] = []
    for line in text.split(separator: "\n") where !line.hasPrefix("#") && !line.isEmpty {
        let words = line.split(separator: " ")
        let id = "\(words[0]) \(words[1])"
        var row = VectorRow()
        for word in words.dropFirst(2) {
            let pair = word.split(separator: "=", maxSplits: 1)
            row[String(pair[0])] = String(pair[1])
        }
        let got: [(field: String, bytes: [UInt8])]
        do {
            got = try primitiveOutputs(String(words[0]), row)
        } catch {
            failures.append("\(id): \(error)")
            continue
        }
        ran += 1
        let cut = row["truncate"].flatMap { Int($0) }
        for (field, value) in got {
            let want = vectorBytes(row[field] ?? "")
            let shown = cut.map { Array(value.prefix($0)) } ?? value
            if shown != want { failures.append("\(id): \(field) expected \(vectorHex(want)) got \(vectorHex(shown))") }
        }
    }
    return failures
}

private struct UnknownPrimitive: Error {
    let name: String
}

private func primitiveOutputs(_ primitive: String, _ row: VectorRow) throws -> [(field: String, bytes: [UInt8])] {
    let key = vectorBytes(row["key"] ?? "")
    switch primitive {
    case "sha256":
        let message = row["repeat"].map { [UInt8](repeating: vectorBytes(row["byte"] ?? "")[0], count: Int($0) ?? 0) }
            ?? vectorBytes(row["msg"] ?? "")
        return [("digest", FramePrimitives.sha256(message))]
    case "hmac256":
        return [("mac", FramePrimitives.hmac256(key: key, data: vectorBytes(row["data"] ?? "")))]
    case "hkdf256":
        let (ikm, salt) = (vectorBytes(row["ikm"] ?? ""), vectorBytes(row["salt"] ?? ""))
        return [("prk", FramePrimitives.hkdfExtract(ikm: ikm, salt: salt)),
                ("okm", FramePrimitives.hkdf256(ikm: ikm, salt: salt, info: vectorBytes(row["info"] ?? ""),
                                                length: Int(row["len"] ?? "") ?? 0))]
    case "chacha-block":
        return [("block", try ChaCha20.block(key: key, nonce: vectorBytes(row["nonce"] ?? ""),
                                             counter: UInt32(row["counter"] ?? "") ?? 0))]
    case "chacha-xor":
        var data = vectorBytes(row["plain"] ?? "")
        try ChaCha20.xor(&data, key: key, nonce: vectorBytes(row["nonce"] ?? ""), counter: UInt32(row["counter"] ?? "") ?? 0)
        return [("cipher", data)]
    default:
        throw UnknownPrimitive(name: primitive)
    }
}

/// AZ-3234 AC-2 and AC-3 (PB-02; AC-G1.2, AC-G1.3): the published SHA-256, HMAC-SHA256, HKDF-SHA256 and ChaCha20
/// rows of `fixtures/crypto/vectors.txt`, and the loader on a copy with one expected byte changed. The file holds
/// 27 rows (6 SHA-256, 8 HMAC, 3 HKDF, 6 ChaCha20 blocks, 4 ChaCha20 ciphers); the task text says 39, which is its
/// line count with the comments.
@Suite struct CryptoVectorTests {
    @Test func everyRow_matchesThePublishedValue() throws {
        // Arrange
        let text = try repositoryFile("fixtures/crypto/vectors.txt")
        var ran = 0

        // Act
        let failures = primitiveFailures(text, ran: &ran)

        // Assert
        #expect(failures.isEmpty, "\(failures.prefix(5))")
        #expect(ran == 27, "\(ran) rows ran")
    }

    @Test(arguments: [("sha256 fips180-4:b.1", "digest"), ("hmac256 rfc4231:4.2", "mac"), ("hkdf256 rfc5869:a.1", "okm"),
                      ("hkdf256 rfc5869:a.3", "prk"), ("chacha-block rfc8439:2.3.2", "block"),
                      ("chacha-xor rfc8439:2.4.2", "cipher")])
    func loader_oneExpectedByteChanged_failsAndNamesTheRow(row: String, field: String) throws {
        // Arrange
        let text = try repositoryFile("fixtures/crypto/vectors.txt")
        let changed = corrupted(text, field: field) { $0.hasPrefix(row + " ") }
        var ran = 0

        // Act
        let failures = primitiveFailures(changed, ran: &ran)

        // Assert
        #expect(changed != text, "the copy differs from the file")
        #expect(failures.count == 1, "\(failures)")
        #expect(failures.first?.hasPrefix(row + ":") == true, "\(failures)")
    }
}
