#include "packbin/os_random.hpp"

#include <cstddef>
#include <cstdint>

#if defined(__APPLE__)
#include <stdlib.h>
#elif defined(__linux__)
#include <cerrno>
#include <sys/random.h>
#else
#include <cstdio>
#endif

namespace packbin {

bool os_random(std::uint8_t* out, std::size_t n, void* ctx) {
  (void)ctx;
  if (out == nullptr)
    return n == 0;
#if defined(__APPLE__)
  arc4random_buf(out, n);
  return true;
#elif defined(__linux__)
  std::size_t got = 0;
  while (got < n) {
    ssize_t r = getrandom(out + got, n - got, 0);
    if (r < 0) {
      if (errno == EINTR)
        continue;
      return false;
    }
    got += static_cast<std::size_t>(r);
  }
  return true;
#else
  std::FILE* f = std::fopen("/dev/urandom", "rb");
  if (f == nullptr)
    return false;
  std::size_t got = std::fread(out, 1, n, f);
  std::fclose(f);
  return got == n;
#endif
}

}  // namespace packbin
