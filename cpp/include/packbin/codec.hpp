#pragma once

#include "packbin/ecc.hpp"
#include "packbin/fields.hpp"
#include "packbin/order.hpp"
#include "packbin/table.hpp"

#include <array>
#include <cstddef>
#include <cstdint>
#include <type_traits>

namespace packbin {

// A packet is the type number byte followed by the fields of one scheme.
template <typename Row, std::size_t N>
struct Scheme {
  std::uint8_t type_number = 0;
  // Parity bytes appended to every packet (0 to 32, set with `parity(scheme, n)`), see ecc.hpp.
  std::uint8_t parity = 0;
  std::array<Field, N> fields{};
  // Ok, or SchemeInvalid with the field id that broke the order or reference rules.
  Result status{};
};

namespace detail {

// Not constexpr on purpose: reaching one of these while a constexpr scheme is built stops the
// compile. The id travels as a template argument so GCC and Clang both print it
// (`scheme_field_id_breaks_order<2>` / `[with int Id = 2]`). Ids outside 0..255 report -1.
template <int Id>
void scheme_field_id_breaks_order() {}
inline void scheme_type_number_not_0_to_255() {}
inline void scheme_parity_not_0_to_32_or_ecc_removed() {}

template <int Id>
constexpr void stop_at_field_id(int field_id) {
  if constexpr (Id > 255) {
    scheme_field_id_breaks_order<-1>();
  } else {
    if (field_id == Id)
      scheme_field_id_breaks_order<Id>();
    else
      stop_at_field_id<Id + 1>(field_id);
  }
}

constexpr void invalid_field_id(int field_id) {
  if (constant_evaluated()) {
    if (field_id < 0)
      scheme_field_id_breaks_order<-1>();
    else
      stop_at_field_id<0>(field_id);
  }
}

constexpr void invalid_type_number() {
  if (constant_evaluated())
    scheme_type_number_not_0_to_255();
}

constexpr void invalid_parity() {
  if (constant_evaluated())
    scheme_parity_not_0_to_32_or_ecc_removed();
}

// Message error correction around the plain walk (ecc.hpp holds the codec). A build with
// PACKBIN_NO_ECC has no protected scheme: every count is 0 and these collapse to nothing.
#ifndef PACKBIN_NO_ECC
inline constexpr bool kEcc = true;
#else
inline constexpr bool kEcc = false;
#endif
inline constexpr int kMaxParity = 32;
inline constexpr std::size_t kMaxSent = 254;

// The parity count a pack or unpack of `s` applies; the field is 0 or at most 32 for a scheme
// built with `parity`, and a hand-edited one is refused by the codec.
template <typename Row, std::size_t N>
constexpr int parity_of(Scheme<Row, N> const& s) {
  return kEcc ? static_cast<int>(s.parity) : 0;
}

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

// Room for `n` parity bytes after `len` field bytes already in `out`. Fields above 254 - n are
// `TooLong` and the written bytes are zeroed.
inline Result parity_room(std::uint8_t* out, std::size_t cap, std::size_t len, int n) {
  if (n == 0)
    return Result{};
  if (n > kMaxParity)
    return fail(Error::SchemeInvalid, 0, -1, kMaxParity);
  std::size_t limit = kMaxSent - static_cast<std::size_t>(n);
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

#else

inline Result check_message(std::uint8_t const*, std::size_t, int) { return Result{}; }

inline Result repair_message(std::uint8_t*, std::size_t, int, int limit, std::uint8_t& repaired) {
  repaired = 0;
  return limit == 0 ? Result{} : fail(Error::BadValue, 0, -1, 0);
}

inline Result parity_room(std::uint8_t*, std::size_t, std::size_t, int) { return Result{}; }

inline Result seal(std::uint8_t*, std::size_t len, int) { return Result{Error::Ok, len}; }

#endif

// A correction limit is 0 to n / 2 (0 only for a scheme without parity).
inline bool limit_ok(int n, int limit) { return limit >= 0 && limit <= n / 2; }

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

template <typename Row, typename C>
constexpr bool binds_row() {
  return std::is_void<C>::value || std::is_same<C, Row>::value;
}

Result pack_table(Field const* t, std::size_t n, std::uint8_t type_number, void const* row,
                  Writer& w, ScratchRef scratch);
Result unpack_table(Field const* t, std::size_t n, void* row, Reader& r);

}  // namespace detail

template <typename Row, typename... Ns>
constexpr Scheme<Row, detail::total<Ns...>()> scheme(int type_number, Ns const&... nodes) {
  static_assert((detail::binds_row<Row, typename Ns::Class>() && ...),
                "packbin: a scheme field binds a member of another row type");
  Scheme<Row, detail::total<Ns...>()> s{};
  if (type_number < 0 || type_number > 255) {
    s.status = fail(Error::SchemeInvalid, 0, -1);
    detail::invalid_type_number();
    return s;
  }
  s.type_number = static_cast<std::uint8_t>(type_number);
  std::size_t at = 0;
  ((void)(detail::copy_fields(s.fields, at, nodes)), ...);
  s.status = check_table(s.fields.data(), s.fields.size());
  if (!s.status.ok())
    detail::invalid_field_id(s.status.field);
  return s;
}

template <typename Row, std::size_t N>
constexpr Result validate(Scheme<Row, N> const& s) {
  return s.status;
}

// The scheme with `n` parity bytes after every packet (message error correction, ecc.hpp):
// `constexpr auto s = parity(scheme<Row>(...), 4);`. `n` above 32 or below 0 is SchemeInvalid
// (a compile error for a `constexpr` scheme); so is any `n` above 0 in a build with
// PACKBIN_NO_ECC, which links no codec. A scheme that was already invalid keeps its own error.
template <typename Row, std::size_t N>
constexpr Scheme<Row, N> parity(Scheme<Row, N> s, int n) {
  if (n < 0 || n > detail::kMaxParity || (!detail::kEcc && n != 0)) {
    if (s.status.ok())
      s.status = fail(Error::SchemeInvalid, 0, -1, detail::kEcc ? detail::kMaxParity : 0);
    s.parity = 0;
    detail::invalid_parity();
    return s;
  }
  s.parity = static_cast<std::uint8_t>(n);
  return s;
}

namespace detail {

template <typename Row, std::size_t N>
Result pack_clear(Scheme<Row, N> const& s, Row const& row, std::uint8_t* out, std::size_t cap,
                  ScratchRef scratch) {
  if (!s.status.ok())
    return s.status;
  Writer w{out, cap, 0};
  return pack_table(s.fields.data(), N, s.type_number, &row, w, scratch);
}

template <typename Row, std::size_t N>
Result unpack_clear(Scheme<Row, N> const& s, std::uint8_t const* data, std::size_t len,
                    Row& row) {
  if (len < 1)
    return fail(Error::ShortPacket, 0, -1, 1);
  if (data[0] != s.type_number)
    return fail(Error::TypeMismatch, 0, -1);
  Reader r{data, len, 1};
  return unpack_table(s.fields.data(), N, &row, r);
}

template <typename Row, std::size_t N>
Result unpack_clear_checked(Scheme<Row, N> const& s, std::uint8_t const* data, std::size_t len,
                            Row& row) {
  return s.status.ok() ? unpack_clear(s, data, len, row) : s.status;
}

}  // namespace detail

// Writes the packet into `out`: the fields, then the scheme's parity bytes. On success `offset`
// is the packet length. A packet with strings passes `scratch` (a `Scratch<Chars>`, 12 bytes per
// code point of its longest string) for the optimal parse; a string that needs more is
// `ScratchTooSmall`. A protected packet whose fields are longer than 254 minus the parity count
// is `TooLong` (`offset` the field bytes, `needed` the limit) and `out` is left zeroed.
template <typename Row, std::size_t N>
Result pack(Scheme<Row, N> const& s, Row const& row, std::uint8_t* out, std::size_t cap,
            ScratchRef scratch = {}) {
  Result r = detail::pack_clear(s, row, out, cap, scratch);
  if constexpr (detail::kEcc) {
    if (r.ok() && s.parity != 0) {
      Result room = detail::parity_room(out, cap, r.offset, s.parity);
      if (!room.ok())
        return room;
      return detail::seal(out, r.offset, s.parity);
    }
  }
  return r;
}

// Reads one packet of this scheme into `row`. Optional members that the packet leaves out are
// reset. On failure the fields read before the failure keep their values. A protected scheme
// detects only: the buffer is not touched, and any wrong byte is `Uncorrectable`; use
// `unpack_repair` to fix wrong bytes in a writable buffer.
template <typename Row, std::size_t N>
Result unpack(Scheme<Row, N> const& s, std::uint8_t const* data, std::size_t len, Row& row) {
  if (!s.status.ok())
    return s.status;
  if constexpr (detail::kEcc) {
    int n = s.parity;
    if (n != 0) {
      Result g = detail::check_message(data, len, n);
      if (!g.ok())
        return g;
      std::size_t clear = len - static_cast<std::size_t>(n);
      return detail::finish_message(detail::unpack_clear(s, data, clear, row), n, 0);
    }
  }
  return detail::unpack_clear(s, data, len, row);
}

// Repairs up to `limit` wrong bytes of `data` in place (parity bytes included; `limit` from 0 to
// parity / 2, more is `BadValue` before any byte is read), then reads the packet. On success
// `repaired` is the number of bytes fixed and `data` equals the packet as it was packed. Beyond
// the limit the result is `Uncorrectable` and `data` is not changed. `limit` 0 is detect-only.
template <typename Row, std::size_t N>
Result unpack_repair(Scheme<Row, N> const& s, std::uint8_t* data, std::size_t len, Row& row,
                     int limit) {
  if (!s.status.ok())
    return s.status;
  int n = detail::parity_of(s);
  std::uint8_t repaired = 0;
  Result g = detail::repair_message(data, len, n, limit, repaired);
  if (!g.ok())
    return g;
  std::size_t clear = len - static_cast<std::size_t>(n);
  return detail::finish_message(detail::unpack_clear(s, data, clear, row), n, repaired);
}

template <typename Row, std::size_t N, typename F>
struct Handler {
  Scheme<Row, N> const& scheme;
  Row& row;
  F on_row;
};

// One candidate for `unpack(data, len, on(...), on(...))`: the row is filled and `on_row(row)`
// runs only when the packet's type number is this scheme's and the whole packet reads.
template <typename Row, std::size_t N, typename F>
Handler<Row, N, F> on(Scheme<Row, N> const& s, Row& row, F on_row) {
  return Handler<Row, N, F>{s, row, on_row};
}

namespace detail {

template <typename H>
bool same_type(H const& h, std::uint8_t t) {
  return h.scheme.type_number == t;
}

template <typename H, typename... Hs>
int count_type(std::uint8_t t, H const& h, Hs const&... rest) {
  return (same_type(h, t) ? 1 : 0) + (0 + ... + (same_type(rest, t) ? 1 : 0));
}

template <typename H, typename... Hs>
bool unique_types(H const& first, Hs const&... rest) {
  return (count_type(first.scheme.type_number, first, rest...) == 1) &&
         ((count_type(rest.scheme.type_number, first, rest...) == 1) && ...);
}

template <typename H>
bool differs(H const& h, int n, int& other) {
  if (parity_of(h.scheme) == n)
    return false;
  other = parity_of(h.scheme);
  return true;
}

// The parity count every handler declares. A mix is `SchemeInvalid`: `offset` is the first
// handler's count and `needed` the first count that differs.
template <typename H, typename... Hs>
Result shared_parity(int& n, H const& first, Hs const&... rest) {
  n = parity_of(first.scheme);
  int other = n;
  if ((false || ... || differs(rest, n, other)))
    return fail(Error::SchemeInvalid, static_cast<std::size_t>(n), -1,
                static_cast<std::size_t>(other));
  return Result{};
}

template <typename H>
void try_one(H const& h, std::uint8_t const* data, std::size_t len, bool& matched,
             Result& result) {
  if (matched || !same_type(h, data[0]))
    return;
  matched = true;
  result = unpack_clear_checked(h.scheme, data, len, h.row);
  if (result.ok())
    h.on_row(h.row);
}

// The packet without its parity bytes goes to the handler of its type number.
template <typename H, typename... Hs>
Result dispatch_clear(std::uint8_t const* data, std::size_t len, H const& first,
                      Hs const&... rest) {
  if (len < 1)
    return fail(Error::ShortPacket, 0, -1, 1);
  bool matched = false;
  Result result{};
  try_one(first, data, len, matched, result);
  (try_one(rest, data, len, matched, result), ...);
  if (!matched)
    return fail(Error::TypeMismatch, 0, -1);
  return result;
}

}  // namespace detail

// Reads the packet whose type number a handler names. All handlers must declare the same parity
// count (a mix is `SchemeInvalid`). A protected packet is only checked, as in `unpack(scheme,
// ...)`, then dispatched.
template <typename H, typename... Hs>
Result unpack(std::uint8_t const* data, std::size_t len, H const& first, Hs const&... rest) {
  if (!detail::unique_types(first, rest...))
    return fail(Error::SchemeInvalid, 0, -1);
  if constexpr (detail::kEcc) {
    int n = 0;
    Result shared = detail::shared_parity(n, first, rest...);
    if (!shared.ok())
      return shared;
    if (n != 0) {
      Result g = detail::check_message(data, len, n);
      if (!g.ok())
        return g;
      return detail::finish_message(
          detail::dispatch_clear(data, len - static_cast<std::size_t>(n), first, rest...), n, 0);
    }
  }
  return detail::dispatch_clear(data, len, first, rest...);
}

// `unpack(data, len, on(...), ...)` for protected schemes: the message is repaired in place
// first (up to `limit` wrong bytes, the type byte included), then dispatched on the repaired
// type number. Same rules as `unpack(scheme, data, len, row, limit)`.
template <typename H, typename... Hs>
Result unpack_repair(std::uint8_t* data, std::size_t len, int limit, H const& first,
                     Hs const&... rest) {
  if (!detail::unique_types(first, rest...))
    return fail(Error::SchemeInvalid, 0, -1);
  int n = 0;
  Result shared = detail::shared_parity(n, first, rest...);
  if (!shared.ok())
    return shared;
  std::uint8_t repaired = 0;
  Result g = detail::repair_message(data, len, n, limit, repaired);
  if (!g.ok())
    return g;
  return detail::finish_message(
      detail::dispatch_clear(data, len - static_cast<std::size_t>(n), first, rest...), n,
      repaired);
}

}  // namespace packbin
