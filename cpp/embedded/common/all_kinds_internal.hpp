// Helpers the all-kinds parts share; not part of the public header.
#pragma once

#include "all_kinds.hpp"

#include <cstddef>

namespace all_kinds {

template <typename T>
int differs(packbin::Opt<T> const& a, packbin::Opt<T> const& b) {
  return (a.has != b.has || (a.has && !(a.value == b.value))) ? 1 : 0;
}

template <typename T, std::size_t N, typename Eq>
int differs(packbin::Array<T, N> const& a, packbin::Array<T, N> const& b, Eq eq) {
  if (a.count != b.count)
    return 1;
  for (std::size_t i = 0; i < a.count; ++i)
    if (!eq(a.items[i], b.items[i]))
      return 1;
  return 0;
}

}  // namespace all_kinds
