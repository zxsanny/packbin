#pragma once

// Compact text format (contract compact-text 1.0.0): the tables shared by the encoder and the
// decoder. Everything here is constant data built at compile time; no heap, no mutable state.

#include "packbin/text_tables.hpp"

#include <cstddef>
#include <cstdint>

namespace packbin {
namespace detail {
namespace txt {

namespace tbl = ::packbin::text;

constexpr std::size_t kMaxText = 65535;
constexpr std::uint8_t kRawPrefix = 0x10;
constexpr unsigned kMaxCode = 16;
constexpr unsigned kHeaderBits = 6;
// Modes: 0 ua, 1 ru, 2 en are text modes; 3 is the number mode; start mode 4 is raw UTF-8.
constexpr unsigned kNumMode = 3;
constexpr unsigned kRawMode = 4;

// Symbol positions in the table of one mode: letters, the shared characters (the number
// characters in mode 3), the switches to the other three modes, then CAP, LOCK and ESC.
struct Layout {
  std::uint8_t letters;
  std::uint8_t shared;
  std::uint8_t sw;
  std::uint8_t cap;
  std::uint8_t lock;
  std::uint8_t esc;
};

constexpr Layout text_layout(unsigned letters) {
  return Layout{static_cast<std::uint8_t>(letters),
                static_cast<std::uint8_t>(letters),
                static_cast<std::uint8_t>(letters + 32),
                static_cast<std::uint8_t>(letters + 35),
                static_cast<std::uint8_t>(letters + 36),
                static_cast<std::uint8_t>(letters + 37)};
}

inline constexpr Layout kLayout[4] = {text_layout(34), text_layout(33), text_layout(27),
                                      Layout{0, 0, 15, 255, 255, 18}};

static_assert(sizeof(tbl::kLengthsUa) == 72 && kLayout[0].esc + 1 == 72, "ua table size");
static_assert(sizeof(tbl::kLengthsRu) == 71 && kLayout[1].esc + 1 == 71, "ru table size");
static_assert(sizeof(tbl::kLengthsEn) == 65 && kLayout[2].esc + 1 == 65, "en table size");
static_assert(sizeof(tbl::kLengthsNum) == 19 && kLayout[3].esc + 1 == 19, "num table size");
static_assert(sizeof(tbl::kShared) / sizeof(tbl::kShared[0]) == 32, "32 shared characters");
static_assert(sizeof(tbl::kNumset) / sizeof(tbl::kNumset[0]) == 15, "15 number characters");
static_assert(tbl::kUaUpper[33] == 0 && tbl::kEnUpper[26] == 0, "only the apostrophe has no capital");

constexpr unsigned kMaxSymbols = 72;
constexpr unsigned kMaxLetters = 34;

// Everything the encoder and the decoder look up, in one constant object (no pointers, so it is
// read-only data even in position-independent code). Index 0 to 3 is the mode.
struct Tab {
  std::uint8_t length[4][kMaxSymbols];       // code length of each symbol
  std::uint16_t code[4][kMaxSymbols];        // canonical code of each symbol (contract: Code assignment)
  std::uint8_t count[4][kMaxCode + 1];       // symbols per code length
  std::uint8_t symbol[4][kMaxSymbols];       // symbols sorted by (code length, index)
  std::uint32_t lower[3][kMaxLetters];       // letters of the text modes
  std::uint32_t upper[3][kMaxLetters];       // their capitals, 0 for none
};

template <std::size_t N>
constexpr void fill_codes(Tab& t, unsigned m, std::uint8_t const (&len)[N]) {
  unsigned count[kMaxCode + 1] = {};
  for (std::size_t i = 0; i < N; ++i) {
    t.length[m][i] = len[i];
    ++count[len[i]];
  }
  unsigned next[kMaxCode + 2] = {};
  unsigned start[kMaxCode + 2] = {};
  unsigned code = 0;
  for (unsigned l = 1; l <= kMaxCode; ++l) {
    code = (code + count[l - 1]) << 1;
    next[l] = code;
    start[l + 1] = start[l] + count[l];
    t.count[m][l] = static_cast<std::uint8_t>(count[l]);
  }
  for (std::size_t i = 0; i < N; ++i) {
    t.code[m][i] = static_cast<std::uint16_t>(next[len[i]]++);
    t.symbol[m][start[len[i]]++] = static_cast<std::uint8_t>(i);
  }
}

template <std::size_t N>
constexpr void fill_letters(Tab& t, unsigned m, std::uint32_t const (&lower)[N],
                            std::uint32_t const (&upper)[N]) {
  for (std::size_t i = 0; i < N; ++i) {
    t.lower[m][i] = lower[i];
    t.upper[m][i] = upper[i];
  }
}

constexpr Tab make_tab() {
  Tab t{};
  fill_codes(t, 0, tbl::kLengthsUa);
  fill_codes(t, 1, tbl::kLengthsRu);
  fill_codes(t, 2, tbl::kLengthsEn);
  fill_codes(t, 3, tbl::kLengthsNum);
  fill_letters(t, 0, tbl::kUa, tbl::kUaUpper);
  fill_letters(t, 1, tbl::kRu, tbl::kRuUpper);
  fill_letters(t, 2, tbl::kEn, tbl::kEnUpper);
  return t;
}

inline constexpr Tab kTab = make_tab();

// A table is a complete code when its Kraft sum is exactly 1.
template <std::size_t N>
constexpr bool complete(std::uint8_t const (&len)[N]) {
  unsigned long sum = 0;
  for (std::size_t i = 0; i < N; ++i)
    sum += 1ul << (kMaxCode - len[i]);
  return sum == (1ul << kMaxCode);
}

static_assert(complete(tbl::kLengthsUa) && complete(tbl::kLengthsRu) &&
                  complete(tbl::kLengthsEn) && complete(tbl::kLengthsNum),
              "every code table is complete");

// Smallest code length and smallest ESC code length over the four tables.
constexpr unsigned min_length() {
  unsigned m = kMaxCode;
  for (auto l : tbl::kLengthsUa)
    m = l < m ? l : m;
  for (auto l : tbl::kLengthsRu)
    m = l < m ? l : m;
  for (auto l : tbl::kLengthsEn)
    m = l < m ? l : m;
  for (auto l : tbl::kLengthsNum)
    m = l < m ? l : m;
  return m;
}

constexpr unsigned min_esc() {
  unsigned m = tbl::kLengthsUa[kLayout[0].esc];
  m = tbl::kLengthsRu[kLayout[1].esc] < m ? tbl::kLengthsRu[kLayout[1].esc] : m;
  m = tbl::kLengthsEn[kLayout[2].esc] < m ? tbl::kLengthsEn[kLayout[2].esc] : m;
  m = tbl::kLengthsNum[kLayout[3].esc] < m ? tbl::kLengthsNum[kLayout[3].esc] : m;
  return m;
}

inline constexpr unsigned kMinLength = min_length();
inline constexpr unsigned kMinEsc = min_esc();

// UTF-8 as the contract requires it: shortest form, no surrogates, nothing above U+10FFFF.
// Returns the byte length of the character at `p` (1 to 4) and stores it in `cp`, or 0.
inline unsigned decode_utf8(std::uint8_t const* p, std::size_t n, std::uint32_t& cp) {
  if (n == 0)
    return 0;
  std::uint32_t b0 = p[0];
  if (b0 < 0x80) {
    cp = b0;
    return 1;
  }
  if (b0 < 0xC2 || b0 > 0xF4)
    return 0;
  unsigned need = b0 < 0xE0 ? 2 : b0 < 0xF0 ? 3 : 4;
  if (n < need)
    return 0;
  std::uint32_t v = b0 & (0xFFu >> (need + 1));
  for (unsigned k = 1; k < need; ++k) {
    if ((p[k] & 0xC0) != 0x80)
      return 0;
    v = (v << 6) | (p[k] & 0x3Fu);
  }
  if ((need == 3 && (v < 0x800 || (v >= 0xD800 && v <= 0xDFFF))) ||
      (need == 4 && (v < 0x10000 || v > 0x10FFFF)))
    return 0;
  cp = v;
  return need;
}

inline unsigned utf8_size(std::uint32_t cp) {
  return cp < 0x80 ? 1 : cp < 0x800 ? 2 : cp < 0x10000 ? 3 : 4;
}

}  // namespace txt
}  // namespace detail
}  // namespace packbin
