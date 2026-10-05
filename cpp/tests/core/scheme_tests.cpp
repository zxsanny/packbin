#include "packbin/codec.hpp"

#include "check.hpp"

using check::expect;
using packbin::Error;

namespace {

struct MarkerRow {
  std::uint8_t sid = 0;
};

struct ModifiedRow {
  std::int32_t user_id = 0;
  std::uint8_t status = 0;
};

struct PositionEvent {
  std::int32_t user_id = 0;
  std::int32_t latitude = 0;
  std::int32_t longitude = 0;
};

struct KindRow {
  std::uint8_t kind = 0;
  packbin::Opt<std::uint8_t> kind_id;
};

struct KeyRow {
  std::uint8_t key[4] = {};
  std::uint16_t tail = 0;
};

constexpr auto marker = packbin::scheme<MarkerRow>(32, packbin::u8<&MarkerRow::sid>(0));
constexpr auto modified = packbin::scheme<ModifiedRow>(
    1, packbin::i32<&ModifiedRow::user_id>(0), packbin::u8<&ModifiedRow::status>(1));
constexpr auto position_event = packbin::scheme<PositionEvent>(
    2, packbin::i32<&PositionEvent::user_id>(0), packbin::i32<&PositionEvent::latitude>(1),
    packbin::i32<&PositionEvent::longitude>(2));
constexpr auto kind_scheme = packbin::scheme<KindRow>(
    1, packbin::u8<&KindRow::kind>(0),
    packbin::when(1, packbin::eq(0, 0), packbin::u8<&KindRow::kind_id>(1)));

static_assert(packbin::validate(marker).ok(), "constexpr scheme is valid");
static_assert(marker.type_number == 32, "type number kept");
static_assert(kind_scheme.fields[1].ref == 0, "when resolves its reference at compile time");

void type_number_leads_the_packet() {
  MarkerRow row;
  row.sid = 23;
  std::uint8_t buf[4];
  auto r = packbin::pack(marker, row, buf, sizeof(buf));
  expect(r.ok() && r.offset == 2 && check::same_hex(buf, r.offset, "2017"), "type number byte");
}

void ac1_unknown_type_number() {
  std::uint8_t data[1] = {9};
  ModifiedRow a;
  PositionEvent b;
  int calls = 0;
  auto r = packbin::unpack(data, sizeof(data),
                           packbin::on(modified, a, [&](ModifiedRow const&) { ++calls; }),
                           packbin::on(position_event, b, [&](PositionEvent const&) { ++calls; }));
  expect(r.error == Error::TypeMismatch && r.offset == 0, "AC-1 TypeMismatch");
  expect(calls == 0, "AC-1 no handler runs");

  std::uint8_t one[2];
  check::parse_hex("0217", one, sizeof(one));
  MarkerRow m;
  auto single = packbin::unpack(marker, one, sizeof(one), m);
  expect(single.error == Error::TypeMismatch && one[0] == 2, "AC-1 single scheme mismatch");
}

void ac2_matching_type_number() {
  PositionEvent row;
  row.user_id = 7;
  row.latitude = 8;
  row.longitude = 9;
  std::uint8_t buf[16];
  auto p = packbin::pack(position_event, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "02070000000800000009000000"), "AC-2 hex");

  ModifiedRow a;
  PositionEvent b;
  int mod = 0, pos = 0;
  auto r = packbin::unpack(buf, p.offset,
                           packbin::on(modified, a, [&](ModifiedRow const&) { ++mod; }),
                           packbin::on(position_event, b, [&](PositionEvent const&) { ++pos; }));
  expect(r.ok() && r.offset == 13, "AC-2 ok");
  expect(mod == 0 && pos == 1, "AC-2 only the matching handler");
  expect(b.user_id == 7 && b.latitude == 8 && b.longitude == 9, "AC-2 row filled");
}

void handler_waits_for_whole_packet() {
  std::uint8_t data[3] = {0x01, 0x05, 0x00};
  ModifiedRow a;
  int calls = 0;
  auto r = packbin::unpack(data, sizeof(data),
                           packbin::on(modified, a, [&](ModifiedRow const&) { ++calls; }));
  expect(r.error == Error::ShortPacket && r.field == 0 && r.offset == 1 && r.needed == 4,
         "short packet names field 0");
  expect(calls == 0, "short packet runs no handler");
}

void duplicate_type_numbers() {
  std::uint8_t data[1] = {1};
  ModifiedRow a, b;
  auto r = packbin::unpack(data, sizeof(data), packbin::on(modified, a, [](ModifiedRow const&) {}),
                           packbin::on(modified, b, [](ModifiedRow const&) {}));
  expect(r.error == Error::SchemeInvalid, "duplicate type numbers");
}

