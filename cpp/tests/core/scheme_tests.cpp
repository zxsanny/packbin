#include "packbin/codec.hpp"

#include "check.hpp"

#include <utility>

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

// A bool or an empty group is a presence bit: only inside flags or under a flag bit (AZ-2081).
struct Bare {
  bool b = false;
  std::uint8_t v = 0;
};

struct Presence {
  packbin::Opt<bool> on;
  packbin::Opt<std::uint8_t> n;
};

struct Switch {
  packbin::Opt<bool> on;
};

void bool_outside_flags_is_refused() {
  auto top = packbin::scheme<Bare>(1, packbin::boolean<&Bare::b>(0), packbin::u8<&Bare::v>(1));
  auto v = packbin::validate(top);
  expect(v.error == Error::SchemeInvalid && v.field == 0, "AC-1 bool at top level refused");
  Bare row;
  row.v = 7;
  std::uint8_t buf[8];
  auto p = packbin::pack(top, row, buf, sizeof(buf));
  expect(p.error == Error::SchemeInvalid && p.offset == 0, "AC-1 pack returns the status");
  std::uint8_t data[2] = {1, 7};
  auto u = packbin::unpack(top, data, sizeof(data), row);
  expect(u.error == Error::SchemeInvalid && u.offset == 0, "AC-1 unpack returns the status");

  auto grouped = packbin::scheme<Bare>(
      1, packbin::group(0, packbin::boolean<&Bare::b>(0), packbin::u8<&Bare::v>(1)));
  expect(packbin::validate(grouped).error == Error::SchemeInvalid, "AC-1 bool in a plain group");
}

void empty_group_outside_flags_is_refused() {
  // An empty group takes no order id of its own after its anchor, so the ids below are valid.
  auto top = packbin::scheme<Bare>(1, packbin::u8<&Bare::v>(0), packbin::group<&Bare::b>(1));
  auto v = packbin::validate(top);
  expect(v.error == Error::SchemeInvalid && v.field == 1, "AC-2 empty group at top level");
  auto nested = packbin::scheme<Bare>(
      1, packbin::u8<&Bare::v>(0), packbin::group(1, packbin::group<&Bare::b>(1)));
  expect(packbin::validate(nested).error == Error::SchemeInvalid, "AC-2 empty group in a group");
  auto guarded = packbin::scheme<Bare>(
      1, packbin::u8<&Bare::v>(0),
      packbin::when(1, packbin::eq(0, 1), packbin::group<&Bare::b>(1)));
  expect(packbin::validate(guarded).error == Error::SchemeInvalid, "AC-2 empty group in a when");

  struct Flagged {
    bool b = false;
  };
  struct Items {
    std::uint8_t n = 0;
    packbin::Array<Flagged, 2> items;
    packbin::Array<std::uint8_t, 2> xs;
  };
  auto in_repeat = packbin::scheme<Items>(
      1, packbin::repeat<&Items::items>(0, packbin::group<&Flagged::b>(0)));
  expect(packbin::validate(in_repeat).error == Error::SchemeInvalid,
         "AC-2 empty group in a repeat");
  auto in_times = packbin::scheme<Items>(
      1, packbin::u8<&Items::n>(0),
      packbin::times<&Items::items>(1, 0, packbin::group<&Flagged::b>(1)));
  expect(packbin::validate(in_times).error == Error::SchemeInvalid, "AC-2 empty group in a times");
  auto in_list = packbin::scheme<Items>(1, packbin::list<&Items::xs>(packbin::group(0)));
  expect(packbin::validate(in_list).error == Error::SchemeInvalid, "AC-2 empty group in a list");
}

void empty_group_without_member_is_refused() {
  // A group with no fields and no member can never set its bit, so it is refused even where a
  // presence bit is allowed.
  auto in_flags = packbin::scheme<Presence>(1, packbin::flags(0, packbin::group(0)));
  auto v = packbin::validate(in_flags);
  expect(v.error == Error::SchemeInvalid && v.field == 0, "AZ-2147 AC-1 empty group in flags");
  auto as_bit = packbin::scheme<Presence>(1, packbin::flag_byte(0),
                                          packbin::flag_bit(0, packbin::group(0)));
  expect(packbin::validate(as_bit).error == Error::SchemeInvalid,
         "AZ-2147 AC-1 empty group as a flag bit");

  auto bound = packbin::scheme<Presence>(1, packbin::flags(0, packbin::group<&Presence::on>(0)));
  Presence row;
  row.on = true;
  std::uint8_t buf[4];
  auto t = packbin::pack(bound, row, buf, sizeof(buf));
  expect(t.ok() && check::same_hex(buf, t.offset, "0101"), "AZ-2147 AC-2 bool group true");
  Presence back;
  auto u = packbin::unpack(bound, buf, t.offset, back);
  expect(u.ok() && back.on.has && back.on.value, "AZ-2147 AC-2 bool group unpacks true");
  row.on = false;
  auto f = packbin::pack(bound, row, buf, sizeof(buf));
  expect(f.ok() && check::same_hex(buf, f.offset, "0100"), "AZ-2147 AC-2 bool group false");
}

