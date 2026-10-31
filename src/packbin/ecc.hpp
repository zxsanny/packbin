#pragma once

// Message error correction codec (contract _docs/02_document/contracts/library/message-ecc.md,
// reference scripts/ecc/eccfmt.py). A Reed-Solomon code over GF(256), field polynomial 0x11D,
// alpha = 2, generator roots alpha^0 .. alpha^(n-1), n parity bytes after the clear bytes.
// The code word is one byte longer than what is sent: its first byte is the clear length, which
// is covered by the code and not sent.
//
// Allocation-free and exception-free like the core: fixed buffers on the stack (the repair path
// holds 195 bytes of arrays for n <= 32, about 390 bytes of stack measured on arm64 at -O2;
// protect about 110), tables in read-only data (511 bytes), no global mutable state. Defining
// PACKBIN_NO_ECC removes everything in this header.

#ifndef PACKBIN_NO_ECC

#include "packbin/platform.hpp"

namespace packbin::ecc {

// The sent bytes (clear + parity) never exceed this: the code word is 255 bytes, one is not sent.
inline constexpr std::size_t kMaxSent = 254;
inline constexpr int kMaxParity = 32;

enum class Kind : std::uint8_t {
  Ok,
  Uncorrectable,  // more wrong bytes than the limit allows (or the syndromes are not zero, t = 0)
  Short,          // fewer than n bytes received
  TooLong,        // clear message above 254 - n, or a received buffer above 254
  BadParity,      // n outside 0..32
  BadLimit,       // t outside 0..n / 2
};

struct Outcome {
  Kind kind = Kind::Ok;
  std::uint8_t repaired = 0;  // wrong bytes found and fixed, 0 for an intact buffer

  constexpr bool ok() const { return kind == Kind::Ok; }
};

namespace detail {

struct Tables {
  std::uint8_t exp[255];
  std::uint8_t log[256];

