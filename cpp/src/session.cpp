#include "packbin/packbin.hpp"

#include <array>
#include <cstring>
#include <fstream>

#if defined(__APPLE__)
#include <stdlib.h>
#elif defined(__linux__)
#include <sys/random.h>
#endif

namespace packbin {
namespace {

constexpr char const kInfo[] = "packbin";

void wipe(std::uint8_t* p, std::size_t n) {
  volatile std::uint8_t* v = p;
  for (std::size_t i = 0; i < n; ++i)
    v[i] = 0;
}

std::uint32_t rotr(std::uint32_t x, int n) { return (x >> n) | (x << (32 - n)); }
std::uint32_t rotl(std::uint32_t x, int n) { return (x << n) | (x >> (32 - n)); }

std::uint32_t load32(std::uint8_t const* p) {
  return static_cast<std::uint32_t>(p[0]) | (static_cast<std::uint32_t>(p[1]) << 8) |
         (static_cast<std::uint32_t>(p[2]) << 16) | (static_cast<std::uint32_t>(p[3]) << 24);
}

void store32(std::uint8_t* p, std::uint32_t v) {
  p[0] = static_cast<std::uint8_t>(v);
  p[1] = static_cast<std::uint8_t>(v >> 8);
  p[2] = static_cast<std::uint8_t>(v >> 16);
  p[3] = static_cast<std::uint8_t>(v >> 24);
}

void store64(std::uint8_t* p, std::uint64_t v) {
  for (int i = 0; i < 8; ++i)
    p[i] = static_cast<std::uint8_t>(v >> (8 * i));
}

void sha256(std::uint8_t const* msg, std::size_t len, std::uint8_t out[32]) {
  static constexpr std::uint32_t k[64] = {
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
      0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
      0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
      0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
      0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
      0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
      0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
      0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
      0xc67178f2};

  std::uint32_t h[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                         0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};

  std::uint64_t bit_len = static_cast<std::uint64_t>(len) * 8;
  std::size_t padded = ((len + 9 + 63) / 64) * 64;
  std::vector<std::uint8_t> buf(padded, 0);
  if (len)
    std::memcpy(buf.data(), msg, len);
  buf[len] = 0x80;
  for (int i = 0; i < 8; ++i)
    buf[padded - 1 - i] = static_cast<std::uint8_t>(bit_len >> (8 * i));

  for (std::size_t off = 0; off < padded; off += 64) {
    std::uint32_t w[64];
    for (int i = 0; i < 16; ++i)
      w[i] = (static_cast<std::uint32_t>(buf[off + i * 4]) << 24) |
             (static_cast<std::uint32_t>(buf[off + i * 4 + 1]) << 16) |
             (static_cast<std::uint32_t>(buf[off + i * 4 + 2]) << 8) |
             static_cast<std::uint32_t>(buf[off + i * 4 + 3]);
    for (int i = 16; i < 64; ++i) {
      std::uint32_t s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      std::uint32_t s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    std::uint32_t a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6],
                  hh = h[7];
    for (int i = 0; i < 64; ++i) {
      std::uint32_t S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      std::uint32_t ch = (e & f) ^ ((~e) & g);
      std::uint32_t t1 = hh + S1 + ch + k[i] + w[i];
      std::uint32_t S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      std::uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
      std::uint32_t t2 = S0 + maj;
      hh = g;
      g = f;
      f = e;
      e = d + t1;
      d = c;
      c = b;
      b = a;
      a = t1 + t2;
    }
    h[0] += a;
    h[1] += b;
    h[2] += c;
    h[3] += d;
    h[4] += e;
    h[5] += f;
    h[6] += g;
    h[7] += hh;
  }

  for (int i = 0; i < 8; ++i) {
    out[i * 4] = static_cast<std::uint8_t>(h[i] >> 24);
    out[i * 4 + 1] = static_cast<std::uint8_t>(h[i] >> 16);
    out[i * 4 + 2] = static_cast<std::uint8_t>(h[i] >> 8);
    out[i * 4 + 3] = static_cast<std::uint8_t>(h[i]);
  }
  wipe(buf.data(), buf.size());
}

void hmac_sha256(std::uint8_t const* key, std::size_t key_len, std::uint8_t const* msg,
                 std::size_t msg_len, std::uint8_t out[32]) {
  std::uint8_t kh[32];
  std::uint8_t const* k = key;
  std::size_t kl = key_len;
  if (key_len > 64) {
    sha256(key, key_len, kh);
    k = kh;
    kl = 32;
  }
  std::uint8_t ipad[64];
  std::uint8_t opad[64];
  std::memset(ipad, 0x36, 64);
  std::memset(opad, 0x5c, 64);
  for (std::size_t i = 0; i < kl; ++i) {
    ipad[i] ^= k[i];
    opad[i] ^= k[i];
  }
  std::vector<std::uint8_t> inner(64 + msg_len);
  std::memcpy(inner.data(), ipad, 64);
  if (msg_len)
    std::memcpy(inner.data() + 64, msg, msg_len);
  std::uint8_t ih[32];
  sha256(inner.data(), inner.size(), ih);
  std::uint8_t outer[64 + 32];
  std::memcpy(outer, opad, 64);
  std::memcpy(outer + 64, ih, 32);
  sha256(outer, sizeof(outer), out);
  wipe(kh, 32);
  wipe(ipad, 64);
  wipe(opad, 64);
  wipe(inner.data(), inner.size());
  wipe(ih, 32);
  wipe(outer, sizeof(outer));
}

void hkdf_sha256(std::uint8_t const* ikm, std::size_t ikm_len, std::uint8_t const* salt,
                 std::size_t salt_len, std::uint8_t const* info, std::size_t info_len,
                 std::uint8_t* okm, std::size_t okm_len) {
  std::uint8_t prk[32];
  hmac_sha256(salt, salt_len, ikm, ikm_len, prk);
  std::uint8_t t[32];
  std::size_t t_len = 0;
  std::size_t produced = 0;
  std::uint8_t counter = 1;
  while (produced < okm_len) {
    std::vector<std::uint8_t> msg;
    msg.reserve(t_len + info_len + 1);
    if (t_len)
      msg.insert(msg.end(), t, t + t_len);
    if (info_len)
      msg.insert(msg.end(), info, info + info_len);
    msg.push_back(counter);
    hmac_sha256(prk, 32, msg.data(), msg.size(), t);
    t_len = 32;
    std::size_t n = okm_len - produced;
    if (n > 32)
      n = 32;
    std::memcpy(okm + produced, t, n);
    produced += n;
    ++counter;
    wipe(msg.data(), msg.size());
  }
  wipe(prk, 32);
  wipe(t, 32);
}

void quarter(std::uint32_t* w, int a, int b, int c, int d) {
  w[a] += w[b];
  w[d] ^= w[a];
  w[d] = rotl(w[d], 16);
  w[c] += w[d];
  w[b] ^= w[c];
  w[b] = rotl(w[b], 12);
  w[a] += w[b];
  w[d] ^= w[a];
  w[d] = rotl(w[d], 8);
  w[c] += w[d];
  w[b] ^= w[c];
  w[b] = rotl(w[b], 7);
}

void chacha_block(std::uint8_t const key[32], std::uint8_t const nonce[12], std::uint32_t counter,
                  std::uint8_t output[64]) {
  std::uint32_t state[16];
  state[0] = 0x61707865;
  state[1] = 0x3320646e;
  state[2] = 0x79622d32;
  state[3] = 0x6b206574;
  for (int i = 0; i < 8; ++i)
    state[4 + i] = load32(key + i * 4);
  state[12] = counter;
  state[13] = load32(nonce);
  state[14] = load32(nonce + 4);
  state[15] = load32(nonce + 8);

  std::uint32_t work[16];
  std::memcpy(work, state, sizeof(state));
  for (int i = 0; i < 10; ++i) {
    quarter(work, 0, 4, 8, 12);
    quarter(work, 1, 5, 9, 13);
    quarter(work, 2, 6, 10, 14);
    quarter(work, 3, 7, 11, 15);
    quarter(work, 0, 5, 10, 15);
    quarter(work, 1, 6, 11, 12);
    quarter(work, 2, 7, 8, 13);
    quarter(work, 3, 4, 9, 14);
  }
  for (int i = 0; i < 16; ++i)
    store32(output + i * 4, work[i] + state[i]);
}

void chacha_xor(std::uint8_t const key[32], std::uint8_t const nonce[12], std::uint32_t counter,
                std::uint8_t* data, std::size_t len) {
  std::uint8_t block[64];
  std::size_t offset = 0;
  while (offset < len) {
    chacha_block(key, nonce, counter, block);
    std::size_t n = len - offset;
    if (n > 64)
      n = 64;
    for (std::size_t i = 0; i < n; ++i)
      data[offset + i] ^= block[i];
    offset += n;
    ++counter;
  }
  wipe(block, 64);
}

bool fill_random(std::uint8_t* out, std::size_t n) {
#if defined(__APPLE__)
  arc4random_buf(out, n);
  return true;
#elif defined(__linux__)
  return getentropy(out, n) == 0;
#else
  std::ifstream in("/dev/urandom", std::ios::binary);
  if (!in)
    return false;
  in.read(reinterpret_cast<char*>(out), static_cast<std::streamsize>(n));
  return static_cast<std::size_t>(in.gcount()) == n;
#endif
}

}  // namespace

PackSession::PackSession(std::array<std::uint8_t, SeedSize> seed) : seed_(seed) {}

std::optional<PackSession> PackSession::load(std::uint8_t const* seed, std::size_t len) {
  if (len != SeedSize)
    return std::nullopt;
  std::array<std::uint8_t, SeedSize> copy{};
  std::memcpy(copy.data(), seed, SeedSize);
  return PackSession(copy);
}

std::optional<std::vector<std::uint8_t>> PackSession::start() {
  if (send_ || !seed_)
    return std::nullopt;
  std::vector<std::uint8_t> nonce(NonceSize);
  if (!fill_random(nonce.data(), NonceSize))
    return std::nullopt;
  return start(nonce.data(), nonce.size());
}

std::optional<std::vector<std::uint8_t>> PackSession::start(std::uint8_t const* nonce,
                                                            std::size_t len) {
  if (!open(nonce, len, true))
    return std::nullopt;
  return std::vector<std::uint8_t>(nonce, nonce + len);
}

bool PackSession::join(std::uint8_t const* nonce, std::size_t len) {
  return open(nonce, len, false);
}

bool PackSession::open(std::uint8_t const* nonce, std::size_t len, bool initiator) {
  if (!seed_ || send_ || len != NonceSize)
    return false;
  std::uint8_t both[SeedSize * 2];
  hkdf_sha256(seed_->data(), SeedSize, nonce, NonceSize,
              reinterpret_cast<std::uint8_t const*>(kInfo), sizeof(kInfo) - 1, both,
              sizeof(both));
  std::array<std::uint8_t, SeedSize> first{};
  std::array<std::uint8_t, SeedSize> second{};
  std::memcpy(first.data(), both, SeedSize);
  std::memcpy(second.data(), both + SeedSize, SeedSize);
  send_ = initiator ? first : second;
  recv_ = initiator ? second : first;
  wipe(both, sizeof(both));
  wipe(seed_->data(), seed_->size());
  seed_.reset();
  return true;
}

void PackSession::pad_xor(std::array<std::uint8_t, SeedSize> const& key, std::uint64_t packet,
                          std::vector<std::uint8_t>& data) {
  std::uint8_t nonce[12] = {};
  store64(nonce, packet);
  chacha_xor(key.data(), nonce, 0, data.data(), data.size());
}

}  // namespace packbin