void bool_inside_flags_is_unchanged() {
  auto in_flags = packbin::scheme<Presence>(
      1, packbin::flags(0, packbin::boolean<&Presence::on>(0), packbin::u8<&Presence::n>(1)));
  Presence row;
  row.on = true;
  row.n = 7;
  std::uint8_t buf[8];
  auto t = packbin::pack(in_flags, row, buf, sizeof(buf));
  expect(t.ok() && check::same_hex(buf, t.offset, "010307"), "AC-3 flags bool true");
  Presence back;
  auto tu = packbin::unpack(in_flags, buf, t.offset, back);
  expect(tu.ok() && back.on.has && back.on.value && back.n.has && back.n.value == 7,
         "AC-3 flags bool true unpacks");
  row.on = false;
  auto f = packbin::pack(in_flags, row, buf, sizeof(buf));
  expect(f.ok() && check::same_hex(buf, f.offset, "010207"), "AC-3 flags bool false");
  Presence off;
  auto fu = packbin::unpack(in_flags, buf, f.offset, off);
  expect(fu.ok() && !off.on.has && off.n.has, "AC-3 flags bool false reads as absent");

  auto split = packbin::scheme<Switch>(
      1, packbin::flag_byte(0), packbin::flag_bit(0, packbin::boolean<&Switch::on>(0)));
  Switch s;
  s.on = true;
  auto st = packbin::pack(split, s, buf, sizeof(buf));
  expect(st.ok() && check::same_hex(buf, st.offset, "0101"), "AC-3 flag bit bool true");
  Switch sback;
  auto su = packbin::unpack(split, buf, st.offset, sback);
  expect(su.ok() && sback.on.has && sback.on.value, "AC-3 flag bit bool true unpacks");
  s.on = false;
  auto sf = packbin::pack(split, s, buf, sizeof(buf));
  expect(sf.ok() && check::same_hex(buf, sf.offset, "0100"), "AC-3 flag bit bool false");
  Switch none;
  auto sn = packbin::pack(split, none, buf, sizeof(buf));
  expect(sn.ok() && check::same_hex(buf, sn.offset, "0100"), "AC-3 flag bit bool absent");
}

// A u2 holds at most 64 children (16 bytes): a 65th is a construction error (AC-4).
struct Wide64 {
  std::uint8_t c0 = 0, c1 = 0, c2 = 0, c3 = 0, c4 = 0, c5 = 0, c6 = 0, c7 = 0;
  std::uint8_t c8 = 0, c9 = 0, c10 = 0, c11 = 0, c12 = 0, c13 = 0, c14 = 0, c15 = 0;
  std::uint8_t c16 = 0, c17 = 0, c18 = 0, c19 = 0, c20 = 0, c21 = 0, c22 = 0, c23 = 0;
  std::uint8_t c24 = 0, c25 = 0, c26 = 0, c27 = 0, c28 = 0, c29 = 0, c30 = 0, c31 = 0;
  std::uint8_t c32 = 0, c33 = 0, c34 = 0, c35 = 0, c36 = 0, c37 = 0, c38 = 0, c39 = 0;
  std::uint8_t c40 = 0, c41 = 0, c42 = 0, c43 = 0, c44 = 0, c45 = 0, c46 = 0, c47 = 0;
  std::uint8_t c48 = 0, c49 = 0, c50 = 0, c51 = 0, c52 = 0, c53 = 0, c54 = 0, c55 = 0;
  std::uint8_t c56 = 0, c57 = 0, c58 = 0, c59 = 0, c60 = 0, c61 = 0, c62 = 0, c63 = 0;
};

