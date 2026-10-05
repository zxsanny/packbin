#include "values.hpp"

#include <cstring>

namespace packbin {
namespace detail {

namespace {

// One unpack walk. The walk recurses once per nesting level through unpack_one and, for
// counted kinds, unpack_items; everything else stays out of that path to keep the stack small.
struct Walk {
  Field const* t;
  Reader& r;
  // The last value read for each flag byte number (0..7).
  std::uint8_t flag_bytes[8];
};

Result unpack_one(Walk& w, std::size_t i, void* obj);

bool ref_value(Walk const& w, Field const& f, void* obj, std::int64_t& out) {
  return f.ref >= 0 && read_int(w.t[f.ref], obj, out);
}

Result get_u16(Reader& r, std::size_t& out, int id) {
  std::uint16_t n = 0;
  Result res = get_num<std::uint16_t>(r, n, false, id);
  out = n;
  return res;
}

// The children of entry i, in order, on the same object.
Result unpack_children(Walk& w, std::size_t i, void* obj) {
  for (std::size_t j = i + 1; j < i + w.t[i].span; j += w.t[j].span) {
    Result res = unpack_one(w, j, obj);
    if (!res.ok())
      return res;
  }
  return Result{};
}

// Bytes, utf8 (after its u16 length) and sized (length from its count).
PACKBIN_NOINLINE
Result unpack_text(Walk& w, std::size_t i, void* obj) {
  Field const& f = w.t[i];
  Reader& r = w.r;
  std::size_t len = f.size;
  if (f.kind == Kind::Utf8) {
    Result res = get_u16(r, len, f.id);
    if (!res.ok())
      return res;
  } else if (f.kind == Kind::Sized) {
    std::int64_t count = 0;
    if (!ref_value(w, f, obj, count) || count < 0)
      return fail(Error::BadValue, r.pos, f.id);
    len = static_cast<std::size_t>(count);
  }
  std::size_t at = r.pos;
  std::uint8_t const* p = nullptr;
  Result res = get_bytes(r, p, len, f.id);
  if (!res.ok())
    return res;
  return store_text(f, member(f, obj), p, len, at);
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
  std::size_t nbytes = (static_cast<std::size_t>(count) * width + 7) / 8;
  std::uint8_t const* p = nullptr;
  Result res = get_bytes(r, p, nbytes, f.id);
  if (!res.ok() || m == nullptr)
    return res;
  if (static_cast<std::size_t>(count) > f.size)
    return fail(Error::TooMany, at, f.id, static_cast<std::size_t>(count));
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
      res = unpack_one(w, j, obj);
  }
  return res;
}

bool same_key(Field const& key, void* a, void* b) {
  std::uint8_t const* da = nullptr;
  std::uint8_t const* db = nullptr;
  std::size_t la = 0, lb = 0;
  text_bytes(key, member(key, a), da, la);
  text_bytes(key, member(key, b), db, lb);
  return la == lb && (la == 0 || std::memcmp(da, db, la) == 0);
}

// A dict entry whose key repeats an earlier entry's key is BadValue at the entry's offset.
PACKBIN_NOINLINE
Result check_new_key(Walk const& w, std::size_t i, void* m, std::size_t at) {
  Field const& f = w.t[i];
  Field const& key = w.t[i + 1];
  if (m == nullptr || key.access == nullptr)
    return Result{};
  std::uint16_t count = *f.count(m);
  void* last = f.item(m, count - 1u);
  for (std::uint16_t k = 0; k + 1u < count; ++k) {
    if (same_key(key, f.item(m, k), last))
      return fail(Error::BadValue, at, f.id);
  }
  return Result{};
}

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
    count = static_cast<std::size_t>(value);
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
// the next Array item. A null array skips the items.
Result unpack_items(Walk& w, std::size_t i, void* m, std::size_t count) {
  Field const& f = w.t[i];
  bool to_end = f.kind == Kind::Repeat;
  for (std::size_t k = 0; to_end ? w.r.pos < w.r.len : k < count; ++k) {
    std::size_t at = w.r.pos;
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
    if (m != nullptr)
      ++*f.count(m);
    if (f.kind == Kind::Dict) {
      Result res = check_new_key(w, i, m, at);
      if (!res.ok())
        return res;
    }
  }
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
      return when_matches(w.t, f, obj) ? unpack_children(w, i, obj) : Result{};
    case Kind::Flags:
      return unpack_flags(w, i, obj);
    case Kind::FlagByte:
      return get_num<std::uint8_t>(w.r, w.flag_bytes[f.size], false, f.id);
    case Kind::FlagBit:
      if (w.flag_bytes[w.t[f.ref].size] & (1u << f.bit))
        return unpack_one(w, i + 1, obj);
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
