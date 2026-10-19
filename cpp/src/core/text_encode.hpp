#pragma once

// Compact text encoder (contract compact-text 1.0.0, "Encoding"): the optimal parse over the
// 8 states (mode, capital lock) with the contract's tie-break, in the caller's scratch.

#include "text.hpp"
#include "text_count.hpp"

#include "packbin/platform.hpp"

namespace packbin {
namespace detail {
namespace txt {

namespace {

// How a character can be written in each text mode: the index of the letter, the capital and the
// shared or number character it is, or -1.
struct Cls {
  std::int8_t low[3];
  std::int8_t up[3];
  std::int8_t sh;
  std::int8_t num;
};

int find(std::uint32_t const* a, unsigned n, std::uint32_t cp) {
  for (unsigned i = 0; i < n; ++i)
    if (a[i] == cp)
      return static_cast<int>(i);
  return -1;
}

Cls classify(std::uint32_t cp) {
  Cls c{{-1, -1, -1}, {-1, -1, -1}, -1, -1};
  if (cp < 0x80) {
    c.low[2] = static_cast<std::int8_t>(find(tbl::kEn, 27, cp));
    c.up[2] = static_cast<std::int8_t>(find(tbl::kEnUpper, 26, cp));
    if (cp == 39)
      c.low[0] = static_cast<std::int8_t>(find(tbl::kUa, 34, cp));
    c.sh = static_cast<std::int8_t>(find(tbl::kShared, 32, cp));
    c.num = static_cast<std::int8_t>(find(tbl::kNumset, 15, cp));
  } else if (cp >= 0x400 && cp < 0x500) {
    c.low[0] = static_cast<std::int8_t>(find(tbl::kUa, 34, cp));
    c.up[0] = static_cast<std::int8_t>(find(tbl::kUaUpper, 33, cp));
    c.low[1] = static_cast<std::int8_t>(find(tbl::kRu, 33, cp));
    c.up[1] = static_cast<std::int8_t>(find(tbl::kRuUpper, 33, cp));
  }
  return c;
}

// An edge that consumes the character. `kind`: 0 one symbol, 1 CAP then the letter `sym`, 2 ESC
// then the UTF-8 bytes.
struct Edge {
  std::uint8_t first;
  std::uint8_t kind;
  std::uint8_t sym;
  std::uint8_t bits;
};

// A control edge: no character is consumed, the state changes to `to` = mode * 2 + lock.
struct Ctrl {
  std::uint8_t first;
  std::uint8_t bits;
  std::uint8_t to;
};

constexpr unsigned kStates = 8;
constexpr unsigned kMaxCtrl = 4;

unsigned edges_of(Cls const& c, unsigned state, unsigned nbytes, Edge (&out)[3]) {
  unsigned m = state >> 1;
  unsigned lock = state & 1;
  Layout const& lay = kLayout[m];
  std::uint8_t const* ln = kTab.length[m];
  unsigned n = 0;
  if (m < kNumMode) {
    if (c.low[m] >= 0 && (lock == 0 || kTab.upper[m][c.low[m]] == 0)) {
      auto s = static_cast<std::uint8_t>(c.low[m]);
      out[n++] = Edge{s, 0, s, ln[s]};
    }
    if (c.up[m] >= 0) {
      auto s = static_cast<std::uint8_t>(c.up[m]);
      if (lock != 0)
        out[n++] = Edge{s, 0, s, ln[s]};
      else
        out[n++] = Edge{lay.cap, 1, s, static_cast<std::uint8_t>(ln[lay.cap] + ln[s])};
    }
    if (c.sh >= 0) {
      auto s = static_cast<std::uint8_t>(lay.shared + c.sh);
      out[n++] = Edge{s, 0, s, ln[s]};
    }
  } else if (c.num >= 0) {
    auto s = static_cast<std::uint8_t>(c.num);
    out[n++] = Edge{s, 0, s, ln[s]};
  }
  out[n++] = Edge{lay.esc, 2, lay.esc, static_cast<std::uint8_t>(ln[lay.esc] + 8 * nbytes)};
  return n;
}

constexpr unsigned ctrl_of(unsigned state, Ctrl (&out)[kMaxCtrl]) {
  unsigned m = state >> 1;
  unsigned lock = state & 1;
  Layout const& lay = kLayout[m];
  std::uint8_t const* ln = kTab.length[m];
  unsigned n = 0;
  for (unsigned j = 0; j < 3; ++j) {
    unsigned target = j < m ? j : j + 1;
    auto s = static_cast<std::uint8_t>(lay.sw + j);
    out[n++] = Ctrl{s, ln[s], static_cast<std::uint8_t>(target * 2 + lock)};
  }
  if (m < kNumMode)
    out[n++] = Ctrl{lay.lock, ln[lay.lock], static_cast<std::uint8_t>(m * 2 + (lock ^ 1))};
  return n;
}

struct ControlSet {
  Ctrl edge[kStates][kMaxCtrl];
  std::uint8_t count[kStates];
};

constexpr ControlSet make_controls() {
  ControlSet set{};
  for (unsigned st = 0; st < kStates; ++st) {
    Ctrl tmp[kMaxCtrl] = {};
    set.count[st] = static_cast<std::uint8_t>(ctrl_of(st, tmp));
    for (unsigned k = 0; k < set.count[st]; ++k)
      set.edge[st][k] = tmp[k];
  }
  return set;
}

// Read-only: the control edges depend on the tables alone, so they are not built on the stack.
constexpr ControlSet kCtl = make_controls();

// The cost of finishing from character `i` in each state, kept in the scratch as a minimum
// (`base`) and 8 byte deltas: from any state another is at most three control edges away
// (3 * 16 bits), so a delta always fits a byte. Position `n` (the end) costs 0 everywhere and is
// not stored.
struct Costs {
  std::uint32_t* w;
  std::size_t n;

