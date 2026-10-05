#include "packbin/codec.hpp"

struct Row {
  bool b = false;
  std::uint8_t v = 0;
};

// A bool is a presence bit; outside flags it could never round-trip.
constexpr auto s = packbin::scheme<Row>(1, packbin::boolean<&Row::b>(0), packbin::u8<&Row::v>(1));

int main() { return s.type_number; }
