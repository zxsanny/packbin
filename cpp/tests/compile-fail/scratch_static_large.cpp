#include "packbin/packbin.hpp"

// The accepted way to hold a large Scratch: static storage.
int main(int argc, char**) {
  static packbin::Scratch<65535> scratch;
  const std::size_t i = static_cast<std::size_t>(argc) * 4099u;
  volatile std::uint32_t* words = scratch.words;
  words[i] = 1;
  return static_cast<int>(words[i]) - 1;
}
