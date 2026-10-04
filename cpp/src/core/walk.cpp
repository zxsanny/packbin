#include "values.hpp"

#include <cstring>

namespace packbin {
namespace detail {

namespace {

Result pack_range(Field const* t, std::size_t begin, std::size_t end, void* obj, Writer& w);
Result unpack_range(Field const* t, std::size_t begin, std::size_t end, void* obj, Reader& r);

bool when_matches(Field const* t, Field const& f, void* obj) {
  std::int64_t value = 0;
  return f.ref >= 0 && read_int(t[f.ref], obj, value) && value == f.eq;
}

Result pack_one(Field const* t, std::size_t i, void* obj, Writer& w) {
  Field const& f = t[i];
  void* m = member(f, obj);
  if (is_number(f.kind)) {
    if (!present(t, i, obj))
      return fail(Error::BadValue, w.len, f.id);
    return put_number(f, m, w);
  }
  switch (f.kind) {
    case Kind::Bool:
      return Result{};
    case Kind::Bytes:
      if (m == nullptr)
        return fail(Error::BadValue, w.len, f.id);
      return put_bytes(w, static_cast<std::uint8_t const*>(m), f.size, f.id);
    case Kind::When:
      if (when_matches(t, f, obj))
        return pack_range(t, i + 1, i + f.span, obj, w);
      return Result{};
    default:
      return fail(Error::SchemeInvalid, w.len, f.id);
  }
}

Result pack_range(Field const* t, std::size_t begin, std::size_t end, void* obj, Writer& w) {
  for (std::size_t j = begin; j < end; j += t[j].span) {
    Result r = pack_one(t, j, obj, w);
    if (!r.ok())
      return r;
  }
  return Result{};
}

Result unpack_one(Field const* t, std::size_t i, void* obj, Reader& r) {
  Field const& f = t[i];
  void* m = member(f, obj);
  if (is_number(f.kind))
    return get_number(f, m, r);
  switch (f.kind) {
    case Kind::Bool:
      set_bool(f, m);
      return Result{};
    case Kind::Bytes: {
      std::uint8_t const* p = nullptr;
      Result res = get_bytes(r, p, f.size, f.id);
      if (res.ok() && m != nullptr && f.size != 0)
        std::memcpy(m, p, f.size);
      return res;
    }
    case Kind::When:
      if (when_matches(t, f, obj))
        return unpack_range(t, i + 1, i + f.span, obj, r);
      return Result{};
    default:
      return fail(Error::SchemeInvalid, r.pos, f.id);
  }
}

Result unpack_range(Field const* t, std::size_t begin, std::size_t end, void* obj, Reader& r) {
  for (std::size_t j = begin; j < end; j += t[j].span) {
    Result res = unpack_one(t, j, obj, r);
    if (!res.ok())
      return res;
  }
  return Result{};
}

}  // namespace

Result pack_table(Field const* t, std::size_t n, std::uint8_t type_number, void const* row,
                  Writer& w) {
  Result r = put_num<std::uint8_t>(w, type_number, false, -1);
  if (!r.ok())
    return r;
  // Pack only reads through the accessors; they return non-const pointers because unpack uses
  // the same table to write.
  r = pack_range(t, 0, n, const_cast<void*>(row), w);
  if (!r.ok())
    return r;
  return Result{Error::Ok, w.len};
}

Result unpack_table(Field const* t, std::size_t n, void* row, Reader& r) {
  clear_scope(t, 0, n, row);
  Result res = unpack_range(t, 0, n, row, r);
  if (!res.ok())
    return res;
  return finish(r);
}

}  // namespace detail
}  // namespace packbin
