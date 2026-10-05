// Host-only session checks: the source scan for OS random references (AC-3) and a round trip
// through the operating-system random source. The firmware runner does not build this file;
// the session vectors live in session_tests.cpp.

#include "packbin/os_random.hpp"
#include "packbin/session.hpp"

#include "check.hpp"

#include <dirent.h>

#include <cstdio>
#include <cstring>

using check::expect;
using packbin::PackSession;

namespace {

struct Position {
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t profile = 0;
  std::uint8_t flags = 0;
};

constexpr auto position = packbin::scheme<Position>(
    0x40, packbin::u16<&Position::sid>(0), packbin::i32<&Position::lat>(1),
    packbin::i32<&Position::lon>(2), packbin::u8<&Position::profile>(3),
    packbin::u8<&Position::flags>(4));

Position position_row() {
  Position p;
  p.sid = 1;
  p.lat = 500000000;
  p.lon = 300000000;
  p.profile = 1;
  return p;
}

bool same_row(Position const& a, Position const& b) {
  return a.sid == b.sid && a.lat == b.lat && a.lon == b.lon && a.profile == b.profile &&
         a.flags == b.flags;
}

void seed_bytes(std::uint8_t (&seed)[32]) {
  for (std::size_t i = 0; i < sizeof(seed); ++i)
    seed[i] = static_cast<std::uint8_t>(i + 1);
}

bool all_bytes(std::uint8_t const* p, std::size_t n, std::uint8_t v) {
  for (std::size_t i = 0; i < n; ++i)
    if (p[i] != v)
      return false;
  return true;
}

// Reads a whole source file into `buf`; false when it is missing or does not fit.
bool read_text(char const* path, char* buf, std::size_t cap) {
  std::FILE* f = std::fopen(path, "rb");
  if (f == nullptr)
    return false;
  std::size_t n = std::fread(buf, 1, cap - 1, f);
  bool whole = std::feof(f) != 0;
  std::fclose(f);
  buf[n] = '\0';
  return whole;
}

bool os_random_named(char const* text) {
  return std::strstr(text, "sys/random.h") != nullptr ||
         std::strstr(text, "/dev/urandom") != nullptr ||
         std::strstr(text, "arc4random") != nullptr;
}

bool only_core_headers(char const* text) {
  static char const* const allowed[] = {"cstdint", "cstddef", "cstring", "type_traits",
                                        "limits",  "array",   "utility"};
  for (char const* at = std::strstr(text, "#include <"); at != nullptr;
       at = std::strstr(at + 1, "#include <")) {
    char const* name = at + std::strlen("#include <");
    char const* end = std::strchr(name, '>');
    if (end == nullptr)
      return false;
    bool ok = false;
    for (char const* a : allowed)
      if (std::strlen(a) == static_cast<std::size_t>(end - name) &&
          std::strncmp(name, a, std::strlen(a)) == 0)
        ok = true;
    if (!ok)
      return false;
  }
  return true;
}

char const* cpp_root() {
  static char const* const roots[] = {"", "cpp/", "../"};
  char buf[256];
  for (char const* root : roots) {
    std::snprintf(buf, sizeof(buf), "%ssrc/core/session.cpp", root);
    std::FILE* f = std::fopen(buf, "rb");
    if (f != nullptr) {
      std::fclose(f);
      return root;
    }
  }
  return nullptr;
}

int scan_core_file(char const* path, int& dirty) {
  static char text[1 << 16];
  if (!read_text(path, text, sizeof(text))) {
    std::fprintf(stderr, "AC-3 cannot read %s\n", path);
    ++dirty;
    return 0;
  }
  if (os_random_named(text) || !only_core_headers(text)) {
    std::fprintf(stderr, "AC-3 OS reference in %s\n", path);
    ++dirty;
  }
  return 1;
}

void ac3_no_os_in_core() {
  char const* root = cpp_root();
  expect(root != nullptr, "AC-3 sources found");
  if (root == nullptr)
    return;
  char path[256];
  int scanned = 0;
  int dirty = 0;

  std::snprintf(path, sizeof(path), "%ssrc/core", root);
  DIR* dir = opendir(path);
  expect(dir != nullptr, "AC-3 src/core listed");
  for (dirent* e = dir ? readdir(dir) : nullptr; e != nullptr; e = readdir(dir)) {
    std::size_t len = std::strlen(e->d_name);
    bool source = len > 4 && (std::strcmp(e->d_name + len - 4, ".cpp") == 0 ||
                              std::strcmp(e->d_name + len - 4, ".hpp") == 0);
    if (!source)
      continue;
    std::snprintf(path, sizeof(path), "%ssrc/core/%s", root, e->d_name);
    scanned += scan_core_file(path, dirty);
  }
  if (dir != nullptr)
    closedir(dir);

  static char const* const headers[] = {"core.hpp",  "table.hpp", "fields.hpp",
                                        "order.hpp", "codec.hpp", "session.hpp"};
  for (char const* h : headers) {
    std::snprintf(path, sizeof(path), "%sinclude/packbin/%s", root, h);
    scanned += scan_core_file(path, dirty);
  }
  expect(scanned >= 9 && dirty == 0, "AC-3 0 OS random references in the core");

  static char text[1 << 14];
  std::snprintf(path, sizeof(path), "%ssrc/os_random.cpp", root);
  expect(read_text(path, text, sizeof(text)) && os_random_named(text),
         "AC-3 the host adapter holds the OS random source");
}

void host_os_random_round_trip() {
  std::uint8_t seed[32];
  seed_bytes(seed);
  PackSession opener, waiter;
  std::uint8_t nonce[16] = {};
  bool started = opener.load(seed, sizeof(seed)) && opener.start(packbin::os_random, nullptr,
                                                                  nonce);
  expect(started, "host os_random start");
  expect(!all_bytes(nonce, sizeof(nonce), 0), "host nonce filled");
  expect(waiter.load(seed, sizeof(seed)) && waiter.join(nonce, sizeof(nonce)), "host join");

  Position row = position_row();
  std::uint8_t buf[32];
  auto p = opener.pack(position, row, buf, sizeof(buf));
  Position got;
  auto u = waiter.unpack(position, buf, p.offset, got);
  expect(p.ok() && u.ok() && same_row(got, row), "host round trip");
}

}  // namespace

int run_core_session_host_tests() {
  ac3_no_os_in_core();
  host_os_random_round_trip();
  return check::failures();
}
