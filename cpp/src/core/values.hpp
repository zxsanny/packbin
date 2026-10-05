#pragma once

#include "packbin/codec.hpp"

#include <cstddef>
#include <cstdint>

// The walkers recurse once per nesting level, so their frames set the stack budget. Leaf
// helpers with large locals stay out of line to keep those frames small.
#if defined(__GNUC__)
#define PACKBIN_NOINLINE __attribute__((noinline))
#else
#define PACKBIN_NOINLINE
#endif

namespace packbin {
namespace detail {

// Calls `fn(T{})` with the C++ type of an integer kind. Returns BadValue for other kinds;
// counts and `when` read only integers, so no floating-point code is pulled in for them.
template <typename Fn>
Result visit_integer(Kind kind, int id, Fn&& fn) {
  switch (kind) {
    case Kind::U8:
      return fn(std::uint8_t{});
    case Kind::U16:
      return fn(std::uint16_t{});
    case Kind::U32:
      return fn(std::uint32_t{});
    case Kind::U64:
      return fn(std::uint64_t{});
    case Kind::I8:
      return fn(std::int8_t{});
    case Kind::I16:
      return fn(std::int16_t{});
    case Kind::I32:
      return fn(std::int32_t{});
    case Kind::I64:
      return fn(std::int64_t{});
    default:
      return fail(Error::BadValue, 0, id);
  }
}

// The bound member of `f` inside `obj`, or nullptr when the field is unbound or the object is
// being skipped.
inline void* member(Field const& f, void* obj) {
  if (obj == nullptr || f.access == nullptr)
    return nullptr;
  return f.access(obj);
}

template <typename T>
T load_member(Field const& f, void* m) {
  if (f.optional())
    return static_cast<Opt<T>*>(m)->value;
  return *static_cast<T*>(m);
}

template <typename T>
void store_member(Field const& f, void* m, T value) {
  if (f.optional())
    *static_cast<Opt<T>*>(m) = value;
  else
    *static_cast<T*>(m) = value;
}

// Calls `fn(T{})` with the C++ type of a number kind. Returns BadValue for other kinds.
template <typename Fn>
Result visit_number(Kind kind, int id, Fn&& fn) {
  switch (kind) {
    case Kind::U8:
      return fn(std::uint8_t{});
    case Kind::U16:
      return fn(std::uint16_t{});
    case Kind::U32:
      return fn(std::uint32_t{});
    case Kind::U64:
      return fn(std::uint64_t{});
    case Kind::I8:
      return fn(std::int8_t{});
    case Kind::I16:
      return fn(std::int16_t{});
    case Kind::I32:
      return fn(std::int32_t{});
    case Kind::I64:
      return fn(std::int64_t{});
    case Kind::F32:
      return fn(float{});
    case Kind::F64:
      if constexpr (f64_supported<double>)
        return fn(double{});
      else
        return fail(Error::BadValue, 0, id);
    default:
      return fail(Error::BadValue, 0, id);
  }
}

constexpr bool is_number(Kind k) {
  return k == Kind::U8 || k == Kind::U16 || k == Kind::U32 || k == Kind::U64 ||
         k == Kind::I8 || k == Kind::I16 || k == Kind::I32 || k == Kind::I64 ||
         k == Kind::F32 || k == Kind::F64;
}

bool present(Field const* t, std::size_t i, void* obj);
bool read_int(Field const& f, void* obj, std::int64_t& out);
// True when the `when` entry `f` matches: its source field is present and equals `f.eq`.
bool when_matches(Field const* t, Field const& f, void* obj);
void clear_scope(Field const* t, std::size_t begin, std::size_t end, void* obj);
void set_bool(Field const& f, void* m);

// The bytes of a string or byte-block member: a View, a Text/Blob, or a std::uint8_t[n].
void text_bytes(Field const& f, void* m, std::uint8_t const*& data, std::size_t& len);
// Stores `n` read bytes at `p` into that member (nothing when m is null). A Text/Blob shorter
// than `n` is TooMany at `offset`.
Result store_text(Field const& f, void* m, std::uint8_t const* p, std::size_t n,
                  std::size_t offset);
void clear_text(Field const& f, void* m);

Result put_number(Field const& f, void* m, Writer& w);
Result get_number(Field const& f, void* m, Reader& r);

}  // namespace detail
}  // namespace packbin
