#pragma once

#include "packbin/core.hpp"

#include "packbin/platform.hpp"

namespace packbin {

enum class Kind : std::uint8_t {
  U8,
  U16,
  U32,
  U64,
  I8,
  I16,
  I32,
  I64,
  F32,
  F64,
  Bytes,
  Bool,
  Flags,
  FlagByte,
  FlagBit,
  When,
  Repeat,
  Group,
  Sized,
  U2,
  Bits,
  Packed,
  Times,
  Utf8,
  List,
  Dict,
};

// A row member the packet may leave out: presence decides flag bits and `when` matches.
template <typename T>
struct Opt {
  T value{};
  bool has = false;

  constexpr Opt() = default;
  constexpr Opt(T v) : value(v), has(true) {}
  Opt& operator=(T v) {
    value = v;
    has = true;
    return *this;
  }
  void reset() {
    value = T{};
    has = false;
  }
};

// Borrowed bytes: on unpack it points into the caller's input buffer; nothing is copied. It
// binds `bytes` and `sized` members, never a string.
struct View {
  std::uint8_t const* data = nullptr;
  std::size_t len = 0;
};

// A string kept as it is on the wire: the payload bytes after the count header, borrowed from
// the input (valid while the input lives), never decoded or validated. A field or list element
// bound to `Packed` is read and skipped by its count, so a build without the codec
// (PACKBIN_NO_TEXT) still reads the fields after a string and can forward the bytes. Pack
// writes the count of `len` and the bytes as given: an opaque field for relays. An empty
// string is `len == 0`.
struct Packed {
  std::uint8_t const* data = nullptr;
  std::size_t len = 0;
};

// Fixed caller storage for a string (`Text`) or a byte block (`Blob`). A longer value is
// `TooMany`, never cut. `len` comes first so the walker finds `data` at a fixed offset.
template <std::size_t N>
struct Text {
  static_assert(N > 0 && N <= 65535, "packbin: Text<N> holds 1..65535 bytes");
  std::uint16_t len = 0;
  char data[N] = {};
};

template <std::size_t N>
struct Blob {
  static_assert(N > 0 && N <= 65535, "packbin: Blob<N> holds 1..65535 bytes");
  std::uint16_t len = 0;
  std::uint8_t data[N] = {};
};

// Caller storage for a counted kind: up to N items; more on the wire is `TooMany`.
template <typename T, std::size_t N>
struct Array {
  static_assert(N > 0 && N <= 65535, "packbin: Array<T, N> holds 1..65535 items");
  using value_type = T;
  static constexpr std::size_t capacity = N;
  std::uint16_t count = 0;
  T items[N] = {};
};

// One dictionary entry. The key is a decoded copy (`Text<N>`): keys are ordered and checked
// as text (strictly ascending on unpack).
template <typename V, typename Key>
struct Entry {
  using value_type = V;
  using key_type = Key;
  Key key{};
  V value{};
};

namespace flag {
constexpr std::uint8_t BigEndian = 1;
constexpr std::uint8_t Optional = 2;
// String and byte storage: Borrowed is a View (bytes, sized), Fixed is Text<N>/Blob<N>, Opaque
// is a Packed string; none is std::uint8_t[n].
constexpr std::uint8_t Borrowed = 4;
constexpr std::uint8_t Fixed = 8;
constexpr std::uint8_t Opaque = 64;
// Set by a builder that could not bind this entry; the scheme check reports SchemeInvalid.
constexpr std::uint8_t Invalid = 16;
// A `when` or `times` that a flag bit decides and whose source is written after its flag byte
// (see `Field::late`).
constexpr std::uint8_t Late = 32;
// Set at resolve time on a `when` whose span holds a flag byte: the unpack walk enters it in its own
// flag scope (see `check_table`).
constexpr std::uint8_t HoldsFlagByte = 128;
}  // namespace flag

// Returns the bound member inside one row or element object.
using Access = void* (*)(void* obj);
// Item `i` of an Array, and the Array's count.
using Item = void* (*)(void* array, std::size_t i);
using Count = std::uint16_t* (*)(void* array);

#if defined(__GNUC__)
using EqValue = std::int64_t __attribute__((aligned(4)));
#else
using EqValue = std::int64_t;
#endif

// One entry of a scheme table. Children follow their parent in preorder; `span` counts the
// entry and all of its descendants, so the next sibling is at `index + span`.
struct Field {
  Kind kind = Kind::U8;
  std::uint8_t flags = 0;
  std::int16_t id = -1;
  std::uint16_t span = 1;
  // Order id named by `eq()` or a count, and its table index once the scheme resolves it.
  // A flag bit refers to its flag byte.
  std::int16_t ref_id = -1;
  std::int16_t ref = -1;
  // `bytes(n)` length; Text/Blob/Array capacity; flag byte group number.
  std::uint16_t size = 0;
  // `packed` bit width (1 or 2) and count bias (0 or -1); a flag bit's position. On the count
  // or `when` source of a `times`, `bits`, `packed`, `sized` or `when`, and on a `when` that holds
  // that source, `bit` is the distance back to the nearest `when` that holds it, or 0.
  std::uint8_t width = 0;
  std::int8_t bias = 0;
  std::uint8_t bit = 0;
  // A flag bit: the distance to the first `when` or `times` it decides (itself or inside a
  // group) whose source is written after its flag byte, or 0; on that `when` or `times`, the
  // distance to the next one (each carries `flag::Late`). A reader decides that bit where the
  // byte is read, before the source exists, so a body held only by those members cannot set the
  // bit and pack refuses it; another member of the bit that holds a value sets the bit and the
  // body packs.
  std::uint8_t late = 0;
  // Aligned to 4 bytes, not 8: a 32-bit target pads every entry by 4 bytes for a 64-bit member
  // (the 14-entry table of the size probe is 56 bytes smaller).
  EqValue eq = 0;
  Access access = nullptr;
  Item item = nullptr;
  Count count = nullptr;

