// AZ-2666 audit probe, mode edge: the AC-1 and AC-2 edge cases a random run is unlikely to hit
// (ECC sweeps, refusal order, text limits, ESC cuts, keys, Packed).

#include "probe_common.hpp"
#include "text_decode.hpp"

namespace probe {

namespace {

void expect(bool c, char const* what) {
  std::printf("%s %s\n", c ? "ok  " : "FAIL", what);
  if (!c)
    ++g_fail;
}

}  // namespace

int edge(std::string const& fix) {
  (void)fix;
  // ECC: every n = 1..32 and every N = 0..256, three buffer contents, t = n / 2 and 0.
  {
    std::size_t calls = 0, wrote = 0;
    for (int n = 1; n <= 32; ++n) {
      for (std::size_t N = 0; N <= 256; ++N) {
        for (int fill = 0; fill < 3; ++fill) {
          Bytes b(N);
          for (std::size_t i = 0; i < N; ++i)
            b[i] = fill == 0 ? 0x00 : fill == 1 ? 0xFF : static_cast<std::uint8_t>(i * 37 + n);
          for (int t : {0, n / 2}) {
            Exact in(b);
            ecc::Outcome o = ecc::repair(in.data(), in.n, n, t);
            ++calls;
            if (!o.ok() && N != 0 && std::memcmp(in.data(), b.data(), N) != 0)
              ++wrote;
            ecc::Kind want = N > 254 ? ecc::Kind::TooLong
                             : N < static_cast<std::size_t>(n) ? ecc::Kind::Short
                                                               : o.kind;
            if (o.kind != want)
              ++g_fail;
          }
        }
      }
    }
    std::printf("edge_ecc_sweep calls=%zu refused_and_wrote=%zu\n", calls, wrote);
    expect(wrote == 0, "a refused repair never writes (n 1..32, N 0..256)");
  }
  // Codewords of every n = 1..32 and N = n..254 with t, t + 1 and n - t + 1 wrong bytes at distinct
  // positions (the first and the last byte included): t is repaired exactly, t + 1 .. n - t is
  // refused, and a refusal writes nothing.
  {
    Rng r(7);
    std::size_t calls = 0, bad = 0;
    for (int n = 1; n <= 32; ++n) {
      int t = n / 2;
      for (std::size_t N = static_cast<std::size_t>(n); N <= 254; ++N) {
        Bytes clear(N - static_cast<std::size_t>(n));
        for (auto& c : clear)
          c = r.byte();
        Bytes w = protect_clear(clear, n);
        for (int k : {t, t + 1, n - t + 1}) {
          if (k > static_cast<int>(N))
            continue;
          std::vector<std::size_t> pos(N);
          for (std::size_t i = 0; i < N; ++i)
            pos[i] = i;
          if (N >= 2)
            std::swap(pos[1], pos[N - 1]);
          for (std::size_t i = 2; i < static_cast<std::size_t>(k); ++i)
            std::swap(pos[i], pos[i + r.below(N - i)]);
          Bytes b = w;
          for (int e = 0; e < k; ++e)
            b[pos[e]] ^= static_cast<std::uint8_t>(1 + r.below(255));
          Exact in(b);
          ecc::Outcome o = ecc::repair(in.data(), N, n, t);
          ++calls;
          bool same_as_sent = std::memcmp(in.data(), w.data(), N) == 0;
          bool unchanged = std::memcmp(in.data(), b.data(), N) == 0;
          if (k <= t)
            bad += !(o.ok() && o.repaired == k && same_as_sent);
          else if (k <= n - t)
            bad += !(!o.ok() && unchanged);
          else
            bad += !o.ok() && !unchanged;
        }
      }
    }
    std::printf("edge_ecc_codeword_sweep calls=%zu bad=%zu\n", calls, bad);
    expect(bad == 0, "n 1..32, N n..254: t wrong bytes repaired, t+1..n-t refused, refusals write nothing");
  }
  {
    Bytes b(255, 0);
    Exact in(b);
    expect(ecc::repair(in.data(), 255, 4, 2).kind == ecc::Kind::TooLong, "255 bytes: TooLong");
    expect(ecc::repair(in.data(), 3, 4, 2).kind == ecc::Kind::Short, "3 bytes under n = 4: Short");
    expect(ecc::repair(in.data(), 4, 4, 3).kind == ecc::Kind::BadLimit, "t = 3 above 4 / 2: BadLimit");
    expect(ecc::repair(in.data(), 4, 33, 0).kind == ecc::Kind::BadParity, "n = 33: BadParity");
    expect(ecc::repair(in.data(), 4, -1, 0).kind == ecc::Kind::BadParity, "n = -1: BadParity");
    expect(ecc::repair(in.data(), 4, 4, -1).kind == ecc::Kind::BadLimit, "t = -1: BadLimit");
    expect(ecc::check(in.data(), 255, 4).kind == ecc::Kind::TooLong, "check of 255 bytes: TooLong");
    Bytes clear(254 - 32, 0x5A);
    Bytes w = protect_clear(clear, 32);
    expect(w.size() == 254, "a 254-byte protected message (222 clear + 32 parity)");
    Exact one(w);
    one.data()[0] ^= 1;
    one.data()[253] ^= 0x80;
    ecc::Outcome o = ecc::repair(one.data(), 254, 32, 16);
    expect(o.ok() && o.repaired == 2 && std::memcmp(one.data(), w.data(), 254) == 0,
           "first and last byte of a 254-byte message repaired");
    Bytes empty_clear;
    Bytes we = protect_clear(empty_clear, 32);
    Exact e(we);
    e.data()[31] ^= 0x33;
    o = ecc::repair(e.data(), 32, 32, 16);
    expect(o.ok() && o.repaired == 1, "N = n (empty clear): a parity byte repaired");
  }
  // Text: limits and the raw path.
  {
    Bytes raw(1 + 65535, 'a');
    raw[0] = 0x10;
    Exact in(raw);
    txt::Sink s{nullptr, txt::kMaxText};
    expect(txt::decode_payload(in.data(), in.n, s) && s.len == 65535, "raw 65,535 bytes accepted");
    raw.push_back('a');
    Exact in2(raw);
    txt::Sink s2{nullptr, txt::kMaxText};
    expect(!txt::decode_payload(in2.data(), in2.n, s2), "raw 65,536 bytes refused");
    Bytes one{0x10};
    Exact in3(one);
    txt::Sink s3{nullptr, txt::kMaxText};
    std::printf("note raw_prefix_alone accepted=%d (empty text from a 1-byte raw payload)\n",
                txt::decode_payload(in3.data(), in3.n, s3));
    Bytes compact_empty{0x08};  // pad 0, mode 2 (en), 2 zero bits: total 8 bits, 2 of symbols
    Exact in4(compact_empty);
    txt::Sink s4{nullptr, txt::kMaxText};
    std::printf("note one_byte_compact_00001000 accepted=%d len=%zu\n",
                txt::decode_payload(in4.data(), in4.n, s4), s4.len);
    Bytes header_only{0x48};  // pad 2, mode 2: 6 bits, no symbol
    Exact in5(header_only);
    txt::Sink s5{nullptr, txt::kMaxText};
    std::printf("note header_only_payload accepted=%d len=%zu\n",
                txt::decode_payload(in5.data(), in5.n, s5), s5.len);
    // Every invalid ESC form at the very end of the payload (bytes cut by one bit).
    for (int cut = 1; cut <= 31; ++cut) {
      // en mode, ESC (code from kTab), then a 4-byte lead F0 9F 98 80 shortened by `cut` bits.
      unsigned m = 2, esc = txt::kLayout[2].esc;
      std::vector<bool> bits;
      auto put = [&](unsigned code, unsigned len) {
        for (unsigned i = len; i-- > 0;)
          bits.push_back(((code >> i) & 1u) != 0);
      };
      put(txt::kTab.code[m][esc], txt::kTab.length[m][esc]);
      put(0xF09F9880u >> cut, 32 - cut);
      std::size_t total = 6 + bits.size();
      std::size_t nb = (total + 7) / 8;
      unsigned pad = static_cast<unsigned>(nb * 8 - total);
      if (pad > 7)
        continue;
      Bytes p(nb, 0);
      p[0] = static_cast<std::uint8_t>(pad << 5 | m << 2);
      for (std::size_t i = 0; i < bits.size(); ++i)
        if (bits[i])
          p[(6 + i) / 8] |= static_cast<std::uint8_t>(0x80u >> ((6 + i) % 8));
      Exact in6(p);
      txt::Sink s6{nullptr, txt::kMaxText};
      if (txt::decode_payload(in6.data(), in6.n, s6)) {
        std::printf("FAIL esc cut %d accepted\n", cut);
        ++g_fail;
      }
    }
    expect(true, "ESC cut short by 1..31 bits at the payload end: no read past it (ASan)");
  }
  // Duplicate keys: the same text as a raw and as a compact payload; an unbound dict.
  {
    // "a" raw: 02 10 61; "a" compact (en): 02 10 61 is what the encoder writes; use the alt row
    // `alt.escape_for_letter` text d18f ("я"): compact 05c3ff3463c0 vs raw 03 10 d1 8f.
    Bytes pkt{5, 2, 0, 0x05, 0xc3, 0xff, 0x34, 0x63, 0xc0, 0x01, 0x03, 0x10, 0xd1, 0x8f, 0x02};
    Exact in(pkt);
    static R5 r5;
    packbin::Result res = packbin::unpack(s5, in.data(), in.n, r5);
    expect(res.error == Error::BadValue, "bound dict: one text in two byte forms is a repeated key");
    pkt[0] = 6;
    Exact in2(pkt);
    R3 r3;
    res = packbin::unpack(s6, in2.data(), in2.n, r3);
    std::printf("note unbound_dict_repeated_key error=%d (0: accepted; the other packages refuse it)\n",
                static_cast<int>(res.error));
    Bytes same{6, 2, 0, 0x02, 0x10, 0x61, 0x01, 0x02, 0x10, 0x61, 0x02};
    Exact in3(same);
    res = packbin::unpack(s6, in3.data(), in3.n, r3);
    std::printf("note unbound_dict_identical_keys error=%d\n", static_cast<int>(res.error));
  }
  // Packed: the count is bounded by the input.
  {
    Bytes pkt{2, 0xFF, 0xFF, 0x7F, 0x10, 0x41, 0x00};
    Exact in(pkt);
    static R2 r2;
    packbin::Result res = packbin::unpack(s2, in.data(), in.n, r2);
    expect(res.error == Error::ShortPacket && res.needed == 2097151,
           "Packed count 2,097,151 over a 4-byte rest: ShortPacket, nothing borrowed");
    Bytes four{2, 0x80, 0x80, 0x80, 0x01, 0x00};
    Exact in2(four);
    res = packbin::unpack(s2, in2.data(), in2.n, r2);
    expect(res.error == Error::BadValue, "a 4-byte count: BadValue");
  }
  std::printf("failures=%d\nresult=%s\n", g_fail, g_fail == 0 ? "PASS" : "FAIL");
  return g_fail == 0 ? 0 : 1;
}

}  // namespace probe
