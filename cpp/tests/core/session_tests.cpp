#include "packbin/os_random.hpp"
#include "packbin/session.hpp"

#include "check.hpp"

#include <dirent.h>

#include <cstdio>
#include <cstring>

using check::expect;
using packbin::Error;
using packbin::PackSession;

namespace {

struct Position {
  std::uint16_t sid = 0;
  std::int32_t lat = 0;
  std::int32_t lon = 0;
  std::uint8_t profile = 0;
  std::uint8_t flags = 0;
};

// The flags byte stays 0 here, which is the same byte an empty flags group writes.
constexpr auto position = packbin::scheme<Position>(
    0x40, packbin::u16<&Position::sid>(0), packbin::i32<&Position::lat>(1),
    packbin::i32<&Position::lon>(2), packbin::u8<&Position::profile>(3),
    packbin::u8<&Position::flags>(4));

constexpr char const* kGoldenHex = "4001000065cd1d00a3e1110100";
constexpr char const* kCipherHex = "b55d0a29c56c203712b241232e";
constexpr char const* kNonceHex = "01000000000000000000000000000000";

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

void fixture_nonce(std::uint8_t (&nonce)[16]) { check::parse_hex(kNonceHex, nonce, 16); }

bool all_bytes(std::uint8_t const* p, std::size_t n, std::uint8_t v) {
  for (std::size_t i = 0; i < n; ++i)
    if (p[i] != v)
      return false;
  return true;
}

bool open_pair(PackSession& opener, PackSession& waiter) {
  std::uint8_t seed[32];
  std::uint8_t nonce[16];
  seed_bytes(seed);
  fixture_nonce(nonce);
  return opener.load(seed, sizeof(seed)) && waiter.load(seed, sizeof(seed)) &&
         opener.start(nonce, sizeof(nonce)) && waiter.join(nonce, sizeof(nonce));
}

void ac1_same_session_bytes() {
  PackSession opener, waiter;
  expect(open_pair(opener, waiter), "AC-1 start and join");
  Position row = position_row();

  std::uint8_t small[4] = {0xaa, 0xaa, 0xaa, 0xaa};
  auto full = opener.pack(position, row, small, sizeof(small));
  expect(full.error == Error::BufferFull && full.offset == 3 && all_bytes(small, 3, 0) &&
             small[3] == 0xaa,
         "AC-1 failed pack leaves no clear bytes and writes nothing past the offset");

  std::uint8_t buf[32];
  auto p = opener.pack(position, row, buf, sizeof(buf));
  expect(p.ok() && p.offset == 13, "AC-1 length 13");
  expect(p.ok() && check::same_hex(buf, p.offset, kCipherHex),
         "AC-1 ciphertext (send index kept by the failed pack)");

  Position got;
  auto u = waiter.unpack(position, buf, p.offset, got);
  expect(u.ok() && u.offset == 13, "AC-1 waiter unpack ok");
  expect(same_row(got, row), "AC-1 waiter fields mismatches 0");
  expect(check::same_hex(buf, p.offset, kGoldenHex), "AC-1 buffer is clear after unpack");

  std::uint8_t second[32];
  auto p2 = opener.pack(position, row, second, sizeof(second));
  expect(p2.ok() && p2.offset == 13 && !check::same_hex(second, 13, kCipherHex),
         "AC-1 next packet index gives another pad");
  Position again;
  int calls = 0;
  auto u2 = waiter.unpack(second, p2.offset, packbin::on(position, again, [&](Position const&) {
                            ++calls;
                          }));
  expect(u2.ok() && calls == 1 && same_row(again, row), "AC-1 handler unpack of packet 1");

  std::uint8_t clear[32];
  auto c = packbin::pack(position, row, clear, sizeof(clear));
  expect(c.ok() && check::same_hex(clear, c.offset, kGoldenHex), "AC-1 clear pack golden");
}

struct RandomCalls {
  int calls = 0;
};

bool failing_random(std::uint8_t* out, std::size_t n, void* ctx) {
  ++static_cast<RandomCalls*>(ctx)->calls;
  if (n > 0)
    out[0] = 0x11;
  return false;
}

void ac2_random_failure() {
  std::uint8_t seed[32];
  seed_bytes(seed);
  PackSession s;
  expect(s.load(seed, sizeof(seed)), "AC-2 load");
  RandomCalls ctx;
  std::uint8_t nonce_out[16];
  std::memset(nonce_out, 0xaa, sizeof(nonce_out));
  expect(!s.start(failing_random, &ctx, nonce_out), "AC-2 start reports failure");
  expect(ctx.calls == 1 && !s.is_open(), "AC-2 nothing opens");
  expect(all_bytes(nonce_out, sizeof(nonce_out), 0xaa), "AC-2 nonce_out untouched");

  std::uint8_t buf[32];
  std::memset(buf, 0xaa, sizeof(buf));
  auto p = s.pack(position, position_row(), buf, sizeof(buf));
  expect(p.error == Error::BadValue && p.offset == 0 && all_bytes(buf, sizeof(buf), 0xaa),
         "AC-2 0 bytes padded");

  std::uint8_t nonce[16];
  fixture_nonce(nonce);
  expect(s.start(nonce, sizeof(nonce)), "AC-2 seed kept for a later start");
  auto q = s.pack(position, position_row(), buf, sizeof(buf));
  expect(q.ok() && check::same_hex(buf, q.offset, kCipherHex), "AC-2 later start bytes");
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

void ac4_length_rules() {
  std::uint8_t seed[33];
  for (std::size_t i = 0; i < sizeof(seed); ++i)
    seed[i] = static_cast<std::uint8_t>(i + 1);
  std::uint8_t nonce[17] = {};
  int sessions = 0;

  PackSession short_seed, long_seed;
  if (short_seed.load(seed, 31) || long_seed.load(seed, 33))
    ++sessions;
  if (short_seed.start(nonce, 16) || long_seed.join(nonce, 16))
    ++sessions;

  PackSession s;
  expect(s.load(seed, 32), "AC-4 good seed loads");
  if (s.join(nonce, 15) || s.join(nonce, 17) || s.start(nonce, 15) || s.start(nonce, 17))
    ++sessions;
  if (s.is_open() || short_seed.is_open() || long_seed.is_open())
    ++sessions;
  expect(sessions == 0, "AC-4 sessions created 0");

  std::uint8_t buf[32];
  std::memset(buf, 0xaa, sizeof(buf));
  auto p = s.pack(position, position_row(), buf, sizeof(buf));
  expect(p.error == Error::BadValue && p.field == -1 && all_bytes(buf, sizeof(buf), 0xaa),
         "AC-4 pack before open writes nothing");
  Position row;
  auto u = s.unpack(position, buf, sizeof(buf), row);
  expect(u.error == Error::BadValue && all_bytes(buf, sizeof(buf), 0xaa),
         "AC-4 unpack before open leaves the buffer");

  PackSession reloaded;
  expect(reloaded.load(seed, 32) && !reloaded.load(seed, 31) && !reloaded.start(nonce, 16),
         "AC-4 a failed load drops the earlier seed");
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

int run_core_session_tests() {
  ac1_same_session_bytes();
  ac2_random_failure();
  ac3_no_os_in_core();
  ac4_length_rules();
  host_os_random_round_trip();
  return check::failures();
}
