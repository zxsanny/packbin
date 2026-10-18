// Message ECC codec vectors (AZ-2687): every row kind of fixtures/ecc/vectors.txt through
// ecc::protect, ecc::check and ecc::repair. enc: the parity equals the vector. fix: repair gives
// the clear bytes and the count. bad: repair is refused with the kind and leaves the buffer as it
// was. lim: protect accepts or refuses the clear length. par: n above 32 is BadParity. lmt: a
// limit above n / 2 is BadLimit.
#include "packbin/ecc.hpp"

#include "check.hpp"
#include "ecc_support_host.hpp"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>

using check::expect;
using ecc_test::Bytes;
using ecc_test::from_hex;
using packbin::ecc::Kind;

namespace {

struct Row {
  std::string kind;
  std::string id;
  std::vector<std::string> f;
};

bool read_rows(std::vector<Row>& rows) {
  for (auto const* path : {"../fixtures/ecc/vectors.txt", "fixtures/ecc/vectors.txt"}) {
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

bool same(Bytes const& a, Bytes const& b) {
  return a.size() == b.size() && (a.empty() || std::memcmp(a.data(), b.data(), a.size()) == 0);
}

Kind kind_of(std::string const& name) {
  if (name == "uncorrectable")
    return Kind::Uncorrectable;
  if (name == "short")
    return Kind::Short;
  if (name == "too_long")
    return Kind::TooLong;
  if (name == "bad_parity")
    return Kind::BadParity;
  if (name == "bad_limit")
    return Kind::BadLimit;
  return Kind::Ok;
}

// enc <id> <n> <clear> <protected>
void run_enc(Row const& r) {
  int n = std::stoi(r.f[0]);
  Bytes clear = from_hex(r.f[1]);
  Bytes want = from_hex(r.f[2]);
  std::uint8_t parity[32] = {};
  Kind k = packbin::ecc::protect(clear.data(), clear.size(), n, parity);
  Bytes got = clear;
  got.insert(got.end(), parity, parity + n);
  expect(k == Kind::Ok && same(got, want), r.id.c_str());
  auto c = packbin::ecc::check(want.data(), want.size(), n);
  expect(c.ok() && c.repaired == 0, r.id.c_str());
}

// fix <id> <n> <t> <received> <clear> <count>
void run_fix(Row const& r) {
  int n = std::stoi(r.f[0]);
  int t = std::stoi(r.f[1]);
  Bytes word = from_hex(r.f[2]);
  Bytes clear = from_hex(r.f[3]);
  int count = std::stoi(r.f[4]);
  auto o = packbin::ecc::repair(word.data(), word.size(), n, t);
  Bytes head(word.begin(), word.end() - n);
  expect(o.ok() && o.repaired == count && same(head, clear), r.id.c_str());
  expect(packbin::ecc::check(word.data(), word.size(), n).ok(), r.id.c_str());
}

// bad <id> <n> <t> <received> <kind>
void run_bad(Row const& r) {
  int n = std::stoi(r.f[0]);
  int t = std::stoi(r.f[1]);
  Bytes word = from_hex(r.f[2]);
  Bytes before = word;
  Kind want = kind_of(r.f[3]);
  auto o = packbin::ecc::repair(word.data(), word.size(), n, t);
  expect(o.kind == want && o.repaired == 0 && same(word, before), r.id.c_str());
  if (t == 0 && want == Kind::Uncorrectable) {
    auto c = packbin::ecc::check(word.data(), word.size(), n);
    expect(c.kind == Kind::Uncorrectable, r.id.c_str());
  }
}

// lim <id> <n> <clear_len> <ok|too_long>
void run_lim(Row const& r) {
  int n = std::stoi(r.f[0]);
  std::size_t len = static_cast<std::size_t>(std::stoul(r.f[1]));
  Bytes clear(len, 0);
  std::uint8_t parity[32] = {};
  Kind k = packbin::ecc::protect(clear.data(), len, n, parity);
  expect(k == (r.f[2] == "ok" ? Kind::Ok : Kind::TooLong), r.id.c_str());
}

// par <id> <n>
void run_par(Row const& r) {
  int n = std::stoi(r.f[0]);
  std::uint8_t clear[1] = {0};
  std::uint8_t parity[32] = {};
  expect(packbin::ecc::protect(clear, 1, n, parity) == Kind::BadParity, r.id.c_str());
  expect(packbin::ecc::check(clear, 1, n).kind == Kind::BadParity, r.id.c_str());
  expect(packbin::ecc::repair(clear, 1, n, 0).kind == Kind::BadParity, r.id.c_str());
}

// lmt <id> <n> <t>
void run_lmt(Row const& r) {
  int n = std::stoi(r.f[0]);
  int t = std::stoi(r.f[1]);
  std::uint8_t word[64] = {};
  auto o = packbin::ecc::repair(word, sizeof(word), n, t);
  expect(o.kind == Kind::BadLimit && o.repaired == 0, r.id.c_str());
}

}  // namespace

int run_core_ecc_vectors_host_tests() {
  std::vector<Row> rows;
  if (!read_rows(rows)) {
    std::fprintf(stderr, "ecc vectors: fixtures/ecc/vectors.txt not found\n");
    ++check::failures();
    return check::failures();
  }
  int seen[6] = {};
  for (auto const& r : rows) {
    if (r.kind == "enc") {
      run_enc(r);
      ++seen[0];
    } else if (r.kind == "fix") {
      run_fix(r);
      ++seen[1];
    } else if (r.kind == "bad") {
      run_bad(r);
      ++seen[2];
    } else if (r.kind == "lim") {
      run_lim(r);
      ++seen[3];
    } else if (r.kind == "par") {
      run_par(r);
      ++seen[4];
    } else if (r.kind == "lmt") {
      run_lmt(r);
      ++seen[5];
    } else {
      std::fprintf(stderr, "ecc vectors: unknown row kind %s\n", r.kind.c_str());
      ++check::failures();
    }
  }
  for (int count : seen)
    expect(count > 0, "ecc vectors: every row kind is present");
  std::printf("ecc vectors: enc %d fix %d bad %d lim %d par %d lmt %d\n", seen[0], seen[1], seen[2],
              seen[3], seen[4], seen[5]);
  return check::failures();
}
