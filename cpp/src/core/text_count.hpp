#pragma once

// The count header of a string field: a varint of 1 to 3 bytes (LEB128, minimal), then that
// many payload bytes. Shared by the codec and by `Packed`, so a build with PACKBIN_NO_TEXT can
// skip, read and forward a string without the codec.

#include "packbin/core.hpp"

#include <cstddef>
#include <cstdint>

namespace packbin {
namespace detail {
namespace txt {

// The largest count a 3-byte varint holds.
constexpr std::size_t kMaxCount = 2097151;

inline unsigned varint_size(std::size_t n) { return n < 128 ? 1 : n < 16384 ? 2 : 3; }

inline std::uint8_t* put_varint(std::uint8_t* p, std::size_t n) {
  while (n >= 128) {
    *p++ = static_cast<std::uint8_t>(n | 0x80);
    n >>= 7;
  }
  *p++ = static_cast<std::uint8_t>(n);
  return p;
}

// Reads the count of a string: BadValue for a fourth byte or a non-minimal form.
inline Result get_count(Reader& r, std::size_t& out, int id) {
  std::size_t at = r.pos;
  std::size_t n = 0;
  for (unsigned k = 0; k < 3; ++k) {
    if (r.left() == 0)
      return fail(Error::ShortPacket, r.pos, id, 1);
    std::uint8_t b = r.data[r.pos++];
    n |= static_cast<std::size_t>(b & 0x7F) << (7 * k);
    if ((b & 0x80) == 0) {
      if (k > 0 && b == 0)
        return fail(Error::BadValue, at, id);
      out = n;
      return Result{};
    }
  }
  return fail(Error::BadValue, at, id);
}

}  // namespace txt
}  // namespace detail
}  // namespace packbin
