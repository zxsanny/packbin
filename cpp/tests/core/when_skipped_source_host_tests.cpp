// AZ-2816: a `when` whose source field sits inside a `when` that does not hold is false, on pack
// and on unpack, as in the other packages (the source is not written, so it is absent). Before the
// change the core matched the source's value in the row and wrote a body its own unpack refused
// (`TrailingBytes`), and on unpack an unread source read as 0 and matched `when(k == 0)`.
// Reference bytes: the Python package on 2026-10-21. Host-only.

#include "packbin/packbin.hpp"

#include "check.hpp"
#include "member_cases.hpp"

#include <cstddef>
#include <cstdint>

#pragma GCC diagnostic ignored "-Warray-bounds"

using member_cases::round_trip;
using member_cases::same_opt;
using member_cases::unpack_only;
using packbin::Opt;
namespace pb = packbin;

namespace {

struct Row {
  Opt<std::uint8_t> mode;
  Opt<std::uint16_t> a;
  Opt<std::uint8_t> k;
  Opt<std::uint8_t> b;

  bool same_as(Row const& o) const {
    return same_opt(mode, o.mode) && same_opt(a, o.a) && same_opt(k, o.k) && same_opt(b, o.b);
  }
};

Row row(int mode, int a, int k, int b) {
  Row r;
  r.mode = static_cast<std::uint8_t>(mode);
  if (a >= 0)
    r.a = static_cast<std::uint16_t>(a);
  if (k >= 0)
    r.k = static_cast<std::uint8_t>(k);
  if (b >= 0)
    r.b = static_cast<std::uint8_t>(b);
  return r;
}

// u8 mode; when(mode == 1) { u16 a; u8 k }; when(k == value) { u8 b }
auto source_in_when(int value) {
  return pb::scheme<Row>(1, pb::u8<&Row::mode>(0),
                         pb::when(1, pb::eq(0, 1), pb::u16<&Row::a>(1), pb::u8<&Row::k>(2)),
                         pb::when(3, pb::eq(2, value), pb::u8<&Row::b>(3)));
}

// The row packs to the bytes and the bytes unpack to `want` (the fields a skipped when never reads
// stay unset).
template <typename S, typename R>
void packs_and_unpacks(S const& s, R const& in, char const* hex, R const& want, char const* name) {
  std::uint8_t buf[32];
  auto p = pb::pack(s, in, buf, sizeof(buf));
  check::expect(p.ok() && check::same_hex(buf, p.offset, hex), member_cases::say(name, "pack bytes").c_str());
  unpack_only(s, hex, want, name);
}

void ac1_skipped_source_value_not_equal() {
  packs_and_unpacks(source_in_when(2), row(0, 7, 2, 5), "0100", row(0, -1, -1, -1),
                    "AC-1 k==2, source skipped, row holds k=2");
}

void ac2_skipped_source_value_zero() {
  packs_and_unpacks(source_in_when(0), row(0, 7, 0, 5), "0100", row(0, -1, -1, -1),
                    "AC-2 k==0, source skipped, row holds k=0");
}

void ac3_held_source() {
  round_trip(source_in_when(2), row(1, 7, 2, 5), "010107000205", "AC-3 k==2, source written");
  round_trip(source_in_when(0), row(1, 7, 0, 5), "010107000005", "AC-3 k==0, source written");
  packs_and_unpacks(source_in_when(2), row(1, 7, 3, 5), "0101070003", row(1, 7, 3, -1),
                    "AC-3 k==2, source written with k=3, consumer false");
}

struct Nested {
  Opt<std::uint8_t> m0;
  Opt<std::uint8_t> m1;
  Opt<std::uint8_t> k;
  Opt<std::uint8_t> b;

  bool same_as(Nested const& o) const {
    return same_opt(m0, o.m0) && same_opt(m1, o.m1) && same_opt(k, o.k) && same_opt(b, o.b);
  }
};

Nested nested(int m0, int m1, int k, int b) {
  Nested n;
  n.m0 = static_cast<std::uint8_t>(m0);
  if (m1 >= 0)
    n.m1 = static_cast<std::uint8_t>(m1);
  if (k >= 0)
    n.k = static_cast<std::uint8_t>(k);
  if (b >= 0)
    n.b = static_cast<std::uint8_t>(b);
  return n;
}

// u8 m0; when(m0 == 1) { u8 m1; when(m1 == 1) { u8 k } }; when(k == 2) { u8 b }
auto source_two_whens_deep() {
  return pb::scheme<Nested>(
      1, pb::u8<&Nested::m0>(0),
      pb::when(1, pb::eq(0, 1), pb::u8<&Nested::m1>(1),
               pb::when(2, pb::eq(1, 1), pb::u8<&Nested::k>(2))),
      pb::when(3, pb::eq(2, 2), pb::u8<&Nested::b>(3)));
}

void ac4_nested_skip() {
  auto s = source_two_whens_deep();
  packs_and_unpacks(s, nested(0, 1, 2, 5), "0100", nested(0, -1, -1, -1), "AC-4 outer when false");
  packs_and_unpacks(s, nested(1, 0, 2, 5), "010100", nested(1, 0, -1, -1), "AC-4 inner when false");
  packs_and_unpacks(s, nested(1, 1, 2, 5), "0101010205", nested(1, 1, 2, 5), "AC-4 both hold, k=2");
  packs_and_unpacks(s, nested(1, 1, 3, 5), "01010103", nested(1, 1, 3, -1), "AC-4 both hold, k=3");
}

struct Held {
  Opt<std::uint8_t> mode;
  Opt<std::uint8_t> k;
  Opt<std::uint8_t> b;

