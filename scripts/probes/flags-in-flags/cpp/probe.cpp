// Probe of AZ-4251: a `flags` that is a direct member of a `flags`. It builds scheme S of ../README.md
// with the public API, packs each shape's values and unpacks its own bytes. One line per shape:
// package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints what happens.
//
// The row is a struct: `x` is an `Opt<std::uint8_t>` (absent when it has no value), `b` a `bool` (a
// clear bit is `false`). Ids: both `flags` and `x` are 0, `b` is 1. A failure is a `Result` value,
// printed as its members.
//
// The scheme is built at run time (`auto s = scheme<Row>(...)`, checked with `validate(s)`): the form
// that reports a refused scheme as a value. With -DPROBE_CONSTEXPR the translation unit holds it as a
// constant (`constexpr auto s = ...`), where a refused scheme does not compile; `run.sh` builds each
// shape that way too. The scheme is the same in every shape, so the -DSHAPE_<NAME> that run.sh passes
// selects nothing here.
//
// `probe <shape>` prints one shape: `run.sh` starts one process per shape, so a crash in one shape
// is its own line.
#include <packbin/packbin.hpp>

#include <cstdio>
#include <cstring>
#include <string>

namespace pb = packbin;

#ifdef PROBE_CONSTEXPR
#define PROBE_SCHEME constexpr auto
#define PROBE_SUFFIX "-constexpr"
#else
#define PROBE_SCHEME auto
#define PROBE_SUFFIX ""
#endif

struct Row {
  pb::Opt<std::uint8_t> x;
  bool b = false;
};

std::string number(unsigned long long n) { return std::to_string(n); }

std::string shown(Row const& r) {
  return std::string("{\"b\":") + (r.b ? "true" : "false") + ",\"x\":" + (r.x.has ? number(r.x.value) : "null") + "}";
}

char const* name_of(pb::Error e) {
  switch (e) {
    case pb::Error::Ok:
      return "Ok";
    case pb::Error::ShortPacket:
      return "ShortPacket";
    case pb::Error::TrailingBytes:
      return "TrailingBytes";
    case pb::Error::TypeMismatch:
      return "TypeMismatch";
    case pb::Error::BufferFull:
      return "BufferFull";
    case pb::Error::TooMany:
      return "TooMany";
    case pb::Error::BadValue:
      return "BadValue";
    case pb::Error::SchemeInvalid:
      return "SchemeInvalid";
    case pb::Error::ScratchTooSmall:
      return "ScratchTooSmall";
    case pb::Error::Uncorrectable:
      return "Uncorrectable";
    case pb::Error::TooLong:
      return "TooLong";
    case pb::Error::TagMismatch:
      return "TagMismatch";
    case pb::Error::Duplicate:
      return "Duplicate";
    case pb::Error::TooOld:
      return "TooOld";
  }
  return "unknown";
}

// The package has no text for a failure: a `Result` is its error, the order id of the field (-1 when
// none), the bytes that field needed and the byte offset.
std::string refused(pb::Result const& r) {
  return std::string("refused: {\"error\":\"") + name_of(r.error) + "\",\"field\":" + std::to_string(r.field) +
         ",\"needed\":" + number(r.needed) + ",\"offset\":" + number(r.offset) + "}";
}

std::string hex(std::uint8_t const* data, std::size_t len) {
  static char const digits[] = "0123456789abcdef";
  std::string out;
  for (std::size_t i = 0; i < len; ++i) {
    out += digits[data[i] >> 4];
    out += digits[data[i] & 15];
  }
  return out;
}

// Written at once: a line that a crash cuts short still holds the cells before it.
void emit(std::string const& text) {
  std::fputs(text.c_str(), stdout);
  std::fflush(stdout);
}

template <std::size_t N>
void probe(char const* shape, pb::Scheme<Row, N> const& s, Row const& values) {
  emit(std::string("cpp\t") + shape + PROBE_SUFFIX "\t");
  pb::Result built = pb::validate(s);
  if (!built.ok()) {
    emit(refused(built) + "\t-\t-\n");
    return;
  }
  emit("built\t");
  std::uint8_t buf[16] = {};
  pb::Result packed = pb::pack(s, values, buf, sizeof(buf));
  if (!packed.ok()) {
    emit(refused(packed) + "\t-\n");
    return;
  }
  emit(hex(buf, packed.offset) + "\t");
  Row got;
  pb::Result read = pb::unpack(s, buf, packed.offset, got);
  if (!read.ok()) {
    emit(refused(read) + "\n");
    return;
  }
  emit(shown(got) == shown(values) ? "same\n" : "differs: " + shown(got) + "\n");
}

// S: flags(flags(u8 x), bool b).
void run(char const* shape, Row const& values) {
  PROBE_SCHEME s = pb::scheme<Row>(
      1, pb::flags(0, pb::flags(0, pb::u8<&Row::x>(0)), pb::boolean<&Row::b>(1)));
  probe(shape, s, values);
}

Row row_of(bool has_x, bool b) {
  Row r;
  if (has_x)
    r.x = 9;
  r.b = b;
  return r;
}

struct Shape {
  char const* name;
  bool has_x;
  bool b;
};

Shape const shapes[] = {
    {"both", true, true},
    {"x-only", true, false},
    {"b-only", false, true},
    {"none", false, false},
};

int main(int argc, char** argv) {
  if (argc == 2) {
    for (Shape const& shape : shapes) {
      if (std::strcmp(shape.name, argv[1]) == 0) {
        run(shape.name, row_of(shape.has_x, shape.b));
        return 0;
      }
    }
  }
  std::fprintf(stderr, "usage: probe <shape>; shapes:");
  for (Shape const& shape : shapes)
    std::fprintf(stderr, " %s", shape.name);
  std::fprintf(stderr, "\n");
  return 2;
}
