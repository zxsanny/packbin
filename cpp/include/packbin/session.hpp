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

  // Packs the row clear into `out`, pads it in place, then appends the scheme's parity bytes
  // (the code covers the padded bytes). The send index advances only when the pack succeeds;
  // on failure the clear bytes before the reported offset are zeroed and nothing past it is
  // written.
  template <typename Row, std::size_t N>
  Result pack(Scheme<Row, N> const& s, Row const& row, std::uint8_t* out, std::size_t cap,
              ScratchRef scratch = {}) {
    if (!open_)
      return fail(Error::BadValue, 0, -1);
    Result r = detail::pack_clear(s, row, out, cap, scratch);
    int n = detail::parity_of(s);
    if constexpr (detail::kEcc) {
      if (r.ok() && n != 0) {
        Result room = detail::parity_room(out, cap, r.offset, n);
        if (!room.ok())
          r = room;
      }
    }
    if (!r.ok()) {
      if (out != nullptr && r.offset != 0)
        std::memset(out, 0, r.offset < cap ? r.offset : cap);
      return r;
    }
    pad(send_.data(), send_count_++, out, r.offset);
    if constexpr (detail::kEcc) {
      if (n != 0)
        return detail::seal(out, r.offset, n);
    }
    return r;
  }

  // Removes the pad in place, then unpacks; borrowed views point into the clear `data`. The
  // receive index advances for every packet the call accepts, whether or not it then reads,
  // and for a protected packet that is refused (`Uncorrectable`, short, too long) as well, so
  // the next packet from the sender still lines up. Only a refused argument (a limit above
  // parity / 2, handlers that disagree on the parity count) leaves the index alone. This form
  // detects only; see `unpack_repair`.
  template <typename Row, std::size_t N>
  Result unpack(Scheme<Row, N> const& s, std::uint8_t* data, std::size_t len, Row& row) {
    return unpack_repair(s, data, len, row, 0);
  }

  template <typename H, typename... Hs>
  Result unpack(std::uint8_t* data, std::size_t len, H const& first, Hs const&... rest) {
    return unpack_repair(data, len, 0, first, rest...);
  }

  // Repairs up to `limit` wrong bytes of the padded packet and its parity first, drops the
  // parity, removes the pad, then reads (the order of the contract: the code covers the padded
  // bytes). `data` ends as the clear packet without parity; `repaired` counts the fixed bytes.
  template <typename Row, std::size_t N>
  Result unpack_repair(Scheme<Row, N> const& s, std::uint8_t* data, std::size_t len, Row& row,
                       int limit) {
    if (!open_)
      return fail(Error::BadValue, 0, -1);
    int n = s.status.ok() ? detail::parity_of(s) : 0;
    if (!detail::limit_ok(n, limit))
      return fail(Error::BadValue, 0, -1, static_cast<std::size_t>(n / 2));
    if (n == 0) {
      pad(recv_.data(), recv_count_++, data, len);
      return detail::unpack_clear_checked(s, data, len, row);
    }
    std::uint64_t index = recv_count_++;
    std::uint8_t repaired = 0;
    Result g = detail::repair_message(data, len, n, limit, repaired);
    if (!g.ok())
      return g;
    std::size_t clear = len - static_cast<std::size_t>(n);
    pad(recv_.data(), index, data, clear);
    return detail::finish_message(detail::unpack_clear_checked(s, data, clear, row), n,
                                  repaired);
  }

  template <typename H, typename... Hs>
  Result unpack_repair(std::uint8_t* data, std::size_t len, int limit, H const& first,
                       Hs const&... rest) {
    if (!open_)
      return fail(Error::BadValue, 0, -1);
    int n = 0;
    if (!detail::unique_types(first, rest...)) {
      pad(recv_.data(), recv_count_++, data, len);
      return fail(Error::SchemeInvalid, 0, -1);
    }
    Result shared = detail::shared_parity(n, first, rest...);
    if (!shared.ok())
      return shared;
    if (!detail::limit_ok(n, limit))
      return fail(Error::BadValue, 0, -1, static_cast<std::size_t>(n / 2));
    if (n == 0) {
      pad(recv_.data(), recv_count_++, data, len);
      return detail::dispatch_clear(data, len, first, rest...);
    }
    std::uint64_t index = recv_count_++;
    std::uint8_t repaired = 0;
    Result g = detail::repair_message(data, len, n, limit, repaired);
    if (!g.ok())
      return g;
    std::size_t clear = len - static_cast<std::size_t>(n);
    pad(recv_.data(), index, data, clear);
    return detail::finish_message(detail::dispatch_clear(data, clear, first, rest...), n,
                                  repaired);
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
