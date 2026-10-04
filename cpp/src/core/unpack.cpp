#include "values.hpp"

#include <cstring>

namespace packbin {
namespace detail {

namespace {

struct Walk {
  Field const* t;
  Reader& r;
  // The last value read for each flag byte number (0..7).
  std::uint8_t flag_bytes[8];
};

Result unpack_one(Walk& w, std::size_t i, void* obj);

Result unpack_range(Walk& w, std::size_t begin, std::size_t end, void* obj) {
  for (std::size_t j = begin; j < end; j += w.t[j].span) {
    Result res = unpack_one(w, j, obj);
    if (!res.ok())
      return res;
  }
  return Result{};
}

bool ref_value(Walk const& w, Field const& f, void* obj, std::int64_t& out) {
  return f.ref >= 0 && read_int(w.t[f.ref], obj, out);
}

Result get_u16(Reader& r, std::size_t& out, int id) {
  std::uint16_t n = 0;
  Result res = get_num<std::uint16_t>(r, n, false, id);
  out = n;
  return res;
}

Result unpack_text(Field const& f, void* m, Reader& r, std::size_t len) {
  std::size_t at = r.pos;
  std::uint8_t const* p = nullptr;
  Result res = get_bytes(r, p, len, f.id);
  if (!res.ok())
    return res;
  return store_text(f, m, p, len, at);
}

// Bits (width 1) or packed numbers (width 1 or 2) into an Array<std::uint8_t, N>.
Result unpack_small(Field const& f, void* m, Reader& r, std::int64_t count, unsigned width) {
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

// One item of a repeat, times, list or dict. A null array means the items are skipped.
Result unpack_item(Walk& w, std::size_t i, void* m) {
  Field const& f = w.t[i];
  void* item = nullptr;
  if (m != nullptr) {
    std::uint16_t& count = *f.count(m);
    if (count >= f.size)
      return fail(Error::TooMany, w.r.pos, f.id, static_cast<std::size_t>(count) + 1);
    item = f.item(m, count);
    clear_scope(w.t, i + 1, i + f.span, item);
  }
  Result res = unpack_range(w, i + 1, i + f.span, item);
  if (res.ok() && m != nullptr)
    ++*f.count(m);
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

Result unpack_counted(Walk& w, std::size_t i, void* m, std::size_t count) {
  Field const& f = w.t[i];
  if (m != nullptr && count > f.size)
    return fail(Error::TooMany, w.r.pos, f.id, count);
  for (std::size_t k = 0; k < count; ++k) {
    std::size_t at = w.r.pos;
    Result res = unpack_item(w, i, m);
    if (res.ok() && f.kind == Kind::Dict)
      res = check_new_key(w, i, m, at);
    if (!res.ok())
      return res;
  }
  return Result{};
}

Result unpack_one(Walk& w, std::size_t i, void* obj) {
  Field const& f = w.t[i];
  Reader& r = w.r;
  void* m = member(f, obj);
  if (is_number(f.kind))
    return get_number(f, m, r);
  std::int64_t value = 0;
  std::size_t count = 0;
  switch (f.kind) {
    case Kind::Bool:
      set_bool(f, m);
      return Result{};
    case Kind::Bytes:
      return unpack_text(f, m, r, f.size);
    case Kind::Utf8: {
      Result res = get_u16(r, count, f.id);
      return res.ok() ? unpack_text(f, m, r, count) : res;
    }
    case Kind::Sized:
      if (!ref_value(w, f, obj, value) || value < 0)
        return fail(Error::BadValue, r.pos, f.id);
      return unpack_text(f, m, r, static_cast<std::size_t>(value));
    case Kind::When:
      if (ref_value(w, f, obj, value) && value == f.eq)
        return unpack_range(w, i + 1, i + f.span, obj);
      return Result{};
    case Kind::Flags: {
      std::uint8_t byte = 0;
      Result res = get_num<std::uint8_t>(r, byte, false, f.id);
      unsigned k = 0;
      for (std::size_t j = i + 1; res.ok() && j < i + f.span; j += w.t[j].span, ++k) {
        if (byte & (1u << k))
          res = unpack_one(w, j, obj);
      }
      return res;
    }
    case Kind::FlagByte:
      return get_num<std::uint8_t>(r, w.flag_bytes[f.size], false, f.id);
    case Kind::FlagBit:
      if (w.flag_bytes[w.t[f.ref].size] & (1u << f.bit))
        return unpack_one(w, i + 1, obj);
      return Result{};
    case Kind::Group:
      if (f.span == 1) {
        set_bool(f, m);
        return Result{};
      }
      return unpack_range(w, i + 1, i + f.span, obj);
    case Kind::U2:
      return unpack_u2(w, i, obj);
    case Kind::Bits:
      if (!ref_value(w, f, obj, value))
        return fail(Error::BadValue, r.pos, f.id);
      return unpack_small(f, m, r, value, 1);
    case Kind::Packed:
      if (!ref_value(w, f, obj, value))
        return fail(Error::BadValue, r.pos, f.id);
      return unpack_small(f, m, r, value + f.bias, f.width);
    case Kind::Repeat:
      while (r.pos < r.len) {
        Result res = unpack_item(w, i, m);
        if (!res.ok())
          return res;
      }
      return Result{};
    case Kind::Times:
      if (!ref_value(w, f, obj, value) || value < 0)
        return fail(Error::BadValue, r.pos, f.id);
      return unpack_counted(w, i, m, static_cast<std::size_t>(value));
    case Kind::List:
    case Kind::Dict: {
      Result res = get_u16(r, count, f.id);
      return res.ok() ? unpack_counted(w, i, m, count) : res;
    }
    default:
      break;
  }
  return fail(Error::SchemeInvalid, r.pos, f.id);
}

}  // namespace

Result unpack_table(Field const* t, std::size_t n, void* row, Reader& r) {
  clear_scope(t, 0, n, row);
  Walk w{t, r, {}};
  Result res = unpack_range(w, 0, n, row);
  if (!res.ok())
    return res;
  return finish(r);
}

}  // namespace detail
}  // namespace packbin
