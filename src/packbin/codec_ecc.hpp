#pragma once

// The message error correction glue around the plain walk (codec.hpp): the parity setting of a
// scheme (a count, or a percentage) turned into the count of one message, the room for the
// parity, the protect and the check or repair of a received message. ecc.hpp holds the codec.

#include "packbin/core.hpp"
#include "packbin/ecc.hpp"

#include "packbin/platform.hpp"

namespace packbin::detail {


// Message error correction around the plain walk (ecc.hpp holds the codec). A build with
// PACKBIN_NO_ECC has no protected scheme: every count is 0 and these collapse to nothing.
#ifndef PACKBIN_NO_ECC
inline constexpr bool kEcc = true;
#else
inline constexpr bool kEcc = false;
#endif
inline constexpr int kMaxParity = 32;
inline constexpr std::size_t kMaxSent = 254;

inline constexpr int kPercentBase = 256;
inline constexpr int kMaxPercent = 100;
inline constexpr int kMaxPercentLimit = 16;

#ifndef PACKBIN_NO_ECC

inline Result ecc_error(ecc::Kind kind, std::size_t len, int n) {
  switch (kind) {
    case ecc::Kind::Ok:
      return Result{};
    case ecc::Kind::Uncorrectable:
      return fail(Error::Uncorrectable, 0, -1);
    case ecc::Kind::Short:
      return fail(Error::ShortPacket, len, -1, static_cast<std::size_t>(n));
    case ecc::Kind::TooLong:
      return fail(Error::TooLong, len, -1, ecc::kMaxSent);
    case ecc::Kind::BadLimit:
      return fail(Error::BadValue, 0, -1, static_cast<std::size_t>(n / 2));
    case ecc::Kind::BadParity:
      break;
  }
  return fail(Error::SchemeInvalid, 0, -1, kMaxParity);
}

// Detect only: ok when the syndromes of a protected message are zero. Reads, never writes.
inline Result check_message(std::uint8_t const* data, std::size_t len, int n) {
  if (n == 0)
    return Result{};
  ecc::Outcome o = ecc::check(data, len, n);
  return ecc_error(o.kind, len, n);
}

// Repairs up to `limit` wrong bytes in place; on any refusal the buffer is as it was.
inline Result repair_message(std::uint8_t* data, std::size_t len, int n, int limit,
                             std::uint8_t& repaired) {
  ecc::Outcome o = ecc::repair(data, len, n, limit);
  repaired = o.repaired;
  return ecc_error(o.kind, len, n);
}

// The parity bytes of `len` clear bytes under a percentage p: the percentage of the length,
// rounded up, at most 32. `len` is at most 254, so 100 * len + 99 fits a 16-bit unsigned.
inline int percent_count(int p, std::size_t len) {
  unsigned n = (static_cast<unsigned>(p) * static_cast<unsigned>(len) + 99u) / 100u;
  return n > static_cast<unsigned>(kMaxParity) ? kMaxParity : static_cast<int>(n);
}

// The largest clear length whose protected message stays within 254 bytes under p (1 to 100).
inline std::size_t percent_limit(int p) {
  std::size_t len = kMaxSent;
  while (len + static_cast<std::size_t>(percent_count(p, len)) > kMaxSent)
    --len;
  return len;
}

// The parity count of a received message of `len` bytes under `setting`: the count itself, or
// for a percentage the one clear length with length + count = len (strictly increasing, so at
// most 255 steps). A length no clear length gives is `Uncorrectable`.
inline Result received_parity(int setting, std::size_t len, int& n) {
  if (setting < kPercentBase) {
    n = setting;
    return Result{};
  }
  if (setting > kPercentBase + kMaxPercent)
    return fail(Error::SchemeInvalid, 0, -1, kMaxPercent);
  if (len > kMaxSent)
    return fail(Error::TooLong, len, -1, kMaxSent);
  int p = setting - kPercentBase;
  for (std::size_t clear = 0;; ++clear) {
    int count = percent_count(p, clear);
    std::size_t sent = clear + static_cast<std::size_t>(count);
    if (sent == len) {
      n = count;
      return Result{};
    }
    if (sent > len)
      return fail(Error::Uncorrectable, 0, -1);
  }
}

// Repairs `data` under `setting`; `n` is the parity count of this message. A percentage takes a
// limit from 0 to 16 (else `BadValue` before any byte is read) and lowers it to n / 2.
inline Result repair_setting(std::uint8_t* data, std::size_t len, int setting, int limit,
                             std::uint8_t& repaired, int& n) {
  if (setting >= kPercentBase) {
    if (limit < 0 || limit > kMaxPercentLimit)
      return fail(Error::BadValue, 0, -1, kMaxPercentLimit);
    Result found = received_parity(setting, len, n);
    if (!found.ok())
      return found;
    if (limit > n / 2)
      limit = n / 2;
  } else {
    n = setting;
  }
  return repair_message(data, len, n, limit, repaired);
}

// Room for the parity of `len` field bytes already in `out` under `setting`; `n` is the count
// of this message. Fields above 254 - n (above the largest clear length of a percentage) are
// `TooLong` and the written bytes are zeroed.
inline Result parity_room(std::uint8_t* out, std::size_t cap, std::size_t len, int setting,
                          int& n) {
  n = 0;
  if (setting == 0)
    return Result{};
  std::size_t limit = 0;
  if (setting >= kPercentBase) {
    if (setting > kPercentBase + kMaxPercent)
      return fail(Error::SchemeInvalid, 0, -1, kMaxPercent);
    int p = setting - kPercentBase;
    n = len > kMaxSent ? kMaxParity : percent_count(p, len);
    if (len + static_cast<std::size_t>(n) > kMaxSent)
      limit = percent_limit(p);
    else
      limit = len;
  } else {
    n = setting;
    if (n > kMaxParity)
      return fail(Error::SchemeInvalid, 0, -1, kMaxParity);
    limit = kMaxSent - static_cast<std::size_t>(n);
  }
  if (len > limit) {
    std::memset(out, 0, len < cap ? len : cap);
    return fail(Error::TooLong, len, -1, limit);
  }
  if (cap - len < static_cast<std::size_t>(n))
    return fail(Error::BufferFull, len, -1, static_cast<std::size_t>(n));
  return Result{};
}

// Appends the parity of the `len` bytes in `out`; `parity_room` has checked the room.
inline Result seal(std::uint8_t* out, std::size_t len, int n) {
  if (n != 0) {
    ecc::Kind k = ecc::protect(out, len, n, out + len);
    if (k != ecc::Kind::Ok)
      return ecc_error(k, len, n);
  }
  return Result{Error::Ok, len + static_cast<std::size_t>(n)};
}

// The parity of a packed message `r` (the field bytes in `out`) under `setting`.
inline Result protect_packet(Result r, int setting, std::uint8_t* out, std::size_t cap) {
  if (!r.ok() || setting == 0)
    return r;
  int n = 0;
  Result room = parity_room(out, cap, r.offset, setting, n);
  if (!room.ok())
    return room;
  return seal(out, r.offset, n);
}

// Detect only: the parity count of a received message under `setting`, then its syndromes.
inline Result check_received(int setting, std::uint8_t const* data, std::size_t len, int& n) {
  Result g = received_parity(setting, len, n);
  return g.ok() ? check_message(data, len, n) : g;
}

#else

inline Result check_message(std::uint8_t const*, std::size_t, int) { return Result{}; }

inline Result repair_message(std::uint8_t*, std::size_t, int, int limit, std::uint8_t& repaired) {
  repaired = 0;
  return limit == 0 ? Result{} : fail(Error::BadValue, 0, -1, 0);
}

inline Result received_parity(int, std::size_t, int& n) {
  n = 0;
  return Result{};
}

inline Result repair_setting(std::uint8_t* data, std::size_t len, int, int limit,
                             std::uint8_t& repaired, int& n) {
  n = 0;
  return repair_message(data, len, 0, limit, repaired);
}

inline Result parity_room(std::uint8_t*, std::size_t, std::size_t, int, int& n) {
  n = 0;
  return Result{};
}

inline Result seal(std::uint8_t*, std::size_t len, int) { return Result{Error::Ok, len}; }

inline Result protect_packet(Result r, int, std::uint8_t*, std::size_t) { return r; }

inline Result check_received(int, std::uint8_t const*, std::size_t, int& n) {
  n = 0;
  return Result{};
}

#endif

// A read of the field bytes done: the whole message was consumed, parity included.
inline Result finish_message(Result r, int n, std::uint8_t repaired) {
  if (r.ok()) {
    r.offset += static_cast<std::size_t>(n);
#ifndef PACKBIN_NO_ECC
    r.repaired = repaired;
#else
    (void)repaired;
#endif
  }
  return r;
}

}  // namespace packbin::detail
