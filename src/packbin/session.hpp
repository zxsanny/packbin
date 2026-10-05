#pragma once

// Session pad on the core: keys come from HKDF-SHA-256 over the shared seed and the opener's
// nonce, and every packet is XORed in place with a ChaCha20 stream keyed by the packet index.
// No heap, no OS calls; the random source is the caller's.

#include "packbin/codec.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <cstring>

namespace packbin {

// Fills `out` with `n` random bytes; false when no randomness is available.
using RandomFn = bool (*)(std::uint8_t* out, std::size_t n, void* ctx);

class PackSession {
 public:
  static constexpr std::size_t SeedSize = 32;
  static constexpr std::size_t NonceSize = 16;

  PackSession() = default;
  ~PackSession();
  // A copy would reuse the send pad for the same packet index.
  PackSession(PackSession const&) = delete;
  PackSession& operator=(PackSession const&) = delete;

  // Clears any previous seed or session, then keeps the seed. False when `len` is not 32.
  bool load(std::uint8_t const* seed, std::size_t len);

  // Opens as the initiator with the caller's nonce. False when `len` is not 16, no seed is
  // loaded or the session is already open.
  bool start(std::uint8_t const* nonce, std::size_t len);

  // Opens as the initiator with 16 bytes from `random`, written to `nonce_out` on success. When
  // `random` fails nothing opens and `nonce_out` is left as it was.
  bool start(RandomFn random, void* ctx, std::uint8_t* nonce_out);

  // Opens as the responder with the initiator's nonce.
  bool join(std::uint8_t const* nonce, std::size_t len);

  bool is_open() const { return open_; }

  // Packs the row clear into `out`, then pads it in place. The send index advances only when
  // the pack succeeds; on failure the clear bytes before the reported offset are zeroed and
  // nothing past it is written.
  template <typename Row, std::size_t N>
  Result pack(Scheme<Row, N> const& s, Row const& row, std::uint8_t* out, std::size_t cap) {
    if (!open_)
      return fail(Error::BadValue, 0, -1);
    Result r = packbin::pack(s, row, out, cap);
    if (!r.ok()) {
      if (out != nullptr && r.offset != 0)
        std::memset(out, 0, r.offset < cap ? r.offset : cap);
      return r;
    }
    pad(send_.data(), send_count_++, out, r.offset);
    return r;
  }

  // Removes the pad in place, then unpacks; borrowed views point into the clear `data`. The
  // receive index advances for every packet that is unpadded, whether or not it then reads.
  template <typename Row, std::size_t N>
  Result unpack(Scheme<Row, N> const& s, std::uint8_t* data, std::size_t len, Row& row) {
    if (!open_)
      return fail(Error::BadValue, 0, -1);
    pad(recv_.data(), recv_count_++, data, len);
    return packbin::unpack(s, data, len, row);
  }

  template <typename H, typename... Hs>
  Result unpack(std::uint8_t* data, std::size_t len, H const& first, Hs const&... rest) {
    if (!open_)
      return fail(Error::BadValue, 0, -1);
    pad(recv_.data(), recv_count_++, data, len);
    return packbin::unpack(data, len, first, rest...);
  }

 private:
  bool open(std::uint8_t const* nonce, std::size_t len, bool initiator);
  void clear();
  static void pad(std::uint8_t const* key, std::uint64_t packet, std::uint8_t* data,
                  std::size_t len);

  std::array<std::uint8_t, SeedSize> seed_{};
  std::array<std::uint8_t, SeedSize> send_{};
  std::array<std::uint8_t, SeedSize> recv_{};
  std::uint64_t send_count_ = 0;
  std::uint64_t recv_count_ = 0;
  bool loaded_ = false;
  bool open_ = false;
};

}  // namespace packbin
