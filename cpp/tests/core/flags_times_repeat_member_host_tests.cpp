// AZ-2120 AC-4, AC-5 and AZ-2128: a `times` or `repeat` that is a member of `flags` (or sits in
// a group or a flag bit under it) is written like any other value: its bit is on exactly when a
// round is written. The hex strings are the bytes the C# package gives for the same schemes and
// rows (loop 18 reference table). The rounds are an Array of structs, so each round holds one
// entry per body value. Host-only.

#include "packbin/packbin.hpp"

#include "check.hpp"
#include "member_cases.hpp"

#include <cstdint>

using member_cases::pack_refused;
using member_cases::round_trip;
using member_cases::same_opt;
using member_cases::unpack_only;
using packbin::Array;
using packbin::Opt;
namespace pb = packbin;

namespace {

struct Item {
  Opt<std::uint8_t> pt;
  Opt<std::uint8_t> pu;
};

struct T {
  std::uint8_t n = 0;
  Array<Item, 4> rounds;
  Opt<std::uint16_t> heading;

  bool same_as(T const& o) const {
    if (n != o.n || rounds.count != o.rounds.count || !same_opt(heading, o.heading))
      return false;
    for (std::size_t i = 0; i < rounds.count; ++i) {
      if (!same_opt(rounds.items[i].pt, o.rounds.items[i].pt) ||
          !same_opt(rounds.items[i].pu, o.rounds.items[i].pu))
        return false;
    }
    return true;
  }
};

// pt (and pu when `pu` is not -1) per round; heading -1 leaves it unset.
T trow(int n, int pt0, int pt1, int heading, int pu0 = -1, int pu1 = -1) {
  T t;
  t.n = static_cast<std::uint8_t>(n);
  int pts[2] = {pt0, pt1};
  int pus[2] = {pu0, pu1};
  for (int i = 0; i < 2; ++i) {
    if (pts[i] < 0 && pus[i] < 0)
      continue;
    if (pts[i] >= 0)
      t.rounds.items[i].pt = static_cast<std::uint8_t>(pts[i]);
    if (pus[i] >= 0)
      t.rounds.items[i].pu = static_cast<std::uint8_t>(pus[i]);
    t.rounds.count = static_cast<std::uint16_t>(i + 1);
  }
  if (heading >= 0)
    t.heading = static_cast<std::uint16_t>(heading);
  return t;
}

constexpr int kNone = -1;

// TA: u8 n; flags { times(n) { u8 pt }, u16 heading }.
auto ta() {
  return pb::scheme<T>(1, pb::u8<&T::n>(0),
                       pb::flags(1, pb::times<&T::rounds>(1, 0, pb::u8<&Item::pt>(1)),
                                 pb::u16<&T::heading>(2)));
}

// TS: the split form, a flag byte with a bit for the `times` and a bit for `heading`.
auto ts() {
  return pb::scheme<T>(1, pb::u8<&T::n>(0), pb::flag_byte(0),
                       pb::flag_bit(0, pb::times<&T::rounds>(1, 0, pb::u8<&Item::pt>(1))),
                       pb::flag_bit(0, pb::u16<&T::heading>(2)));
}

// TG: flags { group { times(n) { u8 pt } }, u16 heading }.
auto tg() {
  return pb::scheme<T>(
      1, pb::u8<&T::n>(0),
      pb::flags(1, pb::group(1, pb::times<&T::rounds>(1, 0, pb::u8<&Item::pt>(1))),
                pb::u16<&T::heading>(2)));
}

template <typename S>
void times_cases(S const& s, char const* shape) {
  char name[96];
  auto label = [&](char const* what) {
    std::snprintf(name, sizeof(name), "AC-4 %s %s", shape, what);
    return name;
  };
  round_trip(s, trow(0, kNone, kNone, 90), "0100025a00", label("0 rounds"));
  round_trip(s, trow(1, 5, kNone, 90), "010103055a00", label("1 round"));
  round_trip(s, trow(2, 5, 6, 90), "01020305065a00", label("2 rounds"));
  round_trip(s, trow(2, 5, 6, kNone), "0102010506", label("only the times"));
  round_trip(s, trow(0, kNone, kNone, kNone), "010000", label("only n"));
  unpack_only(s, "0100025a00", trow(0, kNone, kNone, 90), label("old packet"));
  unpack_only(s, "01020305065a00", trow(2, 5, 6, 90), label("new packet"));
  pack_refused(s, trow(2, 5, kNone, 90), 1, label("list too short"));
  pack_refused(s, trow(1, kNone, kNone, 90), 1, label("values missing"));
  pack_refused(s, trow(0, 5, kNone, 90), 1, label("count 0, values given"));
  T surplus = trow(1, 5, 6, 90);
  pack_refused(s, surplus, 1, label("list too long"));
}

void times_member_of_flags() { times_cases(ta(), "flags"); }
void times_in_a_flag_bit() { times_cases(ts(), "flag bit"); }
void times_in_a_group() { times_cases(tg(), "group"); }

// T2: the round holds two values.
auto t2() {
  return pb::scheme<T>(
      1, pb::u8<&T::n>(0),
      pb::flags(1,
                pb::times<&T::rounds>(1, 0, pb::u8<&Item::pt>(1), pb::u8<&Item::pu>(2)),
                pb::u16<&T::heading>(3)));
}

void times_with_two_values() {
  auto s = t2();
  pack_refused(s, trow(1, 5, kNone, 90), 2, "AC-4 T-two-values-missing");
  round_trip(s, trow(1, 5, kNone, 90, 6), "01010305065a00", "AC-4 T-two-values-1");
  round_trip(s, trow(2, 5, 6, 90, 7, 8), "010203050706085a00", "AC-4 T-two-values-2");
}

// The count is a flags member itself: a count that was skipped is no round, and no error.
struct Counted {
  Opt<std::uint8_t> n;
  Array<Item, 4> rounds;

