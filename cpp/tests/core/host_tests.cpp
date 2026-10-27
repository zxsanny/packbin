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

bool ident_char(char c) {
  return (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '_';
}

// True when `call` (such as `rand(`) occurs where no identifier character comes before it, so
// `operand(` and `brand(` are not the call but `std::rand(` and ` rand(` are.
bool names_call(char const* text, char const* call) {
  for (char const* at = std::strstr(text, call); at != nullptr; at = std::strstr(at + 1, call))
    if (at == text || !ident_char(at[-1]))
      return true;
  return false;
}

// A source of random bytes of an operating system, a C library or a vendor SDK, by file, device
// or function; `random.h` also covers "esp_random.h", "sys/random.h" and "board_random.hpp".
bool names_an_os_rng(char const* text) {
  static char const* const names[] = {
      "random.h",       "/dev/urandom",          "/dev/random",        "arc4random",
      "getrandom",      "getentropy",            "esp_random",         "esp_fill_random",
      "random_device",  "RandomNumberGenerator", "SecRandomCopyBytes", "BCryptGenRandom",
      "CryptGenRandom", "RtlGenRandom",          "RAND_bytes",         "mbedtls_ctr_drbg",
      "rand48"};
  static char const* const calls[] = {"rand(", "srand(", "random(", "rand_r("};
  for (char const* n : names)
    if (std::strstr(text, n) != nullptr)
      return true;
  for (char const* c : calls)
    if (names_call(text, c))
      return true;
  return false;
}

// The first `close` of the line starting at `p`, or null when the line ends first.
char const* closing(char const* p, char close) {
  for (; *p != '\0' && *p != '\n'; ++p)
    if (*p == close)
      return p;
  return nullptr;
}

bool allowed_header(char const* name, std::size_t len) {
  static char const* const allowed[] = {"cstdint", "cstddef", "cstring", "type_traits",
                                        "limits",  "array",   "utility"};
  for (char const* a : allowed)
    if (std::strlen(a) == len && std::strncmp(name, a, len) == 0)
      return true;
  return false;
}

// A quoted include is a header of the library: packbin/<name>.hpp, or <name>.hpp in src/core.
bool own_header(char const* name, std::size_t len) {
  if (len < 5 || std::strncmp(name + len - 4, ".hpp", 4) != 0)
    return false;
  if (len > 8 && std::strncmp(name, "packbin/", 8) == 0)
    name += 8;
  for (; *name != '"'; ++name)
    if (*name == '/')
      return false;
  return true;
}

// Every `#include` of `text` (spaces allowed around the #, mid-line and commented out too) names
// a header of the library, or a standard header the core allows between <>; anything else, such
// as <random>, <unistd.h>, "esp_random.h" or a macro, is false.
bool only_core_includes(char const* text) {
  for (char const* hash = std::strchr(text, '#'); hash != nullptr;
       hash = std::strchr(hash + 1, '#')) {
    char const* p = hash + 1;
    while (*p == ' ' || *p == '\t')
      ++p;
    if (std::strncmp(p, "include", 7) != 0)
      continue;
    p += 7;
    while (*p == ' ' || *p == '\t')
      ++p;
    char const* end = (*p == '<' || *p == '"') ? closing(p + 1, *p == '<' ? '>' : '"') : nullptr;
    if (end == nullptr)
      return false;
    std::size_t len = static_cast<std::size_t>(end - (p + 1));
    if (*p == '<' ? !allowed_header(p + 1, len) : !own_header(p + 1, len))
      return false;
  }
  return true;
}

bool core_text_clean(char const* text) {
  return !names_an_os_rng(text) && only_core_includes(text);
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
  if (!core_text_clean(text)) {
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

// The scan has to see what it is for: each snippet below is source a core file must not hold, and
// the clean ones (prose about random bytes, names that only end like a call) must pass.
void ac3_scan_catches_each_pattern() {
  static char const* const dirty[] = {
      "#include <sys/random.h>\n",
      "#include \"sys/random.h\"\n",
      "#include <esp_random.h>\n",
      "#include \"esp_random.h\"\n",
      "#include \"packbin/board_random.hpp\"\n",
      "#include \"driver/rng.h\"\n",
      "#include \"nrf_rng.h\"\n",
      "#include <random>\n",
      "#include <cstdlib>\n",
      "#include <stdlib.h>\n",
      "#include <unistd.h>\n",
      "#  include\t<fcntl.h>\n",
      "#include RANDOM_HEADER\n",
      "int a;\n#include \"../outside.hpp\"\n",
      "esp_fill_random(out, n);\n",
      "uint32_t r = esp_random();\n",
      "getrandom(out, n, 0);\n",
      "arc4random_buf(out, n);\n",
      "getentropy(out, n);\n",
      "std::fopen(\"/dev/urandom\", \"rb\");\n",
      "std::fopen(\"/dev/random\", \"rb\");\n",
      "std::random_device rd;\n",
      "var g = RandomNumberGenerator.Create();\n",
      "int x = rand();\n",
      "int x = std::rand() % 7;\n",
      "srand(1);\n",
      "x = random();\n",
      "rand_r(&seed);\n",
      "double d = drand48();\n",
      "RAND_bytes(out, n);\n",
      "SecRandomCopyBytes(nullptr, n, out);\n",
      "BCryptGenRandom(nullptr, out, n, 2);\n",
      "mbedtls_ctr_drbg_random(&ctx, out, n);\n"};
  static char const* const clean[] = {
      "#include \"packbin/platform.hpp\"\n#include \"values.hpp\"\n#include <cstdint>\n",
      "# include <array>\n#include \"packbin/text_tables.hpp\"\n",
      "// The caller supplies random bytes; the core draws none.\n",
      "int operand(int x); int brand(int y); int grand(int z);\n",
      "int strand(int a) { return operand(a); }\n"};
  for (char const* snippet : dirty) {
    char msg[160];
    std::snprintf(msg, sizeof(msg), "AC-3 the scan misses: %.100s", snippet);
    expect(!core_text_clean(snippet), msg);
  }
  for (char const* snippet : clean) {
    char msg[160];
    std::snprintf(msg, sizeof(msg), "AC-3 the scan flags clean text: %.100s", snippet);
    expect(core_text_clean(snippet), msg);
  }
}

}  // namespace

int run_core_host_tests() {
  throughput();
  parallel_pack();
  no_gpu();
  ac3_no_os_in_core();
  ac3_scan_catches_each_pattern();
  return check::failures();
}
