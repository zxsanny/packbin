#include "values.hpp"

#include <cstring>

namespace packbin {
namespace detail {

namespace {

// One pack walk. The walk recurses once per nesting level through pack_one and, for counted
// kinds, pack_items; everything else stays out of that path to keep the stack small.
struct Pack {
  Field const* t;
  std::size_t n;
  Writer& w;
};

Result pack_one(Pack& p, std::size_t i, void* obj);

Result bad(Writer const& w, Field const& f) { return fail(Error::BadValue, w.len, f.id); }

Result put_u16(Writer& w, std::size_t value, int id) {
  return put_num<std::uint16_t>(w, static_cast<std::uint16_t>(value), false, id);
}

// The value of a count or `when` source, or false when it is absent.
bool ref_value(Field const* t, Field const& f, void* obj, std::int64_t& out) {
  return f.ref >= 0 && read_int(t[f.ref], obj, out);
}

// The children of entry i, in order, on the same object.
Result pack_children(Pack& p, std::size_t i, void* obj) {
  for (std::size_t j = i + 1; j < i + p.t[i].span; j += p.t[j].span) {
    Result r = pack_one(p, j, obj);
    if (!r.ok())
      return r;
  }
  return Result{};
}

// `count` items of a repeat, times, list or dict: the children of entry i on each item.
Result pack_items(Pack& p, std::size_t i, void* m, std::size_t count) {
  Field const& f = p.t[i];
  for (std::size_t k = 0; k < count; ++k) {
    void* item = f.item(m, k);
    for (std::size_t j = i + 1; j < i + f.span; j += p.t[j].span) {
      Result r = pack_one(p, j, item);
      if (!r.ok())
        return r;
    }
  }
  return Result{};
}

PACKBIN_NOINLINE
Result pack_flags(Pack& p, std::size_t i, void* obj) {
  Field const* t = p.t;
  std::uint8_t byte = 0;
  unsigned k = 0;
  for (std::size_t j = i + 1; j < i + t[i].span; j += t[j].span, ++k) {
    if (present(t, j, obj))
      byte = static_cast<std::uint8_t>(byte | (1u << k));
  }
  Result r = put_num<std::uint8_t>(p.w, byte, false, t[i].id);
  k = 0;
  for (std::size_t j = i + 1; r.ok() && j < i + t[i].span; j += t[j].span, ++k) {
    if (byte & (1u << k))
      r = pack_one(p, j, obj);
  }
  return r;
}

PACKBIN_NOINLINE
Result pack_flag_byte(Pack& p, std::size_t i, void* obj) {
  Field const* t = p.t;
  std::uint8_t byte = 0;
  for (std::size_t j = i + 1; j < p.n; ++j) {
    if (t[j].kind == Kind::FlagBit && t[j].ref == static_cast<std::int16_t>(i) &&
        present(t, j + 1, obj))
      byte = static_cast<std::uint8_t>(byte | (1u << t[j].bit));
  }
  return put_num<std::uint8_t>(p.w, byte, false, t[i].id);
}

// Bytes, utf8 (with its u16 length) and sized (length checked against its count).
PACKBIN_NOINLINE
Result pack_text(Pack& p, std::size_t i, void* obj) {
  Field const& f = p.t[i];
  Writer& w = p.w;
  void* m = member(f, obj);
  if (m == nullptr)
    return bad(w, f);
  std::uint8_t const* data = nullptr;
  std::size_t len = 0;
  text_bytes(f, m, data, len);
  if (f.kind == Kind::Bytes && len != f.size)
    return bad(w, f);
  if (f.kind == Kind::Sized) {
    std::int64_t count = 0;
    if (!ref_value(p.t, f, obj, count) || count < 0 || len != static_cast<std::size_t>(count))
      return bad(w, f);
  }
  if (f.kind == Kind::Utf8) {
    if (len > 65535)
      return bad(w, f);
    Result r = put_u16(w, len, f.id);
    if (!r.ok())
      return r;
  }
  return put_bytes(w, data, len, f.id);
}

// Bits (width 1) or packed numbers (width 1 or 2) from an Array<std::uint8_t, N>.
PACKBIN_NOINLINE
Result pack_small(Pack& p, std::size_t i, void* obj) {
  Field const& f = p.t[i];
  Writer& w = p.w;
  void* m = member(f, obj);
  std::int64_t count = 0;
  if (!ref_value(p.t, f, obj, count))
    return bad(w, f);
  unsigned width = f.kind == Kind::Bits ? 1 : f.width;
  if (f.kind == Kind::Packed)
    count += f.bias;
  if (m == nullptr || count < 0 || *f.count(m) != count)
    return bad(w, f);
  unsigned per = 8 / width;
  unsigned max = (1u << width) - 1;
  std::size_t nbytes = (static_cast<std::size_t>(count) * width + 7) / 8;
  if (w.cap - w.len < nbytes)
    return fail(Error::BufferFull, w.len, f.id, nbytes);
  for (std::size_t b = 0; b < nbytes; ++b)
    w.data[w.len + b] = 0;
  for (std::int64_t k = 0; k < count; ++k) {
    auto value = *static_cast<std::uint8_t*>(f.item(m, static_cast<std::size_t>(k)));
    if (value > max)
      return bad(w, f);
    auto at = static_cast<std::size_t>(k) / per;
    auto shift = (static_cast<unsigned>(k) % per) * width;
    w.data[w.len + at] = static_cast<std::uint8_t>(w.data[w.len + at] | (value << shift));
  }
  w.len += nbytes;
  return Result{};
}

PACKBIN_NOINLINE
Result pack_u2(Pack& p, std::size_t i, void* obj) {
  Field const* t = p.t;
  Field const& f = t[i];
  Writer& w = p.w;
  std::size_t k = f.span - 1;
  std::size_t nbytes = (k + 3) / 4;
  if (w.cap - w.len < nbytes)
    return fail(Error::BufferFull, w.len, f.id, nbytes);
  std::uint8_t raw[16] = {};
  if (nbytes > sizeof(raw))
    return bad(w, f);
  for (std::size_t c = 0; c < k; ++c) {
    Field const& child = t[i + 1 + c];
    std::int64_t value = 0;
    if (!read_int(child, obj, value) || value < 0 || value > 3)
      return bad(w, child);
    raw[c / 4] = static_cast<std::uint8_t>(raw[c / 4] | (value << ((c % 4) * 2)));
  }
  return put_bytes(w, raw, nbytes, f.id);
}

// Dict keys go on the wire in strictly increasing unsigned byte order, as in every package.
PACKBIN_NOINLINE
bool keys_ascending(Field const* t, std::size_t i, void* m) {
  Field const& f = t[i];
  Field const& key = t[i + 1];
  std::size_t count = *f.count(m);
  for (std::size_t k = 1; k < count; ++k) {
    std::uint8_t const *a = nullptr, *b = nullptr;
    std::size_t la = 0, lb = 0;
    text_bytes(key, member(key, f.item(m, k - 1)), a, la);
    text_bytes(key, member(key, f.item(m, k)), b, lb);
    std::size_t common = la < lb ? la : lb;
    int c = common == 0 ? 0 : std::memcmp(a, b, common);
    if (c > 0 || (c == 0 && la >= lb))
      return false;
  }
  return true;
}

// How many items a repeat, times, list or dict writes, after writing a list/dict count.
// SIZE_MAX means the pack already failed with `out`.
PACKBIN_NOINLINE
std::size_t item_count(Pack& p, std::size_t i, void* obj, void* m, Result& out) {
  Field const& f = p.t[i];
  constexpr std::size_t stop = static_cast<std::size_t>(-1);
  if (f.kind == Kind::Repeat)
    return m == nullptr ? 0 : *f.count(m);
  if (f.kind == Kind::Times) {
    std::int64_t count = 0;
    if (!ref_value(p.t, f, obj, count) || count < 0 ||
        (count != 0 && (m == nullptr || *f.count(m) != count))) {
      out = bad(p.w, f);
      return stop;
    }
    return static_cast<std::size_t>(count);
  }
  if (m == nullptr || (f.kind == Kind::Dict && !keys_ascending(p.t, i, m))) {
    out = bad(p.w, f);
    return stop;
  }
  out = put_u16(p.w, *f.count(m), f.id);
  return out.ok() ? *f.count(m) : stop;
}

Result pack_one(Pack& p, std::size_t i, void* obj) {
  Field const& f = p.t[i];
  if (is_number(f.kind))
    return present(p.t, i, obj) ? put_number(f, member(f, obj), p.w) : bad(p.w, f);
  switch (f.kind) {
    case Kind::Bool:
      return Result{};
    case Kind::Bytes:
    case Kind::Utf8:
    case Kind::Sized:
      return pack_text(p, i, obj);
    case Kind::When:
      return when_matches(p.t, f, obj) ? pack_children(p, i, obj) : Result{};
    case Kind::Flags:
      return pack_flags(p, i, obj);
    case Kind::FlagByte:
      return pack_flag_byte(p, i, obj);
    case Kind::FlagBit:
      return present(p.t, i + 1, obj) ? pack_one(p, i + 1, obj) : Result{};
    case Kind::Group:
      return pack_children(p, i, obj);
    case Kind::U2:
      return pack_u2(p, i, obj);
    case Kind::Bits:
    case Kind::Packed:
      return pack_small(p, i, obj);
    case Kind::Repeat:
    case Kind::Times:
    case Kind::List:
    case Kind::Dict: {
      void* m = member(f, obj);
      Result r{};
      std::size_t count = item_count(p, i, obj, m, r);
      if (count == static_cast<std::size_t>(-1) || count == 0)
        return r;
      return pack_items(p, i, m, count);
    }
    default:
      break;
  }
  return fail(Error::SchemeInvalid, p.w.len, f.id);
}

}  // namespace

Result pack_table(Field const* t, std::size_t n, std::uint8_t type_number, void const* row,
                  Writer& w) {
  Result r = put_num<std::uint8_t>(w, type_number, false, -1);
  if (!r.ok())
    return r;
  Pack p{t, n, w};
  // Pack only reads through the accessors; they return non-const pointers because unpack uses
  // the same table to write.
  void* obj = const_cast<void*>(row);
  for (std::size_t j = 0; j < n; j += t[j].span) {
    r = pack_one(p, j, obj);
    if (!r.ok())
      return r;
  }
  return Result{Error::Ok, w.len};
}

}  // namespace detail
}  // namespace packbin