  bool same_as(Counted const& o) const {
    if (!same_opt(n, o.n) || rounds.count != o.rounds.count)
      return false;
    for (std::size_t i = 0; i < rounds.count; ++i) {
      if (!same_opt(rounds.items[i].pt, o.rounds.items[i].pt))
        return false;
    }
    return true;
  }
};

constexpr auto skipped_count_scheme() {
  return pb::scheme<Counted>(
      1, pb::flags(0, pb::u8<&Counted::n>(0),
                   pb::times<&Counted::rounds>(1, 0, pb::u8<&Item::pt>(1))));
}

void times_with_a_skipped_count() {
  constexpr auto s = skipped_count_scheme();
  Counted c;
  c.rounds.count = 1;
  c.rounds.items[0].pt = 5;
  std::uint8_t buf[16];
  auto p = pb::pack(s, c, buf, sizeof(buf));
  check::expect(p.ok() && check::same_hex(buf, p.offset, "0100"),
                "AC-4 times with a skipped count: both bits clear");
  Counted full;
  full.n = 1;
  full.rounds.count = 1;
  full.rounds.items[0].pt = 5;
  round_trip(s, full, "01030105", "AC-4 times with its count in the same flags");
}

// An Array count above its capacity is refused whatever the times count is; nothing is walked.
void times_with_a_hostile_array_count() {
  auto s = ta();
  T hostile = trow(0, kNone, kNone, 90);
  hostile.rounds.count = 60000;
  pack_refused(s, hostile, 1, "AC-4 hostile Array count, count 0");
  hostile.n = 2;
  pack_refused(s, hostile, 1, "AC-4 hostile Array count, count 2");
}

struct R {
  Opt<std::uint8_t> mode;
  Opt<std::uint16_t> heading;
  Array<Item, 4> rounds;

  bool same_as(R const& o) const {
    if (!same_opt(mode, o.mode) || !same_opt(heading, o.heading) || rounds.count != o.rounds.count)
      return false;
    for (std::size_t i = 0; i < rounds.count; ++i) {
      if (!same_opt(rounds.items[i].pt, o.rounds.items[i].pt) ||
          !same_opt(rounds.items[i].pu, o.rounds.items[i].pu))
        return false;
    }
    return true;
  }
};

R rrow(int mode, int heading, int pt0 = -1, int pt1 = -1, int pu0 = -1, int pu1 = -1) {
  R r;
  r.mode = static_cast<std::uint8_t>(mode);
  if (heading >= 0)
    r.heading = static_cast<std::uint16_t>(heading);
  int pts[2] = {pt0, pt1};
  int pus[2] = {pu0, pu1};
  for (int i = 0; i < 2; ++i) {
    if (pts[i] < 0 && pus[i] < 0)
      continue;
    if (pts[i] >= 0)
      r.rounds.items[i].pt = static_cast<std::uint8_t>(pts[i]);
    if (pus[i] >= 0)
      r.rounds.items[i].pu = static_cast<std::uint8_t>(pus[i]);
    r.rounds.count = static_cast<std::uint16_t>(i + 1);
  }
  return r;
}

// RA: u8 mode; flags { u16 heading, repeat { u8 pt } }. The repeat reads to the end.
auto ra() {
  return pb::scheme<R>(1, pb::u8<&R::mode>(0),
                       pb::flags(1, pb::u16<&R::heading>(1),
                                 pb::repeat<&R::rounds>(2, pb::u8<&Item::pt>(2))));
}

void repeat_member_of_flags() {
  auto s = ra();
  round_trip(s, rrow(1, 90), "0101015a00", "AC-4 R-0-rounds");
  round_trip(s, rrow(1, 90, 5), "0101035a0005", "AC-4 R-1-round");
  round_trip(s, rrow(1, 90, 5, 6), "0101035a000506", "AC-4 R-2-rounds");
  round_trip(s, rrow(1, kNone, 5, 6), "0101020506", "AC-4 R-only-repeat");
  round_trip(s, rrow(1, kNone), "010100", "AC-4 R-only-mode");
  unpack_only(s, "0101015a00", rrow(1, 90), "AC-5 R-old-packet");
  unpack_only(s, "0101035a000506", rrow(1, 90, 5, 6), "AC-5 R-new-packet");
}

// R2: the round holds two values.
auto r2() {
  return pb::scheme<R>(
      1, pb::u8<&R::mode>(0),
      pb::flags(1, pb::u16<&R::heading>(1),
                pb::repeat<&R::rounds>(2, pb::u8<&Item::pt>(2), pb::u8<&Item::pu>(3))));
}

void repeat_with_two_values() {
  auto s = r2();
  pack_refused(s, rrow(1, 90, 5), 3, "AC-4 R-missing-body-value");
  round_trip(s, rrow(1, 90, 5, kNone, 6), "0101035a000506", "AC-4 R-two-values-1");
  round_trip(s, rrow(1, 90, 5, 6, 7, 8), "0101035a0005070608", "AC-4 R-two-values-2");
  unpack_only(s, "0101035a0005060708", rrow(1, 90, 5, 7, 6, 8), "AC-5 R-two-values-unpack");
}

}  // namespace

int run_core_flags_times_repeat_member_host_tests() {
  times_member_of_flags();
  times_in_a_flag_bit();
  times_in_a_group();
  times_with_two_values();
  times_with_a_skipped_count();
  times_with_a_hostile_array_count();
  repeat_member_of_flags();
  repeat_with_two_values();
  return check::failures();
}
