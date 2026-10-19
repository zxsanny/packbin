// AZ-2431 (U19, security F36): a `when` whose `eq` names a source id no field can have (negative,
// or above the int16 range of an id, which the table would wrap to a negative one) is
// SchemeInvalid at the `when`'s own id: at the top level, in a group and in a `times` or `repeat`
// round body. Before, it built, never held, dropped its members on pack, and the packet then
// failed to unpack.
//
// G2: the AZ-2416 empty-body rule (`has_member` in `check_shape`, order.hpp) pinned on its own,
// not through that spelling. `check_table` runs `check_shape` (the body rule) before `resolve`
// (the scope rule), so a round whose only `when` names a field outside the round reaches the body
// rule first. A round's id is the id of its first child, so the body rule and the scope rule
// refuse at the same id; only a direct call of `check_shape` or `has_member` tells which rule
// fired, and these tests make one. A round whose only member is a `when` cannot build in C++: the
// `when` needs a source in the round before it, and that source is itself a member. Host-only.

#include "packbin/packbin.hpp"

#include "check.hpp"

#include <array>
#include <cstddef>
#include <cstdint>

using packbin::Array;
using packbin::Opt;
namespace pb = packbin;

namespace {

struct Item {
  Opt<std::uint8_t> pt;
};

struct Row {
  std::uint8_t n = 0;
  Opt<std::uint8_t> c;
  Array<Item, 4> rounds;
};

bool refused_at(pb::Result v, int field) {
  return v.error == pb::Error::SchemeInvalid && v.field == field;
}

// --- AC-1: a source id no field can have -----------------------------------------------------

void u19_negative_eq_source_is_refused_at_the_when() {
  // Arrange
  auto top = pb::scheme<Row>(1, pb::u8<&Row::n>(0),
                             pb::when(1, pb::eq(-1, 1), pb::u8<&Row::c>(1)));
  auto in_group = pb::scheme<Row>(
      1, pb::u8<&Row::n>(0), pb::group(1, pb::u8<&Row::c>(1), pb::when(2, pb::eq(-1, 1), pb::u8(2))));
  auto in_times = pb::scheme<Row>(
      1, pb::u8<&Row::n>(0),
      pb::times<&Row::rounds>(1, 0, pb::u8<&Item::pt>(1), pb::when(2, pb::eq(-1, 1), pb::u8(2))));
  auto in_repeat = pb::scheme<Row>(
      1, pb::repeat<&Row::rounds>(0, pb::u8<&Item::pt>(0), pb::when(1, pb::eq(-1, 1), pb::u8(1))));

  // Act / Assert
  check::expect(refused_at(pb::validate(top), 1), "U19 AC-1 eq(-1) at the top level");
  check::expect(refused_at(pb::validate(in_group), 2), "U19 AC-1 eq(-1) in a group");
  check::expect(refused_at(pb::validate(in_times), 2), "U19 AC-1 eq(-1) in a times round body");
  check::expect(refused_at(pb::validate(in_repeat), 1), "U19 AC-1 eq(-1) in a repeat round body");
}

void u19_any_id_out_of_range_is_refused() {
  // Arrange
  auto minus_seven = pb::scheme<Row>(1, pb::u8<&Row::n>(0),
                                     pb::when(1, pb::eq(-7, 1), pb::u8<&Row::c>(1)));
  auto wraps_to_minus_one = pb::scheme<Row>(1, pb::u8<&Row::n>(0),
                                            pb::when(1, pb::eq(65535, 1), pb::u8<&Row::c>(1)));
  auto above_int16 = pb::scheme<Row>(1, pb::u8<&Row::n>(0),
                                     pb::when(1, pb::eq(32768, 1), pb::u8<&Row::c>(1)));
  auto empty_body = pb::scheme<Row>(1, pb::u8<&Row::n>(0), pb::when(1, pb::eq(-1, 1)));

  // Act / Assert
  check::expect(refused_at(pb::validate(minus_seven), 1), "U19 AC-1 eq(-7)");
  check::expect(refused_at(pb::validate(wraps_to_minus_one), 1), "U19 AC-1 eq(65535)");
  check::expect(refused_at(pb::validate(above_int16), 1), "U19 AC-1 eq(32768)");
  check::expect(refused_at(pb::validate(empty_body), 1), "U19 AC-1 eq(-1) with no child");
}

void u19_pack_and_unpack_refuse_the_scheme() {
  // Arrange
  auto s = pb::scheme<Row>(1, pb::u8<&Row::n>(0), pb::when(1, pb::eq(-1, 1), pb::u8<&Row::c>(1)));
  Row row;
  row.n = 1;
  row.c = 5;
  std::uint8_t buf[8];
  std::uint8_t const packet[] = {0x01, 0x01};
  Row back;

  // Act
  auto p = pb::pack(s, row, buf, sizeof(buf));
  auto u = pb::unpack(s, packet, sizeof(packet), back);

  // Assert: at HEAD (b8b2809) pack wrote 0101 with c dropped.
  check::expect(refused_at(p, 1), "U19 AC-1 pack refuses at the when");
  check::expect(refused_at(u, 1), "U19 AC-1 unpack refuses at the when");
}

// --- AC-3: the empty-body rule on its own ------------------------------------------------------

// The body rule alone: `check_shape` on the round's own table, which runs no scope rule. -1 when
// it passes, else the id it refused at.
template <typename Node>
int shape_refused_at(Node const& round) {
  pb::detail::Check c{};
  pb::detail::check_shape(round.f.data(), 0, Node::size, false, c);
  return c.failed ? c.field : -1;
}

template <typename Node>
bool body_has_member(Node const& round) {
  return pb::detail::has_member(round.f.data(), 1, Node::size);
}

// The body rule refuses `body` as a times and as a repeat body (directly, at the round id 1, with
// has_member false), and the public scheme is refused at the same id.
template <typename Body>
bool body_rule_refuses(Body const& body) {
  auto t = pb::times(1, 0, body);
  auto r = pb::repeat(1, body);
  auto st = pb::scheme<Row>(1, pb::u8<&Row::n>(0), t);
  auto sr = pb::scheme<Row>(1, pb::u8<&Row::n>(0), r);
  return !body_has_member(t) && !body_has_member(r) && shape_refused_at(t) == 1 &&
         shape_refused_at(r) == 1 && refused_at(pb::validate(st), 1) &&
         refused_at(pb::validate(sr), 1);
}

// The body rule passes `body` as a times and as a repeat body (has_member true).
template <typename Body>
bool body_rule_passes(Body const& body) {
  auto t = pb::times(1, 0, body);
  auto r = pb::repeat(1, body);
  return body_has_member(t) && body_has_member(r) && shape_refused_at(t) == -1 &&
         shape_refused_at(r) == -1;
}

template <typename Body>
bool round_builds(Body const& body) {
  auto t = pb::scheme<Row>(1, pb::u8<&Row::n>(0), pb::times(1, 0, body));
  auto r = pb::scheme<Row>(1, pb::u8<&Row::n>(0), pb::repeat(1, body));
  return pb::validate(t).ok() && pb::validate(r).ok();
}

void g2_empty_shapes_are_refused_by_the_body_rule() {
  // Arrange: each `when` names `n` (id 0), a valid id outside the round.
  auto empty_when = pb::when(1, pb::eq(0, 1));
  auto when_of_empty_when = pb::when(1, pb::eq(0, 1), pb::when(1, pb::eq(0, 2)));
  auto empty_group = pb::group(1);
  auto group_of_empty_when = pb::group(1, pb::when(1, pb::eq(0, 1)));
  auto group_of_group = pb::group(1, pb::group(1, pb::when(1, pb::eq(0, 1))));

  // Act / Assert
  check::expect(body_rule_refuses(empty_when), "AZ-2431 AC-3 empty when");
  check::expect(body_rule_refuses(when_of_empty_when), "AZ-2431 AC-3 when of an empty when");
  check::expect(body_rule_refuses(empty_group), "AZ-2431 AC-3 empty group");
  check::expect(body_rule_refuses(group_of_empty_when), "AZ-2431 AC-3 group of an empty when");
  check::expect(body_rule_refuses(group_of_group), "AZ-2431 AC-3 group of a group of an empty when");
}

void g2_member_shapes_pass_the_body_rule() {
  // Arrange
  auto zero_width = pb::bytes(1, 0);
  auto fbyte = pb::flag_byte(0);
  auto memberless_flags = pb::flags(1);
  auto when_with_u8 = pb::when(1, pb::eq(0, 1), pb::u8(1));
  auto when_of_when_with_u8 = pb::when(1, pb::eq(0, 1), pb::when(1, pb::eq(0, 2), pb::u8(1)));
  auto group_of_when_with_bytes = pb::group(1, pb::when(1, pb::eq(0, 1), pb::bytes(1, 0)));

  // Act / Assert: the body rule passes all six.
  check::expect(body_rule_passes(zero_width), "AZ-2431 AC-3 zero-width bytes: body rule");
  check::expect(body_rule_passes(fbyte), "AZ-2431 AC-3 flag byte: body rule");
  check::expect(body_rule_passes(memberless_flags), "AZ-2431 AC-3 member-less flags: body rule");
  check::expect(body_rule_passes(when_with_u8), "AZ-2431 AC-3 when with a u8: body rule");
  check::expect(body_rule_passes(when_of_when_with_u8),
                "AZ-2431 AC-3 when of a when with a u8: body rule");
  check::expect(body_rule_passes(group_of_when_with_bytes),
                "AZ-2431 AC-3 group of a when with a zero-width bytes: body rule");
  // The three without a `when` build; a group with a u8 does too.
  check::expect(round_builds(zero_width), "AZ-2431 AC-3 zero-width bytes builds");
  check::expect(round_builds(fbyte), "AZ-2431 AC-3 flag byte builds");
  check::expect(round_builds(memberless_flags), "AZ-2431 AC-3 member-less flags builds");
  check::expect(round_builds(pb::group(1, pb::u8(1))), "AZ-2431 AC-3 group with a u8 builds");
  // A `when` holding a member passes the body rule, so the refusal of the whole scheme at the
  // when (id 1) comes from the scope rule: its source `n` is outside the round.
  auto t = pb::scheme<Row>(1, pb::u8<&Row::n>(0), pb::times(1, 0, when_with_u8));
  check::expect(refused_at(pb::validate(t), 1), "AZ-2431 AC-3 when with a u8: scope rule");
}

// Index of the first times or repeat in a table.
template <std::size_t N>
std::size_t round_at(pb::detail::FixedArray<pb::Field, N> const& t) {
  for (std::size_t i = 0; i < N; ++i)
    if (t[i].kind == pb::Kind::Times || t[i].kind == pb::Kind::Repeat)
      return i;
  return N;
}

// The scheme is refused at `id`, and the body rule alone refuses its table at the same id with
// no member in the round.
template <typename S>
bool vector_reaches_the_body_rule(S const& s, int id) {
  pb::detail::Check c{};
  pb::detail::check_shape(s.fields.data(), 0, s.fields.size(), false, c);
  std::size_t at = round_at(s.fields);
  bool empty = at < s.fields.size() &&
               !pb::detail::has_member(s.fields.data(), at + 1, at + s.fields[at].span);
  return refused_at(pb::validate(s), id) && c.failed && c.field == id && empty;
}

struct Plain {
  std::uint8_t a = 0;
};

// The three `construct_empty_*when*` hostile vectors, spelled as in fixtures/hostile/README.md
// (the `when` names `mode`, id 0, outside the round): in C++ the body rule refuses them.
void g2_hostile_empty_when_vectors_reach_the_body_rule() {
  // Arrange
  auto times = pb::scheme<Plain>(1, pb::u8(0), pb::u8(1),
                                 pb::times(2, 1, pb::when(2, pb::eq(0, 1))));
  auto repeat = pb::scheme<Plain>(1, pb::u8(0), pb::repeat(1, pb::when(1, pb::eq(0, 1))));
  auto nested = pb::scheme<Plain>(
      1, pb::u8(0), pb::u8(1),
      pb::times(2, 1, pb::when(2, pb::eq(0, 1), pb::when(2, pb::eq(0, 1)))));

  // Act / Assert
  check::expect(vector_reaches_the_body_rule(times, 2), "AZ-2416 construct_empty_when_times_body");
  check::expect(vector_reaches_the_body_rule(repeat, 1), "AZ-2416 construct_empty_when_repeat_body");
  check::expect(vector_reaches_the_body_rule(nested, 2), "AZ-2416 construct_empty_nested_when_body");
}

}  // namespace

int run_core_empty_body_rule_host_tests() {
  u19_negative_eq_source_is_refused_at_the_when();
  u19_any_id_out_of_range_is_refused();
  u19_pack_and_unpack_refuse_the_scheme();
  g2_empty_shapes_are_refused_by_the_body_rule();
  g2_member_shapes_pass_the_body_rule();
  g2_hostile_empty_when_vectors_reach_the_body_rule();
  return check::failures();
}
