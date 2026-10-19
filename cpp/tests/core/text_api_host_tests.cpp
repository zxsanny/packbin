// String binding rules (AZ-2656): UTF-8 refusals name the field, a Packed borrows and forwards
// the payload with the codec present, in a list and as a dictionary value. AZ-2733 (CS-D2): a
// Text<N> in every round of a `times` and of a `repeat`, and under a `flags` bit, is the compact
// field of the text. A bound Text<N> is always present on pack, so its flags bit is always set: "bit
// clear on pack" has no C++ row (owner 2026-10-20, excluded); only unpack reads a clear bit.
#include "packbin/packbin.hpp"

#include "check.hpp"

#include <cstdint>
#include <cstring>
#include <initializer_list>
#include <string>

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

// A round that holds one text. The field bytes are rows of fixtures/text/vectors.txt:
// "привіт" 05a37aa424e0, "hello, world" 09eaa2d67fe1edf16a00, "я" 02a300, the empty text 00.
struct Word {
  Text<16> text;
};

constexpr char kHello[] = "\xd0\xbf\xd1\x80\xd0\xb8\xd0\xb2\xd1\x96\xd1\x82";
constexpr char kHelloWorld[] = "hello, world";
constexpr char kYa[] = "\xd1\x8f";

bool same_words(Array<Word, 4> const& a, Array<Word, 4> const& b) {
  if (a.count != b.count)
    return false;
  for (std::size_t i = 0; i < a.count; ++i) {
    if (a.items[i].text.len != b.items[i].text.len ||
        std::memcmp(a.items[i].text.data, b.items[i].text.data, a.items[i].text.len) != 0)
      return false;
  }
  return true;
}

void fill_words(Array<Word, 4>& words, std::initializer_list<char const*> texts) {
  for (char const* t : texts) {
    Text<16>& to = words.items[words.count++].text;
    to.len = static_cast<std::uint16_t>(std::strlen(t));
    std::memcpy(to.data, t, to.len);
  }
}

struct Counted {
  std::uint8_t n = 0;
  Array<Word, 4> words;

  bool same_as(Counted const& o) const { return n == o.n && same_words(words, o.words); }
};

struct Repeated {
  Array<Word, 4> words;

  bool same_as(Repeated const& o) const { return same_words(words, o.words); }
};

constexpr auto counted_words = packbin::scheme<Counted>(
    1, packbin::u8<&Counted::n>(0),
    packbin::times<&Counted::words>(1, 0, packbin::utf8<&Word::text>(1)));

constexpr auto repeated_words = packbin::scheme<Repeated>(
    1, packbin::repeat<&Repeated::words>(0, packbin::utf8<&Word::text>(0)));

// The row packs to the pinned hex, the hex unpacks to the row, and the unpacked row packs again to
// the same bytes. Pack takes a scratch for the code points of the texts.
template <typename S, typename Row>
void text_round_trip(S const& s, Row const& row, char const* hex, char const* name) {
  std::string label(name);
  std::uint8_t buf[64];
  packbin::Scratch<16> scratch;
  auto p = packbin::pack(s, row, buf, sizeof(buf), scratch);
  expect(p.ok() && check::same_hex(buf, p.offset, hex), (label + ": pack bytes").c_str());
  std::uint8_t wire[64];
  std::size_t n = check::parse_hex(hex, wire, sizeof(wire));
  Row back;
  auto u = packbin::unpack(s, wire, n, back);
  expect(u.ok() && back.same_as(row), (label + ": unpack row").c_str());
  std::uint8_t again[64];
  auto r = packbin::pack(s, back, again, sizeof(again), scratch);
  expect(u.ok() && r.ok() && check::same_hex(again, r.offset, hex),
         (label + ": repack of the unpacked row").c_str());
}

Counted counted_row(std::initializer_list<char const*> texts) {
  Counted row;
  row.n = static_cast<std::uint8_t>(texts.size());
  fill_words(row.words, texts);
  return row;
}

Repeated repeated_row(std::initializer_list<char const*> texts) {
  Repeated row;
  fill_words(row.words, texts);
  return row;
}

