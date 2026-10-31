// Every row of fixtures/ecc/percent-vectors.txt (pct, encp, inv, limp, fixp, badp, parp, lmtp)
// through the codec steps that pack, unpack and unpack_repair call, and the public API for the
// scheme rows.
#include "packbin/codec.hpp"

#include "check.hpp"
#include "ecc_percent_support_host.hpp"
#include "ecc_support_host.hpp"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

using check::expect;
using ecc_percent::base;
using ecc_percent::corrupt;
using ecc_percent::msg_of_length;
using ecc_percent::Msg;
using ecc_percent::protect_msg;
using ecc_percent::ref_clear;
using ecc_percent::ref_count;
using ecc_percent::ref_largest;
using ecc_percent::same_msg;
using ecc_percent::setting_of;
using ecc_percent::msg_scheme;
using ecc_percent::kHead;
using ecc_test::Bytes;
using ecc_test::from_hex;
using ecc_test::Rng;
using packbin::Error;

namespace {

namespace pd = packbin::detail;

// The rows of fixtures/ecc/percent-vectors.txt.
struct Row {
  std::string kind;
  std::string id;
  std::vector<std::string> f;
};

bool read_rows(std::vector<Row>& rows) {
  for (auto const* path :
       {"../fixtures/ecc/percent-vectors.txt", "fixtures/ecc/percent-vectors.txt"}) {
    std::ifstream in(path);
    if (!in)
      continue;
    std::string line;
    while (std::getline(in, line)) {
      if (line.empty() || line[0] == '#')
        continue;
      std::istringstream fields(line);
      Row r;
      fields >> r.kind >> r.id;
      for (std::string word; fields >> word;)
        r.f.push_back(word);
      rows.push_back(r);
    }
    return true;
  }
  return false;
}

// pct <id> <p> <L> <n>
void run_pct(Row const& r) {
  int p = std::stoi(r.f[0]);
  int len = std::stoi(r.f[1]);
  expect(pd::percent_count(p, static_cast<std::size_t>(len)) == std::stoi(r.f[2]) &&
             ref_count(p, len) == std::stoi(r.f[2]),
         r.id.c_str());
}

// encp <id> <p> <clear> <protected>
void run_encp(Row const& r) {
  int p = std::stoi(r.f[0]);
  Bytes clear = from_hex(r.f[1]);
  Bytes want = from_hex(r.f[2]);
  Bytes buf(400, 0);
  if (!clear.empty())
    std::memcpy(buf.data(), clear.data(), clear.size());
  int n = -1;
  auto room = pd::parity_room(buf.data(), buf.size(), clear.size(), setting_of(p), n);
  auto sealed = pd::seal(buf.data(), clear.size(), n);
  buf.resize(sealed.offset);
  expect(room.ok() && sealed.ok() && buf == want, r.id.c_str());
}

// inv <id> <p> <N> <L|none>
void run_inv(Row const& r) {
  int p = std::stoi(r.f[0]);
  std::size_t sent = static_cast<std::size_t>(std::stoul(r.f[1]));
  int n = -1;
  auto res = pd::received_parity(setting_of(p), sent, n);
  if (r.f[2] == "none")
    expect(res.error == Error::Uncorrectable, r.id.c_str());
  else
    expect(res.ok() && static_cast<int>(sent) - n == std::stoi(r.f[2]), r.id.c_str());
}

// limp <id> <p> <clear_len> <ok|too_long>
void run_limp(Row const& r) {
  int p = std::stoi(r.f[0]);
  std::size_t len = static_cast<std::size_t>(std::stoul(r.f[1]));
  Bytes buf(400, 0);
  int n = -1;
  auto room = pd::parity_room(buf.data(), buf.size(), len, setting_of(p), n);
  expect(room.error == (r.f[2] == "ok" ? Error::Ok : Error::TooLong), r.id.c_str());
}

// fixp <id> <p> <t> <received> <clear> <count>
void run_fixp(Row const& r) {
  int p = std::stoi(r.f[0]);
  int t = std::stoi(r.f[1]);
  Bytes word = from_hex(r.f[2]);
  Bytes clear = from_hex(r.f[3]);
  int count = std::stoi(r.f[4]);
  std::uint8_t repaired = 99;
  int n = -1;
  auto res = pd::repair_setting(word.data(), word.size(), setting_of(p), t, repaired, n);
  Bytes head(word.begin(), word.end() - n);
  expect(res.ok() && repaired == count && head == clear, r.id.c_str());
}

// badp <id> <p> <t> <received> <kind>
void run_badp(Row const& r) {
  int p = std::stoi(r.f[0]);
  int t = std::stoi(r.f[1]);
  Bytes word = from_hex(r.f[2]);
  Bytes before = word;
  std::uint8_t repaired = 0;
  int n = -1;
  auto res = pd::repair_setting(word.data(), word.size(), setting_of(p), t, repaired, n);
  Error want = r.f[3] == "too_long" ? Error::TooLong : Error::Uncorrectable;
  expect(res.error == want && repaired == 0 && word == before, r.id.c_str());
}

// parp <id> <p> <n>: a C++ scheme has no constructor that takes both, so the last setter wins.
void run_parp(Row const& r) {
  int p = std::stoi(r.f[0]);
  int n = std::stoi(r.f[1]);
  bool p_valid = p >= 0 && p <= 100;
  auto by_percent = packbin::parity_percent(packbin::parity(base, n), p);
  expect(p_valid ? by_percent.status.ok() && by_percent.parity == 0 &&
                       by_percent.parity_percent == p
                 : by_percent.status.error == Error::SchemeInvalid,
         r.id.c_str());
  if (p_valid) {
    auto by_count = packbin::parity(packbin::parity_percent(base, p), n);
    expect(by_count.status.ok() && by_count.parity == n && by_count.parity_percent == 0,
           r.id.c_str());
  }
}

// lmtp <id> <t>
void run_lmtp(Row const& r) {
  int t = std::stoi(r.f[0]);
  Rng rng(1);
  auto s = packbin::parity_percent(base, 25);
  Msg m = msg_of_length(40, rng);
  Bytes word = protect_msg(s, m);
  word[5] ^= 0x40;
  Bytes before = word;
  Msg back;
  auto res = packbin::unpack_repair(s, word.data(), word.size(), back, t);
  std::uint8_t repaired = 9;
  int n = -1;
  auto direct = pd::repair_setting(word.data(), 7, setting_of(25), t, repaired, n);
  expect(res.error == Error::BadValue && word == before && direct.error == Error::BadValue,
         r.id.c_str());
}

void vectors() {
  std::vector<Row> rows;
  if (!read_rows(rows)) {
    std::fprintf(stderr, "ecc percent vectors: fixtures/ecc/percent-vectors.txt not found\n");
    ++check::failures();
    return;
  }
  int seen[8] = {};
  for (auto const& r : rows) {
    if (r.kind == "pct") {
      run_pct(r);
      ++seen[0];
    } else if (r.kind == "encp") {
      run_encp(r);
      ++seen[1];
    } else if (r.kind == "inv") {
      run_inv(r);
      ++seen[2];
    } else if (r.kind == "limp") {
      run_limp(r);
      ++seen[3];
    } else if (r.kind == "fixp") {
      run_fixp(r);
      ++seen[4];
    } else if (r.kind == "badp") {
      run_badp(r);
      ++seen[5];
    } else if (r.kind == "parp") {
      run_parp(r);
      ++seen[6];
    } else if (r.kind == "lmtp") {
      run_lmtp(r);
      ++seen[7];
    } else {
      std::fprintf(stderr, "ecc percent vectors: unknown row kind %s\n", r.kind.c_str());
      ++check::failures();
    }
  }
  for (int count : seen)
    expect(count > 0, "ecc percent vectors: every row kind is present");
  std::printf("ecc percent vectors: pct %d encp %d inv %d limp %d fixp %d badp %d parp %d lmtp %d\n",
              seen[0], seen[1], seen[2], seen[3], seen[4], seen[5], seen[6], seen[7]);
}

}  // namespace

int run_core_ecc_percent_vectors_host_tests() {
  vectors();
  return check::failures();
}
