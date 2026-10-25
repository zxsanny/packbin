import Packbin
import Testing

/// AZ-3234 (README example for the docs task): the code between `README-BEGIN` and `README-END` is the frame-mode
/// example of the README, run as printed. The values are the contract's worked examples E1 (the key, the epoch, the
/// message id and the associated data) and E4 (the MAC-only tag).
@Suite struct FrameReadmeExampleTests {
    @Test func readmeExample_sealOpenWithAWindowAndMacOnly_runsAsPrinted() throws {
        // README-BEGIN
        // Load once: the keys of each direction are derived here. One tag length (4, 8 or 16) per key.
        let key = [UInt8](repeating: 0x11, count: 32)
        let node = try FrameSession.load(key: key, epoch: 1, config: FrameConfig(tagLength: 4))

        // A message id that is never sealed twice with other contents under one (key, epoch, direction).
        let context = MessageContext(msgID: [0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0], kind: 4)
        let ad: [UInt8] = [0, 1, 0, 0x30, 0x10, 0x05, 0xe8, 3, 0, 0, 4]  // authenticated, not sent

        // Seal into your own buffer: clear part, then ciphertext, then the 4-byte tag.
        var body = [UInt8](repeating: 0, count: 255)
        let length = try node.seal(direction: .up, context: context, ad: ad, clear: [],
                                   plain: Array("hello, relay".utf8), into: &body)  // 12 + 4 bytes

        // Open with the sender's replay window. The counter must come from bytes the tag covers.
        var window = ReplayWindow()
        var plain = [UInt8](repeating: 0, count: 255)
        let opened = try node.open(direction: .up, context: context, ad: ad, body: Array(body[0..<length]),
                                   clearLength: 0, window: &window, counter: 7, into: &plain)
        // opened.slot == .current, String(decoding: plain[0..<opened.plainLength], as: UTF8.self) == "hello, relay"

        // The same frame again is refused before any MAC is computed.
        var replayKind: PackbinError.Kind?
        do {
            _ = try node.open(direction: .up, context: context, ad: ad, body: Array(body[0..<length]), clearLength: 0,
                              window: &window, counter: 7, into: &plain)
        } catch let error as PackbinError {
            replayKind = error.kind  // .duplicate
        }

        // MAC-only: a 4-byte network check over a wave number and the frame bytes, hashed in parts.
        let net = try MacKey.derive(key: [UInt8](repeating: 0x22, count: 32), epoch: 7, label: Array("net".utf8))
        let wave: [UInt8] = [0xe8, 3, 0, 0]
        let frame: [UInt8] = Array(0xc0...0xd3)
        let tag = try net.tag([wave, frame], length: 4)  // 56db9bec
        let valid = net.verify([wave, frame], tag: tag)
        // README-END

        #expect(length == 16)
        #expect(opened == FrameOpened(slot: .current, clearLength: 0, plainLength: 12))
        #expect(String(decoding: plain[0..<opened.plainLength], as: UTF8.self) == "hello, relay")
        #expect(replayKind == .duplicate)
        #expect(tag == [0x56, 0xdb, 0x9b, 0xec] && valid)
    }
}
