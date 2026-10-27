// The core's crypto module (src/core/crypto.hpp, kept for the frame port: owner decision D2 of
// loop 74) on every row of fixtures/crypto/vectors.txt (AZ-3201, PB-02; the row syntax is at the
// top of that file): 27 rows of five primitives. A copy of the file with one hex digit changed,
// written outside the repository ($TMPDIR, else /tmp), fails on that row only.
#include "../../src/core/crypto.hpp"

#include "check.hpp"

#include <unistd.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

using check::expect;
namespace crypto = packbin::detail::crypto;

namespace {

using Bytes = std::vector<std::uint8_t>;

struct Row {
  std::string primitive;
  std::string id;
  std::vector<std::pair<std::string, std::string>> fields;

  bool has(char const* name) const {
    for (auto const& f : fields)
      if (f.first == name)
        return true;
    return false;
  }

  // The value of `name`, or "(no <name>)" so that a missing field reads as a mismatch.
  std::string text(char const* name) const {
    for (auto const& f : fields)
      if (f.first == name)
        return f.second;
    return std::string("(no ") + name + ")";
  }
};

bool load(char const* path, std::vector<Row>& rows) {
  std::ifstream in(path);
  if (!in)
    return false;
  std::string line;
  while (std::getline(in, line)) {
    if (line.empty() || line[0] == '#')
      continue;
    std::istringstream words(line);
    Row r;
    words >> r.primitive >> r.id;
    for (std::string word; words >> word;) {
      std::size_t at = word.find('=');
      if (at == std::string::npos)
        r.fields.emplace_back(word, "(no value)");
      else
        r.fields.emplace_back(word.substr(0, at), word.substr(at + 1));
    }
    rows.push_back(r);
  }
  return true;
}

int nibble(char c) {
  if (c >= '0' && c <= '9')
    return c - '0';
  if (c >= 'a' && c <= 'f')
    return c - 'a' + 10;
  return -1;
}

// Lowercase hex, "-" for the empty string; false on anything else.
bool from_hex(std::string const& hex, Bytes& out) {
  out.clear();
  if (hex == "-")
    return true;
  if (hex.empty() || hex.size() % 2 != 0)
    return false;
  for (std::size_t i = 0; i < hex.size(); i += 2) {
    int hi = nibble(hex[i]);
    int lo = nibble(hex[i + 1]);
    if (hi < 0 || lo < 0)
      return false;
    out.push_back(static_cast<std::uint8_t>((hi << 4) | lo));
  }
  return true;
}

std::string to_hex(std::uint8_t const* p, std::size_t n) {
  static char const digits[] = "0123456789abcdef";
  std::string s;
  for (std::size_t i = 0; i < n; ++i) {
    s += digits[p[i] >> 4];
    s += digits[p[i] & 0x0f];
  }
  return s;
}

bool number(std::string const& text, unsigned long long max, unsigned long long& out) {
  if (text.empty() || text.find_first_not_of("0123456789") != std::string::npos)
    return false;
  out = std::strtoull(text.c_str(), nullptr, 10);
  return out <= max;
}

// What the module answers for a row, in the form of the row's expected value.
struct Answer {
  std::string expected;
  std::string got;
};

Answer malformed(std::string expected) { return Answer{expected, "(malformed row)"}; }

// The message whole and in 37-byte pieces through the streaming state.
Answer run_sha256(Row const& r) {
  Bytes msg;
  if (r.has("msg")) {
    if (!from_hex(r.text("msg"), msg))
      return malformed(r.text("digest"));
  } else {
    Bytes byte;
    unsigned long long repeat = 0;
    if (!from_hex(r.text("byte"), byte) || byte.size() != 1 ||
        !number(r.text("repeat"), 1u << 30, repeat))
      return malformed(r.text("digest"));
    msg.assign(static_cast<std::size_t>(repeat), byte[0]);
  }
  std::uint8_t whole[crypto::kDigestSize];
  crypto::sha256(msg.data(), msg.size(), whole);
  crypto::Sha256 s;
  for (std::size_t at = 0; at < msg.size(); at += 37)
    s.update(msg.data() + at, msg.size() - at < 37 ? msg.size() - at : 37);
  std::uint8_t pieces[crypto::kDigestSize];
  s.finish(pieces);
  std::string got = to_hex(whole, sizeof(whole));
  if (std::memcmp(whole, pieces, sizeof(whole)) != 0)
    got = "pieces " + to_hex(pieces, sizeof(pieces)) + " whole " + got;
  return Answer{r.text("digest"), got};
}

// The MAC in one call and with the data in 37-byte pieces; `truncate` keeps the first n bytes.
Answer run_hmac(Row const& r) {
  Bytes key, data;
  unsigned long long keep = crypto::kDigestSize;
  if (!from_hex(r.text("key"), key) || !from_hex(r.text("data"), data) ||
      (r.has("truncate") && !number(r.text("truncate"), crypto::kDigestSize, keep)))
    return malformed(r.text("mac"));
  std::uint8_t whole[crypto::kDigestSize];
  crypto::hmac_sha256(key.data(), key.size(), data.data(), data.size(), whole);
  crypto::HmacSha256 mac;
  mac.begin(key.data(), key.size());
  for (std::size_t at = 0; at < data.size(); at += 37)
    mac.update(data.data() + at, data.size() - at < 37 ? data.size() - at : 37);
  std::uint8_t pieces[crypto::kDigestSize];
  mac.end(pieces);
  std::string got = to_hex(whole, static_cast<std::size_t>(keep));
  if (std::memcmp(whole, pieces, sizeof(whole)) != 0)
    got = "pieces " + to_hex(pieces, sizeof(pieces)) + " whole " + got;
  return Answer{r.text("mac"), got};
}

// Extract (prk), extract and expand in one call (okm), and expand of that prk (the same okm).
Answer run_hkdf(Row const& r) {
  std::string expected = "prk=" + r.text("prk") + " okm=" + r.text("okm");
  Bytes ikm, salt, info;
  unsigned long long len = 0;
  if (!from_hex(r.text("ikm"), ikm) || !from_hex(r.text("salt"), salt) ||
      !from_hex(r.text("info"), info) || !number(r.text("len"), crypto::kMaxOkm, len))
    return malformed(expected);
  std::uint8_t prk[crypto::kDigestSize];
  crypto::hkdf_extract(salt.data(), salt.size(), ikm.data(), ikm.size(), prk);
  Bytes okm(static_cast<std::size_t>(len));
  Bytes again(static_cast<std::size_t>(len));
  bool one = crypto::hkdf_sha256(ikm.data(), ikm.size(), salt.data(), salt.size(), info.data(),
                                 info.size(), okm.data(), okm.size());
  bool two = crypto::hkdf_expand(prk, info.data(), info.size(), again.data(), again.size());
  std::string got = "prk=" + to_hex(prk, sizeof(prk)) + " okm=" + to_hex(okm.data(), okm.size());
  if (!one || !two || okm != again)
    got += " (expand of the prk differs or refused)";
  return Answer{expected, got};
}

bool key_nonce_counter(Row const& r, Bytes& key, Bytes& nonce, std::uint32_t& counter) {
  unsigned long long c = 0;
  if (!from_hex(r.text("key"), key) || key.size() != crypto::kKeySize ||
      !from_hex(r.text("nonce"), nonce) || nonce.size() != crypto::kNonceSize ||
      !number(r.text("counter"), 0xffffffffull, c))
    return false;
  counter = static_cast<std::uint32_t>(c);
  return true;
}

Answer run_block(Row const& r) {
  Bytes key, nonce;
  std::uint32_t counter = 0;
  if (!key_nonce_counter(r, key, nonce, counter))
    return malformed(r.text("block"));
  std::uint8_t block[crypto::kBlockSize];
  crypto::chacha20_block(key.data(), nonce.data(), counter, block);
  return Answer{r.text("block"), to_hex(block, sizeof(block))};
}

// The cipher, and the plain text back from it with the same stream.
Answer run_cipher(Row const& r) {
  Bytes key, nonce, plain;
  std::uint32_t counter = 0;
  if (!key_nonce_counter(r, key, nonce, counter) || !from_hex(r.text("plain"), plain))
    return malformed(r.text("cipher"));
  Bytes data = plain;
  bool sealed = crypto::chacha20_xor(key.data(), nonce.data(), counter, data.data(), data.size());
  std::string got = to_hex(data.data(), data.size());
  bool opened = crypto::chacha20_xor(key.data(), nonce.data(), counter, data.data(), data.size());
  if (!sealed || !opened || data != plain)
    got += " (decrypt differs or refused)";
  return Answer{r.text("cipher"), got};
}

// "<primitive> <id>: expected X, got Y" when the module's answer differs from the row, else "".
std::string mismatch(Row const& r) {
  Answer a;
  if (r.primitive == "sha256")
    a = run_sha256(r);
  else if (r.primitive == "hmac256")
    a = run_hmac(r);
  else if (r.primitive == "hkdf256")
    a = run_hkdf(r);
  else if (r.primitive == "chacha-block")
    a = run_block(r);
  else if (r.primitive == "chacha-xor")
    a = run_cipher(r);
  else
    a = Answer{"a known primitive", "(unknown primitive)"};
  if (a.got == a.expected)
    return std::string();
  return r.primitive + " " + r.id + ": expected " + a.expected + ", got " + a.got;
}

char const* vectors_path() {
  for (char const* path : {"../fixtures/crypto/vectors.txt", "fixtures/crypto/vectors.txt"}) {
    std::ifstream in(path);
    if (in)
      return path;
  }
  return nullptr;
}

struct Count {
  char const* primitive;
  int want;
  int seen;
};

int every_row_matches(std::vector<Row> const& rows) {
  // Arrange
  Count counts[] = {{"sha256", 6, 0}, {"hmac256", 8, 0}, {"hkdf256", 3, 0},
                    {"chacha-block", 6, 0}, {"chacha-xor", 4, 0}};
  int passed = 0;

  // Act and Assert: one check per row, named by the row.
  for (auto const& r : rows) {
    for (auto& c : counts)
      if (r.primitive == c.primitive)
        ++c.seen;
    std::string problem = mismatch(r);
    expect(problem.empty(), ("crypto vectors: " + problem).c_str());
    if (problem.empty())
      ++passed;
  }

  // Assert
  bool shape = rows.size() == 27;
  for (auto const& c : counts)
    shape = shape && c.seen == c.want;
  expect(shape, "crypto vectors: the file holds 27 rows: sha256 6, hmac256 8, hkdf256 3, "
                "chacha-block 6, chacha-xor 4");
  return passed;
}

// The file with the last hex digit of `field` changed in the first `primitive` row; `changed`
// is that row's "<primitive> <id>". False when no row has the field.
bool changed_copy(char const* path, char const* primitive, char const* field, std::string& text,
                  std::string& changed) {
  std::ifstream in(path);
  std::string line;
  std::string prefix = std::string(field) + "=";
  while (std::getline(in, line)) {
    std::istringstream words(line);
    std::string first, id;
    words >> first >> id;
    std::size_t at = line.find(" " + prefix);
    if (changed.empty() && first == primitive && at != std::string::npos) {
      std::size_t end = line.find(' ', at + 1);
      std::size_t last = (end == std::string::npos ? line.size() : end) - 1;
      line[last] = line[last] == '0' ? '1' : '0';
      changed = first + " " + id;
    }
    text += line + "\n";
  }
  return !changed.empty();
}

// Best effort: a copy left behind is reported, not a failure of the vectors.
void remove_temp(char const* path) {
  if (std::remove(path) != 0)
    std::fprintf(stderr, "crypto vectors: cannot remove %s\n", path);
}

// Writes `text` to a new file outside the repository; its path, or "" when it cannot.
std::string write_temp(std::string const& text) {
  char const* dir = std::getenv("TMPDIR");
  std::string name = std::string(dir != nullptr && dir[0] != '\0' ? dir : "/tmp") +
                     "/packbin-crypto-vectors-XXXXXX";
  std::vector<char> path(name.begin(), name.end());
  path.push_back('\0');
  int fd = mkstemp(path.data());
  if (fd < 0)
    return std::string();
  bool whole = write(fd, text.data(), text.size()) == static_cast<ssize_t>(text.size());
  bool closed = close(fd) == 0;
  if (!whole || !closed) {
    remove_temp(path.data());
    return std::string();
  }
  return std::string(path.data());
}

int one_changed_digit_fails_its_row_only(char const* path) {
  struct Case {
    char const* primitive;
    char const* field;
  };
  Case const cases[] = {{"sha256", "digest"},       {"hmac256", "mac"},
                        {"hkdf256", "prk"},          {"hkdf256", "okm"},
                        {"chacha-block", "block"},   {"chacha-xor", "cipher"}};
  int caught = 0;
  for (auto const& c : cases) {
    // Arrange
    std::string text, changed;
    std::string what = std::string("crypto vectors: a copy with one digit of ") + c.primitive +
                       " " + c.field + " changed";
    if (!changed_copy(path, c.primitive, c.field, text, changed)) {
      expect(false, (what + ": no row to change").c_str());
      continue;
    }
    std::string copy = write_temp(text);

    // Act
    std::vector<Row> rows;
    bool read = !copy.empty() && load(copy.c_str(), rows);
    if (!copy.empty())
      remove_temp(copy.c_str());
    std::string failing;
    for (auto const& r : rows)
      if (!mismatch(r).empty())
        failing += (failing.empty() ? "" : ", ") + r.primitive + " " + r.id;

    // Assert
    bool ok = read && rows.size() == 27 && failing == changed;
    expect(ok, (what + " fails on " + changed + " only (failing: " + failing + ")").c_str());
    if (ok)
      ++caught;
  }
  return caught;
}

// The block counter is 32 bits: a stream from the last counter holds one block.
void a_stream_past_the_last_block_counter_is_refused() {
  // Arrange
  std::uint8_t key[crypto::kKeySize] = {};
  std::uint8_t nonce[crypto::kNonceSize] = {};
  std::uint8_t block[crypto::kBlockSize];
  crypto::chacha20_block(key, nonce, 0xffffffffu, block);
  std::uint8_t data[crypto::kBlockSize + 1] = {};

  // Act
  bool one = crypto::chacha20_xor(key, nonce, 0xffffffffu, data, crypto::kBlockSize);
  std::uint8_t before[sizeof(data)];
  std::memcpy(before, data, sizeof(data));
  bool more = crypto::chacha20_xor(key, nonce, 0xffffffffu, data, sizeof(data));

  // Assert
  expect(one && std::memcmp(before, block, sizeof(block)) == 0,
         "crypto: 64 bytes from the last block counter are that block");
  expect(!more && std::memcmp(data, before, sizeof(data)) == 0,
         "crypto: 65 bytes from the last block counter are refused and the data is untouched");
}

// RFC 5869: at most 255 blocks of output.
void hkdf_gives_at_most_255_blocks() {
  // Arrange
  std::uint8_t ikm[22];
  std::memset(ikm, 0x0b, sizeof(ikm));
  std::uint8_t prk[crypto::kDigestSize];
  crypto::hkdf_extract(nullptr, 0, ikm, sizeof(ikm), prk);
  Bytes longest(crypto::kMaxOkm + 1, 0xaa);
  Bytes over(crypto::kMaxOkm + 1, 0xaa);

  // Act
  bool full = crypto::hkdf_expand(prk, nullptr, 0, longest.data(), crypto::kMaxOkm);
  bool refused = !crypto::hkdf_expand(prk, nullptr, 0, over.data(), over.size()) &&
                 !crypto::hkdf_sha256(ikm, sizeof(ikm), nullptr, 0, nullptr, 0, over.data(),
                                      over.size());

  // Assert
  expect(full && longest[crypto::kMaxOkm - 1] != 0xaa && longest[crypto::kMaxOkm] == 0xaa,
         "crypto: HKDF expands to 8,160 bytes");
  expect(refused && over == Bytes(crypto::kMaxOkm + 1, 0xaa),
         "crypto: HKDF refuses 8,161 bytes and leaves the output untouched");
}

}  // namespace

int run_core_crypto_vectors_host_tests() {
  char const* path = vectors_path();
  std::vector<Row> rows;
  if (path == nullptr || !load(path, rows)) {
    std::fprintf(stderr, "crypto vectors: fixtures/crypto/vectors.txt not found\n");
    ++check::failures();
    return check::failures();
  }
  int passed = every_row_matches(rows);
  int caught = one_changed_digit_fails_its_row_only(path);
  a_stream_past_the_last_block_counter_is_refused();
  hkdf_gives_at_most_255_blocks();
  std::printf("crypto vectors: %d of %zu rows pass; %d of 6 one-digit copies caught\n", passed,
              rows.size(), caught);
  return check::failures();
}
