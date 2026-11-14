// Probe of AZ-4291: how deep a scheme may be nested. `probe <shape> <depth>` prints one line, tab
// separated: package, shape-with-depth (`when-1000`), build, pack, unpack. It asserts nothing: it prints
// what happens. A stack overflow in the package kills the process; `run.sh` runs each case through
// ../case.sh, so that death is one `crashed:` line.
//
// How the nesting is built. A C++ scheme is a table of `Field` entries in preorder (`Scheme<Row, N>`,
// N a compile-time constant); the builders `when(...)` and `group(...)` nest by template arguments,
// so 50,000 levels cannot be written in source (and 50,000 nested template calls would only test the
// compiler). This probe takes the head entry of one real builder call (`when(1, eq(0, 1), u8<&Row::b>(1))`
// or `group(0, u8<&Row::b>(0))`), copies it D times into a table of N = D + 2 (when) or D + 1 (group)
// entries in a loop, sets each entry's `span` the way `nest()` does, and checks the table with
// `check_table`, the call `scheme()` makes for its status. The table is static storage, so the stack
// the package meets is its own. The probe itself never recurses.
//
// Group form: C++ has no group without an anchor. A group is anchored (its id is the id of its first
// child, its members are members of the row around it and share its ids), so `group-D` is D groups
// inside each other, all anchored at id 0, the innermost holding `u8 b` (id 0): the "group inside a
// group" form the package has. The table is the same one `group(0, group(0, ... u8<&Row::b>(0)))` builds.
//
// Limits of the table that this probe cannot go around: `Field::span` is 16 bits, so a table holds at
// most 65,535 entries; depth 50,000 fits (50,002 entries, 1.6 MB).
#include <packbin/packbin.hpp>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

namespace pb = packbin;

struct Row {
  std::uint8_t a = 0;
  std::uint8_t b = 0;
};

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
// none), the bytes that field needed and the byte offset. At most 120 characters after `refused: `.
std::string refused(pb::Result const& r) {
  std::string text = std::string("{\"error\":\"") + name_of(r.error) + "\",\"field\":" + std::to_string(r.field) +
                     ",\"needed\":" + std::to_string(r.needed) + ",\"offset\":" + std::to_string(r.offset) + "}";
  if (text.size() > 120)
    text.resize(120);
  return "refused: " + text;
}

// Hex of at most 80 characters as it is; a longer one is its first 40 characters, `...` and the byte count.
std::string hex(std::uint8_t const* data, std::size_t len) {
  static char const digits[] = "0123456789abcdef";
  std::string out;
  for (std::size_t i = 0; i < len; ++i) {
    out += digits[data[i] >> 4];
    out += digits[data[i] & 15];
  }
  if (out.size() > 80)
    return out.substr(0, 40) + "..." + std::to_string(len);
  return out;
}

// Written at once: a line that a crash cuts short still holds the cells before it.
void emit(std::string const& text) {
  std::fputs(text.c_str(), stdout);
  std::fflush(stdout);
}

enum class Shape { When, Group };

// One table of N entries, built in a loop. when: a, W1..WD, b (N = D + 2); group: G1..GD, b (N = D + 1).
template <std::size_t N>
pb::Scheme<Row, N>& build(Shape shape, std::size_t depth) {
  static pb::Scheme<Row, N> s;
  s = pb::Scheme<Row, N>{};
  s.type_number = 1;
  std::size_t at = 0;
  if (shape == Shape::When) {
    s.fields[at++] = pb::u8<&Row::a>(0).f[0];
    pb::Field head = pb::when(1, pb::eq(0, 1), pb::u8<&Row::b>(1)).f[0];
    for (std::size_t i = 0; i < depth; ++i) {
      head.span = static_cast<std::uint16_t>(N - at);
      s.fields[at++] = head;
    }
    s.fields[at++] = pb::u8<&Row::b>(1).f[0];
  } else {
    pb::Field head = pb::group(0, pb::u8<&Row::b>(0)).f[0];
    for (std::size_t i = 0; i < depth; ++i) {
      head.span = static_cast<std::uint16_t>(N - at);
      s.fields[at++] = head;
    }
    s.fields[at++] = pb::u8<&Row::b>(0).f[0];
  }
  s.status = pb::check_table(s.fields.data(), s.fields.size());
  return s;
}

template <std::size_t N>
void probe(char const* label, Shape shape, std::size_t depth) {
  emit(std::string("cpp\t") + label + "\t");
  pb::Scheme<Row, N>& s = build<N>(shape, depth);
  pb::Result built = pb::validate(s);
  if (!built.ok()) {
    emit(refused(built) + "\t-\t-\n");
    return;
  }
  emit("built\t");
  Row values;
  values.a = 1;
  values.b = 7;
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
  if (shape == Shape::When && got.a == values.a && got.b == values.b)
    emit("same\n");
  else if (shape == Shape::Group && got.b == values.b)
    emit("same\n");
  else
    emit("differs: {\"a\":" + std::to_string(got.a) + ",\"b\":" + std::to_string(got.b) + "}\n");
}

int main(int argc, char** argv) {
  if (argc == 3) {
    std::size_t depth = static_cast<std::size_t>(std::strtoul(argv[2], nullptr, 10));
    std::string label = std::string(argv[1]) + "-" + argv[2];
    if (std::strcmp(argv[1], "when") == 0) {
      if (depth == 1000)
        probe<1002>(label.c_str(), Shape::When, depth);
      else if (depth == 5000)
        probe<5002>(label.c_str(), Shape::When, depth);
      else if (depth == 50000)
        probe<50002>(label.c_str(), Shape::When, depth);
      else
        goto usage;
      return 0;
    }
    if (std::strcmp(argv[1], "group") == 0) {
      if (depth == 1000)
        probe<1001>(label.c_str(), Shape::Group, depth);
      else if (depth == 5000)
        probe<5001>(label.c_str(), Shape::Group, depth);
      else if (depth == 50000)
        probe<50001>(label.c_str(), Shape::Group, depth);
      else
        goto usage;
      return 0;
    }
  }
usage:
  std::fprintf(stderr, "usage: probe <when|group> <1000|5000|50000>\n");
  return 2;
}
