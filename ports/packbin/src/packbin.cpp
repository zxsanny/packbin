#include "walk.hpp"

namespace packbin {

std::vector<std::uint8_t> pack_body(std::vector<Field> const& fields, Values const& values) {
  std::vector<std::uint8_t> out;
  out.reserve(32);
  pack_nodes(fields, values, out);
  return out;
}

UnpackResult<> unpack_body(std::vector<Field> const& fields, std::uint8_t const* data,
                           std::size_t len, std::size_t offset) {
  Values out;
  auto err = unpack_nodes(data, len, offset, fields, out, false);
  if (err) {
    UnpackResult<> r;
    r.ok = false;
    r.short_packet = *err;
    return r;
  }
  if (offset < len) {
    UnpackResult<> r;
    r.ok = false;
    r.trailing = TrailingBytes{len - offset};
    return r;
  }
  UnpackResult<> r;
  r.ok = true;
  r.value = std::move(out);
  return r;
}

}  // namespace packbin
