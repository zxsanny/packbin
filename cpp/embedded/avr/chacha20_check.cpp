// AZ-3452: runs chacha20_xor on an ATmega328P, where int and size_t are 16 bits. cpp/embedded/arm.sh
// (target_avr_uno) runs this image on simavr and compares what it prints on the UART with
// chacha20_expected.txt, line for line. A line that differs, a missing line or no output fails the row.
// A failing case adds a `BAD <group> <n>` line.

#include <avr/interrupt.h>
#include <avr/io.h>
#include <avr/sleep.h>
#include <string.h>

#include "core/crypto.hpp"

namespace crypto = packbin::detail::crypto;

namespace {

constexpr unsigned kBlock = crypto::kBlockSize;
constexpr unsigned kMaxLen = 2 * kBlock + 1;

void put(char c) {
  while (!(UCSR0A & _BV(UDRE0))) {
  }
  UDR0 = static_cast<unsigned char>(c);
}

void text(char const* s) {
  while (*s != '\0')
    put(*s++);
}

void number(unsigned v) {
  char digits[6];
  unsigned n = 0;
  do {
    digits[n++] = static_cast<char>('0' + v % 10);
    v /= 10;
  } while (v != 0);
  while (n != 0)
    put(digits[--n]);
}

void bad(char const* group, unsigned n) {
  text("BAD ");
  text(group);
  put(' ');
  number(n);
  put('\n');
}

void result(char const* group, unsigned passed, unsigned of) {
  text(group);
  put(' ');
  number(passed);
  put('/');
  number(of);
  put('\n');
}

void key_00_to_1f(std::uint8_t* key) {
  for (unsigned i = 0; i < crypto::kKeySize; ++i)
    key[i] = static_cast<std::uint8_t>(i);
}

// RFC 8439 2.4.2.
char const kRfcPlain[] =
    "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, "
    "sunscreen would be it.";
constexpr unsigned kRfcLen = sizeof(kRfcPlain) - 1;
constexpr std::uint8_t kRfcNonce[crypto::kNonceSize] = {0, 0, 0, 0, 0, 0, 0, 0x4a, 0, 0, 0, 0};
constexpr std::uint8_t kRfcCipher[kRfcLen] = {
    0x6e, 0x2e, 0x35, 0x9a, 0x25, 0x68, 0xf9, 0x80, 0x41, 0xba, 0x07, 0x28, 0xdd, 0x0d, 0x69, 0x81,
    0xe9, 0x7e, 0x7a, 0xec, 0x1d, 0x43, 0x60, 0xc2, 0x0a, 0x27, 0xaf, 0xcc, 0xfd, 0x9f, 0xae, 0x0b,
    0xf9, 0x1b, 0x65, 0xc5, 0x52, 0x47, 0x33, 0xab, 0x8f, 0x59, 0x3d, 0xab, 0xcd, 0x62, 0xb3, 0x57,
    0x16, 0x39, 0xd6, 0x24, 0xe6, 0x51, 0x52, 0xab, 0x8f, 0x53, 0x0c, 0x35, 0x9f, 0x08, 0x61, 0xd8,
    0x07, 0xca, 0x0d, 0xbf, 0x50, 0x0d, 0x6a, 0x61, 0x56, 0xa3, 0x8e, 0x08, 0x8a, 0x22, 0xb6, 0x5e,
    0x52, 0xbc, 0x51, 0x4d, 0x16, 0xcc, 0xf8, 0x06, 0x81, 0x8c, 0xe9, 0x1a, 0xb7, 0x79, 0x37, 0x36,
    0x5a, 0xf9, 0x0b, 0xbf, 0x74, 0xa3, 0x5b, 0xe6, 0xb4, 0x0b, 0x8e, 0xed, 0xf2, 0x78, 0x5e, 0x42,
    0x87, 0x4d};

// The number of ciphertext bytes that equal the RFC ciphertext.
unsigned rfc_bytes_equal() {
  std::uint8_t key[crypto::kKeySize];
  key_00_to_1f(key);
  std::uint8_t data[kRfcLen];
  memcpy(data, kRfcPlain, kRfcLen);
  if (!crypto::chacha20_xor(key, kRfcNonce, 1, data, kRfcLen))
    return 0;
  unsigned equal = 0;
  for (unsigned i = 0; i < kRfcLen; ++i)
    equal += data[i] == kRfcCipher[i] ? 1 : 0;
  return equal;
}

constexpr unsigned kLens[] = {0, 1, 63, 64, 65, kRfcLen, 127, 128, 129};
constexpr unsigned kLenCount = sizeof(kLens) / sizeof(kLens[0]);

// For one length: the stream built block by block from chacha20_block (matches, restored).
void stream_case(unsigned len, bool& matches, bool& restored) {
  std::uint8_t key[crypto::kKeySize];
  key_00_to_1f(key);
  std::uint8_t plain[kMaxLen];
  std::uint8_t expect[kMaxLen];
  std::uint8_t data[kMaxLen];
  for (unsigned i = 0; i < len; ++i)
    plain[i] = static_cast<std::uint8_t>(i * 7 + 3);
  std::uint8_t block[kBlock];
  for (unsigned at = 0, counter = 1; at < len; at += kBlock, ++counter) {
    crypto::chacha20_block(key, kRfcNonce, counter, block);
    for (unsigned i = 0; i < kBlock && at + i < len; ++i)
      expect[at + i] = static_cast<std::uint8_t>(plain[at + i] ^ block[i]);
  }
  memcpy(data, plain, len);
  bool first = crypto::chacha20_xor(key, kRfcNonce, 1, data, len);
  matches = first && memcmp(data, expect, len) == 0;
  bool second = crypto::chacha20_xor(key, kRfcNonce, 1, data, len);
  restored = second && memcmp(data, plain, len) == 0;
}

// The five cases of the host test `block_counter_edge`: the block counter is 32 bits.
constexpr unsigned kEdgeCases = 5;

void edge_cases(bool (&ok)[kEdgeCases]) {
  std::uint8_t key[crypto::kKeySize];
  key_00_to_1f(key);
  std::uint8_t nonce[crypto::kNonceSize] = {1, 2, 3};
  std::uint8_t last[kBlock];
  std::uint8_t before_last[kBlock];
  crypto::chacha20_block(key, nonce, 0xffffffffu, last);
  crypto::chacha20_block(key, nonce, 0xfffffffeu, before_last);
  std::uint8_t data[kMaxLen];
  std::uint8_t untouched[kMaxLen];

  memset(data, 0, sizeof(data));
  bool one = crypto::chacha20_xor(key, nonce, 0xffffffffu, data, kBlock);
  ok[0] = one && memcmp(data, last, kBlock) == 0;
  memset(data, 0, sizeof(data));
  bool two = crypto::chacha20_xor(key, nonce, 0xfffffffeu, data, 2 * kBlock);
  ok[1] = two && memcmp(data, before_last, kBlock) == 0 && memcmp(data + kBlock, last, kBlock) == 0;
  memset(data, 0x5a, sizeof(data));
  memcpy(untouched, data, sizeof(data));
  bool over_one = crypto::chacha20_xor(key, nonce, 0xffffffffu, data, kBlock + 1);
  ok[2] = !over_one && memcmp(data, untouched, sizeof(data)) == 0;
  bool over_two = crypto::chacha20_xor(key, nonce, 0xfffffffeu, data, 2 * kBlock + 1);
  ok[3] = !over_two && memcmp(data, untouched, sizeof(data)) == 0;
  ok[4] = crypto::chacha20_xor(key, nonce, 0xffffffffu, data, 0);
}

}  // namespace

