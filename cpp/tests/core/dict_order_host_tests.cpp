// Dict keys must be strictly ascending by their decoded UTF-8 bytes (compact-text invariants; AZ-2713):
// out of order and repeated keys are refused whether the dict is bound or not, the check is one
// compare with the previous key, and a session scheme that was not built spends no receive position
// (AZ-2722, F57).
#include "packbin/codec.hpp"
#include "packbin/session.hpp"

#include "check.hpp"
#include "load_factor.hpp"

#include <chrono>
#include <cstdio>
#include <cstdint>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

using check::expect;
using packbin::Array;
using packbin::Entry;
using packbin::Error;
using packbin::PackSession;
using packbin::Text;

namespace {

struct Bound {
  Array<Entry<std::uint8_t, Text<8>>, 4> m;
};

struct Unit {};

struct BigBound {
  Array<Entry<std::uint8_t, Text<8>>, 65535> m;
};

Error bound_error(std::string const& hex) {
  auto s = packbin::scheme<Bound>(1, packbin::dict<&Bound::m>(packbin::u8(0)));
  std::uint8_t data[64];
  std::size_t n = check::parse_hex(hex.c_str(), data, sizeof(data));
  Bound row;
  return packbin::unpack(s, data, n, row).error;
}

Error unbound_error(std::string const& hex) {
  auto s = packbin::scheme<Unit>(1, packbin::dict(packbin::u8(0)));
  std::uint8_t data[64];
  std::size_t n = check::parse_hex(hex.c_str(), data, sizeof(data));
  Unit row;
  return packbin::unpack(s, data, n, row).error;
}

struct Packet {
  char const* what;
  char const* hex;
  bool accepted;
};

// Each key is a string field (count, payload); the value is one byte. 026bd0 is "b" in the
// compact form, 02c900 is "a".
constexpr Packet kPackets[] = {
    {"out of order", "0102000210620002106100", false},
    {"repeated", "0102000210610002106100", false},
    {"repeated in the raw and the compact form", "0102000210610002c90000", false},
    {"a prefix after the longer key", "010200031061620002106100", false},
    {"U+10000 before U+FF5E (UTF-16 order, not UTF-8)", "0102000510f0908080000410efbd9e00", false},
    {"ascending", "0102000210610002106200", true},
    {"ascending, the second key compact", "0102000210610002" "6bd000", true},
    {"a prefix before the longer key", "010200021061000310616200", true},
    {"U+FF5E before U+10000 (UTF-8 order)", "0102000410efbd9e000510f090808000", true},
    {"the empty key first", "010200" "00" "00" "021061" "00", true},
    {"the empty key twice", "010200" "00" "00" "00" "00", false},
    {"a lone key", "010100021061" "00", true},
};

void packets_by_order() {
  for (auto const& p : kPackets) {
    std::string name = std::string("bound dict: ") + p.what;
    expect((bound_error(p.hex) == Error::Ok) == p.accepted, name.c_str());
    name = std::string("unbound dict: ") + p.what;
    expect((unbound_error(p.hex) == Error::Ok) == p.accepted, name.c_str());
    if (!p.accepted) {
      expect(bound_error(p.hex) == Error::BadValue, "a refused order is BadValue (bound)");
      expect(unbound_error(p.hex) == Error::BadValue, "a refused order is BadValue (unbound)");
    }
  }
}

// 65,535 keys "k00000" to "k65534" as raw strings with a one byte value: 8 bytes each.
std::vector<std::uint8_t> many_keys(bool descending_tail) {
  std::vector<std::uint8_t> p = {0x01, 0xff, 0xff};
  for (int i = 0; i < 65535; ++i) {
    int k = (descending_tail && i == 65534) ? 0 : i;
    char key[8];
    std::snprintf(key, sizeof(key), "k%05d", k);
    p.push_back(7);
    p.push_back(0x10);
    p.insert(p.end(), key, key + 6);
    p.push_back(0);
  }
  return p;
}

double seconds_since(std::chrono::steady_clock::time_point t0) {
  return std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
}

// AC-3: the cost is linear in the entries. The old bound dict check took 17 s for this packet.
void many_keys_are_linear() {
  std::vector<std::uint8_t> good = many_keys(false);
  auto bound = packbin::scheme<BigBound>(1, packbin::dict<&BigBound::m>(packbin::u8(0)));
  auto row = std::make_unique<BigBound>();
  auto limit = load_factor::bound(1.0);
  auto t0 = std::chrono::steady_clock::now();
  auto r = packbin::unpack(bound, good.data(), good.size(), *row);
  expect(r.ok() && row->m.count == 65535, "65,535 ascending keys unpack into a bound Array");
  load_factor::expect_within(seconds_since(t0), limit, "65,535 keys unpack in under a second (bound)");

  auto unbound = packbin::scheme<Unit>(1, packbin::dict(packbin::u8(0)));
  Unit unit;
  limit = load_factor::bound(1.0);
  t0 = std::chrono::steady_clock::now();
  r = packbin::unpack(unbound, good.data(), good.size(), unit);
  expect(r.ok(), "65,535 ascending keys unpack in a dict that is not bound");
  load_factor::expect_within(seconds_since(t0), limit, "65,535 keys unpack in under a second (unbound)");

  std::vector<std::uint8_t> bad = many_keys(true);
  limit = load_factor::bound(1.0);
  t0 = std::chrono::steady_clock::now();
  r = packbin::unpack(unbound, bad.data(), bad.size(), unit);
  expect(r.error == Error::BadValue, "the last key of 65,535 sorting first is refused");
  load_factor::expect_within(seconds_since(t0), limit, "the refusal is as fast (unbound)");
}

// Two keys of 65,535 bytes that differ in the last byte: the compare reads each payload once.
void long_keys_share_a_prefix() {
  std::vector<std::uint8_t> p = {0x01, 0x02, 0x00};
  for (int k = 0; k < 2; ++k) {
    p.push_back(0x80);  // count 65,536 = 80 80 04
    p.push_back(0x80);
    p.push_back(0x04);
    p.push_back(0x10);
    p.insert(p.end(), 65534, 'a');
    p.push_back(k == 0 ? 'a' : 'b');
    p.push_back(0);
  }
  auto unbound = packbin::scheme<Unit>(1, packbin::dict(packbin::u8(0)));
  Unit unit;
  auto limit = load_factor::bound(1.0);
  auto t0 = std::chrono::steady_clock::now();
  auto r = packbin::unpack(unbound, p.data(), p.size(), unit);
  expect(r.ok(), "two 65,535 byte keys that differ in the last byte, ascending");
  p[3 + 4 + 65535 + 1 + 3 + 1 + 65534] = 'a';  // the second key's last byte: now equal
  r = packbin::unpack(unbound, p.data(), p.size(), unit);
  expect(r.error == Error::BadValue, "the same keys, equal, are refused");
  load_factor::expect_within(seconds_since(t0), limit,
                             "long keys with a shared prefix are checked in under a second");
}

struct Position {
  std::uint16_t sid = 0;
};

constexpr auto kPlain = packbin::scheme<Position>(0x40, packbin::u16<&Position::sid>(0));

// F57: a scheme that was not built answers its own error before the buffer or the receive position
// is touched, so the next valid payload still lines up.
void session_scheme_not_built_spends_nothing() {
  std::uint8_t seed[32];
  for (std::size_t i = 0; i < sizeof(seed); ++i)
    seed[i] = static_cast<std::uint8_t>(i + 1);
  std::uint8_t nonce[16] = {1};
  PackSession a;
  PackSession b;
  expect(a.load(seed, sizeof(seed)) && b.load(seed, sizeof(seed)) &&
             a.start(nonce, sizeof(nonce)) && b.join(nonce, sizeof(nonce)),
         "both sessions open");
  Position row;
  row.sid = 0x1234;
  std::uint8_t wire[16];
  auto p = a.pack(kPlain, row, wire, sizeof(wire));
  expect(p.ok(), "the sender packs");
  std::uint8_t copy[16];
  std::memcpy(copy, wire, sizeof(wire));

  auto bad = packbin::parity(kPlain, 40);
  Position out;
  auto r = b.unpack(bad, wire, p.offset, out);
  expect(r.error == Error::SchemeInvalid, "a scheme with 40 parity bytes is SchemeInvalid");
  expect(std::memcmp(wire, copy, sizeof(wire)) == 0, "the buffer is not touched");
  auto next = b.unpack(kPlain, wire, p.offset, out);
  expect(next.ok() && out.sid == 0x1234, "the next valid payload is read at the same position");

  // A handler whose scheme was not built is refused the same way, before the pad and the position.
  // The valid unpack above removed the pad in place and spent position 0; a third payload comes next.
  std::uint8_t second[16];
  auto p2 = a.pack(kPlain, row, second, sizeof(second));
  std::memcpy(copy, second, sizeof(copy));
  int runs = 0;
  auto h = b.unpack(second, p2.offset, packbin::on(bad, out, [&](Position const&) { ++runs; }));
  expect(h.error == Error::SchemeInvalid && runs == 0, "a handler with an unbuilt scheme is SchemeInvalid");
  expect(std::memcmp(second, copy, sizeof(copy)) == 0, "the buffer is not touched by the handler call");
  auto again = b.unpack(kPlain, second, p2.offset, out);
  expect(again.ok() && out.sid == 0x1234, "the receive position is unchanged after the handler call");
}

struct Keyed {
  Array<Entry<std::uint8_t, Text<4>>, 2> m;
};

void put_key(Text<4>& key, char const* bytes, std::size_t n) {
  key.len = static_cast<std::uint16_t>(n);
  std::memcpy(key.data, bytes, n);
}

// The pack side compares keys as unsigned bytes: a signed compare puts U+0080 (c2 80) before DEL
// (7f), a length-first compare puts "ab" after "b".
bool packs_in_order(char const* first, std::size_t n1, char const* second, std::size_t n2) {
  auto s = packbin::scheme<Keyed>(1, packbin::dict<&Keyed::m>(packbin::u8(0)));
  Keyed row;
  row.m.count = 2;
  put_key(row.m.items[0].key, first, n1);
  put_key(row.m.items[1].key, second, n2);
  std::uint8_t buf[32];
  packbin::Scratch<16> scratch;
  auto r = packbin::pack(s, row, buf, sizeof(buf), scratch);
  if (!r.ok())
    expect(r.error == Error::BadValue, "a refused key order is BadValue");
  return r.ok();
}

void pack_orders_keys_as_unsigned_bytes() {
  expect(packs_in_order("\x7f", 1, "\xc2\x80", 2), "pack: 7f then c2 80 (a high byte after a low one)");
  expect(!packs_in_order("\xc2\x80", 2, "\x7f", 1), "pack: c2 80 then 7f is refused");
  expect(packs_in_order("a", 1, "ab", 2), "pack: a then ab (the prefix first)");
  expect(!packs_in_order("ab", 2, "a", 1), "pack: ab then a is refused");
  expect(!packs_in_order("a", 1, "a", 1), "pack: a twice is refused");
  expect(packs_in_order("ab", 2, "b", 1), "pack: ab then b (the longer key sorts first)");
  expect(!packs_in_order("b", 1, "ab", 2), "pack: b then ab is refused");
}

}  // namespace

int run_core_dict_order_host_tests() {
  packets_by_order();
  many_keys_are_linear();
  long_keys_share_a_prefix();
  pack_orders_keys_as_unsigned_bytes();
  session_scheme_not_built_spends_nothing();
  return check::failures();
}
