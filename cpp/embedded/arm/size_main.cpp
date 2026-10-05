// AC-5 size probe for the reference target (Cortex-M4F). Built twice: with the 14-entry scheme
// table below, and with PACKBIN_SIZE_BASELINE (same startup, meter and printing, no packbin).
// Flash of "core + one 14-field table" = image size difference between the two.

#include "semihost.h"
#include "stack_meter.hpp"

#include <cstddef>
#include <cstdint>

#ifndef PACKBIN_SIZE_BASELINE
#include "packbin/codec.hpp"
#endif

namespace {

std::uint8_t packet[64];

void say(char const* key, unsigned long value) {
  sh_write(key);
  sh_write_uint(value);
  sh_write("\n");
}

#ifndef PACKBIN_SIZE_BASELINE

struct Point {
  std::int32_t lat = 0;
  std::int32_t lon = 0;
};

struct Route {
  std::uint16_t sid = 0;
  std::uint16_t owner = 0;
  packbin::Opt<std::uint16_t> leg;
  packbin::Opt<bool> masked;
  packbin::Opt<std::uint16_t> title;
  std::uint8_t n = 0;
  packbin::Array<std::uint8_t, 8> kinds;
  packbin::Array<Point, 8> points;
  packbin::Array<std::uint8_t, 8> mask;
  packbin::View name;
};

namespace pb = packbin;

// The route scheme of the cross-language vectors plus a utf8 name: 14 table entries.
constexpr auto route = pb::scheme<Route>(
    0x34, pb::u16<&Route::sid>(0), pb::u16<&Route::owner>(1),
    pb::flags(2, pb::u16<&Route::leg>(2), pb::boolean<&Route::masked>(3),
              pb::u16<&Route::title>(4)),
    pb::u8<&Route::n>(5), pb::packed<&Route::kinds>(2, 6, 5),
    pb::times<&Route::points>(7, 5, pb::i32<&Point::lat>(7), pb::i32<&Point::lon>(8)),
    pb::when(9, pb::eq(3, 1), pb::packed<&Route::mask>(1, 9, 5, -1)), pb::utf8<&Route::name>(10));
static_assert(route.fields.size() == 14, "the size probe uses a 14-entry scheme table");

Route row;
Route back;

#endif

}  // namespace

int main() {
  int failures = 0;
#ifndef PACKBIN_SIZE_BASELINE
  row.sid = 16;
  row.leg = 21;
  row.masked = true;
  row.n = 2;
  row.kinds.count = 2;
  row.kinds.items[0] = 1;
  row.kinds.items[1] = 3;
  row.points.count = 2;
  row.points.items[0] = Point{500000000, 300000000};
  row.points.items[1] = Point{500010000, 300010000};
  row.mask.count = 1;
  row.mask.items[0] = 1;
  static char const name[] = "uav";
  row.name = pb::View{reinterpret_cast<std::uint8_t const*>(name), 3};
  pb::Result p{};
  pb::Result u{};
  std::size_t pack_stack =
      stack_meter::measure([&] { p = pb::pack(route, row, packet, sizeof(packet)); });
  std::size_t unpack_stack =
      stack_meter::measure([&] { u = pb::unpack(route, packet, p.offset, back); });
  bool same = back.sid == 16 && back.leg.has && back.leg.value == 21 && back.points.count == 2 &&
              back.points.items[1].lon == 300010000 && back.mask.count == 1 &&
              back.name.len == 3;
  failures = (p.ok() ? 0 : 1) + (u.ok() ? 0 : 1) + (same ? 0 : 1);
  say("TABLE_ENTRIES ", route.fields.size());
  say("PACKET_LEN ", p.offset);
#else
  std::size_t pack_stack = stack_meter::measure([&] { packet[0] = 1; });
  std::size_t unpack_stack = stack_meter::measure([&] { packet[1] = packet[0]; });
#endif
  say("PACK_STACK ", pack_stack);
  say("UNPACK_STACK ", unpack_stack);
  say("FAILURES ", static_cast<unsigned long>(failures));
  return failures;
}
