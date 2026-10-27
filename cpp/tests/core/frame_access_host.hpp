#pragma once

// Test-only door into the keys of a FrameSession and a MacKey (the classes name detail::FrameTestAccess as
// a friend). Included by the host frame tests; no library code includes it.

#include "packbin/frame.hpp"

namespace packbin {
namespace detail {

struct FrameTestAccess {
  // K_enc(d) and K_mac(d) of the current slot, direction 1 to 3.
  static std::uint8_t const* enc(FrameSession const& s, unsigned d) { return s.current_.enc[d - 1]; }
  static std::uint8_t const* mac(FrameSession const& s, unsigned d) { return s.current_.mac[d - 1]; }
  static std::uint8_t const* previous_enc(FrameSession const& s, unsigned d) { return s.previous_.enc[d - 1]; }
  static std::uint8_t const* previous_mac(FrameSession const& s, unsigned d) { return s.previous_.mac[d - 1]; }
  static std::uint8_t const* label_key(MacKey const& k) { return k.key_; }
};

}  // namespace detail
}  // namespace packbin
