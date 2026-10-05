#pragma once

// Measures the stack a call uses on the target: paints a window below the current stack
// pointer, runs the call, then finds the deepest byte that changed.

#include <cstddef>
#include <cstdint>

namespace stack_meter {

constexpr std::size_t kWindow = 8192;
// Bytes just below the measuring frame left unpainted for paint()'s own frame.
constexpr std::size_t kGuard = 64;
constexpr std::uint8_t kPaint = 0xa5;

__attribute__((noinline)) inline void paint(std::uint8_t* lo, std::uint8_t* hi) {
  for (volatile std::uint8_t* p = lo; p < hi; ++p)
    *p = kPaint;
}

inline std::uintptr_t stack_pointer() {
  std::uintptr_t sp;
  __asm__ volatile("mov %0, sp" : "=r"(sp));
  return sp;
}

// Stack bytes below this frame that `fn` touched (an upper bound: it includes the call into
// `fn`). Returns kWindow when the window was too small.
template <typename F>
__attribute__((noinline)) std::size_t measure(F const& fn) {
  std::uintptr_t top = stack_pointer();
  auto* lo = reinterpret_cast<std::uint8_t*>(top - kWindow);
  paint(lo, reinterpret_cast<std::uint8_t*>(top - kGuard));
  fn();
  volatile std::uint8_t* p = lo;
  while (reinterpret_cast<std::uintptr_t>(p) < top - kGuard && *p == kPaint)
    ++p;
  return static_cast<std::size_t>(top - reinterpret_cast<std::uintptr_t>(p));
}

}  // namespace stack_meter