  // The cost of the cheapest state from character `i`.
  std::uint32_t base(std::size_t i) const { return i >= n ? 0 : w[i * kScratchWordsPerChar]; }

  // How much dearer state `s` is than the cheapest one.
  std::uint32_t delta(std::size_t i, unsigned s) const {
    if (i >= n)
      return 0;
    return (w[i * kScratchWordsPerChar + 1 + (s >> 2)] >> (8 * (s & 3))) & 0xFFu;
  }

  std::uint32_t at(std::size_t i, unsigned s) const { return base(i) + delta(i, s); }

  // `rel` holds the deltas, with a minimum of 0.
  void put(std::size_t i, std::uint32_t lowest, std::uint8_t const (&rel)[kStates]) const {
    std::uint32_t* cell = w + i * kScratchWordsPerChar;
    cell[0] = lowest;
    cell[1] = 0;
    cell[2] = 0;
    for (unsigned s = 0; s < kStates; ++s)
      cell[1 + (s >> 2)] |= static_cast<std::uint32_t>(rel[s]) << (8 * (s & 3));
  }
};

// Walks the validated UTF-8 backwards: the code point that ends at `end`.
unsigned step_back(std::uint8_t const* s, std::size_t& end, std::uint32_t& cp) {
  std::size_t at = end;
  do {
    --at;
  } while ((s[at] & 0xC0) == 0x80);
  unsigned n = decode_utf8(s + at, end - at, cp);
  end = at;
  return n;
}

// Fills the scratch from the end of the text. Returns the cost of the whole text from the best
// start mode, which it stores in `start`.
std::uint32_t solve(std::uint8_t const* s, std::size_t len, std::size_t chars,
                    Costs const& costs, unsigned& start) {
  std::size_t end = len;
  for (std::size_t i = chars; i-- > 0;) {
    std::uint32_t cp = 0;
    unsigned nbytes = step_back(s, end, cp);
    Cls c = classify(cp);
    // Costs are kept relative to the cheapest state of the next character (the end costs 0): a
    // state's cost is its cheapest edge plus the delta of the state it leads to.
    std::uint8_t rel[kStates];
    for (unsigned st = 0; st < kStates; ++st) {
      Edge e[3];
      unsigned ne = edges_of(c, st, nbytes, e);
      unsigned best = e[0].bits;
      for (unsigned k = 1; k < ne; ++k)
        best = e[k].bits < best ? e[k].bits : best;
      rel[st] = static_cast<std::uint8_t>(best + costs.delta(i + 1, st));
    }
    for (bool changed = true; changed;) {
      changed = false;
      for (unsigned st = 0; st < kStates; ++st) {
        for (unsigned k = 0; k < kCtl.count[st]; ++k) {
          unsigned v = kCtl.edge[st][k].bits + rel[kCtl.edge[st][k].to];
          if (v < rel[st]) {
            rel[st] = static_cast<std::uint8_t>(v);
            changed = true;
          }
        }
      }
    }
    std::uint8_t lo = rel[0];
    for (unsigned st = 1; st < kStates; ++st)
      lo = rel[st] < lo ? rel[st] : lo;
    for (unsigned st = 0; st < kStates; ++st)
      rel[st] = static_cast<std::uint8_t>(rel[st] - lo);
    costs.put(i, costs.base(i + 1) + lo, rel);
  }
  // The start mode is the one with the cheapest unlocked state; a tie goes to the smaller mode.
  start = 0;
  for (unsigned m = 1; m < 4; ++m)
    start = costs.at(0, m * 2) < costs.at(0, start * 2) ? m : start;
  return costs.at(0, start * 2);
}

// Writes bits, most significant first, into a zeroed buffer.
struct BitOut {
  std::uint8_t* p;
  std::size_t pos;

