#include "values.hpp"
#include "text_count.hpp"
#ifndef PACKBIN_NO_TEXT
#include "text_decode.hpp"
#endif

#include "packbin/platform.hpp"

namespace packbin {
namespace detail {

namespace {

// Flag byte numbers are 0..7.
constexpr std::size_t kFlagBytes = 8;

// One unpack walk. The walk recurses once per nesting level through unpack_one and, for
// counted kinds, unpack_items; everything else stays out of that path to keep the stack small.
struct Walk {
  Field const* t;
  Reader& r;
  // The last value read for each flag byte number (0..7) in the scope being read.
  std::uint8_t flag_bytes[kFlagBytes];
};

Result unpack_one(Walk& w, std::size_t i, void* obj);

bool ref_value(Walk const& w, Field const& f, void* obj, std::int64_t& out) {
  return f.ref >= 0 && read_int(w.t[f.ref], obj, out);
}

// A count read from the packet is a non-negative 64-bit value. Where size_t is 32 bits it must
// not wrap to a small number: clamp it, so the ordinary short-packet or capacity checks fail it.
constexpr std::size_t kCountCap = static_cast<std::size_t>(-1) - 2;

std::size_t clamp_count(std::int64_t v) {
  return static_cast<std::uint64_t>(v) > kCountCap ? kCountCap : static_cast<std::size_t>(v);
}

Result get_u16(Reader& r, std::size_t& out, int id) {
  std::uint16_t n = 0;
  Result res = get_num<std::uint16_t>(r, n, false, id);
  out = n;
  return res;
}

// True when a flag byte is read anywhere in t[begin, end).
bool reads_flag_byte(Field const* t, std::size_t begin, std::size_t end) {
  for (std::size_t k = begin; k < end; ++k)
    if (t[k].kind == Kind::FlagByte)
      return true;
  return false;
}

Result unpack_children(Walk& w, std::size_t i, void* obj);

bool flag_bit_set(Walk const& w, Field const& f) {
  return (w.flag_bytes[w.t[f.ref].size] & (1u << f.bit)) != 0;
}

// Runs Fn, then brings back the flag bytes of the scope around it, so a flag byte read inside is
// not seen after it: a `when`, a `flags` member or the child of a flag bit (an error ends the whole
// unpack).
template <Result (*Fn)(Walk&, std::size_t, void*)>
PACKBIN_NOINLINE
Result with_outer_flags(Walk& w, std::size_t i, void* obj) {
  std::uint8_t outer[kFlagBytes];
  std::memcpy(outer, w.flag_bytes, sizeof(outer));
  Result res = Fn(w, i, obj);
  std::memcpy(w.flag_bytes, outer, sizeof(outer));
  return res;
}

// The children of entry i, in order, on the same object. Two kinds of child are entered here and not
// through unpack_one: a `when` (skipped when it does not hold; when it holds and reads no flag byte
// its children follow it in this loop; when it reads a flag byte, a nested call of this function
// inside its own flag scope) and a flag bit (its child inside the flag scope). A chain of such
// entries then costs the stack of this function and with_outer_flags per flag scope. unpack_table,
// a `times` round and a flags member still reach these kinds through unpack_one.
Result unpack_children(Walk& w, std::size_t i, void* obj) {
  std::size_t end = i + w.t[i].span;
  for (std::size_t j = i + 1; j < end;) {
    Field const& f = w.t[j];
    if (f.kind == Kind::When) {
      if (!when_matches(w.t, f, obj)) {
        j += f.span;
        continue;
      }
      if (!reads_flag_byte(w.t, j + 1, j + f.span)) {
        ++j;
        continue;
      }
      Result res = with_outer_flags<unpack_children>(w, j, obj);
      if (!res.ok())
        return res;
      j += f.span;
      continue;
    }
    if (f.kind == Kind::FlagBit) {
      if (flag_bit_set(w, f)) {
        Result res = with_outer_flags<unpack_one>(w, j + 1, obj);
        if (!res.ok())
          return res;
      }
      j += f.span;
      continue;
    }
    Result res = unpack_one(w, j, obj);
    if (!res.ok())
      return res;
    j += f.span;
  }
  return Result{};
}

#ifndef PACKBIN_NO_TEXT
// A string's payload `p` (`count` bytes, the count at `at`, the payload at `body`) into a Text<N>,
// or checked and dropped when the field is unbound. A text that does not fit is TooMany with its
// full size and the member empty.
PACKBIN_NOINLINE
Result decode_text(Field const& f, void* m, std::uint8_t const* p, std::size_t count,
                   std::size_t at, std::size_t body) {
  if (count == 0) {
    if (m != nullptr)
      clear_text(f, m);
    return Result{};
  }
  txt::Sink sink{nullptr, txt::kMaxText};
  if (m != nullptr && f.fixed()) {
    sink.out = static_cast<std::uint8_t*>(m) + sizeof(std::uint16_t);
    sink.cap = f.size;
  }
  if (!txt::decode_payload(p, count, sink)) {
    if (m != nullptr)
      clear_text(f, m);
    return fail(Error::BadValue, at, f.id);
  }
  if (sink.over) {
    if (m != nullptr)
      clear_text(f, m);
    return fail(Error::TooMany, body, f.id, sink.len);
  }
  if (m != nullptr)
    *static_cast<std::uint16_t*>(m) = static_cast<std::uint16_t>(sink.len);
  return Result{};
}
#endif

// Bytes, sized (length from its count) and utf8 (after its count). A utf8 member takes the
// decoded text (a Text<N>) or the payload as it is (a Packed, borrowed from the input); an
// unbound string is checked by the codec, or only skipped by its count in a PACKBIN_NO_TEXT
// build.
PACKBIN_NOINLINE
Result unpack_text(Walk& w, std::size_t i, void* obj) {
  Field const& f = w.t[i];
  Reader& r = w.r;
  std::size_t at = r.pos;
  std::size_t len = f.size;
  if (f.kind == Kind::Utf8) {
    Result res = txt::get_count(r, len, f.id);
    if (!res.ok())
      return res;
  } else if (f.kind == Kind::Sized) {
    std::int64_t count = 0;
    if (!ref_value(w, f, obj, count) || count < 0)
      return fail(Error::BadValue, r.pos, f.id);
    len = clamp_count(count);
  }
  std::size_t body = r.pos;
  std::uint8_t const* p = nullptr;
  Result res = get_bytes(r, p, len, f.id);
  if (!res.ok())
    return res;
  void* m = member(f, obj);
  if (f.kind == Kind::Utf8 && !f.opaque()) {
#ifdef PACKBIN_NO_TEXT
    return m == nullptr ? Result{} : fail(Error::SchemeInvalid, at, f.id);
#else
    return decode_text(f, m, p, len, at, body);
#endif
  }
  return store_text(f, m, p, len, body);
}

// Bits (width 1) or packed numbers (width 1 or 2) into an Array<std::uint8_t, N>.
PACKBIN_NOINLINE
Result unpack_small(Walk& w, std::size_t i, void* obj) {
  Field const& f = w.t[i];
  Reader& r = w.r;
  void* m = member(f, obj);
  std::int64_t count = 0;
  if (!ref_value(w, f, obj, count))
    return fail(Error::BadValue, r.pos, f.id);
  unsigned width = f.kind == Kind::Bits ? 1 : f.width;
  if (f.kind == Kind::Packed)
    count += f.bias;
  if (count < 0)
    return fail(Error::BadValue, r.pos, f.id);
  std::size_t at = r.pos;
  // count <= INT64_MAX and width <= 2, so the bit count fits in 64 bits.
  std::uint64_t nbits = static_cast<std::uint64_t>(count) * width;
  std::size_t nbytes = clamp_count(static_cast<std::int64_t>(nbits / 8 + (nbits % 8 != 0)));
  std::uint8_t const* p = nullptr;
  Result res = get_bytes(r, p, nbytes, f.id);
  if (!res.ok() || m == nullptr)
    return res;
  if (count > static_cast<std::int64_t>(f.size))
    return fail(Error::TooMany, at, f.id, clamp_count(count));
  unsigned per = 8 / width;
  unsigned mask = (1u << width) - 1;
  for (std::int64_t k = 0; k < count; ++k) {
    auto byte = p[static_cast<std::size_t>(k) / per];
    auto shift = (static_cast<unsigned>(k) % per) * width;
    *static_cast<std::uint8_t*>(f.item(m, static_cast<std::size_t>(k))) =
        static_cast<std::uint8_t>((byte >> shift) & mask);
  }
  *f.count(m) = static_cast<std::uint16_t>(count);
  return res;
}

PACKBIN_NOINLINE
Result unpack_u2(Walk& w, std::size_t i, void* obj) {
  Field const& f = w.t[i];
  std::size_t k = f.span - 1;
  std::uint8_t const* p = nullptr;
  Result res = get_bytes(w.r, p, (k + 3) / 4, f.id);
  if (!res.ok())
    return res;
  for (std::size_t c = 0; c < k; ++c) {
    Field const& child = w.t[i + 1 + c];
    void* m = member(child, obj);
    auto value = static_cast<std::uint8_t>((p[c / 4] >> ((c % 4) * 2)) & 3);
    if (m != nullptr)
      store_member<std::uint8_t>(child, m, value);
  }
  return res;
}

PACKBIN_NOINLINE
Result unpack_flags(Walk& w, std::size_t i, void* obj) {
  Field const* t = w.t;
  std::uint8_t byte = 0;
  Result res = get_num<std::uint8_t>(w.r, byte, false, t[i].id);
  unsigned k = 0;
  for (std::size_t j = i + 1; res.ok() && j < i + t[i].span; j += t[j].span, ++k) {
    if (byte & (1u << k))
      res = with_outer_flags<unpack_one>(w, j, obj);
  }
  return res;
}

#ifndef PACKBIN_NO_TEXT
constexpr std::size_t kNoKey = static_cast<std::size_t>(-1);

// The payload of the string whose count starts at `at` (it has been read once, so the count is valid).
void payload_at(Reader const& r, std::size_t at, std::uint8_t const*& p, std::size_t& n) {
  Reader s{r.data, r.len, at};
  txt::get_count(s, n, 0);
  p = s.data + s.pos;
}

// A dict key must sort after the key before it by its decoded UTF-8 bytes (contract compact-text,
// invariants): an equal key repeats it, a smaller one is out of order. Both are BadValue at the
// entry's offset. The keys are compared from their payloads, so a dict that is not bound and a key
// longer than the bound member are checked the same way, with no storage for the previous key.
PACKBIN_NOINLINE
Result check_key_order(Walk const& w, std::size_t i, std::size_t prev, std::size_t at) {
  std::uint8_t const* a = nullptr;
  std::uint8_t const* b = nullptr;
  std::size_t na = 0, nb = 0;
  payload_at(w.r, prev, a, na);
  payload_at(w.r, at, b, nb);
  return txt::compare_payloads(a, na, b, nb) < 0 ? Result{} : fail(Error::BadValue, at, w.t[i].id);
}
#endif

// How many items a times, list or dict holds (read from its count field or the wire). A
// repeat reads until the packet ends. SIZE_MAX means the unpack already failed with `out`.
PACKBIN_NOINLINE
std::size_t item_count(Walk& w, std::size_t i, void* obj, void* m, Result& out) {
  Field const& f = w.t[i];
  constexpr std::size_t stop = static_cast<std::size_t>(-1);
  std::size_t count = 0;
  if (f.kind == Kind::Repeat)
    return stop - 1;
  if (f.kind == Kind::Times) {
    std::int64_t value = 0;
    if (!ref_value(w, f, obj, value) || value < 0) {
      out = fail(Error::BadValue, w.r.pos, f.id);
      return stop;
    }
    count = clamp_count(value);
  } else {
    out = get_u16(w.r, count, f.id);
    if (!out.ok())
      return stop;
  }
  if (m != nullptr && count > f.size) {
    out = fail(Error::TooMany, w.r.pos, f.id, count);
    return stop;
  }
  return count;
}

// Up to `count` items (a repeat: until the packet ends) of the children of entry i, each into
// the next Array item. A null array skips the items. Kept out of line: inlined into unpack_one it
// grows the frame of every nesting level, not only of the counted ones.
PACKBIN_NOINLINE
Result unpack_items(Walk& w, std::size_t i, void* m, std::size_t count) {
  Field const& f = w.t[i];
  bool to_end = f.kind == Kind::Repeat;
  // The rounds read their own flag bytes, which may reuse the numbers of the outer scope; the
  // outer values come back when the container ends (an error ends the whole unpack).
  std::uint8_t outer[kFlagBytes];
  std::memcpy(outer, w.flag_bytes, sizeof(outer));
#ifndef PACKBIN_NO_TEXT
  std::size_t prev_key = kNoKey;
#endif
  for (std::size_t k = 0; to_end ? w.r.pos < w.r.len : k < count; ++k) {
    std::size_t at = w.r.pos;
    std::memset(w.flag_bytes, 0, sizeof(w.flag_bytes));
    void* item = nullptr;
    if (m != nullptr) {
      std::uint16_t filled = *f.count(m);
      if (filled >= f.size)
        return fail(Error::TooMany, at, f.id, static_cast<std::size_t>(filled) + 1);
      item = f.item(m, filled);
      clear_scope(w.t, i + 1, i + f.span, item);
    }
    for (std::size_t j = i + 1; j < i + f.span; j += w.t[j].span) {
      Result res = unpack_one(w, j, item);
      if (!res.ok())
        return res;
    }
    // A round that reads nothing reads nothing every time. A repeat would never reach the end:
    // it adds no item and the bytes left are reported as trailing. An unbound times would only
    // spin through its count.
    if (w.r.pos == at && (to_end || m == nullptr)) {
      std::memcpy(w.flag_bytes, outer, sizeof(outer));
      return Result{};
    }
    if (m != nullptr)
      ++*f.count(m);
#ifndef PACKBIN_NO_TEXT
    if (f.kind == Kind::Dict) {
      if (prev_key != kNoKey) {
        Result res = check_key_order(w, i, prev_key, at);
        if (!res.ok())
          return res;
      }
      prev_key = at;
    }
#endif
  }
  std::memcpy(w.flag_bytes, outer, sizeof(outer));
  return Result{};
}

Result unpack_one(Walk& w, std::size_t i, void* obj) {
  Field const& f = w.t[i];
  if (is_number(f.kind))
    return get_number(f, member(f, obj), w.r);
  switch (f.kind) {
    case Kind::Bool:
      set_bool(f, member(f, obj));
      return Result{};
    case Kind::Bytes:
    case Kind::Utf8:
    case Kind::Sized:
      return unpack_text(w, i, obj);
    case Kind::When:
      return when_matches(w.t, f, obj) ? with_outer_flags<unpack_children>(w, i, obj) : Result{};
    case Kind::Flags:
      return unpack_flags(w, i, obj);
    case Kind::FlagByte:
      return get_num<std::uint8_t>(w.r, w.flag_bytes[f.size], false, f.id);
    case Kind::FlagBit:
      if (flag_bit_set(w, f))
        return with_outer_flags<unpack_one>(w, i + 1, obj);
      return Result{};
    case Kind::Group:
      if (f.span == 1) {
        set_bool(f, member(f, obj));
        return Result{};
      }
      return unpack_children(w, i, obj);
    case Kind::U2:
      return unpack_u2(w, i, obj);
    case Kind::Bits:
    case Kind::Packed:
      return unpack_small(w, i, obj);
    case Kind::Repeat:
    case Kind::Times:
    case Kind::List:
    case Kind::Dict: {
      void* m = member(f, obj);
      Result res{};
      std::size_t count = item_count(w, i, obj, m, res);
      if (count == static_cast<std::size_t>(-1))
        return res;
      return unpack_items(w, i, m, count);
    }
    default:
      break;
  }
  return fail(Error::SchemeInvalid, w.r.pos, f.id);
}

}  // namespace

Result unpack_table(Field const* t, std::size_t n, void* row, Reader& r) {
  clear_scope(t, 0, n, row);
  Walk w{t, r, {}};
  for (std::size_t j = 0; j < n; j += t[j].span) {
    Result res = unpack_one(w, j, row);
    if (!res.ok())
      return res;
  }
  return finish(r);
}

}  // namespace detail
}  // namespace packbin
