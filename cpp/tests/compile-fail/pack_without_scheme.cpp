#include "packbin/packbin.hpp"

struct MarkerRow {
  std::uint8_t sid;
};

// A row alone does not say how to lay out its bytes: pack needs a scheme.
int main() {
  MarkerRow row{23};
  std::uint8_t buf[4];
  (void)packbin::pack(row, buf, sizeof(buf));
  return 0;
}
