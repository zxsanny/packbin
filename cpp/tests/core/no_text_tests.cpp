// A core built with PACKBIN_NO_TEXT (AZ-2656): no codec is linked, yet the fields around a string
// are read, the string is skipped by its count or borrowed as a Packed and forwarded as it is.
// Built and run by `make no-text-test`.
#ifndef PACKBIN_NO_TEXT
#error "no_text_tests.cpp is built with -DPACKBIN_NO_TEXT"
#endif

#include "packbin/codec.hpp"

#include "check.hpp"

#include <cstdint>
#include <cstdio>

using check::expect;
using packbin::Array;
using packbin::Error;
using packbin::Packed;

namespace {

struct Fix {
  std::uint16_t sid = 0;
  Packed text;
  std::uint8_t kind = 0;
};

// u16 sid, a string held as Packed, u8 kind.
constexpr auto fix = packbin::scheme<Fix>(1, packbin::u16<&Fix::sid>(0),
                                          packbin::utf8<&Fix::text>(1), packbin::u8<&Fix::kind>(2));

struct Skipped {
  std::uint16_t sid = 0;
  std::uint8_t kind = 0;
};

constexpr auto skipping = packbin::scheme<Skipped>(
    1, packbin::u16<&Skipped::sid>(0), packbin::utf8(1), packbin::u8<&Skipped::kind>(2));

// "привіт" in the compact format (contract worked example): count 5, then the payload.
constexpr char const* kHello = "013412" "05a37aa424e0" "07";

// AC-6: the fields around the string are read, the payload is borrowed without decoding, and
// packing the row writes the original bytes.
void packed_skips_and_forwards() {
  // Arrange
  std::uint8_t wire[16];
  std::size_t n = check::parse_hex(kHello, wire, sizeof(wire));
  Fix row;
  // Act
  auto u = packbin::unpack(fix, wire, n, row);
  // Assert
  expect(u.ok() && row.sid == 0x1234 && row.kind == 7, "fields around the Packed are read");
  expect(row.text.len == 5 && row.text.data == wire + 4 && row.text.data[0] == 0xa3,
         "Packed holds the payload, no count");
  std::uint8_t again[16];
  auto p = packbin::pack(fix, row, again, sizeof(again));
  expect(p.ok() && check::same_hex(again, p.offset, kHello), "the same row packs to the bytes");

  // The payload is never looked at: bytes that are no text at all go through.
  std::uint8_t junk[8];
  n = check::parse_hex("01341202ffff07", junk, sizeof(junk));
  Fix relay;
  auto ju = packbin::unpack(fix, junk, n, relay);
  expect(ju.ok() && relay.text.len == 2 && relay.kind == 7, "a payload that is no text is held");
  auto jp = packbin::pack(fix, relay, again, sizeof(again));
  expect(jp.ok() && check::same_hex(again, jp.offset, "01341202ffff07"), "and forwarded");

  // An empty string is a count of 0 and an empty Packed.
  n = check::parse_hex("01341200" "07", junk, sizeof(junk));
  Fix empty;
  empty.text = Packed{junk, 3};
  auto eu = packbin::unpack(fix, junk, n, empty);
  expect(eu.ok() && empty.text.len == 0 && empty.kind == 7, "an empty string is an empty Packed");
  auto ep = packbin::pack(fix, empty, again, sizeof(again));
  expect(ep.ok() && check::same_hex(again, ep.offset, "01341200" "07"), "and packs as a 0 count");

  // A payload of 130 bytes has a 2-byte count.
  static std::uint8_t big[140];
  big[0] = 1;
  big[1] = 0x34;
  big[2] = 0x12;
  big[3] = 0x82;
  big[4] = 0x01;
  for (std::size_t i = 0; i < 130; ++i)
    big[5 + i] = static_cast<std::uint8_t>(i);
  big[135] = 9;
  Fix wide;
  static std::uint8_t out[140];
  auto wu = packbin::unpack(fix, big, 136, wide);
  auto wp = packbin::pack(fix, wide, out, sizeof(out));
  expect(wu.ok() && wide.text.len == 130 && wide.kind == 9 && wp.ok() && wp.offset == 136 &&
             std::memcmp(out, big, 136) == 0,
         "a 2-byte count");

  // A string with no member to bind is skipped by its count.
  std::uint8_t skip_wire[16];
  n = check::parse_hex(kHello, skip_wire, sizeof(skip_wire));
  Skipped skipped;
  auto su = packbin::unpack(skipping, skip_wire, n, skipped);
  expect(su.ok() && skipped.sid == 0x1234 && skipped.kind == 7, "an unbound string is skipped");
}

// AC-7: a count larger than the bytes that remain is a short packet naming the field.
void damaged_count() {
  std::uint8_t wire[16];
  std::size_t n = check::parse_hex("01341209a37a07", wire, sizeof(wire));
  Fix row;
  auto u = packbin::unpack(fix, wire, n, row);
  expect(u.error == Error::ShortPacket && u.field == 1 && u.offset == 4 && u.needed == 9,
         "a count past the packet is a short packet");
  expect(row.text.len == 0 && row.text.data == nullptr && row.kind == 0, "and holds no value");

  n = check::parse_hex("013412", wire, sizeof(wire));
  auto none = packbin::unpack(fix, wire, n, row);
  expect(none.error == Error::ShortPacket && none.field == 1, "a missing count is a short packet");
  n = check::parse_hex("0134128000", wire, sizeof(wire));
  auto padded = packbin::unpack(fix, wire, n, row);
  expect(padded.error == Error::BadValue && padded.field == 1, "a count that is not minimal");
  n = check::parse_hex("01341280808001", wire, sizeof(wire));
  auto four = packbin::unpack(fix, wire, n, row);
  expect(four.error == Error::BadValue && four.field == 1, "a count of four bytes");
  // The same refusals when the string is only skipped.
  Skipped skipped;
  n = check::parse_hex("01341209a37a07", wire, sizeof(wire));
  auto skip = packbin::unpack(skipping, wire, n, skipped);
  expect(skip.error == Error::ShortPacket && skip.field == 1, "a skipped string, short packet");
}

// Pack of a Packed: the varint limit of 3 bytes and the buffer cap.
void packed_pack_limits() {
  std::uint8_t buf[8];
  Fix row;
  row.text = Packed{buf, 2097152};
  auto over = packbin::pack(fix, row, buf, sizeof(buf));
  expect(over.error == Error::BadValue && over.field == 1, "a count above 2,097,151");
  row.text = Packed{buf, 2097151};
  auto full = packbin::pack(fix, row, buf, sizeof(buf));
  expect(full.error == Error::BufferFull && full.field == 1 && full.needed == 3 + 2097151,
         "the largest count needs the buffer");
  row.text = Packed{nullptr, 1};
  auto hole = packbin::pack(fix, row, buf, sizeof(buf));
  expect(hole.error == Error::BadValue && hole.field == 1, "bytes that are not there");
  row.text = Packed{};
  auto empty = packbin::pack(fix, row, buf, sizeof(buf));
  expect(empty.ok() && check::same_hex(buf, empty.offset, "01000000" "00"),
         "an empty Packed packs as a 0 count");
  std::uint8_t tiny[6];
  std::uint8_t three[3] = {1, 2, 3};
  row.text = Packed{three, 3};
  auto small = packbin::pack(fix, row, tiny, sizeof(tiny));
  expect(small.error == Error::BufferFull && small.field == 1 && small.needed == 4,
         "the string needs its count and bytes");
}

struct Names {
  Array<Packed, 3> names;
};

constexpr auto names = packbin::scheme<Names>(1, packbin::list<&Names::names>(packbin::utf8(0)));

struct Pairs {
  Array<packbin::Entry<Packed, packbin::Text<4>>, 2> m;
};

// A list of Packed works; a dictionary needs Text<N> keys, so it cannot be bound here.
void list_and_dict() {
  std::uint8_t wire[16];
  std::size_t n = check::parse_hex("010200" "021061" "00", wire, sizeof(wire));
  Names row;
  auto u = packbin::unpack(names, wire, n, row);
  expect(u.ok() && row.names.count == 2 && row.names.items[0].len == 2 &&
             row.names.items[0].data == wire + 4 && row.names.items[1].len == 0,
         "a list of Packed is read");
  std::uint8_t out[16];
  auto p = packbin::pack(names, row, out, sizeof(out));
  expect(p.ok() && check::same_hex(out, p.offset, "010200" "021061" "00"), "and forwarded");

  // Built at run time, a list element or dictionary key that needs the codec is SchemeInvalid.
  struct TextList {
    Array<packbin::Text<4>, 2> xs;
  };
  auto text_list = packbin::scheme<TextList>(1, packbin::list<&TextList::xs>(packbin::utf8(0)));
  expect(text_list.status.error == Error::SchemeInvalid, "a Text<N> element is refused");
  TextList tl;
  std::uint8_t one[4] = {1, 0, 0, 0};
  expect(packbin::unpack(text_list, one, sizeof(one), tl).error == Error::SchemeInvalid,
         "and the scheme does not unpack");
  auto dict = packbin::scheme<Pairs>(1, packbin::dict<&Pairs::m>(packbin::utf8(0)));
  expect(dict.status.error == Error::SchemeInvalid, "a dictionary needs Text<N> keys");
}

}  // namespace

int main() {
  packed_skips_and_forwards();
  damaged_count();
  packed_pack_limits();
  list_and_dict();
  if (check::failures() != 0) {
    std::fprintf(stderr, "%d failure(s)\n", check::failures());
    return 1;
  }
  std::printf("no-text tests passed\n");
  return 0;
}