template <typename S>
bool rejected(S const& s, int field) {
  std::uint8_t buf[8] = {0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa};
  KindRow row;
  auto v = packbin::validate(s);
  auto p = packbin::pack(s, row, buf, sizeof(buf));
  return v.error == Error::SchemeInvalid && v.field == field && p.error == Error::SchemeInvalid &&
         buf[0] == 0xaa;
}

void ac4_runtime_order_errors() {
  auto gap = packbin::scheme<KindRow>(1, packbin::u8<&KindRow::kind>(1));
  expect(rejected(gap, 1), "AC-4 gap");
  auto dup = packbin::scheme<KindRow>(1, packbin::u8<&KindRow::kind>(0),
                                      packbin::u8<&KindRow::kind_id>(0));
  expect(rejected(dup, 0), "AC-4 repeated id");
  auto anchor = packbin::scheme<KindRow>(
      1, packbin::u8<&KindRow::kind>(0),
      packbin::when(2, packbin::eq(0, 0), packbin::u8<&KindRow::kind_id>(1)));
  expect(rejected(anchor, 2), "AC-4 wrong anchor");
  auto ahead = packbin::scheme<KindRow>(
      1, packbin::when(0, packbin::eq(1, 0), packbin::u8<&KindRow::kind_id>(0)),
      packbin::u8<&KindRow::kind>(1));
  expect(rejected(ahead, 0), "AC-4 when names an id not yet walked");
  auto range = packbin::scheme<KindRow>(256, packbin::u8<&KindRow::kind>(0));
  expect(rejected(range, -1), "type number 0..255");
}

void when_adds_its_group() {
  std::uint8_t buf[8];
  KindRow miss;
  miss.kind = 1;
  auto m = packbin::pack(kind_scheme, miss, buf, sizeof(buf));
  expect(m.ok() && m.offset == 2, "when miss adds 0");

  KindRow hit;
  hit.kind = 0;
  hit.kind_id = 9;
  auto h = packbin::pack(kind_scheme, hit, buf, sizeof(buf));
  expect(h.ok() && h.offset == 3 && check::same_hex(buf, 3, "010009"), "when match adds 1");

  KindRow back;
  back.kind_id = 4;
  auto u = packbin::unpack(kind_scheme, buf, h.offset, back);
  expect(u.ok() && back.kind == 0 && back.kind_id.has && back.kind_id.value == 9, "when unpack");

  std::uint8_t miss_bytes[2] = {0x01, 0x01};
  KindRow cleared;
  cleared.kind_id = 4;
  auto c = packbin::unpack(kind_scheme, miss_bytes, sizeof(miss_bytes), cleared);
  expect(c.ok() && cleared.kind == 1 && !cleared.kind_id.has, "when miss leaves it absent");

  KindRow required;
  required.kind = 0;
  auto bad = packbin::pack(kind_scheme, required, buf, sizeof(buf));
  expect(bad.error == Error::BadValue && bad.field == 1, "matched when needs its field");
}

void fixed_bytes() {
  constexpr auto s = packbin::scheme<KeyRow>(
      5, packbin::bytes<&KeyRow::key>(0), packbin::be(packbin::u16<&KeyRow::tail>(1)));
  KeyRow row;
  row.key[0] = 0xde;
  row.key[1] = 0xad;
  row.key[2] = 0xbe;
  row.key[3] = 0xef;
  row.tail = 0x0102;
  std::uint8_t buf[8];
  auto p = packbin::pack(s, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "05deadbeef0102"), "bytes and be hex");
  KeyRow back;
  auto u = packbin::unpack(s, buf, p.offset, back);
  expect(u.ok() && back.key[3] == 0xef && back.tail == 0x0102, "bytes unpack");
  auto full = packbin::pack(s, row, buf, 4);
  expect(full.error == Error::BufferFull && full.field == 0 && full.offset == 1, "bytes full");
}

void unbound_fields_skip() {
  constexpr auto s =
      packbin::scheme<MarkerRow>(3, packbin::u8<&MarkerRow::sid>(0), packbin::u32(1));
  std::uint8_t data[6] = {0x03, 0x07, 0x01, 0x02, 0x03, 0x04};
  MarkerRow row;
  auto u = packbin::unpack(s, data, sizeof(data), row);
  expect(u.ok() && row.sid == 7, "unbound field read and skipped");
  std::uint8_t buf[8];
  auto p = packbin::pack(s, row, buf, sizeof(buf));
  expect(p.error == Error::BadValue && p.field == 1, "unbound field cannot be packed");
}

}  // namespace

int run_core_scheme_tests() {
  type_number_leads_the_packet();
  ac1_unknown_type_number();
  ac2_matching_type_number();
  handler_waits_for_whole_packet();
  duplicate_type_numbers();
  ac4_runtime_order_errors();
  when_adds_its_group();
  fixed_bytes();
  unbound_fields_skip();
  return check::failures();
}
