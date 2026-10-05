// Host-only checks: wall-clock throughput, threads and the process map. The firmware runner
// does not build this file.

#include "packbin/packbin.hpp"

#include "check.hpp"

#include <chrono>
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
  auto start = std::chrono::steady_clock::now();
  for (int i = 0; i < 100000 && ok; ++i) {
    auto p = packbin::pack(position, row, buf, sizeof(buf));
    auto u = packbin::unpack(position, buf, p.offset, back);
    ok = p.ok() && u.ok();
  }
  auto ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start)
                .count();
  expect(ok && back.lat == 500000000, "NFR round trips ok");
  expect(ms <= 1000.0, "NFR 100000 round trips <= 1 s");
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

}  // namespace

int run_core_host_tests() {
  throughput();
  parallel_pack();
  no_gpu();
  return check::failures();
}
