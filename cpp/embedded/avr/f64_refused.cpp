// AZ-2068 AC-2: on avr-gcc, where double is 4 bytes, a scheme with f64 does not compile, and the
// message names f64. cpp/embedded/avr.sh expects this file to fail.

#include <packbin/codec.hpp>

struct Sample {
  std::uint8_t id = 0;
  double value = 0;
};

constexpr auto sample =
    packbin::scheme<Sample>(1, packbin::u8<&Sample::id>(0), packbin::f64<&Sample::value>(1));

int main() { return sample.status.ok() ? 0 : 1; }
