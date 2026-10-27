// The core's crypto module (src/core/crypto.hpp, kept for the frame port: owner decision D2 of
// loop 74) on the target. The published rows of fixtures/crypto/vectors.txt that matter for byte
// order and integer width are constants here, so the Cortex-M3, Cortex-M33F and big-endian s390x
// runners run the word loads and stores, the 32-bit rotates and the count-down loop of the
// stream XOR. The firmware runner builds this file: no heap, no OS calls, no file input. All 27
// rows (and a copy with one digit changed) run on the host in crypto_vectors_host_tests.cpp.
#include "../../src/core/crypto.hpp"

#include "check.hpp"

#include <cstdint>
#include <cstdio>
#include <cstring>

using check::expect;
namespace crypto = packbin::detail::crypto;

namespace {

constexpr std::size_t kDigest = crypto::kDigestSize;
constexpr std::size_t kBlock = crypto::kBlockSize;

std::uint8_t const* bytes_of(char const* text) {
  return reinterpret_cast<std::uint8_t const*>(text);
}

bool all_zero(void const* p, std::size_t n) {
  std::uint8_t const* b = static_cast<std::uint8_t const*>(p);
  for (std::size_t i = 0; i < n; ++i)
    if (b[i] != 0)
      return false;
  return true;
}

bool all_equal(std::uint8_t const* p, std::size_t n, std::uint8_t v) {
  for (std::size_t i = 0; i < n; ++i)
    if (p[i] != v)
      return false;
  return true;
}

// The digest of `msg` in one call, and fed in pieces of `step` bytes (at least 1) through the
// streaming state; both must equal `hex`.
bool digest_is(std::uint8_t const* msg, std::size_t len, std::size_t step, char const* hex) {
  std::uint8_t whole[kDigest];
  crypto::sha256(msg, len, whole);
  crypto::Sha256 s;
  for (std::size_t at = 0; at < len; at += step)
    s.update(msg + at, len - at < step ? len - at : step);
  std::uint8_t pieces[kDigest];
  s.finish(pieces);
  return check::same_hex(whole, sizeof(whole), hex) && check::same_hex(pieces, sizeof(pieces), hex);
}

// The MAC in one call, and with the data fed 5 bytes at a time; both must equal `hex`.
bool mac_is(std::uint8_t const* key, std::size_t key_len, std::uint8_t const* data,
            std::size_t len, char const* hex) {
  std::uint8_t whole[kDigest];
  crypto::hmac_sha256(key, key_len, data, len, whole);
  crypto::HmacSha256 mac;
  mac.begin(key, key_len);
  for (std::size_t at = 0; at < len; at += 5)
    mac.update(data + at, len - at < 5 ? len - at : 5);
  std::uint8_t pieces[kDigest];
  mac.end(pieces);
  return check::same_hex(whole, sizeof(whole), hex) && check::same_hex(pieces, sizeof(pieces), hex);
}

// Extract gives `prk_hex`; extract then expand, and expand of that prk, give the 42 bytes
// `okm_hex`.
bool hkdf_is(std::uint8_t const* ikm, std::size_t ikm_len, std::uint8_t const* salt,
             std::size_t salt_len, std::uint8_t const* info, std::size_t info_len,
             char const* prk_hex, char const* okm_hex) {
  std::uint8_t prk[kDigest];
  crypto::hkdf_extract(salt, salt_len, ikm, ikm_len, prk);
  std::uint8_t one[42];
  std::uint8_t two[42];
  bool ok = crypto::hkdf_sha256(ikm, ikm_len, salt, salt_len, info, info_len, one, sizeof(one));
  ok = crypto::hkdf_expand(prk, info, info_len, two, sizeof(two)) && ok;
  return ok && check::same_hex(prk, sizeof(prk), prk_hex) &&
         check::same_hex(one, sizeof(one), okm_hex) && check::same_hex(two, sizeof(two), okm_hex);
}

void key_00_to_1f(std::uint8_t (&key)[crypto::kKeySize]) {
  for (std::size_t i = 0; i < sizeof(key); ++i)
    key[i] = static_cast<std::uint8_t>(i);
}

constexpr char const* kTwoBlocks = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
constexpr char const* kLadies =
    "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, "
    "sunscreen would be it.";

void sha256_rows() {
  // Arrange
  std::uint8_t const none[1] = {0};
  std::uint8_t a[200];
  std::memset(a, 'a', sizeof(a));

  // Act and Assert
  expect(digest_is(none, 0, 1,
                   "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
         "crypto: SHA-256 of the empty message");
  expect(digest_is(bytes_of("abc"), 3, 1,
                   "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
         "crypto: SHA-256 of abc, byte by byte");
  expect(digest_is(bytes_of(kTwoBlocks), 56, 7,
                   "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"),
         "crypto: SHA-256 of the 448-bit message (padding takes a second block), 7-byte pieces");
  expect(digest_is(a, 55, 37,
                   "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318"),
         "crypto: SHA-256 of 55 bytes (the last length that pads in one block)");
  expect(digest_is(a, 64, 37,
                   "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb"),
         "crypto: SHA-256 of 64 bytes (a full block), split across the block");
  // Computed with Python hashlib, like the derived rows of the fixture.
  expect(digest_is(a, 200, 50,
                   "c2a908d98f5df987ade41b5fce213067efbcc21ef2240212a41e54b5e7c28ae5"),
         "crypto: SHA-256 of 200 bytes in 50-byte pieces (three blocks and a partial one)");
}

void hmac_rows() {
  // Arrange
  std::uint8_t key1[20];
  std::memset(key1, 0x0b, sizeof(key1));
  std::uint8_t key6[131];
  std::memset(key6, 0xaa, sizeof(key6));
  char const* long_key_text = "Test Using Larger Than Block-Size Key - Hash Key First";

  // Act and Assert
  expect(mac_is(key1, sizeof(key1), bytes_of("Hi There"), 8,
                "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7"),
         "crypto: HMAC-SHA256 RFC 4231 case 1");
  expect(mac_is(bytes_of("Jefe"), 4, bytes_of("what do ya want for nothing?"), 28,
                "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"),
         "crypto: HMAC-SHA256 RFC 4231 case 2");
  expect(mac_is(key6, sizeof(key6), bytes_of(long_key_text), std::strlen(long_key_text),
                "60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54"),
         "crypto: HMAC-SHA256 RFC 4231 case 6 (a key above 64 bytes is hashed first)");
}

void hkdf_rows() {
  // Arrange
  std::uint8_t ikm[22];
  std::memset(ikm, 0x0b, sizeof(ikm));
  std::uint8_t salt[13];
  check::parse_hex("000102030405060708090a0b0c", salt, sizeof(salt));
  std::uint8_t info[10];
  check::parse_hex("f0f1f2f3f4f5f6f7f8f9", info, sizeof(info));

  // Act and Assert
  expect(hkdf_is(ikm, sizeof(ikm), salt, sizeof(salt), info, sizeof(info),
                 "077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5",
                 "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf"
                 "34007208d5b887185865"),
         "crypto: HKDF-SHA256 RFC 5869 A.1");
  expect(hkdf_is(ikm, sizeof(ikm), nullptr, 0, nullptr, 0,
                 "19ef24a32c717b167f33a91d6f648bdf96596776afdb6377ac434c1c293ccb04",
                 "8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d"
                 "9d201395faa4b61a96c8"),
         "crypto: HKDF-SHA256 RFC 5869 A.3 (empty salt and info)");
}

void chacha_block_and_stream() {
  // Arrange
  std::uint8_t key[crypto::kKeySize];
  key_00_to_1f(key);
  std::uint8_t block_nonce[crypto::kNonceSize];
  check::parse_hex("000000090000004a00000000", block_nonce, sizeof(block_nonce));
  std::uint8_t stream_nonce[crypto::kNonceSize];
  check::parse_hex("000000000000004a00000000", stream_nonce, sizeof(stream_nonce));
  std::size_t len = std::strlen(kLadies);
  std::uint8_t data[128];
  std::memcpy(data, kLadies, len);

  // Act
  std::uint8_t block[kBlock];
  crypto::chacha20_block(key, block_nonce, 1, block);
  bool sealed = crypto::chacha20_xor(key, stream_nonce, 1, data, len);
  bool cipher_ok = check::same_hex(
      data, len,
      "6e2e359a2568f98041ba0728dd0d6981e97e7aec1d4360c20a27afccfd9fae0bf91b65c5524733ab8f593dab"
      "cd62b3571639d624e65152ab8f530c359f0861d807ca0dbf500d6a6156a38e088a22b65e52bc514d16ccf806"
      "818ce91ab77937365af90bbf74a35be6b40b8eedf2785e42874d");
  bool opened = crypto::chacha20_xor(key, stream_nonce, 1, data, len);

  // Assert
  expect(check::same_hex(block, sizeof(block),
                         "10f1e7e4d13b5915500fdd1fa32071c4c7d1f4c733c068030422aa9ac3d46c4e"
                         "d2826446079faa0914c2d705d98b02a2b5129cd1de164eb9cbd083e8a2503c4e"),
         "crypto: ChaCha20 block RFC 8439 2.3.2");
  expect(len == 114 && sealed && cipher_ok,
         "crypto: ChaCha20 RFC 8439 2.4.2, 114 bytes in two blocks, the second partial");
  expect(opened && std::memcmp(data, kLadies, len) == 0,
         "crypto: the same XOR again gives the plain text back");
}

// A stream of any length is the blocks of its key and nonce in a row with the last one cut short:
// the XOR of zero bytes is the pad itself, and it writes nothing past the length it is given.
void stream_is_the_blocks_in_a_row() {
  // Arrange
  std::uint8_t key[crypto::kKeySize];
  key_00_to_1f(key);
  std::uint8_t nonce[crypto::kNonceSize] = {9, 8, 7};
  std::uint8_t pad[3 * kBlock];
  for (std::uint32_t i = 0; i < 3; ++i)
    crypto::chacha20_block(key, nonce, 7 + i, pad + i * kBlock);
  static std::size_t const lengths[] = {1, 2, 63, 64, 65, 127, 128, 129, 191};

  for (std::size_t len : lengths) {
    // Act
    std::uint8_t data[3 * kBlock] = {};
    bool ok = crypto::chacha20_xor(key, nonce, 7, data, len);
    bool is_pad = std::memcmp(data, pad, len) == 0;
    bool stops = all_zero(data + len, sizeof(data) - len);

    // Assert
    char msg[96];
    std::snprintf(msg, sizeof(msg), "crypto: %u bytes of stream from counter 7 are the blocks",
                  static_cast<unsigned>(len));
    expect(ok && is_pad && stops, msg);
  }
}

// The block counter is 32 bits: a stream may use blocks up to counter 0xffffffff and no more.
void block_counter_edge() {
  // Arrange
  std::uint8_t key[crypto::kKeySize];
  key_00_to_1f(key);
  std::uint8_t nonce[crypto::kNonceSize] = {1, 2, 3};
  std::uint8_t last[kBlock];
  std::uint8_t before_last[kBlock];
  crypto::chacha20_block(key, nonce, 0xffffffffu, last);
  crypto::chacha20_block(key, nonce, 0xfffffffeu, before_last);
  std::uint8_t data[2 * kBlock + 1];
  std::uint8_t untouched[sizeof(data)];

  // Act
  std::memset(data, 0, sizeof(data));
  bool one = crypto::chacha20_xor(key, nonce, 0xffffffffu, data, kBlock);
  bool one_matches = std::memcmp(data, last, kBlock) == 0;
  std::memset(data, 0, sizeof(data));
  bool two = crypto::chacha20_xor(key, nonce, 0xfffffffeu, data, 2 * kBlock);
  bool two_match = std::memcmp(data, before_last, kBlock) == 0 &&
                   std::memcmp(data + kBlock, last, kBlock) == 0;
  std::memset(data, 0x5a, sizeof(data));
  std::memcpy(untouched, data, sizeof(data));
  bool over_one = crypto::chacha20_xor(key, nonce, 0xffffffffu, data, kBlock + 1);
  bool over_one_kept = std::memcmp(data, untouched, sizeof(data)) == 0;
  bool over_two = crypto::chacha20_xor(key, nonce, 0xfffffffeu, data, 2 * kBlock + 1);
  bool over_two_kept = std::memcmp(data, untouched, sizeof(data)) == 0;
  bool empty = crypto::chacha20_xor(key, nonce, 0xffffffffu, data, 0);

  // Assert
  expect(one && one_matches, "crypto: 64 bytes from counter 0xffffffff are that block");
  expect(two && two_match,
         "crypto: 128 bytes from counter 0xfffffffe are blocks 0xfffffffe and 0xffffffff");
  expect(!over_one && over_one_kept,
         "crypto: 65 bytes from counter 0xffffffff are refused and the data is untouched");
  expect(!over_two && over_two_kept,
         "crypto: 129 bytes from counter 0xfffffffe are refused and the data is untouched");
  expect(empty && std::memcmp(data, untouched, sizeof(data)) == 0,
         "crypto: no bytes from counter 0xffffffff is ok");
}

// RFC 5869 2.3: at most 255 blocks of output. The buffer is static: the targets have the RAM, and
// a stack of 8 KB is the wrong thing to ask of a vector test.
std::uint8_t g_okm[crypto::kMaxOkm + 1];

void hkdf_output_limit() {
  // Arrange
  std::uint8_t ikm[22];
  std::memset(ikm, 0x0b, sizeof(ikm));
  std::uint8_t salt[13];
  check::parse_hex("000102030405060708090a0b0c", salt, sizeof(salt));
  std::uint8_t info[10];
  check::parse_hex("f0f1f2f3f4f5f6f7f8f9", info, sizeof(info));
  std::uint8_t prk[kDigest];
  crypto::hkdf_extract(salt, sizeof(salt), ikm, sizeof(ikm), prk);
  std::memset(g_okm, 0xaa, sizeof(g_okm));

  // Act
  bool full = crypto::hkdf_expand(prk, info, sizeof(info), g_okm, crypto::kMaxOkm);
  bool sentinel = g_okm[crypto::kMaxOkm] == 0xaa;
  bool first = check::same_hex(g_okm, 42,
                               "3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf"
                               "34007208d5b887185865");
  // The last block (counter byte 255): computed with Python hmac, as RFC 5869 2.3 defines it; the
  // first 42 bytes of the same run are the RFC 5869 A.1 output above.
  bool last = check::same_hex(g_okm + crypto::kMaxOkm - kDigest, kDigest,
                              "76a3f78bcffe95fecf91923c22ad6ee64d48a6d1b981d7e523d5c0f22154ee88");
  std::memset(g_okm, 0xaa, sizeof(g_okm));
  bool over = crypto::hkdf_expand(prk, info, sizeof(info), g_okm, crypto::kMaxOkm + 1);
  bool over_kept = all_equal(g_okm, sizeof(g_okm), 0xaa);
  bool over_one = crypto::hkdf_sha256(ikm, sizeof(ikm), salt, sizeof(salt), info, sizeof(info),
                                      g_okm, crypto::kMaxOkm + 1);
  bool over_one_kept = all_equal(g_okm, sizeof(g_okm), 0xaa);

  // Assert
  expect(full && first && sentinel,
         "crypto: HKDF expands to 8,160 bytes and starts with the RFC 5869 A.1 output");
  expect(last, "crypto: the 255th HKDF block (counter byte 255) is the one HMAC gives");
  expect(!over && over_kept,
         "crypto: HKDF expand refuses 8,161 bytes and leaves the output untouched");
  expect(!over_one && over_one_kept,
         "crypto: HKDF extract and expand refuses 8,161 bytes and leaves the output untouched");
}

void wipe_clears_what_it_is_given() {
  // Arrange
  std::uint8_t key[32];
  std::memset(key, 0xa5, sizeof(key));
  std::uint8_t kept[4] = {1, 2, 3, 4};
  std::uint8_t out[kDigest];

  // Act
  crypto::wipe(key, sizeof(key));
  crypto::wipe(kept, 0);
  crypto::Sha256 s;
  s.update(bytes_of("abc"), 3);
  s.finish(out);
  crypto::HmacSha256 mac;
  mac.begin(bytes_of("Jefe"), 4);
  mac.update(bytes_of("data"), 4);
  mac.end(out);

  // Assert
  expect(all_zero(key, sizeof(key)), "crypto: wipe zeroes the bytes it is given");
  expect(kept[0] == 1 && kept[1] == 2 && kept[2] == 3 && kept[3] == 4,
         "crypto: wipe of no bytes touches nothing");
  expect(all_zero(&s, sizeof(s)), "crypto: SHA-256 finish wipes its state");
  expect(all_zero(&mac, sizeof(mac)), "crypto: HMAC end wipes its state and its pad");
}

}  // namespace

int run_core_crypto_tests() {
  sha256_rows();
  hmac_rows();
  hkdf_rows();
  chacha_block_and_stream();
  stream_is_the_blocks_in_a_row();
  block_counter_edge();
  hkdf_output_limit();
  wipe_clears_what_it_is_given();
  return check::failures();
}
