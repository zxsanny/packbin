#include "values.hpp"

namespace packbin {
namespace detail {

namespace {

Result pack_one(Field const* t, std::size_t n, std::size_t i, void* obj, Writer& w);

Result pack_range(Field const* t, std::size_t n, std::size_t begin, std::size_t end, void* obj,
                  Writer& w) {
  for (std::size_t j = begin; j < end; j += t[j].span) {
    Result r = pack_one(t, n, j, obj, w);
    if (!r.ok())
      return r;
  }
  return Result{};
}

Result bad(Writer const& w, Field const& f) { return fail(Error::BadValue, w.len, f.id); }

Result put_u16(Writer& w, std::size_t value, int id) {
  return put_num<std::uint16_t>(w, static_cast<std::uint16_t>(value), false, id);
}

// The value of a count or `when` source, or false when it is absent.
bool ref_value(Field const* t, Field const& f, void* obj, std::int64_t& out) {
  return f.ref >= 0 && read_int(t[f.ref], obj, out);
}

std::uint8_t flags_byte(Field const* t, std::size_t i, void* obj) {
  std::uint8_t byte = 0;
  unsigned k = 0;
  for (std::size_t j = i + 1; j < i + t[i].span; j += t[j].span, ++k) {
    if (present(t, j, obj))
      byte = static_cast<std::uint8_t>(byte | (1u << k));
  }
  return byte;
}

std::uint8_t flag_byte_value(Field const* t, std::size_t n, std::size_t i, void* obj) {
  std::uint8_t byte = 0;
  for (std::size_t j = i + 1; j < n; ++j) {
    if (t[j].kind == Kind::FlagBit && t[j].ref == static_cast<std::int16_t>(i) &&
        present(t, j + 1, obj))
      byte = static_cast<std::uint8_t>(byte | (1u << t[j].bit));
  }
  return byte;
}

Result pack_text(Field const& f, void* m, Writer& w, bool with_length) {
  std::uint8_t const* data = nullptr;
  std::size_t len = 0;
  text_bytes(f, m, data, len);
  if (with_length) {
    if (len > 65535)
      return bad(w, f);
    Result r = put_u16(w, len, f.id);
    if (!r.ok())
      return r;
  }
  return put_bytes(w, data, len, f.id);
}

// Bits (width 1) or packed numbers (width 1 or 2) from an Array<std::uint8_t, N>.
Result pack_small(Field const& f, void* m, std::int64_t count, unsigned width, Writer& w) {
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

Result pack_u2(Field const* t, std::size_t i, void* obj, Writer& w) {
  Field const& f = t[i];
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

Result pack_items(Field const* t, std::size_t n, std::size_t i, void* m, std::size_t count,
                  Writer& w) {
  Field const& f = t[i];
  for (std::size_t k = 0; k < count; ++k) {
    Result r = pack_range(t, n, i + 1, i + f.span, f.item(m, k), w);
    if (!r.ok())
      return r;
  }
  return Result{};
}

Result pack_one(Field const* t, std::size_t n, std::size_t i, void* obj, Writer& w) {
  Field const& f = t[i];
  void* m = member(f, obj);
  if (is_number(f.kind))
    return present(t, i, obj) ? put_number(f, m, w) : bad(w, f);
  std::int64_t count = 0;
  switch (f.kind) {
    case Kind::Bool:
      return Result{};
    case Kind::Bytes: {
      if (m == nullptr)
        return bad(w, f);
      if (f.borrowed() && static_cast<View*>(m)->len != f.size)
        return bad(w, f);
      return pack_text(f, m, w, false);
    }
    case Kind::Utf8:
      return m == nullptr ? bad(w, f) : pack_text(f, m, w, true);
    case Kind::Sized: {
      std::uint8_t const* data = nullptr;
      std::size_t len = 0;
      if (m == nullptr || !ref_value(t, f, obj, count))
        return bad(w, f);
      text_bytes(f, m, data, len);
      if (count < 0 || len != static_cast<std::size_t>(count))
        return bad(w, f);
      return put_bytes(w, data, len, f.id);
    }
    case Kind::When:
      if (ref_value(t, f, obj, count) && count == f.eq)
        return pack_range(t, n, i + 1, i + f.span, obj, w);
      return Result{};
    case Kind::Flags: {
      std::uint8_t byte = flags_byte(t, i, obj);
      Result r = put_num<std::uint8_t>(w, byte, false, f.id);
      unsigned k = 0;
      for (std::size_t j = i + 1; r.ok() && j < i + f.span; j += t[j].span, ++k) {
        if (byte & (1u << k))
          r = pack_one(t, n, j, obj, w);
      }
      return r;
    }
    case Kind::FlagByte:
      return put_num<std::uint8_t>(w, flag_byte_value(t, n, i, obj), false, f.id);
    case Kind::FlagBit:
      return present(t, i + 1, obj) ? pack_one(t, n, i + 1, obj, w) : Result{};
    case Kind::Group:
      return pack_range(t, n, i + 1, i + f.span, obj, w);
    case Kind::U2:
      return pack_u2(t, i, obj, w);
    case Kind::Bits:
      if (!ref_value(t, f, obj, count))
        return bad(w, f);
      return pack_small(f, m, count, 1, w);
    case Kind::Packed:
      if (!ref_value(t, f, obj, count))
        return bad(w, f);
      return pack_small(f, m, count + f.bias, f.width, w);
    case Kind::Repeat:
      return m == nullptr ? Result{} : pack_items(t, n, i, m, *f.count(m), w);
    case Kind::Times:
      if (!ref_value(t, f, obj, count) || count < 0)
        return bad(w, f);
      if (count == 0)
        return Result{};
      if (m == nullptr || *f.count(m) != count)
        return bad(w, f);
      return pack_items(t, n, i, m, static_cast<std::size_t>(count), w);
    case Kind::List:
    case Kind::Dict: {
      if (m == nullptr)
        return bad(w, f);
      std::size_t items = *f.count(m);
      Result r = put_u16(w, items, f.id);
      return r.ok() ? pack_items(t, n, i, m, items, w) : r;
    }
    default:
      break;
  }
  return fail(Error::SchemeInvalid, w.len, f.id);
}

}  // namespace

Result pack_table(Field const* t, std::size_t n, std::uint8_t type_number, void const* row,
                  Writer& w) {
  Result r = put_num<std::uint8_t>(w, type_number, false, -1);
  if (!r.ok())
    return r;
  // Pack only reads through the accessors; they return non-const pointers because unpack uses
  // the same table to write.
  r = pack_range(t, n, 0, n, const_cast<void*>(row), w);
  if (!r.ok())
    return r;
  return Result{Error::Ok, w.len};
}

}  // namespace detail
}  // namespace packbin
