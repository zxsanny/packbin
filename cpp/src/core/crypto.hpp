#pragma once

// The core's primitives for frame mode (contract pack-session 2.0.0, ported to C++ in loop 75):
// SHA-256 (FIPS 180-4), HMAC-SHA-256 (RFC 2104), HKDF-SHA-256 (RFC 5869) and the ChaCha20 block
// and stream (RFC 8439). Internal: no header under include/ names it. No heap, no OS calls, no
// mutable global state; key material held in locals is wiped before a function returns.
// tests/core/crypto_vectors_host_tests.cpp checks every row of fixtures/crypto/vectors.txt.

#include "packbin/platform.hpp"

namespace packbin {
namespace detail {
namespace crypto {

constexpr std::size_t kDigestSize = 32;
// The SHA-256 block and the ChaCha20 block are both 64 bytes.
constexpr std::size_t kBlockSize = 64;
constexpr std::size_t kKeySize = 32;
constexpr std::size_t kNonceSize = 12;
// HKDF-SHA-256 expands to at most 255 blocks of the digest (RFC 5869 2.3).
constexpr std::size_t kMaxOkm = 255 * kDigestSize;

// Zeroes `n` bytes through volatile stores, so the compiler keeps a wipe it sees as dead.
void wipe(void* p, std::size_t n);

// Streaming SHA-256: the message goes through one 64-byte block buffer, so no padded copy of it
// is ever held. `finish` writes the digest and wipes the state; a new message needs a new Sha256.
struct Sha256 {
  std::uint32_t h[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
  std::uint8_t block[kBlockSize] = {};
  std::size_t fill = 0;
  std::uint64_t total = 0;

  void update(std::uint8_t const* p, std::size_t n);
  void finish(std::uint8_t out[kDigestSize]);

 private:
  void compress();
};

void sha256(std::uint8_t const* msg, std::size_t len, std::uint8_t out[kDigestSize]);

// HMAC-SHA-256; the message may arrive in parts between `begin` and `end`. A key above 64 bytes
// is hashed first. `end` writes the MAC and wipes the state.
struct HmacSha256 {
  Sha256 inner;
  std::uint8_t opad[kBlockSize] = {};

  void begin(std::uint8_t const* key, std::size_t key_len);
  void update(std::uint8_t const* p, std::size_t n);
  void end(std::uint8_t out[kDigestSize]);
};

void hmac_sha256(std::uint8_t const* key, std::size_t key_len, std::uint8_t const* msg,
                 std::size_t len, std::uint8_t out[kDigestSize]);

// HKDF-SHA-256 extract: prk = HMAC(salt, ikm). An empty salt is the 32 zero bytes of the RFC.
void hkdf_extract(std::uint8_t const* salt, std::size_t salt_len, std::uint8_t const* ikm,
                  std::size_t ikm_len, std::uint8_t prk[kDigestSize]);

// HKDF-SHA-256 expand of `prk` with `info` into `okm_len` bytes. False (and `okm` untouched)
// when `okm_len` is above kMaxOkm.
bool hkdf_expand(std::uint8_t const prk[kDigestSize], std::uint8_t const* info,
                 std::size_t info_len, std::uint8_t* okm, std::size_t okm_len);

// Extract then expand; false as `hkdf_expand`.
bool hkdf_sha256(std::uint8_t const* ikm, std::size_t ikm_len, std::uint8_t const* salt,
                 std::size_t salt_len, std::uint8_t const* info, std::size_t info_len,
                 std::uint8_t* okm, std::size_t okm_len);

// The 64-byte ChaCha20 block of `key`, the 12-byte `nonce` and the 32-bit block `counter`.
void chacha20_block(std::uint8_t const key[kKeySize], std::uint8_t const nonce[kNonceSize],
                    std::uint32_t counter, std::uint8_t out[kBlockSize]);

// XORs `data` in place with the ChaCha20 stream from block `counter` on (encrypts and decrypts).
// False (and `data` untouched) when the stream would need a block counter above 2^32 - 1.
bool chacha20_xor(std::uint8_t const key[kKeySize], std::uint8_t const nonce[kNonceSize],
                  std::uint32_t counter, std::uint8_t* data, std::size_t len);

}  // namespace crypto
}  // namespace detail
}  // namespace packbin
