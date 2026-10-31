// Parity percentage (AZ-3513; contract message-ecc.md 1.1.0): a message whose length varies by an
// optional field, a string field read after the repair, and the refusal of a dispatch mix that
// tells a percentage from a count of the same number (256 + p against p).
#include "packbin/codec.hpp"

#include "check.hpp"
#include "ecc_percent_support_host.hpp"
#include "ecc_support_host.hpp"

#include <cstdint>
#include <cstring>

using check::expect;
using ecc_percent::corrupt;
using ecc_percent::msg_scheme;
using ecc_percent::Msg;
using ecc_test::Bytes;
using packbin::Error;
using packbin::Opt;

namespace {

namespace pd = packbin::detail;

// A type byte, a u64 and an optional field behind a flag byte: a u16 and a u8 that a message
// carries together (13 clear bytes) or leaves out together (10 clear bytes).
struct Optional {
  std::uint64_t id = 0;
  Opt<std::uint16_t> a;
  Opt<std::uint8_t> b;
};

constexpr auto optional_scheme = packbin::parity_percent(
    packbin::scheme<Optional>(5, packbin::u64<&Optional::id>(0),
                              packbin::flags(1, packbin::u16<&Optional::a>(1),
                                             packbin::u8<&Optional::b>(2))),
    25);

// AC-1: each message carries the count of its own length.
void optional_field() {
  Optional with;
  with.id = 0x0102030405060708ULL;
  with.a = 0x0a0b;
  with.b = 0x0c;
  Optional without;
  without.id = with.id;
  std::uint8_t long_buf[64];
  std::uint8_t short_buf[64];

  auto pl = packbin::pack(optional_scheme, with, long_buf, sizeof(long_buf));
  auto ps = packbin::pack(optional_scheme, without, short_buf, sizeof(short_buf));
  expect(pl.ok() && ps.ok(), "AC-1 both messages pack");
  expect(pl.offset == 17 && ps.offset == 13, "AC-1 the sent lengths are 17 and 13");
  expect(ecc_percent::ref_count(25, 13) == 4 && ecc_percent::ref_count(25, 10) == 3,
         "AC-1 the reference counts are 4 and 3");

  Optional back_long;
  Optional back_short;
  auto rl = packbin::unpack_repair(optional_scheme, long_buf, pl.offset, back_long, 0);
  auto rs = packbin::unpack_repair(optional_scheme, short_buf, ps.offset, back_short, 0);
  expect(rl.ok() && rl.repaired == 0 && rs.ok() && rs.repaired == 0, "AC-1 both unpack intact");
  expect(back_long.id == with.id && back_long.a.has && back_long.a.value == 0x0a0b &&
             back_long.b.has && back_long.b.value == 0x0c,
         "AC-1 the message with the field gives it back");
  expect(back_short.id == with.id && !back_short.a.has && !back_short.b.has,
         "AC-1 the message without the field has none");
}

// A string, or in a build without the compact text a bytes field of the same size.
#ifdef PACKBIN_NO_TEXT
struct Named {
  std::uint8_t text[13] = {};
};
constexpr auto named_scheme = packbin::parity_percent(
    packbin::scheme<Named>(6, packbin::bytes<&Named::text>(0)), 25);
#else
struct Named {
  packbin::Text<16> text;
};
constexpr auto named_scheme = packbin::parity_percent(
    packbin::scheme<Named>(6, packbin::utf8<&Named::text>(0)), 25);
#endif

constexpr char kWord[] = "hello packbin";

Named make_named() {
  Named row;
#ifdef PACKBIN_NO_TEXT
  std::memcpy(row.text, kWord, sizeof(row.text));
#else
  row.text.len = sizeof(kWord) - 1;
  std::memcpy(row.text.data, kWord, row.text.len);
#endif
  return row;
}

bool same_word(Named const& row) {
#ifdef PACKBIN_NO_TEXT
  return std::memcmp(row.text, kWord, sizeof(row.text)) == 0;
#else
  return row.text.len == sizeof(kWord) - 1 && std::memcmp(row.text.data, kWord, row.text.len) == 0;
#endif
}

// AC-2: one wrong byte anywhere in the message, repaired with limit 1, gives the original text.
void text_after_repair() {
  Named row = make_named();
  std::uint8_t buf[64];
  packbin::Scratch<16> scratch;
  auto packed = packbin::pack(named_scheme, row, buf, sizeof(buf), scratch);
  expect(packed.ok() && packed.offset > 4, "AC-2 the protected message packs");
  Bytes sent(buf, buf + packed.offset);

  int failures = 0;
  for (std::size_t at = 0; at < sent.size(); ++at) {
    Bytes bad = sent;
    bad[at] = static_cast<std::uint8_t>(bad[at] ^ 0x5a);
    Named back;
    auto r = packbin::unpack_repair(named_scheme, bad.data(), bad.size(), back, 1);
    if (!r.ok() || r.repaired != 1 || !same_word(back))
      ++failures;
  }
  expect(failures == 0, "AC-2 one wrong byte anywhere is repaired and the text is the original");
}

// AC-3: a handler of 25 percent with a handler of count 25 is refused, and 256 + 25 tells which
// setting is the percentage.
void mix_names_the_percentage() {
  constexpr auto percent = packbin::parity_percent(msg_scheme<0x40>(), 25);
  constexpr auto count = packbin::parity(msg_scheme<0x41>(), 25);
  Msg a;
  Msg b;
  int ran = 0;
  auto seen = [&](Msg const&) { ++ran; };
  std::uint8_t data[8] = {0x40, 0, 0, 0, 0, 0, 0, 0};

  auto percent_first =
      packbin::unpack(data, sizeof(data), packbin::on(percent, a, seen), packbin::on(count, b, seen));
  auto count_first =
      packbin::unpack(data, sizeof(data), packbin::on(count, a, seen), packbin::on(percent, b, seen));

  expect(percent_first.error == Error::SchemeInvalid &&
             percent_first.offset == static_cast<std::size_t>(pd::kPercentBase + 25) &&
             percent_first.offset == 281 && percent_first.needed == 25 && ran == 0,
         "AC-3 percentage first: offset 281 (256 + 25), needed 25");
  expect(count_first.error == Error::SchemeInvalid && count_first.offset == 25 &&
             count_first.needed == 281 && ran == 0,
         "AC-3 count first: offset 25, needed 281 (256 + 25)");
}

}  // namespace

int run_core_ecc_percent_fields_host_tests() {
  optional_field();
  text_after_repair();
  mix_names_the_percentage();
  return check::failures();
}
