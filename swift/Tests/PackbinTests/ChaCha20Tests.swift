@_spi(Vectors) import Packbin
import Testing

/// AZ-2518 AC-4 (SW-6): the in-package ChaCha20 against RFC 8439 §2.3.2 (one block) and §2.4.2 (114
/// bytes over two blocks from counter 1, the second block partial). The bytes are the RFC's; OpenSSL
/// 3.6 (`openssl enc -chacha20`) and TypeScript's `session-pad.ts` give the same.
@Suite struct ChaCha20Tests {
    /// The key of both RFC examples: 00 01 02 ... 1f.
    static let key = (0..<32).map { UInt8($0) }

    static let rfcBlock = """
        10f1e7e4d13b5915500fdd1fa32071c4c7d1f4c733c068030422aa9ac3d46c4e\
        d2826446079faa0914c2d705d98b02a2b5129cd1de164eb9cbd083e8a2503c4e
        """

    static let sunscreen = Array(("Ladies and Gentlemen of the class of '99: If I could offer you only one tip "
        + "for the future, sunscreen would be it.").utf8)

    static let rfcCiphertext = """
        6e2e359a2568f98041ba0728dd0d6981e97e7aec1d4360c20a27afccfd9fae0b\
        f91b65c5524733ab8f593dabcd62b3571639d624e65152ab8f530c359f0861d8\
        07ca0dbf500d6a6156a38e088a22b65e52bc514d16ccf806818ce91ab7793736\
        5af90bbf74a35be6b40b8eedf2785e42874d
        """

    @Test func block_rfc8439Section232_givesTheRfcBlock() throws {
        // Arrange
        let nonce = bytes("000000090000004a00000000")

        // Act
        let block = try ChaCha20.block(key: Self.key, nonce: nonce, counter: 1)

        // Assert
        #expect(hex(block) == Self.rfcBlock)
        #expect(mismatchedBytes(block, bytes(Self.rfcBlock)) == 0)
    }

    @Test func xor_rfc8439Section242_givesTheRfcCiphertext() throws {
        // Arrange
        var data = Self.sunscreen
        let nonce = bytes("000000000000004a00000000")

        // Act
        try ChaCha20.xor(&data, key: Self.key, nonce: nonce, counter: 1)

        // Assert
        #expect(Self.sunscreen.count == 114)
        #expect(hex(data) == Self.rfcCiphertext)
        #expect(mismatchedBytes(data, bytes(Self.rfcCiphertext)) == 0)
    }

    @Test func xor_rfc8439Section242Twice_givesThePlaintextBack() throws {
        // Arrange
        var data = bytes(Self.rfcCiphertext)
        let nonce = bytes("000000000000004a00000000")

        // Act
        try ChaCha20.xor(&data, key: Self.key, nonce: nonce, counter: 1)

        // Assert
        #expect(data == Self.sunscreen)
    }

    @Test func xor_300BytesOfZeroAtPacketFive_isTheKeyStreamOpenSSLGives() throws {
        // Arrange: the session's nonce for packet 5, from block 0; five blocks, the last one partial.
        var data = [UInt8](repeating: 0, count: 300)
        let nonce = bytes("050000000000000000000000")
        let openssl = """
            f84e3face34bb5941aab01082aadad99cd9183cf6126bf90fdb2aeb1fcacd9f24465f80b116c4150e7275f3e0ddb0d88\
            c4628c07af6a852503ec90e43363ba79d210f1e4ab7c932a16a78392dd653769dd964f315cc9cfee261c17796f099939\
            3fc06895e2f70a7dcb4cda4beff3abcf5ef42b10e0d517543e577cecc720cb7d098be76019d4947db0e988c415884a79\
            6074f6f9bfae8688bb3af3166bcb893bb07e92f08a478298d1e75a9d6cec133e56c6c1a7e7c30438a05e777e964bd06e\
            00d4e8b831342673c50391de4eb4958801c5c2297ed901991ae5e305d30e1cfb38e69133772b951eeeb79f424bffbb49\
            63886a89e3c6290d7ad21baead56d3baaa2c35812c05b27d90e20d2d312b1af8adf5ff38f06bfaa8ced72c9917167459\
            d63ce74c7468ab1364f27269
            """

        // Act
        try ChaCha20.xor(&data, key: Self.key, nonce: nonce, counter: 0)

        // Assert
        #expect(hex(data) == openssl)
    }

    @Test func xor_eachBlockOfAStream_isTheBlockOfItsCounter() throws {
        // Arrange
        let nonce = bytes("000000000000004a00000000")
        var stream = [UInt8](repeating: 0, count: 3 * ChaCha20.blockSize)

        // Act
        try ChaCha20.xor(&stream, key: Self.key, nonce: nonce, counter: 7)
        let blocks = try (7..<10).map { try ChaCha20.block(key: Self.key, nonce: nonce, counter: UInt32($0)) }

        // Assert
        #expect(stream == blocks.flatMap { $0 })
    }

    @Test func xor_theLastBlockCounter_isUsedOnce() throws {
        // Arrange
        let nonce = [UInt8](repeating: 0, count: ChaCha20.nonceSize)
        var full = [UInt8](repeating: 0, count: ChaCha20.blockSize)
        var empty: [UInt8] = []

        // Act
        try ChaCha20.xor(&full, key: Self.key, nonce: nonce, counter: .max)
        try ChaCha20.xor(&empty, key: Self.key, nonce: nonce, counter: .max)

        // Assert
        #expect(full == (try ChaCha20.block(key: Self.key, nonce: nonce, counter: .max)))
        #expect(empty.isEmpty)
    }

    @Test(arguments: [(UInt32.max, 65), (UInt32.max - 1, 129), (UInt32.max - 1, 1_000)])
    func xor_dataThatNeedsABlockAfterTheLast_isRefusedAndUnchanged(counter: UInt32, count: Int) {
        // Arrange
        let nonce = [UInt8](repeating: 0, count: ChaCha20.nonceSize)
        var data = [UInt8](repeating: 0xa5, count: count)

        // Act
        let error = packbinError { try ChaCha20.xor(&data, key: Self.key, nonce: nonce, counter: counter) }

        // Assert
        #expect(error?.kind == .badValue)
        #expect(error?.reason == "session: \(count) bytes from ChaCha20 block \(counter) pass the last block counter (4294967295)")
        #expect(data == [UInt8](repeating: 0xa5, count: count), "a refused run changes nothing")
    }

    @Test(arguments: [(31, 12, "key is 31 bytes, not 32"), (33, 12, "key is 33 bytes, not 32"),
                      (0, 12, "key is 0 bytes, not 32"), (32, 11, "nonce is 11 bytes, not 12"),
                      (32, 16, "nonce is 16 bytes, not 12"), (32, 0, "nonce is 0 bytes, not 12")])
    func blockAndXor_aKeyOrNonceOfAnotherLength_isRefused(keySize: Int, nonceSize: Int, reason: String) {
        // Arrange
        let key = [UInt8](repeating: 1, count: keySize)
        let nonce = [UInt8](repeating: 2, count: nonceSize)
        var data: [UInt8] = [1, 2, 3]

        // Act
        let blockError = packbinError { try ChaCha20.block(key: key, nonce: nonce, counter: 0) }
        let xorError = packbinError { try ChaCha20.xor(&data, key: key, nonce: nonce, counter: 0) }

        // Assert
        #expect(blockError?.kind == .badValue && blockError?.reason == "session: the ChaCha20 \(reason)")
        #expect(xorError?.kind == .badValue && xorError?.reason == "session: the ChaCha20 \(reason)")
        #expect(data == [1, 2, 3])
    }
}
