#include "packbin/codec.hpp"

struct Row {
  std::uint8_t v = 0;
  bool b = false;
};

// An empty group is a presence bit; outside flags it could never round-trip.
constexpr auto s = packbin::scheme<Row>(1, packbin::u8<&Row::v>(0), packbin::group<&Row::b>(1));

int main() { return s.type_number; }
