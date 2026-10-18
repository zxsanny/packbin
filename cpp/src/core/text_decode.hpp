#pragma once

// Compact text decoder (contract compact-text 1.0.0, "Decoding"). It reads the payload bit by
// bit, writes UTF-8 into a bounded sink, and holds no state beyond a few integers: the work and
// the output are bounded by the payload length (at most 6 bytes of text per payload byte + 8).

#include "text.hpp"

#include <cstring>

namespace packbin {
namespace detail {
namespace txt {

// Where decoded UTF-8 goes. `out` null: the text is checked and counted only. The text that does
// not fit `cap` is still checked and counted (`over`), so the error can name its full size.
struct Sink {
  std::uint8_t* out;
  std::size_t cap;
  std::size_t len = 0;
  bool over = false;

  // False when the text would pass the 65,535 byte limit.
  bool put(std::uint8_t const* bytes, std::size_t n) {
    if (n > kMaxText - len)
      return false;
    if (out != nullptr && !over && n <= cap - len)
      std::memcpy(out + len, bytes, n);
    else if (out != nullptr)
      over = true;
    len += n;
    return true;
  }

  bool put_cp(std::uint32_t cp) {
    std::uint8_t b[4];
    unsigned n = utf8_size(cp);
    if (n == 1) {
      b[0] = static_cast<std::uint8_t>(cp);
    } else if (n == 2) {
      b[0] = static_cast<std::uint8_t>(0xC0 | (cp >> 6));
      b[1] = static_cast<std::uint8_t>(0x80 | (cp & 0x3F));
    } else if (n == 3) {
      b[0] = static_cast<std::uint8_t>(0xE0 | (cp >> 12));
      b[1] = static_cast<std::uint8_t>(0x80 | ((cp >> 6) & 0x3F));
      b[2] = static_cast<std::uint8_t>(0x80 | (cp & 0x3F));
    } else {
      b[0] = static_cast<std::uint8_t>(0xF0 | (cp >> 18));
      b[1] = static_cast<std::uint8_t>(0x80 | ((cp >> 12) & 0x3F));
      b[2] = static_cast<std::uint8_t>(0x80 | ((cp >> 6) & 0x3F));
      b[3] = static_cast<std::uint8_t>(0x80 | (cp & 0x3F));
    }
    return put(b, n);
  }
};

namespace {

// The symbol whose code starts at bit `pos` in mode `mode` (canonical decoding: the codes of one
// length are consecutive). Returns -1 when the bits run out inside the code.
int next_symbol(unsigned mode, std::uint8_t const* p, std::size_t pos, std::size_t total,
                unsigned& used) {
  unsigned code = 0;
  unsigned first = 0;
  unsigned index = 0;
  for (unsigned len = 1; len <= kMaxCode; ++len) {
    std::size_t bit = pos + len - 1;
    if (bit >= total)
      return -1;
    code = (code << 1) | ((p[bit >> 3] >> (7 - (bit & 7))) & 1u);
    unsigned count = kTab.count[mode][len];
    if (code - first < count) {
      used = len;
      return kTab.symbol[mode][index + (code - first)];
    }
    index += count;
    first = (first + count) << 1;
  }
  return -1;
}

std::uint8_t byte_at(std::uint8_t const* p, std::size_t bit) {
  unsigned shift = static_cast<unsigned>(bit & 7);
  std::size_t i = bit >> 3;
  if (shift == 0)
    return p[i];
  return static_cast<std::uint8_t>((p[i] << shift) | (p[i + 1] >> (8 - shift)));
}

// The ESC payload at bit `pos`: 1 to 4 UTF-8 bytes of 8 bits each, no alignment. Returns the bytes
// read (0 when cut short or invalid).
unsigned read_escaped(std::uint8_t const* p, std::size_t pos, std::size_t total,
                      std::uint8_t (&b)[4]) {
  if (pos + 8 > total)
    return 0;
  b[0] = byte_at(p, pos);
  unsigned n = b[0] < 0x80 ? 1 : (b[0] >> 5) == 6 ? 2 : (b[0] >> 4) == 14 ? 3 : (b[0] >> 3) == 30 ? 4 : 0;
  if (n == 0 || pos + 8 * n > total)
    return 0;
  for (unsigned k = 1; k < n; ++k)
    b[k] = byte_at(p, pos + 8 * k);
  std::uint32_t cp = 0;
  return decode_utf8(b, n, cp) == n ? n : 0;
}

// Decodes the symbols of a compact payload of `n` bytes (n >= 1, start mode 0 to 3).
bool decode_compact(std::uint8_t const* p, std::size_t n, Sink& sink) {
  unsigned first = p[0];
  unsigned mode = (first >> 2) & 7;
  unsigned pad = first >> 5;
  std::size_t total = 8 * n - pad;
  if (total < kHeaderBits || (pad != 0 && (p[n - 1] & ((1u << pad) - 1)) != 0))
    return false;
  std::size_t pos = kHeaderBits;
  bool lock = false;
  bool cap = false;
  while (pos < total) {
    unsigned used = 0;
    int sym = next_symbol(mode, p, pos, total, used);
    if (sym < 0)
      return false;
    pos += used;
    Layout const& lay = kLayout[mode];
    unsigned s = static_cast<unsigned>(sym);
    if (s == lay.esc) {
      std::uint8_t b[4];
      unsigned got = cap ? 0 : read_escaped(p, pos, total, b);
      if (got == 0 || !sink.put(b, got))
        return false;
      pos += 8 * got;
    } else if (s >= lay.sw && s < lay.sw + 3u) {
      if (cap)
        return false;
      unsigned j = s - lay.sw;
      mode = j < mode ? j : j + 1;
    } else if (mode != kNumMode && s == lay.cap) {
      if (lock || cap)
        return false;
      cap = true;
    } else if (mode != kNumMode && s == lay.lock) {
      if (cap)
        return false;
      lock = !lock;
    } else if (s < lay.letters) {
      std::uint32_t cp = kTab.lower[mode][s];
      std::uint32_t up = kTab.upper[mode][s];
      if (cap) {
        if (up == 0)
          return false;
        cp = up;
        cap = false;
      } else if (lock && up != 0) {
        cp = up;
      }
      if (!sink.put_cp(cp))
        return false;
    } else {
      if (cap)
        return false;
      std::uint32_t cp = mode == kNumMode ? tbl::kNumset[s] : tbl::kShared[s - lay.shared];
      if (!sink.put_cp(cp))
        return false;
    }
  }
  return !cap;
}

bool valid_utf8(std::uint8_t const* p, std::size_t n) {
  for (std::size_t at = 0; at < n;) {
    std::uint32_t cp = 0;
    unsigned k = decode_utf8(p + at, n - at, cp);
    if (k == 0)
      return false;
    at += k;
  }
  return true;
}

}  // namespace

// True when the payload starts raw UTF-8 mode with the right prefix byte and the text is valid.
inline bool is_raw(std::uint8_t first) { return ((first >> 2) & 7) == kRawMode; }

// Checks a raw payload (start mode 4): prefix byte, valid UTF-8, at most 65,535 bytes. The text
// is `p + 1`, `n - 1` bytes.
inline bool check_raw(std::uint8_t const* p, std::size_t n) {
  return p[0] == kRawPrefix && n - 1 <= kMaxText && valid_utf8(p + 1, n - 1);
}

// Decodes one payload of `n` bytes (n >= 1) into the sink. False: the payload is refused.
inline bool decode_payload(std::uint8_t const* p, std::size_t n, Sink& sink) {
  unsigned mode = (p[0] >> 2) & 7;
  if (mode > kRawMode)
    return false;
  if (mode == kRawMode)
    return check_raw(p, n) && sink.put(p + 1, n - 1);
  return decode_compact(p, n, sink);
}

}  // namespace txt
}  // namespace detail
}  // namespace packbin
