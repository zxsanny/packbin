// String binding rules (AZ-2656): UTF-8 refusals name the field, a Packed borrows and forwards
// the payload with the codec present, in a list and as a dictionary value.
#include "packbin/packbin.hpp"

#include "check.hpp"

#include <cstdint>
#include <cstring>

using check::expect;
using packbin::Array;
using packbin::Entry;
using packbin::Error;
using packbin::Packed;
using packbin::Text;

namespace {

struct Both {
  Text<16> text;
  Packed raw;
  std::uint8_t kind = 0;
};

constexpr auto both = packbin::scheme<Both>(1, packbin::utf8<&Both::text>(0),
                                            packbin::utf8<&Both::raw>(1),
                                            packbin::u8<&Both::kind>(2));

struct One {
  Text<8> text;
};

constexpr auto one = packbin::scheme<One>(1, packbin::utf8<&One::text>(0));

struct Held {
  Packed raw;
};

constexpr auto held = packbin::scheme<Held>(1, packbin::utf8<&Held::raw>(0));

// AC-4: invalid UTF-8 in the raw payload and in an escape is BadValue naming the field, at the
// count. A Packed does not look at the payload, so the same bytes go through it.
void utf8_refused() {
  std::uint8_t raw_bad[8];
  std::size_t n = check::parse_hex("010310c328", raw_bad, sizeof(raw_bad));
  One row;
  auto r = packbin::unpack(one, raw_bad, n, row);
  expect(r.error == Error::BadValue && r.field == 0 && r.offset == 1 && row.text.len == 0,
         "raw c3 28 is BadValue naming the field");

  std::uint8_t esc_bad[12];
  n = check::parse_hex("0106c3ff3b682000", esc_bad, sizeof(esc_bad));
  auto e = packbin::unpack(one, esc_bad, n, row);
  expect(e.error == Error::BadValue && e.field == 0 && e.offset == 1, "an escaped surrogate");

  Held relay;
  auto h = packbin::unpack(held, raw_bad, 5, relay);
  expect(h.ok() && relay.raw.len == 3 && relay.raw.data == raw_bad + 2,
         "a Packed holds invalid UTF-8 unchecked");
  std::uint8_t out[8];
  auto p = packbin::pack(held, relay, out, sizeof(out));
  expect(p.ok() && check::same_hex(out, p.offset, "010310c328"), "and packs it as given");

  // Pack refuses the same bytes in a Text<N>.
  One bad;
  bad.text.len = 2;
  bad.text.data[0] = static_cast<char>(0xc3);
  bad.text.data[1] = 0x28;
  packbin::Scratch<4> scratch;
  auto q = packbin::pack(one, bad, out, sizeof(out), scratch);
  expect(q.error == Error::BadValue && q.field == 0, "pack refuses invalid UTF-8 in a Text<N>");
}

// A Text<N> and a Packed side by side: the Packed holds the payload the Text decodes.
void text_beside_packed() {
  // "привіт", then the same string as a Packed, then the kind byte.
  std::uint8_t wire[24];
  std::size_t n = check::parse_hex("0105a37aa424e0" "05a37aa424e0" "09", wire, sizeof(wire));
  Both row;
  auto u = packbin::unpack(both, wire, n, row);
  expect(u.ok() && row.text.len == 12 && row.raw.len == 5 && row.raw.data == wire + 8 &&
             row.kind == 9,
         "Text<N> and Packed side by side");
  std::uint8_t out[24];
  packbin::Scratch<8> scratch;
  auto p = packbin::pack(both, row, out, sizeof(out), scratch);
  expect(p.ok() && std::memcmp(out, wire, n) == 0 && p.offset == n, "and pack to the same bytes");
}

struct Names {
  Array<Packed, 3> names;
  Array<Entry<Packed, Text<8>>, 2> access;
};

constexpr auto names = packbin::scheme<Names>(
    1, packbin::list<&Names::names>(packbin::utf8(0)),
    packbin::dict<&Names::access>(packbin::utf8(0)));

// A list element is a Packed; a dictionary key is a Text<N> and its value a Packed.
void list_and_dictionary() {
  std::uint8_t wire[32];
  std::size_t n = check::parse_hex("01" "0200" "021061" "00" "0100" "02106b" "021076", wire,
                                   sizeof(wire));
  Names row;
  auto u = packbin::unpack(names, wire, n, row);
  expect(u.ok() && row.names.count == 2 && row.names.items[0].len == 2 &&
             row.names.items[0].data == wire + 4 && row.names.items[1].len == 0,
         "a list of Packed");
  expect(row.access.count == 1 && row.access.items[0].key.len == 1 &&
             row.access.items[0].key.data[0] == 'k' && row.access.items[0].value.len == 2 &&
             row.access.items[0].value.data[1] == 'v',
         "a dictionary of Text keys and Packed values");
  std::uint8_t out[32];
  auto p = packbin::pack(names, row, out, sizeof(out));
  expect(p.ok() && p.offset == n && std::memcmp(out, wire, n) == 0, "forwarded as given");
}

// AC-7 with the codec present: a count past the packet is a short packet naming the field.
void damaged_count() {
  std::uint8_t wire[8];
  std::size_t n = check::parse_hex("010905aa", wire, sizeof(wire));
  Held row;
  auto u = packbin::unpack(held, wire, n, row);
  expect(u.error == Error::ShortPacket && u.field == 0 && u.needed == 9 && row.raw.len == 0,
         "a count larger than the packet");
}

}  // namespace

int run_core_text_api_host_tests() {
  utf8_refused();
  text_beside_packed();
  list_and_dictionary();
  damaged_count();
  return check::failures();
}
