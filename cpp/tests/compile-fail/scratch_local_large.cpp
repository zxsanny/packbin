#include "packbin/packbin.hpp"

// A Scratch<65535> is 786 KB: as a local it overflows a thread stack. Make it static.
int main(int argc, char**) {
  packbin::Scratch<65535> scratch;
  const std::size_t i = static_cast<std::size_t>(argc) * 4099u;
  volatile std::uint32_t* words = scratch.words;
  words[i] = 1;
  return static_cast<int>(words[i]) - 1;
}
