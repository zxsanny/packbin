#include "packbin/packbin.hpp"

struct MarkerRow {
  std::uint8_t sid;
};

int main() {
  MarkerRow row{23};
  (void)packbin::pack(row);
  return 0;
}
