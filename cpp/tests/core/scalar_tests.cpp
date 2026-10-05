#include "packbin/core.hpp"

#include "check.hpp"

#include <limits>

using check::expect;
using packbin::Error;

namespace {

// Position row scalars from the golden fixture `4001000065cd1d00a3e1110100`.
void ac1_golden_scalars() {
  std::uint8_t buf[13];
  packbin::Writer w{buf, sizeof(buf), 0};
  expect(packbin::put_num<std::uint8_t>(w, 0x40, false, -1).ok(), "AC-1 type");
  expect(packbin::put_num<std::uint16_t>(w, 1, false, 0).ok(), "AC-1 sid");
  expect(packbin::put_num<std::int32_t>(w, 500000000, false, 1).ok(), "AC-1 lat");
  expect(packbin::put_num<std::int32_t>(w, 300000000, false, 2).ok(), "AC-1 lon");
  expect(packbin::put_num<std::uint8_t>(w, 1, false, 3).ok(), "AC-1 profile");
  auto last = packbin::put_num<std::uint8_t>(w, 0, false, 4);
  expect(last.ok() && last.offset == 13, "AC-1 written 13");
  expect(w.len == sizeof(buf), "AC-1 length equals packet size");
  expect(check::same_hex(buf, w.len, "4001000065cd1d00a3e1110100"), "AC-1 golden hex");

  packbin::Reader r{buf, sizeof(buf), 0};
  std::uint8_t type = 0, profile = 0, flags = 9;
  std::uint16_t sid = 0;
  std::int32_t lat = 0, lon = 0;
  expect(packbin::get_num(r, type, false, -1).ok() && type == 0x40, "AC-1 read type");
  expect(packbin::get_num(r, sid, false, 0).ok() && sid == 1, "AC-1 read sid");
  expect(packbin::get_num(r, lat, false, 1).ok() && lat == 500000000, "AC-1 read lat");
  expect(packbin::get_num(r, lon, false, 2).ok() && lon == 300000000, "AC-1 read lon");
  expect(packbin::get_num(r, profile, false, 3).ok() && profile == 1, "AC-1 read profile");
  expect(packbin::get_num(r, flags, false, 4).ok() && flags == 0, "AC-1 read flags");
  expect(packbin::finish(r).ok(), "AC-1 no trailing");
}

// Event rows from the scheme and field-id binding suites.
void ac1_event_scalars() {
  std::uint8_t buf[17];
  packbin::Writer w{buf, sizeof(buf), 0};
  packbin::put_num<std::uint8_t>(w, 2, false, -1);
  packbin::put_num<std::int32_t>(w, 7, false, 0);
  packbin::put_num<std::int32_t>(w, 8, false, 1);
  packbin::put_num<std::int32_t>(w, 9, false, 2);
  expect(check::same_hex(buf, w.len, "02070000000800000009000000"), "AC-1 event hex");

  packbin::Writer m{buf, sizeof(buf), 0};
  packbin::put_num<std::uint8_t>(m, 0x20, false, -1);
  packbin::put_num<std::uint16_t>(m, 1, false, 0);
  packbin::put_num<std::int32_t>(m, 500000000, false, 1);
  packbin::put_num<std::int32_t>(m, 300000000, false, 2);
  packbin::put_num<std::uint8_t>(m, 1, false, 3);
  packbin::put_num<std::uint16_t>(m, 0, false, 4);
  packbin::put_num<std::uint16_t>(m, 0, false, 5);
  packbin::put_num<std::uint8_t>(m, 0, false, 6);
  expect(check::same_hex(buf, m.len, "2001000065cd1d00a3e111010000000000"), "AC-1 marker hex");
}

void ac2_buffer_full() {
  std::uint8_t buf[4] = {0xaa, 0xaa, 0xaa, 0xaa};
  packbin::Writer w{buf, 3, 0};
  expect(packbin::put_num<std::uint16_t>(w, 0x0102, false, 0).ok(), "AC-2 first fits");
  auto r = packbin::put_num<std::uint16_t>(w, 0x0304, false, 1);
  expect(r.error == Error::BufferFull, "AC-2 BufferFull");
  expect(r.offset == 2 && r.field == 1 && r.needed == 2, "AC-2 offset and field");
  expect(w.len == 2, "AC-2 length stays");
  expect(buf[2] == 0xaa && buf[3] == 0xaa, "AC-2 nothing past offset");

  std::uint8_t raw[3] = {1, 2, 3};
  std::uint8_t two[2] = {0xaa, 0xaa};
  packbin::Writer b{two, sizeof(two), 0};
  auto rb = packbin::put_bytes(b, raw, 3, 5);
  expect(rb.error == Error::BufferFull && rb.offset == 0 && rb.field == 5, "AC-2 bytes full");
  expect(two[0] == 0xaa && two[1] == 0xaa && b.len == 0, "AC-2 bytes not written");
}

void ac3_short_and_trailing() {
  std::uint8_t data[3] = {0x01, 0x20, 0x34};
  packbin::Reader r{data, sizeof(data), 0};
  std::uint8_t a = 0, b = 0;
  std::uint16_t c = 0;
  packbin::get_num(r, a, false, -1);
  packbin::get_num(r, b, false, 0);
  auto s = packbin::get_num(r, c, false, 5);
  expect(s.error == Error::ShortPacket, "AC-3 ShortPacket");
  expect(s.offset == 2 && s.field == 5 && s.needed == 2 && r.left() == 1, "AC-3 short where");

  std::uint8_t two[2] = {7, 9};
  packbin::Reader t{two, sizeof(two), 0};
  std::uint8_t one = 0;
  packbin::get_num(t, one, false, 0);
  auto tr = packbin::finish(t);
  expect(tr.error == Error::TrailingBytes && tr.offset == 1, "AC-3 TrailingBytes");

  packbin::Reader e{two, sizeof(two), 0};
  std::uint8_t const* got = nullptr;
  auto eb = packbin::get_bytes(e, got, 3, 4);
  expect(eb.error == Error::ShortPacket && eb.needed == 3 && got == nullptr, "AC-3 bytes short");
}

template <typename T>
bool round_trip(T value, bool be, char const* hex) {
  std::uint8_t buf[8];
  packbin::Writer w{buf, sizeof(buf), 0};
  if (!packbin::put_num<T>(w, value, be, 0).ok() || !check::same_hex(buf, w.len, hex))
    return false;
  packbin::Reader r{buf, w.len, 0};
  T back{};
  return packbin::get_num(r, back, be, 0).ok() && back == value && packbin::finish(r).ok();
}

void ac4_byte_order() {
  expect(round_trip<std::uint16_t>(1, false, "0100"), "AC-4 u16 le");
  expect(round_trip<std::uint16_t>(1, true, "0001"), "AC-4 u16 be");
  expect(round_trip<std::uint32_t>(0x01020304u, false, "04030201"), "AC-4 u32 le");
  expect(round_trip<std::uint32_t>(0x01020304u, true, "01020304"), "AC-4 u32 be");
  expect(round_trip<std::uint64_t>(0x0102030405060708ull, false, "0807060504030201"),
         "AC-4 u64 le");
  expect(round_trip<std::uint64_t>(0x0102030405060708ull, true, "0102030405060708"),
         "AC-4 u64 be");
  expect(round_trip<std::int8_t>(-2, false, "fe"), "AC-4 i8");
  expect(round_trip<std::int16_t>(-2, false, "feff"), "AC-4 i16 le");
  expect(round_trip<std::int16_t>(-2, true, "fffe"), "AC-4 i16 be");
  expect(round_trip<std::int32_t>(-2, false, "feffffff"), "AC-4 i32");
  expect(round_trip<std::int64_t>(std::numeric_limits<std::int64_t>::min(), false,
                                  "0000000000000080"),
         "AC-4 i64 min");
  expect(round_trip<float>(1.0f, false, "0000803f"), "AC-4 f32 le");
  expect(round_trip<float>(1.0f, true, "3f800000"), "AC-4 f32 be");

  std::uint8_t buf[8];
  packbin::Writer w{buf, sizeof(buf), 0};
  expect(packbin::put_f64(w, 1.0, false, 0).ok() && check::same_hex(buf, w.len, "000000000000f03f"),
         "AC-4 f64 le");
  packbin::Writer wb{buf, sizeof(buf), 0};
  expect(packbin::put_f64(wb, 1.0, true, 0).ok() && check::same_hex(buf, wb.len, "3ff0000000000000"),
         "AC-4 f64 be");
  packbin::Reader r{buf, 8, 0};
  double back = 0;
  expect(packbin::get_f64(r, back, true, 0).ok() && back == 1.0, "AC-4 f64 read");
}

}  // namespace

int run_core_scalar_tests() {
  ac1_golden_scalars();
  ac1_event_scalars();
  ac2_buffer_full();
  ac3_short_and_trailing();
  ac4_byte_order();
  return check::failures();
}