int main() {
  UCSR0B = _BV(TXEN0);

  text("SIZES size_t=");
  number(sizeof(std::size_t));
  text(" int=");
  number(sizeof(int));
  put('\n');

  unsigned equal = rfc_bytes_equal();
  result("RFC", equal, kRfcLen);
  if (equal != kRfcLen)
    bad("RFC", equal);

  unsigned matched = 0;
  unsigned restored_count = 0;
  for (unsigned i = 0; i < kLenCount; ++i) {
    bool matches = false;
    bool restored = false;
    stream_case(kLens[i], matches, restored);
    matched += matches ? 1 : 0;
    restored_count += restored ? 1 : 0;
    if (!matches)
      bad("STREAM", kLens[i]);
    if (!restored)
      bad("RESTORED", kLens[i]);
  }
  result("STREAM", matched, kLenCount);
  result("RESTORED", restored_count, kLenCount);

  bool edge[kEdgeCases];
  edge_cases(edge);
  unsigned edge_ok = 0;
  for (unsigned i = 0; i < kEdgeCases; ++i) {
    edge_ok += edge[i] ? 1 : 0;
    if (!edge[i])
      bad("EDGE", i);
  }
  result("EDGE", edge_ok, kEdgeCases);
  text("DONE\n");

  while (!(UCSR0A & _BV(TXC0))) {
  }
  cli();
  sleep_enable();
  sleep_cpu();
  for (;;) {
  }
}
