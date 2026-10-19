// AZ-2068: avr-gcc 7.3 has no __builtin_is_constant_evaluated, so a constant scheme that breaks a
// rule (here a gap: ids 0 and 2) does not stop the compile by itself there; its status is
// SchemeInvalid naming the field, and a static_assert on the status is the stop the README names.
// cpp/embedded/arm.sh expects this file to compile with avr-gcc.

#include <packbin/codec.hpp>

struct Pair {
  std::uint8_t a = 0;
  std::uint8_t b = 0;
};

constexpr auto gap =
    packbin::scheme<Pair>(1, packbin::u8<&Pair::a>(0), packbin::u8<&Pair::b>(2));

static_assert(gap.status.error == packbin::Error::SchemeInvalid, "a gap is SchemeInvalid");
static_assert(gap.status.field == 2, "the status names the field after the gap");

int main() { return 0; }
