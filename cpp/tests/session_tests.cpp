#include "packbin/packbin.hpp"

#include <iostream>
#include <string>
#include <vector>

namespace {

int failures = 0;

void expect(bool ok, char const* msg) {
  if (!ok) {
    std::cerr << "FAIL: " << msg << "\n";
    ++failures;
  }
}

std::vector<std::uint8_t> parse_hex(std::string hex) {
  while (!hex.empty() && (hex.back() == '\n' || hex.back() == '\r' || hex.back() == ' '))
    hex.pop_back();
  std::vector<std::uint8_t> out(hex.size() / 2);
  for (std::size_t i = 0; i < out.size(); ++i)
    out[i] = static_cast<std::uint8_t>(std::stoul(hex.substr(i * 2, 2), nullptr, 16));
  return out;
}

auto position_scheme() {
  return packbin::scheme(0x40, {
      packbin::u16(0),
      packbin::i32(1),
      packbin::i32(2),
      packbin::u8(3),
      packbin::flags(4, {packbin::u16(4), packbin::u8(5), packbin::i16(6)}),
  });
}

packbin::Values position_values() {
  packbin::Values v;
  v.emplace("0", packbin::Value{std::uint16_t{1}});
  v.emplace("1", packbin::Value{std::int32_t{500000000}});
  v.emplace("2", packbin::Value{std::int32_t{300000000}});
  v.emplace("3", packbin::Value{std::uint8_t{1}});
  return v;
}

std::vector<std::uint8_t> seed_bytes() {
  std::vector<std::uint8_t> seed(32);
  for (std::size_t i = 0; i < seed.size(); ++i)
    seed[i] = static_cast<std::uint8_t>(i + 1);
  return seed;
}

std::vector<std::uint8_t> fixture_nonce() {
  return parse_hex("01000000000000000000000000000000");
}

constexpr char const* kGoldenHex = "4001000065cd1d00a3e1110100";
constexpr char const* kCipherHex = "b55d0a29c56c203712b241232e";

int field_mismatches(packbin::Values const& got) {
  int n = 0;
  try {
    if (std::get<std::uint16_t>(got.at("0").data) != 1)
      ++n;
    if (std::get<std::int32_t>(got.at("1").data) != 500000000)
      ++n;
    if (std::get<std::int32_t>(got.at("2").data) != 300000000)
      ++n;
    if (std::get<std::uint8_t>(got.at("3").data) != 1)
      ++n;
  } catch (...) {
    return 5;
  }
  if (packbin::present(got, 4))
    ++n;
  if (packbin::present(got, 5))
    ++n;
  if (packbin::present(got, 6))
    ++n;
  return n;
}

void ac1_ciphertext_matches() {
  auto opener = packbin::PackSession::load(seed_bytes());
  expect(opener.has_value(), "AC-1 load");
  if (!opener)
    return;
  auto nonce = opener->start(fixture_nonce());
  expect(nonce.has_value(), "AC-1 start");
  expect(nonce && nonce->size() == packbin::PackSession::NonceSize, "AC-1 nonce size");
  auto payload = opener->pack(position_scheme(), position_values());
  expect(payload.has_value(), "AC-1 pack");
  expect(payload && payload->size() == 13, "AC-1 length 13");
  expect(payload && packbin::to_hex(*payload) == kCipherHex, "AC-1 hex");
  expect(payload && packbin::mismatched_bytes(*payload, parse_hex(kCipherHex)) == 0,
         "AC-1 mismatched 0");
}

void ac2_waiter_recovers() {
  auto opener = packbin::PackSession::load(seed_bytes());
  auto waiter = packbin::PackSession::load(seed_bytes());
  expect(opener.has_value() && waiter.has_value(), "AC-2 load");
  if (!opener || !waiter)
    return;
  auto nonce = opener->start(fixture_nonce());
  expect(nonce.has_value(), "AC-2 start");
  expect(waiter->join(*nonce), "AC-2 join");
  auto payload = opener->pack(position_scheme(), position_values());
  expect(payload.has_value(), "AC-2 pack");
  packbin::Values got;
  auto result = waiter->unpack(*payload, position_scheme().on([&](packbin::Values const& row) {
    got = row;
  }));
  expect(result.ok, "AC-2 ok");
  expect(field_mismatches(got) == 0, "AC-2 field mismatches 0");
}

void ac3_clear_pack_unchanged() {
  auto bytes = packbin::BinaryPacker::pack(position_scheme(), position_values());
  expect(packbin::to_hex(bytes) == kGoldenHex, "AC-3 golden hex");
  expect(packbin::mismatched_bytes(bytes, parse_hex(kGoldenHex)) == 0, "AC-3 mismatched 0");
}

void ac4_bad_lengths() {
  int created = 0;
  if (packbin::PackSession::load(std::vector<std::uint8_t>(31)).has_value())
    ++created;
  if (packbin::PackSession::load(std::vector<std::uint8_t>(33)).has_value())
    ++created;
  auto loaded = packbin::PackSession::load(seed_bytes());
  expect(loaded.has_value(), "AC-4 good seed loads");
  if (!loaded)
    return;
  if (loaded->join(std::vector<std::uint8_t>(15)))
    ++created;
  if (loaded->join(std::vector<std::uint8_t>(17)))
    ++created;
  if (loaded->start(std::vector<std::uint8_t>(15)).has_value())
    ++created;
  expect(created == 0, "AC-4 sessions created 0");
  expect(!loaded->pack(position_scheme(), position_values()).has_value(), "AC-4 pack before open");
}

}  // namespace

int run_session_tests() {
  ac1_ciphertext_matches();
  ac2_waiter_recovers();
  ac3_clear_pack_unchanged();
  ac4_bad_lengths();
  return failures;
}