  void put(unsigned value, unsigned n) {
    while (n != 0) {
      unsigned room = 8 - static_cast<unsigned>(pos & 7);
      unsigned take = n < room ? n : room;
      unsigned bits = (value >> (n - take)) & ((1u << take) - 1);
      p[pos >> 3] = static_cast<std::uint8_t>(p[pos >> 3] | (bits << (room - take)));
      pos += take;
      n -= take;
    }
  }
};

// Writes the symbols of the winning parse: from the state, the edge whose cost plus the cost of
// the rest equals the cheapest, the smallest first symbol among them.
void write_parse(std::uint8_t const* s, std::size_t len, std::size_t chars, unsigned state,
                 Costs const& costs, BitOut& out) {
  std::size_t at = 0;
  for (std::size_t i = 0; i < chars;) {
    std::uint32_t cp = 0;
    unsigned nbytes = decode_utf8(s + at, len - at, cp);
    Cls c = classify(cp);
    std::uint32_t want = costs.at(i, state);
    unsigned m = state >> 1;
    Edge e[3];
    unsigned ne = edges_of(c, state, nbytes, e);
    int best = -1;
    bool is_ctrl = false;
    unsigned best_first = 256;
    for (unsigned k = 0; k < kCtl.count[state]; ++k) {
      Ctrl const& x = kCtl.edge[state][k];
      if (x.first < best_first && x.bits + costs.at(i, x.to) == want) {
        best = static_cast<int>(k);
        is_ctrl = true;
        best_first = x.first;
      }
    }
    for (unsigned k = 0; k < ne; ++k) {
      if (e[k].first < best_first && e[k].bits + costs.at(i + 1, state) == want) {
        best = static_cast<int>(k);
        is_ctrl = false;
        best_first = e[k].first;
      }
    }
    std::uint8_t const* ln = kTab.length[m];
    if (is_ctrl) {
      Ctrl const& x = kCtl.edge[state][best];
      out.put(kTab.code[m][x.first], ln[x.first]);
      state = x.to;
      continue;
    }
    Edge const& x = e[best];
    if (x.kind == 1)  // CAP is the first symbol of this edge, the letter follows
      out.put(kTab.code[m][x.first], ln[x.first]);
    out.put(kTab.code[m][x.sym], ln[x.sym]);
    if (x.kind == 2) {
      for (unsigned b = 0; b < nbytes; ++b)
        out.put(s[at + b], 8);
    }
    at += nbytes;
    ++i;
  }
}

// Writes the compact payload of `size` bytes for the parse that starts in `start`.
void write_compact(std::uint8_t* p, std::size_t size, std::size_t bits, unsigned start,
                   std::uint8_t const* s, std::size_t len, std::size_t chars,
                   Costs const& costs) {
  std::memset(p, 0, size);
  BitOut out{p, 0};
  out.put(static_cast<unsigned>(size * 8 - bits), 3);
  out.put(start, 3);
  write_parse(s, len, chars, start * 2, costs, out);
}

Result put_field(Writer& w, std::size_t size, int id, std::uint8_t** payload) {
  unsigned head = varint_size(size);
  if (w.cap - w.len < head + size)
    return fail(Error::BufferFull, w.len, id, head + size);
  *payload = put_varint(w.data + w.len, size);
  w.len += head + size;
  return Result{Error::Ok, w.len};
}

}  // namespace

// Writes one string field (count, payload) for the UTF-8 text `s`. Nothing is written when the
// text is not valid UTF-8 or too long (BadValue), the scratch is too small (ScratchTooSmall,
// `needed` the scratch bytes) or the buffer is full (BufferFull, `needed` the field bytes).
inline Result encode_field(Writer& w, ScratchRef const& scratch, int id, std::uint8_t const* s,
                           std::size_t len) {
  if (len > kMaxText)
    return fail(Error::BadValue, w.len, id);
  std::uint8_t* p = nullptr;
  if (len == 0)
    return put_field(w, 0, id, &p);
  // One pass: validate, count the characters and bound the compact size from below. A character
  // costs at least the shortest code, and one outside the tables at least ESC and its bytes.
  std::size_t chars = 0;
  std::size_t floor_bits = kHeaderBits;
  for (std::size_t at = 0; at < len; ++chars) {
    std::uint32_t cp = 0;
    unsigned n = decode_utf8(s + at, len - at, cp);
    if (n == 0)
      return fail(Error::BadValue, w.len, id);
    at += n;
    floor_bits += (cp < 0x80 || (cp >= 0x400 && cp < 0x500)) ? kMinLength : kMinEsc + 8 * n;
  }
  std::size_t raw = len + 1;
  if ((floor_bits + 7) / 8 < raw) {
    if (scratch.count / kScratchWordsPerChar < chars)
      return fail(Error::ScratchTooSmall, w.len, id, chars * kScratchWordsPerChar * 4);
    Costs costs{scratch.words, chars};
    unsigned start = 0;
    std::size_t bits = kHeaderBits + solve(s, len, chars, costs, start);
    std::size_t size = (bits + 7) / 8;
    if (size < raw) {
      Result r = put_field(w, size, id, &p);
      if (r.ok())
        write_compact(p, size, bits, start, s, len, chars, costs);
      return r;
    }
  }
  Result r = put_field(w, raw, id, &p);
  if (r.ok()) {
    p[0] = kRawPrefix;
    std::memcpy(p + 1, s, len);
  }
  return r;
}

}  // namespace txt
}  // namespace detail
}  // namespace packbin