  constexpr bool be() const { return (flags & flag::BigEndian) != 0; }
  constexpr bool optional() const { return (flags & flag::Optional) != 0; }
  constexpr bool borrowed() const { return (flags & flag::Borrowed) != 0; }
  constexpr bool fixed() const { return (flags & flag::Fixed) != 0; }
  constexpr bool opaque() const { return (flags & flag::Opaque) != 0; }
  constexpr bool holds_flag_byte() const { return (flags & flag::HoldsFlagByte) != 0; }
};

// The members before `eq` fill 16 bytes on every target, AVR included (`eq` is aligned to 4 there
// too, so `late` sits in what was padding): a new member before `eq` grows every table entry.
static_assert(offsetof(Field, eq) == 16, "Field members before eq take 16 bytes");

// A built piece of a scheme: N table entries whose accessors apply to objects of type C
// (void when nothing in it is bound).
template <typename C, std::size_t N>
struct Node {
  using Class = C;
  static constexpr std::size_t size = N;
  detail::FixedArray<Field, N> f{};
};

struct Eq {
  int field_id;
  std::int64_t value;
};

constexpr Eq eq(int field_id, std::int64_t value) { return Eq{field_id, value}; }

namespace detail {

// GCC before 9 (avr-gcc 7.3) has no __builtin_is_constant_evaluated. There a constant scheme that
// breaks a rule is not stopped at compile time; its status is SchemeInvalid with the field id, as
// for a scheme built at run time, and `static_assert(scheme.status.ok())` restores the stop.
#if defined(__GNUC__) && !defined(__clang__) && __GNUC__ < 9
constexpr bool constant_evaluated() { return false; }
#else
constexpr bool constant_evaluated() { return __builtin_is_constant_evaluated(); }
#endif

// Not constexpr on purpose, like the scheme stoppers in codec.hpp: a string element that cannot
// be bound stops the compile when the scheme is built as a constant, and the name says why. A
// scheme built at run time reports SchemeInvalid instead.
inline void utf8_element_must_be_Text_N_or_Packed_not_View() {}
inline void dict_key_must_be_Text_N() {}
inline void Text_N_needs_the_codec_but_PACKBIN_NO_TEXT_is_defined() {}

template <typename M>
struct Member;

template <typename C, typename T>
struct Member<T C::*> {
  using Class = C;
  using Type = T;
};

template <auto M>
void* access(void* obj) {
  using C = typename Member<decltype(M)>::Class;
  return &(static_cast<C*>(obj)->*M);
}

template <typename T>
struct IsOpt : detail::false_type {};
template <typename T>
struct IsOpt<Opt<T>> : detail::true_type {};

template <typename A, typename B>
struct Join {
  static_assert(detail::is_void<A>::value || detail::is_void<B>::value || detail::is_same<A, B>::value,
                "packbin: fields of one scope bind members of one row type");
  using type = detail::conditional_t<detail::is_void<A>::value, B, A>;
};

template <typename... Cs>
struct JoinAll {
  using type = void;
};
template <typename C, typename... Rest>
struct JoinAll<C, Rest...> {
  using type = typename Join<C, typename JoinAll<Rest...>::type>::type;
};

template <typename... Ns>
constexpr std::size_t total() {
  return (std::size_t{0} + ... + Ns::size);
}

template <std::size_t M, typename Src>
constexpr int copy_fields(detail::FixedArray<Field, M>& dst, std::size_t& at, Src const& src) {
  for (std::size_t i = 0; i < Src::size; ++i)
    dst[at + i] = src.f[i];
  at += Src::size;
  return 0;
}

// A parent entry followed by its children's entries.
template <typename... Ns>
constexpr Node<typename JoinAll<typename Ns::Class...>::type, 1 + total<Ns...>()> nest(
    Field head, Ns const&... children) {
  Node<typename JoinAll<typename Ns::Class...>::type, 1 + total<Ns...>()> out{};
  head.span = static_cast<std::uint16_t>(1 + total<Ns...>());
  out.f[0] = head;
  [[maybe_unused]] std::size_t at = 1;
  ((void)copy_fields(out.f, at, children), ...);
  return out;
}

constexpr Field leaf(Kind kind, int id) {
  Field f{};
  f.kind = kind;
  f.id = static_cast<std::int16_t>(id);
  // An id outside the 15-bit wire range is Invalid (U25, AZ-2472): check_shape reports
  // SchemeInvalid at the field's own id. The id -1 is reserved for list, dict, flag_byte and
  // flag_bit entries that carry none, and for the counted sentinel in counted_leaf.
  if (id < -1 || id > 32767)
    f.flags = static_cast<std::uint8_t>(f.flags | flag::Invalid);
  return f;
}

static_assert(offsetof(Text<1>, data) == sizeof(std::uint16_t), "Text data follows len");
static_assert(offsetof(Blob<1>, data) == sizeof(std::uint16_t), "Blob data follows len");

inline void* self(void* obj) { return obj; }

template <typename A>
void* array_item(void* a, std::size_t i) {
  return &static_cast<A*>(a)->items[i];
}

template <typename A>
std::uint16_t* array_count(void* a) {
  return &static_cast<A*>(a)->count;
}

template <typename E>
void* entry_key(void* e) {
  return &static_cast<E*>(e)->key;
}

template <typename E>
void* entry_value(void* e) {
  return &static_cast<E*>(e)->value;
}

template <typename T>
struct IsArray : detail::false_type {};
template <typename T, std::size_t N>
struct IsArray<Array<T, N>> : detail::true_type {};

template <typename T>
struct IsEntry : detail::false_type {};
template <typename V, typename K>
struct IsEntry<Entry<V, K>> : detail::true_type {};

template <typename T>
struct FixedSize : detail::integral_constant<std::size_t, 0> {};
template <std::size_t N>
struct FixedSize<Text<N>> : detail::integral_constant<std::size_t, N> {};
template <std::size_t N>
struct FixedSize<Blob<N>> : detail::integral_constant<std::size_t, N> {};

constexpr void mark_invalid(Field& f) {
  f.flags = static_cast<std::uint8_t>(f.flags | flag::Invalid);
}

#ifdef PACKBIN_NO_TEXT
constexpr bool kNoText = true;
#else
constexpr bool kNoText = false;
#endif

// Storage of a string (K is Utf8) or byte block bound to a member of type T. A string binds a
// Text<N> (a decoded copy) or a Packed (the payload as it is), never a View; a build without the
// codec binds only Packed.
template <Kind K, typename T>
constexpr void bind_storage(Field& f) {
  if constexpr (detail::is_same<T, View>::value) {
    static_assert(K != Kind::Utf8,
                  "packbin: a utf8 member is a Text<N> (decoded copy) or a Packed, never a View");
    f.flags = static_cast<std::uint8_t>(f.flags | flag::Borrowed);
  } else if constexpr (detail::is_same<T, Packed>::value) {
    if (K != Kind::Utf8)
      mark_invalid(f);
    f.flags = static_cast<std::uint8_t>(f.flags | flag::Opaque);
  } else if constexpr (FixedSize<T>::value != 0) {
    static_assert(K != Kind::Utf8 || !kNoText ||
                      !detail::is_same<T, Text<FixedSize<T>::value>>::value,
                  "packbin: PACKBIN_NO_TEXT links no codec: bind a utf8 member to Packed, not "
                  "Text<N>");
    if (K == Kind::Utf8 && !detail::is_same<T, Text<FixedSize<T>::value>>::value)
      mark_invalid(f);
    f.flags = static_cast<std::uint8_t>(f.flags | flag::Fixed);
    f.size = static_cast<std::uint16_t>(FixedSize<T>::value);
  } else {
    mark_invalid(f);
  }
}

// A list element or dict value bound to T: the element root `f` is a string, so T must be
// a Text<N> or a Packed. The stoppers name the reason when the scheme is a constant.
template <typename T>
constexpr void bind_string_element(Field& f) {
  if constexpr (detail::is_same<T, View>::value) {
    mark_invalid(f);
    if (constant_evaluated())
      utf8_element_must_be_Text_N_or_Packed_not_View();
  } else if constexpr (kNoText && FixedSize<T>::value != 0) {
    mark_invalid(f);
    if (constant_evaluated())
      Text_N_needs_the_codec_but_PACKBIN_NO_TEXT_is_defined();
  } else {
    bind_storage<Kind::Utf8, T>(f);
  }
}

// A dict key: always a decoded Text<N>.
template <typename T>
constexpr void bind_key(Field& f) {
  if constexpr (detail::is_same<T, Packed>::value) {
    mark_invalid(f);
    if (constant_evaluated())
      dict_key_must_be_Text_N();
  } else {
    bind_string_element<T>(f);
  }
}

template <typename T>
constexpr bool holds(Kind k) {
  switch (k) {
    case Kind::U8:
      return detail::is_same<T, std::uint8_t>::value;
    case Kind::U16:
      return detail::is_same<T, std::uint16_t>::value;
    case Kind::U32:
      return detail::is_same<T, std::uint32_t>::value;
    case Kind::U64:
      return detail::is_same<T, std::uint64_t>::value;
    case Kind::I8:
      return detail::is_same<T, std::int8_t>::value;
    case Kind::I16:
      return detail::is_same<T, std::int16_t>::value;
    case Kind::I32:
      return detail::is_same<T, std::int32_t>::value;
    case Kind::I64:
      return detail::is_same<T, std::int64_t>::value;
    case Kind::F32:
      return detail::is_same<T, float>::value;
    case Kind::F64:
      return detail::is_same<T, double>::value;
    case Kind::Bool:
      return detail::is_same<T, bool>::value;
    default:
      return false;
  }
}

template <typename A>
constexpr void bind_array(Field& f) {
  f.item = &array_item<A>;
  f.count = &array_count<A>;
  f.size = static_cast<std::uint16_t>(A::capacity);
}

// Binds the element root `f[0]` of a list or dict to an element of type T. The caller has
// set `f[0].access` (the element itself, or an entry's value). Nested lists and dicts bind
// their own elements the same way; anything else that does not fit T is marked invalid.
template <typename T>
constexpr void bind_element(Field* f) {
  if constexpr (IsArray<T>::value) {
    using Item = typename T::value_type;
    if (f[0].kind == Kind::List && f[0].span == 1 + f[1].span) {
      bind_array<T>(f[0]);
      f[1].access = &self;
      bind_element<Item>(f + 1);
    } else if constexpr (IsEntry<Item>::value) {
      if (f[0].kind == Kind::Dict && f[0].span >= 3) {
        bind_array<T>(f[0]);
        f[1].access = &entry_key<Item>;
        bind_key<typename Item::key_type>(f[1]);
        f[2].access = &entry_value<Item>;
        bind_element<typename Item::value_type>(f + 2);
      } else {
        mark_invalid(f[0]);
      }
    } else {
      mark_invalid(f[0]);
    }
  } else if constexpr (detail::is_same<T, View>::value || detail::is_same<T, Packed>::value ||
                       FixedSize<T>::value != 0) {
    if (f[0].kind == Kind::Utf8 && f[0].span == 1)
      bind_string_element<T>(f[0]);
    else
      mark_invalid(f[0]);
  } else {
    if (f[0].span != 1 || !holds<T>(f[0].kind))
      mark_invalid(f[0]);
  }
}

}  // namespace detail

}  // namespace packbin
