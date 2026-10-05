#include "packbin/core.hpp"

// A 4-byte floating type stands in for a target whose double is 4 bytes (avr-gcc).
int main() {
  std::uint8_t buf[8];
  packbin::Writer w{buf, sizeof(buf), 0};
  (void)packbin::put_f64<float>(w, 1.0f, false, 0);
  return 0;
}
