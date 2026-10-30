#include "all_kinds.hpp"
#include "all_kinds_internal.hpp"

#include <cstring>

namespace all_kinds {

namespace {

namespace pb = packbin;

constexpr auto round_chain_scheme = pb::scheme<RoundChainRow>(
    0x5d, pb::u8<&RoundChainRow::n>(0),
    pb::times<&RoundChainRow::items>(
        1, 0, pb::u8<&RoundItem::m>(1),
        pb::when(2, pb::eq(1, 1), pb::u8<&RoundItem::k1>(2),
                 pb::when(3, pb::eq(2, 1), pb::u8<&RoundItem::k2>(3),
                          pb::when(4, pb::eq(3, 1), pb::u8<&RoundItem::k3>(4),
                                   pb::when(5, pb::eq(4, 1), pb::u8<&RoundItem::b>(5)))))));

static_assert(pb::validate(round_chain_scheme).ok(), "round chain scheme is valid");

constexpr auto flag_round_chain_scheme = pb::scheme<FlagRoundChainRow>(
    0x5e, pb::u8<&FlagRoundChainRow::n>(0),
    pb::times<&FlagRoundChainRow::items>(
        1, 0, pb::u8<&FlagRoundItem::m>(1),
        pb::when(
            2, pb::eq(1, 1), pb::flag_byte(0), pb::flag_bit(0, pb::u8<&FlagRoundItem::d1>(2)),
            pb::u8<&FlagRoundItem::k1>(3),
            pb::when(4, pb::eq(3, 1), pb::flag_byte(0),
                     pb::flag_bit(0, pb::u8<&FlagRoundItem::d2>(4)), pb::u8<&FlagRoundItem::k2>(5),
                     pb::when(6, pb::eq(5, 1), pb::flag_byte(0),
                              pb::flag_bit(0, pb::u8<&FlagRoundItem::d3>(6)),
                              pb::u8<&FlagRoundItem::k3>(7),
                              pb::when(8, pb::eq(7, 1), pb::u8<&FlagRoundItem::b>(8)))))));

static_assert(pb::validate(flag_round_chain_scheme).ok(),
              "flag-byte round chain scheme is valid");

}  // namespace

namespace {

RoundItem round_item(int m, int k1, int k2, int k3, int b) {
  RoundItem item;
  item.m = static_cast<std::uint8_t>(m);
  if (k1 >= 0)
    item.k1 = static_cast<std::uint8_t>(k1);
  if (k2 >= 0)
    item.k2 = static_cast<std::uint8_t>(k2);
  if (k3 >= 0)
    item.k3 = static_cast<std::uint8_t>(k3);
  if (b >= 0)
    item.b = static_cast<std::uint8_t>(b);
  return item;
}

}  // namespace

RoundChainRow round_chain_sample(std::size_t index) {
  RoundChainRow r;
  switch (index) {
    case 0:
      r.n = 2;
      r.items.count = 2;
      r.items.items[0] = round_item(1, 1, 1, 1, 5);
      r.items.items[1] = round_item(1, 1, 1, 1, 6);
      break;
    case 1:
      r.n = 2;
      r.items.count = 2;
      r.items.items[0] = round_item(0, -1, -1, -1, -1);
      r.items.items[1] = round_item(1, 0, -1, -1, -1);
      break;
    case 2:
      r.n = 1;
      r.items.count = 1;
      r.items.items[0] = round_item(1, 1, 0, -1, -1);
      break;
    default:
      r.n = 2;
      r.items.count = 2;
      r.items.items[0] = round_item(1, 1, 1, 0, -1);
      r.items.items[1] = round_item(0, -1, -1, -1, -1);
      break;
  }
  return r;
}

pb::Result round_chain_pack(RoundChainRow const& row, std::uint8_t* out, std::size_t cap) {
  return pb::pack(round_chain_scheme, row, out, cap);
}

pb::Result round_chain_unpack(std::uint8_t const* data, std::size_t len, RoundChainRow& row) {
  return pb::unpack(round_chain_scheme, data, len, row);
}

int round_chain_mismatched(RoundChainRow const& a, RoundChainRow const& b) {
  if (a.n != b.n)
    return 1;
  return differs(a.items, b.items, [](RoundItem const& x, RoundItem const& y) {
    return x.m == y.m && !differs(x.k1, y.k1) && !differs(x.k2, y.k2) && !differs(x.k3, y.k3) &&
           !differs(x.b, y.b);
  });
}

std::uint8_t const* round_chain_expected(std::size_t index, std::size_t& len) {
  static std::uint8_t const all_true[] = {0x5d, 0x02, 0x01, 0x01, 0x01, 0x01, 0x05,
                                          0x01, 0x01, 0x01, 0x01, 0x06};
  static std::uint8_t const first_clear[] = {0x5d, 0x02, 0x00, 0x01, 0x00};
  static std::uint8_t const k2_clear[] = {0x5d, 0x01, 0x01, 0x01, 0x00};
  static std::uint8_t const k3_clear[] = {0x5d, 0x02, 0x01, 0x01, 0x01, 0x00, 0x00};
  switch (index) {
    case 0:
      len = sizeof(all_true);
      return all_true;
    case 1:
      len = sizeof(first_clear);
      return first_clear;
    case 2:
      len = sizeof(k2_clear);
      return k2_clear;
    default:
      len = sizeof(k3_clear);
      return k3_clear;
  }
}

int round_chain_failures(std::size_t index) {
  RoundChainRow row = round_chain_sample(index);
  std::uint8_t buf[16];
  pb::Result p = round_chain_pack(row, buf, sizeof(buf));
  std::size_t want_len = 0;
  std::uint8_t const* want = round_chain_expected(index, want_len);
  int n = (!p.ok() || p.offset != want_len || std::memcmp(buf, want, want_len) != 0) ? 1 : 0;
  RoundChainRow back;
  pb::Result u = round_chain_unpack(want, want_len, back);
  return n + (u.ok() ? 0 : 1) + round_chain_mismatched(row, back);
}

namespace {

FlagRoundItem flag_round_item(int m, int d1, int k1, int d2, int k2, int d3, int k3, int b) {
  FlagRoundItem item;
  item.m = static_cast<std::uint8_t>(m);
  if (d1 >= 0)
    item.d1 = static_cast<std::uint8_t>(d1);
  if (k1 >= 0)
    item.k1 = static_cast<std::uint8_t>(k1);
  if (d2 >= 0)
    item.d2 = static_cast<std::uint8_t>(d2);
  if (k2 >= 0)
    item.k2 = static_cast<std::uint8_t>(k2);
  if (d3 >= 0)
    item.d3 = static_cast<std::uint8_t>(d3);
  if (k3 >= 0)
    item.k3 = static_cast<std::uint8_t>(k3);
  if (b >= 0)
    item.b = static_cast<std::uint8_t>(b);
  return item;
}

}  // namespace

FlagRoundChainRow flag_round_chain_sample(std::size_t index) {
  FlagRoundChainRow r;
  r.n = 2;
  r.items.count = 2;
  switch (index) {
    case 0:
      r.items.items[0] = flag_round_item(1, 7, 1, 8, 1, 9, 1, 5);
      r.items.items[1] = flag_round_item(1, 7, 1, 8, 1, 9, 1, 6);
      break;
    case 1:
      r.items.items[0] = flag_round_item(0, -1, -1, -1, -1, -1, -1, -1);
      r.items.items[1] = flag_round_item(1, 7, 0, -1, -1, -1, -1, -1);
      break;
    case 2:
      r.n = 1;
      r.items.count = 1;
      r.items.items[0] = flag_round_item(1, 7, 1, 8, 0, -1, -1, -1);
      break;
    default:
      r.items.items[0] = flag_round_item(1, -1, 1, -1, 1, -1, 0, -1);
      r.items.items[1] = flag_round_item(0, -1, -1, -1, -1, -1, -1, -1);
      break;
  }
  return r;
}

pb::Result flag_round_chain_pack(FlagRoundChainRow const& row, std::uint8_t* out, std::size_t cap) {
  return pb::pack(flag_round_chain_scheme, row, out, cap);
}

pb::Result flag_round_chain_unpack(std::uint8_t const* data, std::size_t len,
                                   FlagRoundChainRow& row) {
  return pb::unpack(flag_round_chain_scheme, data, len, row);
}

int flag_round_chain_mismatched(FlagRoundChainRow const& a, FlagRoundChainRow const& b) {
  if (a.n != b.n)
    return 1;
  return differs(a.items, b.items, [](FlagRoundItem const& x, FlagRoundItem const& y) {
    return x.m == y.m && !differs(x.d1, y.d1) && !differs(x.k1, y.k1) && !differs(x.d2, y.d2) &&
           !differs(x.k2, y.k2) && !differs(x.d3, y.d3) && !differs(x.k3, y.k3) &&
           !differs(x.b, y.b);
  });
}

std::uint8_t const* flag_round_chain_expected(std::size_t index, std::size_t& len) {
  static std::uint8_t const all_held[] = {0x5e, 0x02, 0x01, 0x01, 0x07, 0x01, 0x01, 0x08, 0x01,
                                          0x01, 0x09, 0x01, 0x05, 0x01, 0x01, 0x07, 0x01, 0x01,
                                          0x08, 0x01, 0x01, 0x09, 0x01, 0x06};
  static std::uint8_t const first_clear[] = {0x5e, 0x02, 0x00, 0x01, 0x01, 0x07, 0x00};
  static std::uint8_t const k2_clear[] = {0x5e, 0x01, 0x01, 0x01, 0x07, 0x01, 0x01, 0x08, 0x00};
  static std::uint8_t const bits_clear[] = {0x5e, 0x02, 0x01, 0x00, 0x01, 0x00,
                                            0x01, 0x00, 0x00, 0x00};
  switch (index) {
    case 0:
      len = sizeof(all_held);
      return all_held;
    case 1:
      len = sizeof(first_clear);
      return first_clear;
    case 2:
      len = sizeof(k2_clear);
      return k2_clear;
    default:
      len = sizeof(bits_clear);
      return bits_clear;
  }
}

int flag_round_chain_failures(std::size_t index) {
  FlagRoundChainRow row = flag_round_chain_sample(index);
  std::uint8_t buf[32];
  pb::Result p = flag_round_chain_pack(row, buf, sizeof(buf));
  std::size_t want_len = 0;
  std::uint8_t const* want = flag_round_chain_expected(index, want_len);
  int n = (!p.ok() || p.offset != want_len || std::memcmp(buf, want, want_len) != 0) ? 1 : 0;
  FlagRoundChainRow back;
  pb::Result u = flag_round_chain_unpack(want, want_len, back);
  return n + (u.ok() ? 0 : 1) + flag_round_chain_mismatched(row, back);
}

}  // namespace all_kinds