// CS-D2 (b): under `times` every round holds the compact field of its text, the empty text
// included (one byte, count 0); the count byte before them is the rounds' count.
void text_in_every_times_round() {
  // Arrange
  Counted none = counted_row({});
  Counted one = counted_row({kYa});
  Counted three = counted_row({kHello, "", kHelloWorld});

  // Act and Assert: pack bytes, unpack row and repack of the unpacked row
  text_round_trip(counted_words, none, "0100", "times 0 rounds");
  text_round_trip(counted_words, one, "010102a300", "times 1 round");
  text_round_trip(counted_words, three, "010305a37aa424e00009eaa2d67fe1edf16a00",
                  "times 3 rounds with an empty text between two texts");
}

// CS-D2 (b): under `repeat` the rounds are the compact fields one after another to the end of
// the packet; no rounds is no byte.
void text_in_every_repeat_round() {
  // Arrange
  Repeated none = repeated_row({});
  Repeated one = repeated_row({kYa});
  Repeated three = repeated_row({kHello, "", kHelloWorld});

  // Act and Assert: pack bytes, unpack row and repack of the unpacked row
  text_round_trip(repeated_words, none, "01", "repeat 0 rounds");
  text_round_trip(repeated_words, one, "0102a300", "repeat 1 round");
  text_round_trip(repeated_words, three, "0105a37aa424e00009eaa2d67fe1edf16a00",
                  "repeat 3 rounds with an empty text between two texts");
}

// A Text<N> as the one member of a `flags`; the second scheme reads a byte after the flags.
struct Flagged {
  Text<16> note;

  bool same_as(Flagged const& o) const {
    return note.len == o.note.len && std::memcmp(note.data, o.note.data, note.len) == 0;
  }
};

struct FlaggedThenByte {
  Text<16> note;
  std::uint8_t after = 0;
};

constexpr auto flagged =
    packbin::scheme<Flagged>(1, packbin::flags(0, packbin::utf8<&Flagged::note>(0)));

constexpr auto flagged_then_byte = packbin::scheme<FlaggedThenByte>(
    1, packbin::flags(0, packbin::utf8<&FlaggedThenByte::note>(0)),
    packbin::u8<&FlaggedThenByte::after>(1));

// CS-D2 (a), the half C++ can express: the bit of a Text<N> is set whatever the text, so an empty
// text is the flags byte 01 and the 1-byte empty field 00, and a text is its compact field.
void text_under_a_flags_bit_set_with_an_empty_text_is_one_byte() {
  // Arrange
  Flagged empty;
  Flagged hello;
  hello.note.len = static_cast<std::uint16_t>(std::strlen(kHello));
  std::memcpy(hello.note.data, kHello, hello.note.len);

  // Act and Assert: pack bytes, unpack row and repack of the unpacked row
  text_round_trip(flagged, empty, "010100", "flags bit set, empty text");
  text_round_trip(flagged, hello, "010105a37aa424e0", "flags bit set, text");
}

// CS-D2 (a), the other half C++ can express: a clear bit reads no byte of a field (the byte after
// the flags byte is the next field, 5a), and the text of the row is left empty.
void unpack_of_a_clear_flags_bit_leaves_the_text_empty_and_reads_no_field() {
  // Arrange
  std::uint8_t wire[8];
  std::size_t n = check::parse_hex("01005a", wire, sizeof(wire));
  FlaggedThenByte row;
  row.note.len = static_cast<std::uint16_t>(std::strlen(kYa));
  std::memcpy(row.note.data, kYa, row.note.len);

  // Act
  auto u = packbin::unpack(flagged_then_byte, wire, n, row);

  // Assert
  expect(u.ok(), "flags bit clear: unpack ok, the 5a was not read as a count");
  expect(row.note.len == 0, "flags bit clear: the text is empty");
  expect(row.after == 0x5a, "flags bit clear: the byte after the flags byte is the next field");
}

}  // namespace

int run_core_text_api_host_tests() {
  utf8_refused();
  text_beside_packed();
  list_and_dictionary();
  damaged_count();
  text_in_every_times_round();
  text_in_every_repeat_round();
  text_under_a_flags_bit_set_with_an_empty_text_is_one_byte();
  unpack_of_a_clear_flags_bit_leaves_the_text_empty_and_reads_no_field();
  return check::failures();
}