constexpr auto wide64 = packbin::scheme<Wide64>(
    1, packbin::u2(
    packbin::u8<&Wide64::c0>(0), packbin::u8<&Wide64::c1>(1), packbin::u8<&Wide64::c2>(2),
    packbin::u8<&Wide64::c3>(3), packbin::u8<&Wide64::c4>(4), packbin::u8<&Wide64::c5>(5),
    packbin::u8<&Wide64::c6>(6), packbin::u8<&Wide64::c7>(7), packbin::u8<&Wide64::c8>(8),
    packbin::u8<&Wide64::c9>(9), packbin::u8<&Wide64::c10>(10), packbin::u8<&Wide64::c11>(11),
    packbin::u8<&Wide64::c12>(12), packbin::u8<&Wide64::c13>(13), packbin::u8<&Wide64::c14>(14),
    packbin::u8<&Wide64::c15>(15), packbin::u8<&Wide64::c16>(16), packbin::u8<&Wide64::c17>(17),
    packbin::u8<&Wide64::c18>(18), packbin::u8<&Wide64::c19>(19), packbin::u8<&Wide64::c20>(20),
    packbin::u8<&Wide64::c21>(21), packbin::u8<&Wide64::c22>(22), packbin::u8<&Wide64::c23>(23),
    packbin::u8<&Wide64::c24>(24), packbin::u8<&Wide64::c25>(25), packbin::u8<&Wide64::c26>(26),
    packbin::u8<&Wide64::c27>(27), packbin::u8<&Wide64::c28>(28), packbin::u8<&Wide64::c29>(29),
    packbin::u8<&Wide64::c30>(30), packbin::u8<&Wide64::c31>(31), packbin::u8<&Wide64::c32>(32),
    packbin::u8<&Wide64::c33>(33), packbin::u8<&Wide64::c34>(34), packbin::u8<&Wide64::c35>(35),
    packbin::u8<&Wide64::c36>(36), packbin::u8<&Wide64::c37>(37), packbin::u8<&Wide64::c38>(38),
    packbin::u8<&Wide64::c39>(39), packbin::u8<&Wide64::c40>(40), packbin::u8<&Wide64::c41>(41),
    packbin::u8<&Wide64::c42>(42), packbin::u8<&Wide64::c43>(43), packbin::u8<&Wide64::c44>(44),
    packbin::u8<&Wide64::c45>(45), packbin::u8<&Wide64::c46>(46), packbin::u8<&Wide64::c47>(47),
    packbin::u8<&Wide64::c48>(48), packbin::u8<&Wide64::c49>(49), packbin::u8<&Wide64::c50>(50),
    packbin::u8<&Wide64::c51>(51), packbin::u8<&Wide64::c52>(52), packbin::u8<&Wide64::c53>(53),
    packbin::u8<&Wide64::c54>(54), packbin::u8<&Wide64::c55>(55), packbin::u8<&Wide64::c56>(56),
    packbin::u8<&Wide64::c57>(57), packbin::u8<&Wide64::c58>(58), packbin::u8<&Wide64::c59>(59),
    packbin::u8<&Wide64::c60>(60), packbin::u8<&Wide64::c61>(61), packbin::u8<&Wide64::c62>(62),
    packbin::u8<&Wide64::c63>(63)));

template <std::size_t... I>
auto wide_unbound(std::index_sequence<I...>) {
  return packbin::scheme<Wide64>(1, packbin::u2(packbin::u8(static_cast<int>(I))...));
}

void u2_limit() {
  expect(packbin::validate(wide64).ok(), "AC-4 64 children build");
  Wide64 row;
  row.c0 = 0; row.c1 = 1; row.c2 = 2; row.c3 = 3; row.c4 = 0; row.c5 = 1;
  row.c6 = 2; row.c7 = 3; row.c8 = 0; row.c9 = 1; row.c10 = 2; row.c11 = 3;
  row.c12 = 0; row.c13 = 1; row.c14 = 2; row.c15 = 3; row.c16 = 0; row.c17 = 1;
  row.c18 = 2; row.c19 = 3; row.c20 = 0; row.c21 = 1; row.c22 = 2; row.c23 = 3;
  row.c24 = 0; row.c25 = 1; row.c26 = 2; row.c27 = 3; row.c28 = 0; row.c29 = 1;
  row.c30 = 2; row.c31 = 3; row.c32 = 0; row.c33 = 1; row.c34 = 2; row.c35 = 3;
  row.c36 = 0; row.c37 = 1; row.c38 = 2; row.c39 = 3; row.c40 = 0; row.c41 = 1;
  row.c42 = 2; row.c43 = 3; row.c44 = 0; row.c45 = 1; row.c46 = 2; row.c47 = 3;
  row.c48 = 0; row.c49 = 1; row.c50 = 2; row.c51 = 3; row.c52 = 0; row.c53 = 1;
  row.c54 = 2; row.c55 = 3; row.c56 = 0; row.c57 = 1; row.c58 = 2; row.c59 = 3;
  row.c60 = 0; row.c61 = 1; row.c62 = 2; row.c63 = 3;
  std::uint8_t buf[32];
  auto p = packbin::pack(wide64, row, buf, sizeof(buf));
  bool all_e4 = p.ok() && p.offset == 17;
  for (std::size_t i = 1; all_e4 && i < p.offset; ++i)
    all_e4 = buf[i] == 0xe4;
  expect(all_e4, "AC-4 64 children pack to 16 bytes");
  Wide64 back;
  auto u = packbin::unpack(wide64, buf, p.offset, back);
  expect(u.ok() && back.c0 == 0 && back.c1 == 1 && back.c63 == 3, "AC-4 64 children unpack");

  auto too_wide = wide_unbound(std::make_index_sequence<65>{});
  auto v = packbin::validate(too_wide);
  expect(v.error == Error::SchemeInvalid && v.field == 0, "AC-4 65 children refused");
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
  bool_outside_flags_is_refused();
  empty_group_outside_flags_is_refused();
  empty_group_without_member_is_refused();
  bool_inside_flags_is_unchanged();
  u2_limit();
  return check::failures();
}
