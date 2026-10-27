// Host-only checks: wall-clock throughput, threads, the process map and a source scan of the
// core for operating-system headers and random sources. The firmware runner does not build this
// file.

#include "packbin/packbin.hpp"

#include "check.hpp"
#include "load_factor.hpp"

#include <dirent.h>

#include <chrono>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>
#include <thread>

using check::expect;
using packbin::Opt;

namespace {

struct Position {
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t profile = 0;
  Opt<std::uint16_t> heading;
  Opt<std::uint8_t> speed;
  Opt<std::int16_t> altitude;
};

constexpr auto position = packbin::scheme<Position>(
    0x40, packbin::u16<&Position::sid>(0), packbin::i32<&Position::lat>(1),
    packbin::i32<&Position::lon>(2), packbin::u8<&Position::profile>(3),
    packbin::flags(4, packbin::u16<&Position::heading>(4), packbin::u8<&Position::speed>(5),
                   packbin::i16<&Position::altitude>(6)));

Position position_row() {
  Position row;
  row.sid = 1;
  row.lat = 500000000;
  row.lon = 300000000;
  row.profile = 1;
  return row;
}

// Project AC-10: 100000 pack and unpack round trips on one core in at most one second.
void throughput() {
  Position row = position_row();
  std::uint8_t buf[16];
  Position back;
  bool ok = true;
  auto limit = load_factor::bound(1.0);
  auto start = std::chrono::steady_clock::now();
  for (int i = 0; i < 100000 && ok; ++i) {
    auto p = packbin::pack(position, row, buf, sizeof(buf));
    auto u = packbin::unpack(position, buf, p.offset, back);
    ok = p.ok() && u.ok();
  }
  auto ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start)
                .count();
  expect(ok && back.lat == 500000000, "NFR round trips ok");
  load_factor::expect_within(ms / 1000.0, limit, "NFR 100000 round trips <= 1 s");
  std::fprintf(stderr, "nfr elapsed_ms %.2f\n", ms);
}

// The core keeps no shared state: two threads packing the same row get the same bytes.
void parallel_pack() {
  Position row = position_row();
  std::uint8_t left[16] = {};
  std::uint8_t right[16] = {};
  packbin::Result a{}, b{};
  std::thread t1([&] { a = packbin::pack(position, row, left, sizeof(left)); });
  std::thread t2([&] { b = packbin::pack(position, row, right, sizeof(right)); });
  t1.join();
  t2.join();
  expect(a.ok() && b.ok() && a.offset == b.offset && std::memcmp(left, right, a.offset) == 0,
         "parallel pack same bytes");
}

void no_gpu() {
  std::ifstream in("/proc/self/maps");
  if (!in)
    return;
  std::stringstream buf;
  buf << in.rdbuf();
  auto blob = buf.str();
  for (auto const* bad : {"libcuda", "libnvidia", "libvulkan", "libopencl", "metal.framework"})
    expect(blob.find(bad) == std::string::npos, bad);
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

bool names_an_os_rng(char const* text) {
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
    std::snprintf(buf, sizeof(buf), "%ssrc/core/pack.cpp", root);
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
  if (names_an_os_rng(text) || !only_core_headers(text)) {
    std::fprintf(stderr, "AC-3 OS reference in %s\n", path);
    ++dirty;
  }
  return 1;
}

// Every source of src/core and the headers the core is built from include no operating-system
// header and name no OS random source (the firmware builds them as they are).
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
                                        "order.hpp", "codec.hpp", "ecc.hpp"};
  for (char const* h : headers) {
    std::snprintf(path, sizeof(path), "%sinclude/packbin/%s", root, h);
    scanned += scan_core_file(path, dirty);
  }
  expect(scanned >= 9 && dirty == 0, "AC-3 0 OS random references in the core");
}

}  // namespace

int run_core_host_tests() {
  throughput();
  parallel_pack();
  no_gpu();
  ac3_no_os_in_core();
  return check::failures();
}