  constexpr Tables() : exp{}, log{} {
    unsigned x = 1;
    for (int i = 0; i < 255; ++i) {
      exp[i] = static_cast<std::uint8_t>(x);
      log[x] = static_cast<std::uint8_t>(i);
      x <<= 1;
      if (x & 0x100)
        x ^= 0x11D;
    }
  }
};

inline constexpr Tables kGf{};

// alpha^e for any e >= 0.
inline std::uint8_t alpha(unsigned e) { return kGf.exp[e % 255]; }

inline std::uint8_t mul(std::uint8_t a, std::uint8_t b) {
  if (a == 0 || b == 0)
    return 0;
  unsigned e = static_cast<unsigned>(kGf.log[a]) + kGf.log[b];
  return kGf.exp[e >= 255 ? e - 255 : e];
}

// a must not be 0.
inline std::uint8_t inv(std::uint8_t a) { return alpha(255u - kGf.log[a]); }

// Monic generator, highest degree first, g[0] = 1; g has n + 1 bytes.
inline void generator(int n, std::uint8_t* g) {
  std::memset(g, 0, static_cast<std::size_t>(n) + 1);
  g[0] = 1;
  for (int i = 0; i < n; ++i) {
    std::uint8_t root = alpha(static_cast<unsigned>(i));
    for (int j = i + 1; j >= 1; --j)
      g[j] ^= mul(g[j - 1], root);
  }
}

// Syndromes S_i = Horner(alpha^i) over [N - n] + word, i in 0..n-1; returns whether any is not 0.
inline bool syndromes(std::uint8_t const* word, std::size_t size, int n, std::uint8_t* s) {
  std::uint8_t sent_clear = static_cast<std::uint8_t>(size - static_cast<std::size_t>(n));
  std::uint8_t any = 0;
  for (int i = 0; i < n; ++i) {
    unsigned step = static_cast<unsigned>(i);
    std::uint8_t acc = sent_clear;
    for (std::size_t k = 0; k < size; ++k) {
      unsigned e = static_cast<unsigned>(kGf.log[acc]) + step;
      acc = static_cast<std::uint8_t>((acc == 0 ? 0 : kGf.exp[e % 255]) ^ word[k]);
    }
    s[i] = acc;
    any |= acc;
  }
  return any != 0;
}

// Berlekamp-Massey: the locator, lowest degree first, in lam[0..n]; returns its degree.
inline int locator(std::uint8_t const* s, int n, std::uint8_t* lam) {
  std::uint8_t prev[kMaxParity + 1];
  std::uint8_t keep[kMaxParity + 1];
  std::memset(lam, 0, static_cast<std::size_t>(n) + 1);
  std::memset(prev, 0, sizeof(prev));
  lam[0] = 1;
  prev[0] = 1;
  int l = 0;
  int m = 1;
  std::uint8_t b = 1;
  for (int r = 0; r < n; ++r) {
    std::uint8_t d = s[r];
    for (int i = 1; i <= l; ++i)
      d ^= mul(lam[i], s[r - i]);
    if (d == 0) {
      ++m;
      continue;
    }
    bool grows = 2 * l <= r;
    if (grows)
      std::memcpy(keep, lam, static_cast<std::size_t>(n) + 1);
    std::uint8_t coef = mul(d, inv(b));
    // x^m * prev has degree at most r + 1 - l <= n, so the loop bound loses no term.
    for (int i = 0; i + m <= n; ++i)
      lam[i + m] ^= mul(coef, prev[i]);
    if (grows) {
      std::memcpy(prev, keep, static_cast<std::size_t>(n) + 1);
      l = r + 1 - l;
      b = d;
      m = 1;
    } else {
      ++m;
    }
  }
  int deg = n;
  while (deg > 0 && lam[deg] == 0)
    --deg;
  return deg;
}

// Value of the polynomial p (lowest degree first, count coefficients) at x.
inline std::uint8_t poly_at(std::uint8_t const* p, int count, std::uint8_t x) {
  std::uint8_t y = 0;
  for (int i = count - 1; i >= 0; --i)
    y = static_cast<std::uint8_t>(mul(y, x) ^ p[i]);
  return y;
}

// The refusals every entry point shares once n is known to be 1..32.
inline Kind size_kind(std::size_t size, int n) {
  if (size > kMaxSent)
    return Kind::TooLong;
  if (size < static_cast<std::size_t>(n))
    return Kind::Short;
  return Kind::Ok;
}

}  // namespace detail

// Writes the n parity bytes of `clear` to parity_out (n bytes; nothing is written for n = 0 or
// on a refusal). A protected message is the clear bytes followed by these.
inline Kind protect(std::uint8_t const* clear, std::size_t len, int n, std::uint8_t* parity_out) {
  if (n < 0 || n > kMaxParity)
    return Kind::BadParity;
  if (n == 0)
    return Kind::Ok;
  if (len > kMaxSent - static_cast<std::size_t>(n))
    return Kind::TooLong;
  std::uint8_t g[kMaxParity + 1];
  detail::generator(n, g);
  std::memset(parity_out, 0, static_cast<std::size_t>(n));
  // Division by g, one byte at a time: the first byte is the clear length, then the clear bytes.
  for (std::size_t k = 0; k <= len; ++k) {
    std::uint8_t in = k == 0 ? static_cast<std::uint8_t>(len) : clear[k - 1];
    std::uint8_t fb = static_cast<std::uint8_t>(in ^ parity_out[0]);
    std::memmove(parity_out, parity_out + 1, static_cast<std::size_t>(n) - 1);
    parity_out[n - 1] = 0;
    if (fb != 0)
      for (int j = 0; j < n; ++j)
        parity_out[j] ^= detail::mul(g[j + 1], fb);
  }
  return Kind::Ok;
}

// Whether the n syndromes of a received buffer (clear + parity, `size` bytes) are all zero.
// Ok: intact. Uncorrectable: not intact (detection only; it does not look for the wrong bytes).
inline Outcome check(std::uint8_t const* word, std::size_t size, int n) {
  if (n < 0 || n > kMaxParity)
    return {Kind::BadParity, 0};
  if (n == 0)
    return {};
  if (Kind k = detail::size_kind(size, n); k != Kind::Ok)
    return {k, 0};
  std::uint8_t s[kMaxParity];
  if (detail::syndromes(word, size, n, s))
    return {Kind::Uncorrectable, 0};
  return {};
}

// Repairs up to t wrong bytes of `word` in place (t from 0 to n / 2). Ok with the number of bytes
// fixed (0 when intact). On any refusal the buffer is left exactly as it was: the repair is
// verified on the syndromes before a byte is written. Refusals are decided in the order of the
// reference: n, t, then n = 0 (nothing to do), length, syndromes.
inline Outcome repair(std::uint8_t* word, std::size_t size, int n, int t) {
  if (n < 0 || n > kMaxParity)
    return {Kind::BadParity, 0};
  if (t < 0 || t > n / 2)
    return {Kind::BadLimit, 0};
  if (n == 0)
    return {};
  if (Kind k = detail::size_kind(size, n); k != Kind::Ok)
    return {k, 0};
  std::uint8_t s[kMaxParity];
  if (!detail::syndromes(word, size, n, s))
    return {};
  if (t == 0)
    return {Kind::Uncorrectable, 0};

  std::uint8_t lam[kMaxParity + 1];
  int deg = detail::locator(s, n, lam);
  if (deg == 0 || deg > t)
    return {Kind::Uncorrectable, 0};

  // Position p (0 = first sent byte) has locator X = alpha^(size - 1 - p); it is wrong when
  // lam(X^-1) = 0. The unsent length byte cannot be wrong: a root there makes the count differ.
  std::uint8_t pos[kMaxParity / 2];
  int found = 0;
  for (std::size_t p = 0; p < size; ++p) {
    unsigned back = static_cast<unsigned>(size - 1 - p);
    if (detail::poly_at(lam, deg + 1, detail::alpha(255u - back)) != 0)
      continue;
    if (found == deg)
      return {Kind::Uncorrectable, 0};
    pos[found++] = static_cast<std::uint8_t>(p);
  }
  if (found != deg)
    return {Kind::Uncorrectable, 0};

  // omega = (S * lam) mod x^n.
  std::uint8_t omega[kMaxParity];
  std::memset(omega, 0, sizeof(omega));
  for (int i = 0; i < n; ++i)
    for (int j = 0; j <= deg && i + j < n; ++j)
      omega[i + j] ^= detail::mul(s[i], lam[j]);

  // Error value at p: X * omega(X^-1) / lam'(X^-1); lam' keeps the odd-degree terms.
  std::uint8_t value[kMaxParity / 2];
  for (int k = 0; k < deg; ++k) {
    unsigned back = static_cast<unsigned>(size - 1 - pos[k]);
    std::uint8_t xi = detail::alpha(255u - back);
    std::uint8_t den = 0;
    for (int i = deg; i >= 1; --i)
      den = static_cast<std::uint8_t>(detail::mul(den, xi) ^ ((i & 1) != 0 ? lam[i] : 0));
    if (den == 0)
      return {Kind::Uncorrectable, 0};
    std::uint8_t num = detail::poly_at(omega, n, xi);
    value[k] = detail::mul(detail::alpha(back), detail::mul(num, detail::inv(den)));
  }

  // The syndromes of the repaired word, without writing it: byte p weighs alpha^(i * back).
  for (int i = 0; i < n; ++i) {
    std::uint8_t after = s[i];
    for (int k = 0; k < deg; ++k) {
      unsigned back = static_cast<unsigned>(size - 1 - pos[k]);
      after ^= detail::mul(value[k], detail::alpha(static_cast<unsigned>(i) * back));
    }
    if (after != 0)
      return {Kind::Uncorrectable, 0};
  }
  for (int k = 0; k < deg; ++k)
    word[pos[k]] ^= value[k];
  return {Kind::Ok, static_cast<std::uint8_t>(deg)};
}

}  // namespace packbin::ecc

#endif  // PACKBIN_NO_ECC
