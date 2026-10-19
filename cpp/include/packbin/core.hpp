#pragma once

// Allocation-free, exception-free core. Standard names come only from packbin/platform.hpp (the C
// integer and memory functions; no other standard header, so avr-gcc builds it). No global or
// static mutable state.

#include "packbin/platform.hpp"

namespace packbin {

enum class Error : std::uint8_t {
  Ok,
  ShortPacket,
  TrailingBytes,
  TypeMismatch,
  BufferFull,
  TooMany,
  BadValue,
  SchemeInvalid,
  // A string needs more encoder scratch than `pack` was given (`needed` is the bytes required).
  ScratchTooSmall,
  // A protected message (a scheme with parity bytes) has more wrong bytes than the correction
  // limit allows, or any wrong byte when the limit is 0. No values are read; no field is named.
  Uncorrectable,
  // A protected message longer than 254 bytes: a received buffer above 254, or fields above
  // 254 minus the parity count on pack (`offset` the length, `needed` the limit). Distinct from
  // `TooMany`.
  TooLong,
};

// Working memory of the compact-text encoder: 3 words (12 bytes) per Unicode code point of the
// longest string packed in one call. A string that needs more than the scratch holds is
// `ScratchTooSmall` naming its field; the encoder never writes a different encoding instead.
// Strings that the format stores as raw UTF-8 without a parse (a lower bound on the compact
// size already loses) need none, and a packet without strings needs no scratch.
constexpr std::size_t kScratchWordsPerChar = 3;

struct ScratchRef {
  std::uint32_t* words = nullptr;
  std::size_t count = 0;
};

// Owned scratch for strings of up to `Chars` code points: `Scratch<64> sc; pack(s, row, out,
// cap, sc);`. The words need no initial value. Scratch<65535> is 786 KB: declare a large one
// `static` (the host build refuses a frame over 64 KB, `-Wframe-larger-than`).
template <std::size_t Chars>
struct Scratch {
  static_assert(Chars > 0 && Chars <= 65535, "packbin: Scratch<N> holds 1..65535 characters");
  std::uint32_t words[Chars * kScratchWordsPerChar];

  operator ScratchRef() { return ScratchRef{words, Chars * kScratchWordsPerChar}; }
};

// On failure, `offset` is the byte where the failure was found, `field` the order id (-1 when
// no field applies) and `needed` the bytes that field required. On success, `offset` is the
// number of bytes written or read (a protected message counts its parity bytes) and `repaired`
// the wrong bytes `unpack_repair` fixed in the buffer (0 for any other call). A build with
// PACKBIN_NO_ECC repairs nothing and has no `repaired`, so its Result is the one of earlier
// releases (the member comes last so the positional initializers of the core stay as they are).
struct Result {
  Error error = Error::Ok;
  std::size_t offset = 0;
  int field = -1;
  std::size_t needed = 0;
#ifndef PACKBIN_NO_ECC
  std::uint8_t repaired = 0;
#endif

  constexpr bool ok() const { return error == Error::Ok; }
};

constexpr Result fail(Error error, std::size_t offset, int field, std::size_t needed = 0) {
  return Result{error, offset, field, needed};
}

struct Writer {
  std::uint8_t* data = nullptr;
  std::size_t cap = 0;
  std::size_t len = 0;
};

struct Reader {
  std::uint8_t const* data = nullptr;
  std::size_t len = 0;
  std::size_t pos = 0;

  std::size_t left() const { return len - pos; }
};

namespace detail {

// Byte order comes from the field, never from the CPU: numbers are split with shifts on an
// unsigned value of the field width.
template <typename U>
void store(std::uint8_t* p, U value, bool be) {
  static_assert(detail::is_unsigned<U>::value, "store takes an unsigned width");
  for (std::size_t i = 0; i < sizeof(U); ++i) {
    std::size_t at = be ? sizeof(U) - 1 - i : i;
    p[at] = static_cast<std::uint8_t>(value >> (8 * i));
  }
}

template <typename U>
U load(std::uint8_t const* p, bool be) {
  static_assert(detail::is_unsigned<U>::value, "load takes an unsigned width");
  U value = 0;
  for (std::size_t i = 0; i < sizeof(U); ++i) {
    std::size_t at = be ? sizeof(U) - 1 - i : i;
    value = static_cast<U>(value | (static_cast<U>(p[at]) << (8 * i)));
  }
  return value;
}

template <std::size_t N>
struct UnsignedOf;
template <>
struct UnsignedOf<1> {
  using type = std::uint8_t;
};
template <>
struct UnsignedOf<2> {
  using type = std::uint16_t;
};
template <>
struct UnsignedOf<4> {
  using type = std::uint32_t;
};
template <>
struct UnsignedOf<8> {
  using type = std::uint64_t;
};

template <typename T>
using unsigned_of = typename UnsignedOf<sizeof(T)>::type;

template <typename T>
unsigned_of<T> to_bits(T value) {
  unsigned_of<T> bits;
  std::memcpy(&bits, &value, sizeof(T));
  return bits;
}

template <typename T>
T from_bits(unsigned_of<T> bits) {
  T value;
  std::memcpy(&value, &bits, sizeof(T));
  return value;
}

}  // namespace detail

template <typename D>
constexpr bool f64_supported = sizeof(D) == 8;

inline Result put_bytes(Writer& w, std::uint8_t const* src, std::size_t n, int field) {
  if (w.cap - w.len < n)
    return fail(Error::BufferFull, w.len, field, n);
  if (n != 0)
    std::memcpy(w.data + w.len, src, n);
  w.len += n;
  return Result{Error::Ok, w.len};
}

inline Result get_bytes(Reader& r, std::uint8_t const*& out, std::size_t n, int field) {
  if (r.left() < n)
    return fail(Error::ShortPacket, r.pos, field, n);
  out = r.data + r.pos;
  r.pos += n;
  return Result{Error::Ok, r.pos};
}

// Integers and f32: T is one of std::uint8_t…std::uint64_t, std::int8_t…std::int64_t, float.
template <typename T>
Result put_num(Writer& w, T value, bool be, int field) {
  static_assert(detail::is_arithmetic<T>::value, "put_num takes a number");
  if (w.cap - w.len < sizeof(T))
    return fail(Error::BufferFull, w.len, field, sizeof(T));
  detail::store(w.data + w.len, detail::to_bits(value), be);
  w.len += sizeof(T);
  return Result{Error::Ok, w.len};
}

template <typename T>
Result get_num(Reader& r, T& out, bool be, int field) {
  static_assert(detail::is_arithmetic<T>::value, "get_num takes a number");
  if (r.left() < sizeof(T))
    return fail(Error::ShortPacket, r.pos, field, sizeof(T));
  out = detail::from_bits<T>(detail::load<detail::unsigned_of<T>>(r.data + r.pos, be));
  r.pos += sizeof(T);
  return Result{Error::Ok, r.pos};
}

template <typename D = double>
Result put_f64(Writer& w, D value, bool be, int field) {
  static_assert(f64_supported<D>, "packbin: f64 needs an 8-byte double on this target");
  return put_num<D>(w, value, be, field);
}

template <typename D = double>
Result get_f64(Reader& r, D& out, bool be, int field) {
  static_assert(f64_supported<D>, "packbin: f64 needs an 8-byte double on this target");
  return get_num<D>(r, out, be, field);
}

inline Result finish(Reader const& r) {
  if (r.pos < r.len)
    return fail(Error::TrailingBytes, r.pos, -1, 0);
  return Result{Error::Ok, r.pos};
}

}  // namespace packbin
