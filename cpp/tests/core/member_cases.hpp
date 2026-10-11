#pragma once

// Helpers for the `when`, `times` and `repeat` as a `flags` member tests (AZ-2120, AZ-2128): a
// row packs to the pinned hex, the hex unpacks to the row, and the unpacked row packs again to
// the same bytes. Host-only, like the tests that include it.

#include "packbin/packbin.hpp"

#include "check.hpp"

#include <cstdint>
#include <cstdio>
#include <string>

namespace member_cases {

template <typename T>
bool same_opt(packbin::Opt<T> const& a, packbin::Opt<T> const& b) {
  return a.has == b.has && (!a.has || a.value == b.value);
}

inline std::string say(char const* name, char const* stage) {
  return std::string(name) + ": " + stage;
}

// Every Row type has `bool same_as(Row const&) const`.
template <typename S, typename Row>
bool unpacks_to(S const& s, char const* hex, Row const& want) {
  std::uint8_t buf[64];
  std::size_t n = check::parse_hex(hex, buf, sizeof(buf));
  Row back;
  auto u = packbin::unpack(s, buf, n, back);
  return u.ok() && back.same_as(want);
}

template <typename S, typename Row>
void unpack_only(S const& s, char const* hex, Row const& want, char const* name) {
  check::expect(unpacks_to(s, hex, want), say(name, "unpack").c_str());
}

template <typename S, typename Row>
void round_trip(S const& s, Row const& row, char const* hex, char const* name) {
  std::uint8_t buf[64];
  auto p = packbin::pack(s, row, buf, sizeof(buf));
  check::expect(p.ok() && check::same_hex(buf, p.offset, hex), say(name, "pack bytes").c_str());
  check::expect(unpacks_to(s, hex, row), say(name, "unpack row").c_str());
  Row back;
  auto u = packbin::unpack(s, buf, p.offset, back);
  std::uint8_t again[64];
  auto r = packbin::pack(s, back, again, sizeof(again));
  check::expect(u.ok() && r.ok() && check::same_hex(again, r.offset, hex), say(name, "repack of the unpacked row").c_str());
}

// Pack refuses with BadValue naming the order id of the missing or surplus value.
template <typename S, typename Row>
void pack_refused(S const& s, Row const& row, int field, char const* name) {
  std::uint8_t buf[64];
  auto p = packbin::pack(s, row, buf, sizeof(buf));
  check::expect(p.error == packbin::Error::BadValue && p.field == field, say(name, "pack error").c_str());
}

}  // namespace member_cases
