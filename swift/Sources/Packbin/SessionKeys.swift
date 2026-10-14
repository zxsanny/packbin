#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// The HKDF info of the contract: the ASCII bytes "packbin".
private let sessionInfo = Array("packbin".utf8)

/// HKDF-SHA256 (RFC 5869) of the session contract: the seed is the input key, the 16 bytes are the
/// salt, the info is "packbin", and the output is 64 bytes, the opener's send key then its receive
/// key. CryptoKit on Apple platforms, swift-crypto's `Crypto` elsewhere: the same API and bytes. The
/// derived `SymmetricKey` zeroes its own storage when it is released.
@available(tvOS 14.0, watchOS 7.0, *)
func sessionKeys(seed: [UInt8], nonce: [UInt8]) -> [UInt8] {
    let both = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: seed), salt: nonce,
                                      info: sessionInfo, outputByteCount: 2 * PackSession.seedSize)
    return both.withUnsafeBytes { [UInt8]($0) }
}
