#include "packbin/session.hpp"

#include <cstddef>
#include <cstdint>
#include <cstring>

namespace packbin {
namespace {

constexpr char const kInfo[] = "packbin";

constexpr std::uint32_t kRound[64] = {
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

// Volatile stores so the compiler keeps the wipe of key material it sees as dead.
void wipe(void* p, std::size_t n) {
  volatile std::uint8_t* v = static_cast<std::uint8_t*>(p);
  for (std::size_t i = 0; i < n; ++i)
    v[i] = 0;
}

std::uint32_t rotr(std::uint32_t x, int n) { return (x >> n) | (x << (32 - n)); }
std::uint32_t rotl(std::uint32_t x, int n) { return (x << n) | (x >> (32 - n)); }

std::uint32_t load32_le(std::uint8_t const* p) {
  return static_cast<std::uint32_t>(p[0]) | (static_cast<std::uint32_t>(p[1]) << 8) |
         (static_cast<std::uint32_t>(p[2]) << 16) | (static_cast<std::uint32_t>(p[3]) << 24);
}

std::uint32_t load32_be(std::uint8_t const* p) {
  return (static_cast<std::uint32_t>(p[0]) << 24) | (static_cast<std::uint32_t>(p[1]) << 16) |
         (static_cast<std::uint32_t>(p[2]) << 8) | static_cast<std::uint32_t>(p[3]);
}

void store32_le(std::uint8_t* p, std::uint32_t v) {
  for (int i = 0; i < 4; ++i)
    p[i] = static_cast<std::uint8_t>(v >> (8 * i));
}

void store32_be(std::uint8_t* p, std::uint32_t v) {
  for (int i = 0; i < 4; ++i)
    p[i] = static_cast<std::uint8_t>(v >> (24 - 8 * i));
}

// Streaming SHA-256 (FIPS 180-4): the message goes through one 64-byte block buffer, so no
// padded copy of it is ever held.
struct Sha256 {
  std::uint32_t h[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
                        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};
  std::uint8_t block[64] = {};
  std::size_t fill = 0;
  std::uint64_t total = 0;

  void compress() {
    std::uint32_t w[64];
    for (int i = 0; i < 16; ++i)
      w[i] = load32_be(block + i * 4);
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
      std::uint32_t t1 = hh + S1 + ch + kRound[i] + w[i];
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
    wipe(w, sizeof(w));
  }

  void update(std::uint8_t const* p, std::size_t n) {
    total += n;
    while (n != 0) {
      std::size_t take = 64 - fill;
      if (take > n)
        take = n;
      std::memcpy(block + fill, p, take);
      fill += take;
      p += take;
      n -= take;
      if (fill == 64) {
        compress();
        fill = 0;
      }
    }
  }

  void finish(std::uint8_t out[32]) {
    std::uint64_t bits = total * 8;
    std::uint8_t one = 0x80;
    update(&one, 1);
    std::uint8_t zero = 0;
    while (fill != 56)
      update(&zero, 1);
    for (int i = 0; i < 8; ++i)
      block[56 + i] = static_cast<std::uint8_t>(bits >> (56 - 8 * i));
    compress();
    for (int i = 0; i < 8; ++i)
      store32_be(out + i * 4, h[i]);
    wipe(this, sizeof(*this));
  }
};

void sha256(std::uint8_t const* msg, std::size_t len, std::uint8_t out[32]) {
  Sha256 s;
  s.update(msg, len);
  s.finish(out);
}

// HMAC-SHA-256 (RFC 2104); the message may arrive in parts between `begin` and `end`.
struct HmacSha256 {
  Sha256 inner;
  std::uint8_t opad[64] = {};

  void begin(std::uint8_t const* key, std::size_t key_len) {
    std::uint8_t kh[32];
    if (key_len > 64) {
      sha256(key, key_len, kh);
      key = kh;
      key_len = 32;
    }
    std::uint8_t ipad[64];
    std::memset(ipad, 0x36, 64);
    std::memset(opad, 0x5c, 64);
    for (std::size_t i = 0; i < key_len; ++i) {
      ipad[i] ^= key[i];
      opad[i] ^= key[i];
    }
    inner.update(ipad, 64);
    wipe(kh, sizeof(kh));
    wipe(ipad, sizeof(ipad));
  }

  void update(std::uint8_t const* p, std::size_t n) { inner.update(p, n); }

  void end(std::uint8_t out[32]) {
    std::uint8_t ih[32];
    inner.finish(ih);
    Sha256 outer;
    outer.update(opad, 64);
    outer.update(ih, 32);
    outer.finish(out);
    wipe(ih, sizeof(ih));
    wipe(opad, sizeof(opad));
  }
};

// HKDF-SHA-256 (RFC 5869) extract and expand.
void hkdf_sha256(std::uint8_t const* ikm, std::size_t ikm_len, std::uint8_t const* salt,
                 std::size_t salt_len, std::uint8_t const* info, std::size_t info_len,
                 std::uint8_t* okm, std::size_t okm_len) {
  std::uint8_t prk[32];
  HmacSha256 extract;
  extract.begin(salt, salt_len);
  extract.update(ikm, ikm_len);
  extract.end(prk);

  std::uint8_t t[32];
  std::size_t t_len = 0;
  std::size_t produced = 0;
  std::uint8_t counter = 1;
  while (produced < okm_len) {
    HmacSha256 expand;
    expand.begin(prk, 32);
    expand.update(t, t_len);
    expand.update(info, info_len);
    expand.update(&counter, 1);
    expand.end(t);
    t_len = 32;
    std::size_t n = okm_len - produced;
    if (n > 32)
      n = 32;
    std::memcpy(okm + produced, t, n);
    produced += n;
    ++counter;
  }
  wipe(prk, sizeof(prk));
  wipe(t, sizeof(t));
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

// ChaCha20 block (RFC 8439).
void chacha_block(std::uint8_t const key[32], std::uint8_t const nonce[12], std::uint32_t counter,
                  std::uint8_t output[64]) {
  std::uint32_t state[16];
  state[0] = 0x61707865;
  state[1] = 0x3320646e;
  state[2] = 0x79622d32;
  state[3] = 0x6b206574;
  for (int i = 0; i < 8; ++i)
    state[4 + i] = load32_le(key + i * 4);
  state[12] = counter;
  state[13] = load32_le(nonce);
  state[14] = load32_le(nonce + 4);
  state[15] = load32_le(nonce + 8);

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
    store32_le(output + i * 4, work[i] + state[i]);
  wipe(state, sizeof(state));
  wipe(work, sizeof(work));
}

}  // namespace

PackSession::~PackSession() { clear(); }

void PackSession::clear() {
  wipe(seed_.data(), seed_.size());
  wipe(send_.data(), send_.size());
  wipe(recv_.data(), recv_.size());
  send_count_ = 0;
  recv_count_ = 0;
  loaded_ = false;
  open_ = false;
}

bool PackSession::load(std::uint8_t const* seed, std::size_t len) {
  clear();
  if (seed == nullptr || len != SeedSize)
    return false;
  std::memcpy(seed_.data(), seed, SeedSize);
  loaded_ = true;
  return true;
}

bool PackSession::start(std::uint8_t const* nonce, std::size_t len) {
  return open(nonce, len, true);
}

bool PackSession::start(RandomFn random, void* ctx, std::uint8_t* nonce_out) {
  if (!loaded_ || open_ || random == nullptr || nonce_out == nullptr)
    return false;
  std::uint8_t nonce[NonceSize];
  bool ok = random(nonce, NonceSize, ctx) && open(nonce, NonceSize, true);
  if (ok)
    std::memcpy(nonce_out, nonce, NonceSize);
  wipe(nonce, sizeof(nonce));
  return ok;
}

bool PackSession::join(std::uint8_t const* nonce, std::size_t len) {
  return open(nonce, len, false);
}

bool PackSession::open(std::uint8_t const* nonce, std::size_t len, bool initiator) {
  if (!loaded_ || open_ || nonce == nullptr || len != NonceSize)
    return false;
  std::uint8_t both[SeedSize * 2];
  hkdf_sha256(seed_.data(), SeedSize, nonce, NonceSize,
              reinterpret_cast<std::uint8_t const*>(kInfo), sizeof(kInfo) - 1, both,
              sizeof(both));
  std::memcpy(initiator ? send_.data() : recv_.data(), both, SeedSize);
  std::memcpy(initiator ? recv_.data() : send_.data(), both + SeedSize, SeedSize);
  wipe(both, sizeof(both));
  wipe(seed_.data(), seed_.size());
  loaded_ = false;
  open_ = true;
  return true;
}

// The ChaCha20 nonce is the packet index, little-endian, in its first 8 bytes; the block
// counter starts at 0 for every packet.
void PackSession::pad(std::uint8_t const* key, std::uint64_t packet, std::uint8_t* data,
                      std::size_t len) {
  std::uint8_t nonce[12] = {};
  for (int i = 0; i < 8; ++i)
    nonce[i] = static_cast<std::uint8_t>(packet >> (8 * i));
  std::uint8_t block[64];
  std::uint32_t counter = 0;
  for (std::size_t offset = 0; offset < len; offset += 64, ++counter) {
    chacha_block(key, nonce, counter, block);
    std::size_t n = len - offset;
    if (n > 64)
      n = 64;
    for (std::size_t i = 0; i < n; ++i)
      data[offset + i] ^= block[i];
  }
  wipe(block, sizeof(block));
}

}  // namespace packbin
