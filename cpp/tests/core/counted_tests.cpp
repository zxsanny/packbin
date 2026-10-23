#include "packbin/codec.hpp"

#include "check.hpp"

#include <cstring>

using check::expect;
using packbin::Array;
using packbin::Error;
using packbin::View;

namespace {

template <std::size_t N>
void put_text(packbin::Text<N>& t, char const* s) {
  t.len = static_cast<std::uint16_t>(std::strlen(s));
  std::memcpy(t.data, s, t.len);
}

template <std::size_t N>
bool text_is(packbin::Text<N> const& t, char const* s) {
  return t.len == std::strlen(s) && std::memcmp(t.data, s, t.len) == 0;
}

struct Name {
  packbin::Text<16> name;
};

constexpr auto name_scheme = packbin::scheme<Name>(1, packbin::utf8<&Name::name>(0));

// A Packed string is the payload as it is on the wire (the count is not part of it).
struct PackedName {
  packbin::Packed name;
};

constexpr auto packed_scheme = packbin::scheme<PackedName>(1, packbin::utf8<&PackedName::name>(0));

void utf8_string() {
  std::uint8_t buf[16];
  packbin::Scratch<16> scratch;
  Name row;
  put_text(row.name, "zxsanny");
  auto p = packbin::pack(name_scheme, row, buf, sizeof(buf), scratch);
  expect(p.ok() && check::same_hex(buf, p.offset, "01062bfcfee119b2"), "utf8 hex");
  Name back;
  auto u = packbin::unpack(name_scheme, buf, p.offset, back);
  expect(u.ok() && text_is(back.name, "zxsanny"), "utf8 text");

  Name empty;
  auto e = packbin::pack(name_scheme, empty, buf, sizeof(buf));
  expect(e.ok() && check::same_hex(buf, e.offset, "0100"), "utf8 empty");
  auto eu = packbin::unpack(name_scheme, buf, e.offset, back);
  expect(eu.ok() && back.name.len == 0, "utf8 empty unpack");

  std::uint8_t cut[4];
  check::parse_hex("01062bfc", cut, sizeof(cut));
  auto s = packbin::unpack(name_scheme, cut, sizeof(cut), back);
  expect(s.error == Error::ShortPacket && s.field == 0 && s.needed == 6 && s.offset == 2,
         "utf8 short");
}

struct Message {
  packbin::Text<48> text;
  View key;
};

struct SmallMessage {
  packbin::Text<16> text;
  View key;
};

constexpr auto message = packbin::scheme<Message>(1, packbin::utf8<&Message::text>(0),
                                                  packbin::bytes<&Message::key>(1, 16));
constexpr auto small_message = packbin::scheme<SmallMessage>(
    1, packbin::utf8<&SmallMessage::text>(0), packbin::bytes<&SmallMessage::key>(1, 16));

void ac3_borrowed_and_ac4_fixed() {
  std::uint8_t key[16];
  for (std::size_t i = 0; i < sizeof(key); ++i)
    key[i] = static_cast<std::uint8_t>(i);
  Message row;
  put_text(row.text, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN");
  row.key = View{key, sizeof(key)};
  std::uint8_t buf[64];
  packbin::Scratch<48> scratch;
  auto p = packbin::pack(message, row, buf, sizeof(buf), scratch);
  expect(p.ok() && p.offset == 1 + 1 + 32 + 16, "AC-3 packet length");

  Message back;
  auto u = packbin::unpack(message, buf, p.offset, back);
  expect(u.ok() && back.text.len == 40 && back.key.len == 16, "AC-3 lengths");
  expect(text_is(back.text, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN"), "AC-3 text decoded");
  expect(back.key.data == buf + 34, "AC-3 bytes view points into input");

  SmallMessage small;
  auto f = packbin::unpack(small_message, buf, p.offset, small);
  expect(f.error == Error::TooMany && f.field == 0 && f.offset == 2 && f.needed == 40 &&
             small.text.len == 0,
         "AC-4 Text<16> too small (S6)");

  SmallMessage fits;
  put_text(fits.text, "hello");
  fits.key = View{key, sizeof(key)};
  auto fp = packbin::pack(small_message, fits, buf, sizeof(buf), scratch);
  SmallMessage fits_back;
  auto fu = packbin::unpack(small_message, buf, fp.offset, fits_back);
  expect(fp.ok() && fu.ok() && text_is(fits_back.text, "hello"), "Text<16> round trip");

  Message wrong;
  put_text(wrong.text, "x");
  wrong.key = View{key, 15};
  auto w = packbin::pack(message, wrong, buf, sizeof(buf), scratch);
  expect(w.error == Error::BadValue && w.field == 1, "bytes view must have length n");

  // A Packed string borrows the payload after the count, raw or compact, and packs back as is.
  PackedName held;
  std::uint8_t one[8];
  check::parse_hex("01021061", one, sizeof(one));
  auto r = packbin::unpack(packed_scheme, one, 4, held);
  expect(r.ok() && held.name.len == 2 && held.name.data == one + 2 && held.name.data[1] == 'a',
         "Packed borrows a raw payload");
  check::parse_hex("01062bfcfee119b2", one, sizeof(one));
  auto c = packbin::unpack(packed_scheme, one, 8, held);
  expect(c.ok() && held.name.len == 6 && held.name.data == one + 2 && held.name.data[0] == 0x2b,
         "Packed borrows a compact payload");
  std::uint8_t again[8];
  auto back_again = packbin::pack(packed_scheme, held, again, sizeof(again));
  expect(back_again.ok() && check::same_hex(again, back_again.offset, "01062bfcfee119b2"),
         "Packed packs the bytes as given");
}

struct Payload {
  std::uint16_t n = 0;
  packbin::Blob<8> payload;
};

constexpr auto sized_scheme = packbin::scheme<Payload>(1, packbin::u16<&Payload::n>(0),
                                                       packbin::sized<&Payload::payload>(1, 0));

void sized_bytes() {
  Payload row;
  row.n = 3;
  row.payload.len = 3;
  std::memcpy(row.payload.data, "uav", 3);
  std::uint8_t buf[16];
  auto p = packbin::pack(sized_scheme, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "010300756176"), "sized 3");
  Payload back;
  auto u = packbin::unpack(sized_scheme, buf, p.offset, back);
  expect(u.ok() && back.payload.len == 3 && std::memcmp(back.payload.data, "uav", 3) == 0,
         "sized unpack");

  Payload none;
  auto z = packbin::pack(sized_scheme, none, buf, sizeof(buf));
  expect(z.ok() && check::same_hex(buf, z.offset, "010000"), "sized 0");

  std::uint8_t cut[4];
  check::parse_hex("01030075", cut, sizeof(cut));
  auto s = packbin::unpack(sized_scheme, cut, sizeof(cut), back);
  expect(s.error == Error::ShortPacket && s.field == 1 && s.needed == 3 && s.offset == 3,
         "AC-5 sized count past the end");

  row.n = 2;
  auto m = packbin::pack(sized_scheme, row, buf, sizeof(buf));
  expect(m.error == Error::BadValue && m.field == 1, "sized length must equal its count");
}

struct Kinds {
  std::uint8_t a = 0, b = 0, c = 0, d = 0;
};

constexpr auto u2_scheme = packbin::scheme<Kinds>(
    1, packbin::u2(packbin::u8<&Kinds::a>(0), packbin::u8<&Kinds::b>(1), packbin::u8<&Kinds::c>(2),
                   packbin::u8<&Kinds::d>(3)));

void two_bit_values() {
  Kinds row{0, 1, 2, 3};
  std::uint8_t buf[8];
  auto p = packbin::pack(u2_scheme, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "01e4"), "u2 e4");
  Kinds back;
  auto u = packbin::unpack(u2_scheme, buf, p.offset, back);
  expect(u.ok() && back.a == 0 && back.b == 1 && back.c == 2 && back.d == 3, "u2 unpack");

  constexpr auto one = packbin::scheme<Kinds>(1, packbin::u2(packbin::u8<&Kinds::a>(0)));
  Kinds single{1, 0, 0, 0};
  auto o = packbin::pack(one, single, buf, sizeof(buf));
  expect(o.ok() && check::same_hex(buf, o.offset, "0101"), "u2 one");
  Kinds wide{4, 0, 0, 0};
  auto w = packbin::pack(one, wide, buf, sizeof(buf));
  expect(w.error == Error::BadValue && w.field == 0, "u2 value 4");

  // The refusals name the child that failed and leave the offset at the end of the type byte; a
  // buffer with no room for the packed bytes is BufferFull, as before the bytes were written in place.
  Kinds second{1, 4, 0, 0};
  auto s = packbin::pack(u2_scheme, second, buf, sizeof(buf));
  expect(s.error == Error::BadValue && s.field == 1 && s.offset == 1, "u2 second child 4");
  Kinds fourth{0, 0, 0, 7};
  auto f = packbin::pack(u2_scheme, fourth, buf, sizeof(buf));
  expect(f.error == Error::BadValue && f.field == 3 && f.offset == 1, "u2 fourth child 7");
  auto full = packbin::pack(u2_scheme, row, buf, 1);
  expect(full.error == Error::BufferFull && full.field == 0 && full.offset == 1 && full.needed == 1,
         "u2 buffer full");
}

struct Bits {
  std::uint8_t n = 0;
  Array<std::uint8_t, 16> bits;
};

constexpr auto bits_scheme =
    packbin::scheme<Bits>(1, packbin::u8<&Bits::n>(0), packbin::bits<&Bits::bits>(1, 0));

void bit_lists() {
  Bits row;
  row.n = 8;
  row.bits.count = 8;
  for (auto& b : row.bits.items)
    b = 1;
  std::uint8_t buf[8];
  auto e = packbin::pack(bits_scheme, row, buf, sizeof(buf));
  expect(e.ok() && check::same_hex(buf, e.offset, "0108ff"), "bits 8");
  row.n = 9;
  row.bits.count = 9;
  auto n = packbin::pack(bits_scheme, row, buf, sizeof(buf));
  expect(n.ok() && check::same_hex(buf, n.offset, "0109ff01"), "bits 9 unused 0");
  Bits back;
  auto u = packbin::unpack(bits_scheme, buf, n.offset, back);
  expect(u.ok() && back.bits.count == 9 && back.bits.items[8] == 1, "bits unpack");

  std::uint8_t cut[3] = {0x01, 0x09, 0x01};
  auto s = packbin::unpack(bits_scheme, cut, sizeof(cut), back);
  expect(s.error == Error::ShortPacket && s.field == 1 && s.needed == 2 && s.offset == 2,
         "bits short");
  row.bits.items[0] = 2;
  auto bad = packbin::pack(bits_scheme, row, buf, sizeof(buf));
  expect(bad.error == Error::BadValue && bad.field == 1, "bit must be 0 or 1");
}

struct Small {
  std::uint8_t n = 0;
  Array<std::uint8_t, 8> kinds;
};

constexpr auto width2 =
    packbin::scheme<Small>(1, packbin::u8<&Small::n>(0), packbin::packed<&Small::kinds>(2, 1, 0));
constexpr auto width1 = packbin::scheme<Small>(1, packbin::u8<&Small::n>(0),
                                               packbin::packed<&Small::kinds>(1, 1, 0, -1));

void packed_numbers() {
  Small row;
  row.n = 4;
  row.kinds.count = 4;
  for (std::uint8_t i = 0; i < 4; ++i)
    row.kinds.items[i] = i;
  std::uint8_t buf[8];
  auto p = packbin::pack(width2, row, buf, sizeof(buf));
  expect(p.ok() && check::same_hex(buf, p.offset, "0104e4"), "width2 e4");
  Small back;
  auto u = packbin::unpack(width2, buf, p.offset, back);
  expect(u.ok() && back.kinds.count == 4 && back.kinds.items[3] == 3, "width2 unpack");

  Small eight;
  eight.n = 9;
  eight.kinds.count = 8;
  for (auto& k : eight.kinds.items)
    k = 1;
  auto e = packbin::pack(width1, eight, buf, sizeof(buf));
  expect(e.ok() && check::same_hex(buf, e.offset, "0109ff"), "bias -1 eight");
  Small none;
  none.n = 1;
  auto z = packbin::pack(width1, none, buf, sizeof(buf));
  expect(z.ok() && z.offset == 2, "bias -1 empty");
  auto zu = packbin::unpack(width1, buf, z.offset, back);
  expect(zu.ok() && back.kinds.count == 0, "bias -1 unpack empty");

  Small mismatch;
  mismatch.n = 2;
  mismatch.kinds.count = 1;
  auto m = packbin::pack(width2, mismatch, buf, sizeof(buf));
  expect(m.error == Error::BadValue && m.field == 1, "packed length names field");

  std::uint8_t many[5] = {0x01, 0x0c, 0xff, 0xff, 0xff};
  Small tiny;
  auto t = packbin::unpack(width2, many, sizeof(many), tiny);
  expect(t.error == Error::TooMany && t.field == 1 && t.needed == 12, "packed 12 into 8");
}

// A 64-bit count whose low 32 bits are small must not shrink to that value where size_t is
// 32 bits: the packet has one byte, the count asks for 2^29 bytes.
void wide_count_is_not_truncated() {
  struct Wide {
    std::uint64_t n = 0;
    packbin::Array<std::uint8_t, 4> bits;
  };
  auto s = packbin::scheme<Wide>(1, packbin::u64<&Wide::n>(0),
                                 packbin::bits<&Wide::bits>(1, 0));
  std::uint8_t data[10] = {1, 4, 0, 0, 0, 1, 0, 0, 0, 0x0f};
  Wide row;
  auto r = packbin::unpack(s, data, sizeof(data), row);
  expect(r.error == Error::ShortPacket && row.bits.count == 0,
         "wide bits count is not cut to 32 bits");
}

}  // namespace

int run_core_container_tests();

int run_core_counted_tests() {
  utf8_string();
  ac3_borrowed_and_ac4_fixed();
  sized_bytes();
  two_bit_values();
  bit_lists();
  packed_numbers();
  wide_count_is_not_truncated();
  return run_core_container_tests();
}
