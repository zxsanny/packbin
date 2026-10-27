// A core built with PACKBIN_NO_ECC (AZ-2688, EC-12): no message error correction is linked. A
// scheme without parity packs and unpacks as before; a scheme that declares parity bytes is
// refused at construction. Built and run by `make no-ecc-test`.
#ifndef PACKBIN_NO_ECC
#error "no_ecc_tests.cpp is built with -DPACKBIN_NO_ECC"
#endif

#include "packbin/codec.hpp"

#include "check.hpp"

#include <cstdint>
#include <cstdio>
#include <cstring>

using check::expect;
using packbin::Error;

namespace {

struct Position {
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t profile = 0;
  std::uint8_t flags = 0;
};

constexpr auto plain = packbin::scheme<Position>(
    0x40, packbin::u16<&Position::sid>(0), packbin::i32<&Position::lat>(1),
    packbin::i32<&Position::lon>(2), packbin::u8<&Position::profile>(3),
    packbin::u8<&Position::flags>(4));

Position position_row() {
  Position p;
  p.sid = 1;
  p.lat = 500000000;
  p.lon = 300000000;
  p.profile = 1;
  return p;
}

void parity_zero_is_the_plain_scheme() {
  auto zero = packbin::parity(plain, 0);
  std::uint8_t out[32];
  auto r = packbin::pack(zero, position_row(), out, sizeof(out));
  expect(zero.status.ok() && r.ok() && check::same_hex(out, r.offset, "4001000065cd1d00a3e1110100"),
         "n = 0 packs the 13-byte fixture without the codec");
  Position back;
  auto u = packbin::unpack(zero, out, r.offset, back);
  expect(u.ok() && u.offset == 13 && back.lat == 500000000,
         "n = 0 unpacks without the codec");
  auto fixed = packbin::unpack_repair(zero, out, r.offset, back, 0);
  expect(fixed.ok(), "unpack_repair with limit 0 reads");
  auto limit = packbin::unpack_repair(zero, out, r.offset, back, 1);
  expect(limit.error == Error::BadValue, "unpack_repair with limit 1 has nothing to repair with");
}

void parity_above_zero_is_refused() {
  auto four = packbin::parity(plain, 4);
  expect(four.status.error == Error::SchemeInvalid && four.parity == 0 &&
             packbin::validate(four).error == Error::SchemeInvalid,
         "n = 4 is SchemeInvalid in a build without the codec");
  std::uint8_t out[32];
  std::memset(out, 0xaa, sizeof(out));
  auto r = packbin::pack(four, position_row(), out, sizeof(out));
  expect(r.error == Error::SchemeInvalid && out[0] == 0xaa, "no message is built from it");
}

}  // namespace

int main() {
  parity_zero_is_the_plain_scheme();
  parity_above_zero_is_refused();
  if (check::failures() != 0) {
    std::fprintf(stderr, "%d failure(s)\n", check::failures());
    return 1;
  }
  std::puts("no-ecc tests passed");
  return 0;
}