  bool same_as(Held const& o) const { return same_opt(mode, o.mode) && same_opt(k, o.k) && same_opt(b, o.b); }
};

Held held(int mode, int k, int b) {
  Held h;
  h.mode = static_cast<std::uint8_t>(mode);
  if (k >= 0)
    h.k = static_cast<std::uint8_t>(k);
  if (b >= 0)
    h.b = static_cast<std::uint8_t>(b);
  return h;
}

// u8 mode; when(mode == 1) { u8 k; when(k == 2) { u8 b } }: the one `when` holds the source and the consumer.
auto both_in_one_when() {
  return pb::scheme<Held>(1, pb::u8<&Held::mode>(0),
                          pb::when(1, pb::eq(0, 1), pb::u8<&Held::k>(1),
                                   pb::when(2, pb::eq(1, 2), pb::u8<&Held::b>(2))));
}

void ac5_one_when_holds_both() {
  auto s = both_in_one_when();
  round_trip(s, held(1, 2, 5), "01010205", "AC-5 k=2, consumer written");
  packs_and_unpacks(s, held(1, 3, 5), "010103", held(1, 3, -1), "AC-5 k=3, consumer false");
  packs_and_unpacks(s, held(0, 2, 5), "0100", held(0, -1, -1), "AC-5 outer false");
}

// AC-2 with plain members: an unread source holds 0 in the row, which must not match `when(k == 0)`.
struct Plain {
  std::uint8_t mode = 0;
  std::uint16_t a = 0;
  std::uint8_t k = 0;
  std::uint8_t b = 0;

  bool same_as(Plain const& o) const { return mode == o.mode && a == o.a && k == o.k && b == o.b; }
};

auto plain_source_in_when(int value) {
  return pb::scheme<Plain>(1, pb::u8<&Plain::mode>(0),
                           pb::when(1, pb::eq(0, 1), pb::u16<&Plain::a>(1), pb::u8<&Plain::k>(2)),
                           pb::when(3, pb::eq(2, value), pb::u8<&Plain::b>(3)));
}

void ac2_plain_members_unread_source_is_not_zero() {
  Plain in;
  in.mode = 0;
  in.a = 7;
  in.k = 0;
  in.b = 5;
  Plain want;
  packs_and_unpacks(plain_source_in_when(0), in, "0100", want, "AC-2 plain members, k==0, source skipped");
  in.k = 2;
  packs_and_unpacks(plain_source_in_when(2), in, "0100", want, "AC-1 plain members, k==2, source skipped");
  Plain on;
  on.mode = 1;
  on.a = 7;
  on.k = 0;
  on.b = 5;
  packs_and_unpacks(plain_source_in_when(0), on, "010107000005", on, "AC-3 plain members, k==0, source written");
}

// AC-6 (AZ-2823): a `when` source holds a link back to the `when` that holds it, as a count does,
// and the link is at most 255 entries long; a longer one is refused when the scheme is checked.
template <std::size_t... Is>
auto source_behind_fillers(std::index_sequence<Is...>) {
  constexpr int fillers = static_cast<int>(sizeof...(Is));
  return pb::scheme<Held>(
      1, pb::u8<&Held::mode>(0),
      pb::when(1, pb::eq(0, 1), pb::u8(1 + static_cast<int>(Is))..., pb::u8<&Held::k>(1 + fillers)),
      pb::when(2 + fillers, pb::eq(1 + fillers, 2), pb::u8<&Held::b>(2 + fillers)));
}

void ac6_source_link_is_limited_to_255_entries() {
  check::expect(pb::validate(source_behind_fillers(std::make_index_sequence<254>())).ok(),
                "AC-6 source 255 entries behind its when builds");
  check::expect(!pb::validate(source_behind_fillers(std::make_index_sequence<255>())).ok(),
                "AC-6 source 256 entries behind its when is refused");
  check::expect(!pb::validate(source_behind_fillers(std::make_index_sequence<300>())).ok(),
                "AC-6 source 301 entries behind its when is refused");
}

}  // namespace

int run_core_when_skipped_source_host_tests() {
  ac1_skipped_source_value_not_equal();
  ac2_skipped_source_value_zero();
  ac2_plain_members_unread_source_is_not_zero();
  ac3_held_source();
  ac4_nested_skip();
  ac5_one_when_holds_both();
  ac6_source_link_is_limited_to_255_entries();
  return check::failures();
}
