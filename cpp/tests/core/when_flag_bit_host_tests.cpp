// AZ-3143 AC-2: a `when` whose span holds a flag byte carries `flag::HoldsFlagByte`, set once when
// the scheme resolves; the unpack walk reads the bit and scans nothing. Checked for a scheme built
// at compile time and for the same scheme built at run time (the type number is a run-time value),
// and for a `when` that holds the flag byte only through a nested `when`. Host-only.

#include "packbin/packbin.hpp"

#include "check.hpp"

#include <cstddef>
#include <cstdint>

using check::expect;
using packbin::Opt;
namespace pb = packbin;

namespace {

struct Row {
  std::uint8_t mode = 0;
  Opt<std::uint8_t> speed;
  Opt<std::uint8_t> inner;
  std::uint8_t tail = 0;
};

// F: u8 mode; when(mode == 1) { flag_byte; bit { u8 speed } }; u8 tail.
template <typename Id>
constexpr auto with_flag_byte(Id id) {
  return pb::scheme<Row>(id, pb::u8<&Row::mode>(0),
                         pb::when(1, pb::eq(0, 1), pb::flag_byte(0),
                                  pb::flag_bit(0, pb::u8<&Row::speed>(1))),
                         pb::u8<&Row::tail>(2));
}

// P: u8 mode; when(mode == 1) { u8 speed }; u8 tail.
template <typename Id>
constexpr auto without_flag_byte(Id id) {
  return pb::scheme<Row>(id, pb::u8<&Row::mode>(0),
                         pb::when(1, pb::eq(0, 1), pb::u8<&Row::speed>(1)), pb::u8<&Row::tail>(2));
}

// N: u8 mode; when(mode == 1) { u8 speed; when(speed == 2) { flag_byte; bit { u8 inner } } };
// u8 tail. The outer `when` holds the flag byte through the inner one.
template <typename Id>
constexpr auto nested_flag_byte(Id id) {
  return pb::scheme<Row>(
      id, pb::u8<&Row::mode>(0),
      pb::when(1, pb::eq(0, 1), pb::u8<&Row::speed>(1),
               pb::when(2, pb::eq(1, 2), pb::flag_byte(0),
                        pb::flag_bit(0, pb::u8<&Row::inner>(2)))),
      pb::u8<&Row::tail>(3));
}

constexpr auto compile_time_f = with_flag_byte(0x61);
constexpr auto compile_time_p = without_flag_byte(0x62);
constexpr auto compile_time_n = nested_flag_byte(0x63);
static_assert(pb::validate(compile_time_f).ok(), "F is valid");
static_assert(pb::validate(compile_time_p).ok(), "P is valid");
static_assert(pb::validate(compile_time_n).ok(), "N is valid");

// How many entries of kind `k` have `holds_flag_byte()`, and how many entries of kind `k` there are.
template <typename S>
void count_bits(S const& s, pb::Kind k, std::size_t& set, std::size_t& all) {
  set = 0;
  all = 0;
  for (std::size_t i = 0; i < s.fields.size(); ++i) {
    pb::Field const& f = s.fields.data()[i];
    if (f.kind != k)
      continue;
    ++all;
    if (f.holds_flag_byte())
      ++set;
  }
}

template <typename S>
bool bit_only_on_whens(S const& s, std::size_t whens_set, std::size_t whens_all) {
  std::size_t set = 0;
  std::size_t all = 0;
  count_bits(s, pb::Kind::When, set, all);
  bool on_whens = set == whens_set && all == whens_all;
  // No other kind carries the bit: the sum over every entry equals the sum over the whens.
  std::size_t any = 0;
  for (std::size_t i = 0; i < s.fields.size(); ++i)
    any += s.fields.data()[i].holds_flag_byte() ? 1 : 0;
  return on_whens && any == whens_set;
}

template <typename S>
bool unpacks_to(S const& s, char const* hex, int mode, int speed, int inner, int tail) {
  std::uint8_t buf[16];
  std::size_t n = check::parse_hex(hex, buf, sizeof(buf));
  Row back;
  auto u = pb::unpack(s, buf, n, back);
  return u.ok() && back.mode == mode && back.speed.has == (speed >= 0) &&
         (speed < 0 || back.speed.value == speed) && back.inner.has == (inner >= 0) &&
         (inner < 0 || back.inner.value == inner) && back.tail == tail;
}

template <typename S>
bool packs_to(S const& s, Row const& row, char const* hex) {
  std::uint8_t buf[16];
  auto p = pb::pack(s, row, buf, sizeof(buf));
  return p.ok() && check::same_hex(buf, p.offset, hex);
}

// F, P and N built one way: the bit is on exactly the `when`s that hold a flag byte, and the rows
// unpack and pack to the same bytes whichever way the scheme was built.
template <typename SF, typename SP, typename SN>
void checks(SF const& f, SP const& p, SN const& n, char const* way) {
  expect(bit_only_on_whens(f, 1, 1), way);
  expect(bit_only_on_whens(p, 0, 1), way);
  expect(bit_only_on_whens(n, 2, 2), way);

  expect(unpacks_to(f, "6101010709", 1, 7, -1, 9), way);
  expect(unpacks_to(f, "61010009", 1, -1, -1, 9), way);
  expect(unpacks_to(f, "610009", 0, -1, -1, 9), way);
  expect(unpacks_to(p, "62010709", 1, 7, -1, 9), way);
  expect(unpacks_to(p, "620009", 0, -1, -1, 9), way);
  expect(unpacks_to(n, "630102010509", 1, 2, 5, 9), way);
  expect(unpacks_to(n, "63010109", 1, 1, -1, 9), way);

  Row row;
  row.mode = 1;
  row.speed = 7;
  row.tail = 9;
  expect(packs_to(f, row, "6101010709"), way);
  expect(packs_to(p, row, "62010709"), way);
}

void az3143_bit_set_by_the_compile_time_builder() {
  // Arrange
  // Act
  // Assert
  checks(compile_time_f, compile_time_p, compile_time_n, "AZ-3143 AC-2 compile-time build");
}

// The type number is read from a volatile at run time, so the builder runs as ordinary code.
void az3143_bit_set_by_the_run_time_builder() {
  // Arrange
  volatile int id_f = 0x61;
  volatile int id_p = 0x62;
  volatile int id_n = 0x63;

  // Act
  auto f = with_flag_byte(static_cast<int>(id_f));
  auto p = without_flag_byte(static_cast<int>(id_p));
  auto n = nested_flag_byte(static_cast<int>(id_n));

  // Assert
  checks(f, p, n, "AZ-3143 AC-2 run-time build");
}

}  // namespace

int run_core_when_flag_bit_host_tests() {
  az3143_bit_set_by_the_compile_time_builder();
  az3143_bit_set_by_the_run_time_builder();
  return check::failures();
}
