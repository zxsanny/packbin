#pragma once

// Host-only random source for PackSession::start. Firmware does not compile os_random.cpp and
// passes its own RandomFn (a hardware RNG, for example).

#include <cstddef>
#include <cstdint>

namespace packbin {

// A RandomFn backed by the operating system; `ctx` is unused.
bool os_random(std::uint8_t* out, std::size_t n, void* ctx);

}  // namespace packbin
