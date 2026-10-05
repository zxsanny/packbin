#pragma once

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
  std::array<Field, N> fields{};
  // Ok, or SchemeInvalid with the field id that broke the order or reference rules.
  Result status{};
};

namespace detail {

constexpr bool constant_evaluated() { return __builtin_is_constant_evaluated(); }

// Not constexpr on purpose: reaching one of these while a constexpr scheme is built stops the
// compile. The id travels as a template argument so GCC and Clang both print it
// (`scheme_field_id_breaks_order<2>` / `[with int Id = 2]`). Ids outside 0..255 report -1.
template <int Id>
void scheme_field_id_breaks_order() {}
inline void scheme_type_number_not_0_to_255() {}

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

template <typename Row, typename C>
constexpr bool binds_row() {
  return std::is_void<C>::value || std::is_same<C, Row>::value;
}

Result pack_table(Field const* t, std::size_t n, std::uint8_t type_number, void const* row,
                  Writer& w);
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

// Writes the packet into `out`. On success `offset` is the packet length.
template <typename Row, std::size_t N>
Result pack(Scheme<Row, N> const& s, Row const& row, std::uint8_t* out, std::size_t cap) {
  if (!s.status.ok())
    return s.status;
  Writer w{out, cap, 0};
  return detail::pack_table(s.fields.data(), N, s.type_number, &row, w);
}

// Reads one packet of this scheme into `row`. Optional members that the packet leaves out are
// reset. On failure the fields read before the failure keep their values.
template <typename Row, std::size_t N>
Result unpack(Scheme<Row, N> const& s, std::uint8_t const* data, std::size_t len, Row& row) {
  if (!s.status.ok())
    return s.status;
  if (len < 1)
    return fail(Error::ShortPacket, 0, -1, 1);
  if (data[0] != s.type_number)
    return fail(Error::TypeMismatch, 0, -1);
  Reader r{data, len, 1};
  return detail::unpack_table(s.fields.data(), N, &row, r);
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

template <typename H>
void try_one(H const& h, std::uint8_t const* data, std::size_t len, bool& matched,
             Result& result) {
  if (matched || !same_type(h, data[0]))
    return;
  matched = true;
  result = unpack(h.scheme, data, len, h.row);
  if (result.ok())
    h.on_row(h.row);
}

}  // namespace detail

template <typename H, typename... Hs>
Result unpack(std::uint8_t const* data, std::size_t len, H const& first, Hs const&... rest) {
  bool unique = (detail::count_type(first.scheme.type_number, first, rest...) == 1) &&
                ((detail::count_type(rest.scheme.type_number, first, rest...) == 1) && ...);
  if (!unique)
    return fail(Error::SchemeInvalid, 0, -1);
  if (len < 1)
    return fail(Error::ShortPacket, 0, -1, 1);
  bool matched = false;
  Result result{};
  detail::try_one(first, data, len, matched, result);
  (detail::try_one(rest, data, len, matched, result), ...);
  if (!matched)
    return fail(Error::TypeMismatch, 0, -1);
  return result;
}

}  // namespace packbin
