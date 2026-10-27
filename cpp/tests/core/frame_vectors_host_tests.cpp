// Frame mode (include/packbin/frame.hpp) on every row of fixtures/frame/vectors.txt (AZ-3202; the row
// syntax is in fixtures/frame/README.md): 157 rows of keys, seal, open, mac and replay. A row's input
// fields build the call through the public API and every output field of the row is compared with what the
// call gave. A copy of the file with one hex digit changed, written outside the repository ($TMPDIR, else
// /tmp), fails on that row only.
#include "packbin/frame.hpp"

#include "check.hpp"
#include "frame_access_host.hpp"

#include <unistd.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <map>
#include <string>
#include <vector>

using check::expect;
using namespace packbin;
using packbin::detail::FrameTestAccess;

namespace {

using Bytes = std::vector<std::uint8_t>;
using Fields = std::map<std::string, std::string>;

constexpr std::uint8_t kSentinel = 0xa5;
constexpr std::size_t kRows = 157;

struct Row {
  Fields fields;

  bool has(char const* name) const { return fields.count(name) != 0; }
  std::string const& text(char const* name) const { return fields.at(name); }
  std::string const& op() const { return text("op"); }
  std::string const& name() const { return text("case"); }
};

std::vector<std::string> split(std::string const& s, char sep) {
  std::vector<std::string> out;
  std::size_t from = 0;
  for (;;) {
    std::size_t at = s.find(sep, from);
    out.push_back(s.substr(from, at == std::string::npos ? std::string::npos : at - from));
    if (at == std::string::npos)
      return out;
    from = at + 1;
  }
}

bool load_rows(char const* path, std::vector<Row>& rows) {
  std::ifstream in(path);
  if (!in)
    return false;
  std::string line;
  while (std::getline(in, line)) {
    if (line.empty() || line[0] == '#')
      continue;
    Row r;
    for (std::string const& token : split(line, ' ')) {
      std::size_t at = token.find('=');
      if (at != std::string::npos)
        r.fields[token.substr(0, at)] = token.substr(at + 1);
    }
    rows.push_back(r);
  }
  return true;
}

// Lowercase hex, "-" for the empty string.
Bytes unhex(std::string const& hex) {
  Bytes out;
  if (hex == "-")
    return out;
  out.resize(hex.size() / 2);
  check::parse_hex(hex.c_str(), out.data(), out.size());
  return out;
}

std::string hex_of(std::uint8_t const* p, std::size_t n) {
  static char const digits[] = "0123456789abcdef";
  if (n == 0)
    return "-";
  std::string s;
  for (std::size_t i = 0; i < n; ++i) {
    s += digits[p[i] >> 4];
    s += digits[p[i] & 0x0f];
  }
  return s;
}

std::string window_text(ReplayWindow const& w) {
  char text[40];
  std::snprintf(text, sizeof(text), "%llx:%llx", static_cast<unsigned long long>(w.top()),
                static_cast<unsigned long long>(w.bits()));
  return text;
}

std::string kind_name(Error e) {
  switch (e) {
    case Error::Ok: return "Ok";
    case Error::BadValue: return "BadValue";
    case Error::TooLong: return "TooLong";
    case Error::BufferFull: return "BufferFull";
    case Error::ShortPacket: return "ShortPacket";
    case Error::TagMismatch: return "TagMismatch";
    case Error::Duplicate: return "Duplicate";
    case Error::TooOld: return "TooOld";
    default: return "other";
  }
}

int number(Row const& r, char const* name, int fallback) {
  return r.has(name) ? std::atoi(r.text(name).c_str()) : fallback;
}

FrameDirections directions_of(Row const& r) {
  unsigned set = 0;
  for (char c : r.has("dirs") ? r.text("dirs") : std::string("123"))
    set |= 1u << (c - '1');
  return static_cast<FrameDirections>(set);
}

Result load_session(FrameSession& s, Row const& r) {
  Bytes key = unhex(r.text("key"));
  return s.load(ByteSpan(key.data(), key.size()), static_cast<std::uint32_t>(std::strtoul(r.text("epoch").c_str(), nullptr, 10)),
                FrameConfig{static_cast<std::uint8_t>(number(r, "tag_len", 4)), directions_of(r)});
}

MsgContext context_of(Row const& r) {
  MsgContext m;
  Bytes id = unhex(r.text("msg_id"));
  std::memcpy(m.msg_id, id.data(), id.size() < sizeof(m.msg_id) ? id.size() : sizeof(m.msg_id));
  m.kind = static_cast<std::uint8_t>(number(r, "kind", 0));
  return m;
}

ByteSpan span_of(Bytes const& b) { return ByteSpan(b.data(), b.size()); }

Fields run_keys(Row const& r) {
  Fields got;
  auto epoch = static_cast<std::uint32_t>(std::strtoul(r.text("epoch").c_str(), nullptr, 10));
  Bytes key = unhex(r.text("key"));
  if (r.has("label")) {
    MacKey mac;
    Result d = mac.derive(span_of(key), epoch, span_of(unhex(r.text("label"))));
    got["k_label"] = d.ok() ? hex_of(FrameTestAccess::label_key(mac), 32) : "BadValue";
    return got;
  }
  unsigned dir = static_cast<unsigned>(number(r, "dir", 1));
  FrameSession s;
  Result d = s.load(span_of(key), epoch, FrameConfig{4, static_cast<FrameDirections>(1u << (dir - 1))});
  got["k_enc"] = d.ok() ? hex_of(FrameTestAccess::enc(s, dir), 32) : "BadValue";
  got["k_mac"] = d.ok() ? hex_of(FrameTestAccess::mac(s, dir), 32) : "BadValue";
  return got;
}

Fields run_seal(Row const& r) {
  Fields got;
  FrameSession s;
  if (!load_session(s, r).ok()) {
    got["result"] = "BadValue";
    return got;
  }
  Bytes out(static_cast<std::size_t>(number(r, "out_len", 300)), kSentinel);
  Bytes ad = unhex(r.text("ad")), clear = unhex(r.text("clear")), plain = unhex(r.text("plain"));
  Result sealed = s.seal(static_cast<FrameDirection>(number(r, "dir", 1)), context_of(r), span_of(ad),
                         span_of(clear), span_of(plain), MutableByteSpan(out.data(), out.size()));
  if (sealed.ok()) {
    got["body"] = hex_of(out.data(), sealed.offset);
    return got;
  }
  got["result"] = kind_name(sealed.error);
  for (std::uint8_t b : out)
    if (b != kSentinel)
      got["result"] += " (a refused seal wrote bytes)";
  return got;
}

Fields run_open(Row const& r) {
  Fields got;
  ReplayWindow window;
  bool windowed = r.has("window");
  if (windowed) {
    std::vector<std::string> parts = split(r.text("window"), ':');
    window = ReplayWindow(std::strtoull(parts[0].c_str(), nullptr, 16), std::strtoull(parts[1].c_str(), nullptr, 16));
  }
  std::string before = window_text(window);
  FrameSession s;
  bool ready = load_session(s, r).ok();
  if (ready && r.has("prev_key")) {
    Bytes prev = unhex(r.text("prev_key"));
    ready = s.set_previous(span_of(prev), static_cast<std::uint32_t>(std::strtoul(r.text("prev_epoch").c_str(), nullptr, 10))).ok();
  }
  if (!ready) {
    got["result"] = "BadValue";
  } else {
    Bytes out(static_cast<std::size_t>(number(r, "out_len", 300)), kSentinel);
    Bytes ad = unhex(r.text("ad")), body = unhex(r.text("body"));
    FrameOpened opened;
    std::uint64_t counter = r.has("counter") ? std::strtoull(r.text("counter").c_str(), nullptr, 10) : 0;
    Result opened_r = s.open(static_cast<FrameDirection>(number(r, "dir", 1)), context_of(r), span_of(ad),
                             span_of(body), static_cast<std::size_t>(number(r, "clear_len", 0)),
                             MutableByteSpan(out.data(), out.size()), opened, windowed ? &window : nullptr, counter);
    got["result"] = kind_name(opened_r.error);
    if (opened_r.ok()) {
      got["slot"] = opened.slot == FrameSlot::Current ? "current" : "previous";
      got["plain"] = hex_of(out.data(), opened.plain_len);
    } else {
      for (std::uint8_t b : out)
        if (b != kSentinel)
          got["result"] += " (a refused open wrote bytes)";
      if (windowed && window_text(window) != before)
        got["result"] += " (a refused open changed the window)";
    }
  }
  if (windowed)
    got["window_after"] = window_text(window);
  return got;
}

Fields run_mac(Row const& r) {
  Fields got;
  MacKey mac;
  Bytes key = unhex(r.text("key"));
  Result d = mac.derive(span_of(key), static_cast<std::uint32_t>(std::strtoul(r.text("epoch").c_str(), nullptr, 10)),
                        span_of(unhex(r.text("label"))));
  if (!d.ok()) {
    got["result"] = "BadValue";
    return got;
  }
  std::vector<Bytes> pieces;
  for (std::string const& p : split(r.has("parts") ? r.text("parts") : r.text("message"), '|'))
    pieces.push_back(unhex(p));
  std::vector<ByteSpan> parts;
  for (Bytes const& p : pieces)
    parts.push_back(span_of(p));
  if (r.has("verify")) {
    Bytes tag = unhex(r.text("verify"));
    got["valid"] = mac.verify(parts.data(), parts.size(), span_of(tag)) ? "true" : "false";
    return got;
  }
  Bytes tag(static_cast<std::size_t>(number(r, "n", 4)), kSentinel);
  Result t = mac.tag(parts.data(), parts.size(), MutableByteSpan(tag.data(), tag.size()));
  if (t.ok())
    got["tag"] = hex_of(tag.data(), tag.size());
  else
    got["result"] = kind_name(t.error);
  for (std::uint8_t b : tag)
    if (!t.ok() && b != kSentinel)
      got["result"] += " (a refused tag wrote bytes)";
  return got;
}

Fields run_replay(Row const& r) {
  ReplayWindow window;
  std::string results, states;
  for (std::string const& step : split(r.text("steps"), ',')) {
    std::size_t colon = step.find(':');
    std::uint64_t n = std::strtoull(step.c_str() + colon + 1, nullptr, 10);
    if (step.compare(0, 5, "check") == 0) {
      Freshness f = window.check(n);
      results += (results.empty() ? "" : ",") + std::string(f == Freshness::Fresh ? "Fresh" : f == Freshness::Duplicate ? "Duplicate" : "TooOld");
    } else {
      window.commit(n);
      states += (states.empty() ? "" : ",") + window_text(window);
    }
  }
  return Fields{{"results", results}, {"states", states.empty() ? "-" : states}};
}

Fields run(Row const& r) {
  if (r.op() == "keys") return run_keys(r);
  if (r.op() == "seal") return run_seal(r);
  if (r.op() == "open") return run_open(r);
  if (r.op() == "mac") return run_mac(r);
  if (r.op() == "replay") return run_replay(r);
  return Fields{{"result", "(unknown op " + r.op() + ")"}};
}

// The output fields of an op (the others are inputs).
std::vector<char const*> outputs(std::string const& op) {
  if (op == "keys") return {"k_enc", "k_mac", "k_label"};
  if (op == "seal") return {"body", "result"};
  if (op == "open") return {"result", "slot", "plain", "window_after"};
  if (op == "mac") return {"tag", "valid", "result"};
  return {"results", "states"};
}

// "case field: expected X, got Y" for each output the call gave differently; empty when the row matches.
std::string mismatch(Row const& r) {
  Fields got = run(r);
  std::string problems;
  for (char const* field : outputs(r.op())) {
    if (!r.has(field))
      continue;
    auto it = got.find(field);
    std::string value = it == got.end() ? "(the call gave none)" : it->second;
    if (value != r.text(field))
      problems += (problems.empty() ? "" : "; ") + r.name() + " " + field + ": expected " + r.text(field) + ", got " + value;
  }
  return problems;
}

char const* vectors_path() {
  for (char const* path : {"../fixtures/frame/vectors.txt", "fixtures/frame/vectors.txt"}) {
    std::ifstream in(path);
    if (in)
      return path;
  }
  return nullptr;
}

int every_row_matches(std::vector<Row> const& rows) {
  // Arrange
  std::map<std::string, int> per_op;
  int passed = 0;

  // Act and Assert: one check per row, named by the row.
  for (Row const& r : rows) {
    ++per_op[r.op()];
    std::string problem = mismatch(r);
    expect(problem.empty(), ("frame vectors: " + problem).c_str());
    if (problem.empty())
      ++passed;
  }
  expect(rows.size() == kRows && per_op["keys"] == 20 && per_op["seal"] == 35 && per_op["open"] == 57 &&
             per_op["mac"] == 42 && per_op["replay"] == 3,
         "frame vectors: the file holds 157 rows: keys 20, seal 35, open 57, mac 42, replay 3");
  return passed;
}

// The file with the last hex digit of `field` changed in the first `op` row that has it; `changed` is that
// row's case. False when no row has the field.
bool changed_copy(char const* path, char const* op, char const* field, std::string& text, std::string& changed) {
  std::ifstream in(path);
  std::string line;
  std::string marker = std::string(" ") + field + "=";
  while (std::getline(in, line)) {
    std::size_t at = line.find(marker);
    if (changed.empty() && line.compare(0, 3 + std::strlen(op), std::string("op=") + op) == 0 && line[3 + std::strlen(op)] == ' ' &&
        at != std::string::npos) {
      std::size_t end = line.find(' ', at + 1);
      std::size_t last = (end == std::string::npos ? line.size() : end) - 1;
      line[last] = line[last] == '0' ? '1' : '0';
      std::size_t name = line.find("case=") + 5;
      changed = line.substr(name, line.find(' ', name) - name);
    }
    text += line + "\n";
  }
  return !changed.empty();
}

void remove_temp(char const* path) {
  if (std::remove(path) != 0)
    std::fprintf(stderr, "frame vectors: cannot remove %s\n", path);
}

// Writes `text` to a new file outside the repository; its path, or "" when it cannot.
std::string write_temp(std::string const& text) {
  char const* dir = std::getenv("TMPDIR");
  std::string name = std::string(dir != nullptr && dir[0] != '\0' ? dir : "/tmp") + "/packbin-frame-vectors-XXXXXX";
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
    char const* op;
    char const* field;
  };
  Case const cases[] = {{"seal", "body"}, {"open", "plain"}, {"mac", "tag"}, {"keys", "k_enc"}, {"replay", "states"}};
  int caught = 0;
  for (Case const& c : cases) {
    // Arrange
    std::string text, changed;
    std::string what = std::string("frame vectors: a copy with one digit of ") + c.op + " " + c.field + " changed";
    if (!changed_copy(path, c.op, c.field, text, changed)) {
      expect(false, (what + ": no row to change").c_str());
      continue;
    }
    std::string copy = write_temp(text);

    // Act
    std::vector<Row> rows;
    bool read = !copy.empty() && load_rows(copy.c_str(), rows);
    if (!copy.empty())
      remove_temp(copy.c_str());
    std::string failing;
    for (Row const& r : rows)
      if (!mismatch(r).empty())
        failing += (failing.empty() ? "" : ", ") + r.name();

    // Assert
    bool ok = read && rows.size() == kRows && failing == changed;
    expect(ok, (what + " fails on " + changed + " only (failing: " + failing + ")").c_str());
    if (ok)
      ++caught;
  }
  return caught;
}

}  // namespace

int run_core_frame_vectors_host_tests() {
  char const* path = vectors_path();
  std::vector<Row> rows;
  if (path == nullptr || !load_rows(path, rows)) {
    std::fprintf(stderr, "frame vectors: fixtures/frame/vectors.txt not found\n");
    ++check::failures();
    return check::failures();
  }
  int passed = every_row_matches(rows);
  int caught = one_changed_digit_fails_its_row_only(path);
  std::printf("frame vectors: %d of %zu rows pass; %d of 5 one-digit copies caught\n", passed, rows.size(), caught);
  return check::failures();
}
