// The four loop 126 cases of fixtures/hostile/cases.txt (AZ-4303, contract scheme-depth.md): a
// scheme nested deeper than 256 levels is refused when it is built (the two construct cases; the two
// pack cases are in hostile_pack_loop21.hpp). The chains are tables filled by a loop
// (scheme_depth_chains.hpp), so no loader recurses. A construct handler answers "scheme_error" only
// for SchemeInvalid with `needed` 256, the depth refusal, so a refusal by another rule fails the case.

#pragma once

#include "hostile_rule_check.hpp"
#include "scheme_depth_chains.hpp"

#include <cstdint>
#include <string>

namespace hostile_depth {

namespace dc = depth_chain;

template <dc::Shape S>
char const* construct_257(std::uint8_t const*, std::size_t) {
  packbin::Result r = dc::status_at<S, 257>();
  if (r.ok())
    return "ok";
  return r.error == packbin::Error::SchemeInvalid && r.needed == 256 ? "scheme_error"
                                                                      : "another_error";
}

inline Handler const kHandlers[] = {
    {"construct_depth_when_257", construct_257<dc::Shape::When>},
    {"construct_depth_group_257", construct_257<dc::Shape::Group>},
};

}  // namespace hostile_depth
