// AZ-2666 audit probe, timing and amplification modes: ecc-worst, text-amp, text-long and
// dict-quad, for the -O2 build (see audit41_probe.cpp).

#include "probe_common.hpp"
#include "text_decode.hpp"

namespace probe {

int ecc_worst(std::size_t iters) {
  Rng r(41);
  int const n = 32;
  Stats full16, random16, burst17, detect0, intact16;
  std::size_t outcome[4] = {};
  std::uint8_t buf[254];
  for (std::size_t it = 0; it < iters; ++it) {
    Bytes clear(254 - n);
    for (auto& c : clear)
      c = r.byte();
    Bytes word = protect_clear(clear, n);
    // (1) 16 wrong bytes at distinct positions: degree-16 locator, 16 roots, full repair.
    std::memcpy(buf, word.data(), 254);
    std::vector<std::size_t> pos(254);
    for (std::size_t i = 0; i < 254; ++i)
      pos[i] = i;
    for (std::size_t i = 0; i < 17; ++i)
      std::swap(pos[i], pos[i + r.below(254 - i)]);
    for (int e = 0; e < 16; ++e)
      buf[pos[e]] ^= static_cast<std::uint8_t>(1 + r.below(255));
    auto a = Clock::now();
    ecc::Outcome o = ecc::repair(buf, 254, n, 16);
    full16.add(seconds_since(a));
    outcome[0] += o.ok() && o.repaired == 16;
    // (2) a random buffer: all syndromes nonzero, degree 16, the full root scan, then refused.
    for (auto& b : buf)
      b = r.byte();
    a = Clock::now();
    o = ecc::repair(buf, 254, n, 16);
    random16.add(seconds_since(a));
    outcome[1] += !o.ok();
    // (3) 17 wrong bytes: beyond t, near-miss locators.
    std::memcpy(buf, word.data(), 254);
    for (int e = 0; e < 17; ++e)
      buf[pos[e]] ^= static_cast<std::uint8_t>(1 + r.below(255));
    a = Clock::now();
    o = ecc::repair(buf, 254, n, 16);
    burst17.add(seconds_since(a));
    outcome[2] += !o.ok();
    // (4) the default limit t = 0 on a damaged buffer: syndromes only.
    a = Clock::now();
    o = ecc::repair(buf, 254, n, 0);
    detect0.add(seconds_since(a));
    outcome[3] += o.kind == ecc::Kind::Uncorrectable;
    // (5) intact, t = 16.
    std::memcpy(buf, word.data(), 254);
    a = Clock::now();
    o = ecc::repair(buf, 254, n, 16);
    intact16.add(seconds_since(a));
  }
  std::printf("mode=ecc-worst n=32 N=254 iterations=%zu\n", iters);
  full16.print("t16_16_errors_repaired");
  random16.print("t16_random_buffer_refused");
  burst17.print("t16_17_errors_refused");
  detect0.print("t0_damaged_detect_only");
  intact16.print("t16_intact");
  std::printf("outcomes repaired16=%zu random_refused=%zu e17_refused=%zu t0_uncorrectable=%zu\n",
              outcome[0], outcome[1], outcome[2], outcome[3]);
  bool ok = outcome[0] == iters && outcome[3] == iters;
  std::printf("peak_rss_kb=%ld\nresult=%s\n", peak_rss_kb(), ok ? "PASS" : "FAIL");
  return ok ? 0 : 1;
}

// The largest compact payload: Russian "o" (3 bits, 2 UTF-8 bytes) `count` times, then spaces.
Bytes ru_o_payload(std::size_t os, std::size_t spaces) {
  unsigned const ru = 1, o = 15, space = 33;
  std::vector<bool> bits;
  auto put = [&](unsigned code, unsigned len) {
    for (unsigned i = len; i-- > 0;)
      bits.push_back(((code >> i) & 1u) != 0);
  };
  for (std::size_t i = 0; i < os; ++i)
    put(txt::kTab.code[ru][o], txt::kTab.length[ru][o]);
  for (std::size_t i = 0; i < spaces; ++i)
    put(txt::kTab.code[ru][space], txt::kTab.length[ru][space]);
  std::size_t total = 6 + bits.size();
  std::size_t nbytes = (total + 7) / 8;
  unsigned pad = static_cast<unsigned>(nbytes * 8 - total);
  Bytes p(nbytes, 0);
  p[0] = static_cast<std::uint8_t>(pad << 5 | ru << 2);
  for (std::size_t i = 0; i < bits.size(); ++i)
    if (bits[i])
      p[(6 + i) / 8] |= static_cast<std::uint8_t>(0x80u >> ((6 + i) % 8));
  return p;
}

struct BigList {
  Array<Text<65535>, 85> l;
};
constexpr auto sbig = packbin::scheme<BigList>(7, packbin::list<&BigList::l>(packbin::utf8(0)));
constexpr auto sbig_unbound = packbin::scheme<R3>(8, packbin::list(packbin::utf8(0)));

int text_amp() {
  std::printf("mode=text-amp ru_o_code_len=%u ru_space_code_len=%u\n", txt::kTab.length[1][15],
              txt::kTab.length[1][33]);
  bool ok = true;
  // Largest accepted: 32,767 x "o" + 1 space = 65,535 bytes.
  Bytes p = ru_o_payload(32767, 1);
  Bytes over = ru_o_payload(32768, 0);
  std::uint8_t* out = new std::uint8_t[65535];
  for (int k = 0; k < 2; ++k) {
    Bytes const& q = k == 0 ? p : over;
    Exact in(q);
    txt::Sink sink{out, 65535};
    Stats s;
    bool res = false;
    for (int i = 0; i < 200; ++i) {
      sink.len = 0;
      sink.over = false;
      auto a = Clock::now();
      res = txt::decode_payload(in.data(), in.n, sink);
      s.add(seconds_since(a));
    }
    std::printf("%s payload=%zu accepted=%d text=%zu ratio=%.3f bound_6N_8=%zu\n",
                k == 0 ? "largest" : "one_more", q.size(), res, sink.len,
                static_cast<double>(sink.len) / q.size(), 6 * q.size() + 8);
    s.print(k == 0 ? "largest_decode" : "one_more_decode");
    ok = ok && (k == 0 ? res && sink.len == 65535 : !res);
  }
  // Many max texts in one packet: 85 x 12,289-byte payloads (about 1 MiB) into Text<65535>.
  Bytes pkt{7, 85, 0};
  for (int i = 0; i < 85; ++i) {
    put_varint(pkt, p.size());
    pkt.insert(pkt.end(), p.begin(), p.end());
  }
  BigList* big = new BigList;
  Exact in(pkt);
  Stats s, su;
  packbin::Result res{};
  for (int i = 0; i < 20; ++i) {
    auto a = Clock::now();
    res = packbin::unpack(sbig, in.data(), in.n, *big);
    s.add(seconds_since(a));
  }
  std::printf("packet_85_max_texts bytes=%zu ok=%d texts=%u decoded_bytes=%zu\n", pkt.size(),
              res.ok(), big->l.count, static_cast<std::size_t>(big->l.count) * 65535);
  s.print("packet_85_max_texts_bound");
  ok = ok && res.ok() && big->l.count == 85;
  pkt[0] = 8;
  Exact in2(pkt);
  R3 r3;
  for (int i = 0; i < 20; ++i) {
    auto a = Clock::now();
    res = packbin::unpack(sbig_unbound, in2.data(), in2.n, r3);
    su.add(seconds_since(a));
  }
  std::printf("packet_85_max_texts_unbound ok=%d\n", res.ok());
  su.print("packet_85_max_texts_unbound");
  std::printf("peak_rss_kb=%ld (BigList storage %zu KB)\nresult=%s\n", peak_rss_kb(),
              sizeof(BigList) / 1024, ok ? "PASS" : "FAIL");
  delete big;
  delete[] out;
  return ok ? 0 : 1;
}

// The longest payload a count allows (2,097,151 bytes) made of LOCK symbols only (ua, 15 bits each,
// an even number of them): it decodes to the empty text, so the length limit never stops it. The
// time is the decoder's cost per payload byte with no output.
struct Small {
  Text<16> s;
};
constexpr auto ssmall = packbin::scheme<Small>(10, packbin::utf8<&Small::s>(0));

int text_long() {
  unsigned const ua = 0, lock = txt::kLayout[0].lock;
  unsigned code = txt::kTab.code[ua][lock], len = txt::kTab.length[ua][lock];
  std::size_t const payload = 2097151;
  std::size_t symbols = (payload * 8 - 6) / len;
  symbols -= symbols % 2;
  std::size_t total = 6 + symbols * len;
  std::size_t nb = (total + 7) / 8;
  Bytes p(nb, 0);
  p[0] = static_cast<std::uint8_t>((nb * 8 - total) << 5 | ua << 2);
  std::size_t bit = 6;
  for (std::size_t k = 0; k < symbols; ++k)
    for (unsigned i = len; i-- > 0; ++bit)
      if ((code >> i) & 1u)
        p[bit / 8] |= static_cast<std::uint8_t>(0x80u >> (bit % 8));
  Bytes pkt{10};
  put_varint(pkt, p.size());
  pkt.insert(pkt.end(), p.begin(), p.end());
  Exact in(pkt);
  Small row;
  Stats st;
  packbin::Result res{};
  for (int i = 0; i < 20; ++i) {
    auto a = Clock::now();
    res = packbin::unpack(ssmall, in.data(), in.n, row);
    st.add(seconds_since(a));
  }
  std::printf("mode=text-long payload=%zu lock_symbols=%zu ok=%d text=%u\n", p.size(), symbols, res.ok(),
              row.s.len);
  st.print("lock_only_2MiB_payload");
  std::printf("peak_rss_kb=%ld\nresult=%s\n", peak_rss_kb(), res.ok() && row.s.len == 0 ? "PASS" : "FAIL");
  return res.ok() ? 0 : 1;
}

// ---------------------------------------------------------------- dict duplicate-key cost

struct DictRow {
  Array<Entry<std::uint8_t, Text<4>>, 65535> d;
};
constexpr auto sdict = packbin::scheme<DictRow>(9, packbin::dict<&DictRow::d>(packbin::u8(0)));

int dict_quad(std::size_t entries) {
  if (entries > 65535)
    entries = 65535;
  // Distinct 3-byte ASCII keys as raw payloads: 04 10 a b c, then the u8 value.
  Bytes pkt{9, static_cast<std::uint8_t>(entries), static_cast<std::uint8_t>(entries >> 8)};
  for (std::size_t i = 0; i < entries; ++i) {
    pkt.push_back(4);
    pkt.push_back(0x10);
    pkt.push_back(static_cast<std::uint8_t>(0x20 + i % 64));
    pkt.push_back(static_cast<std::uint8_t>(0x20 + (i / 64) % 64));
    pkt.push_back(static_cast<std::uint8_t>(0x20 + (i / 4096) % 64));
    pkt.push_back(0);
  }
  DictRow* row = new DictRow;
  Exact in(pkt);
  auto a = Clock::now();
  packbin::Result res = packbin::unpack(sdict, in.data(), in.n, *row);
  double dt = seconds_since(a);
  std::printf("mode=dict-quad entries=%zu packet_bytes=%zu ok=%d count=%u seconds=%.3f "
              "pairs_compared=%.3e row_storage_kb=%zu peak_rss_kb=%ld\n",
              entries, pkt.size(), res.ok(), row->d.count, dt,
              static_cast<double>(entries) * (entries - 1) / 2, sizeof(DictRow) / 1024,
              peak_rss_kb());
  // The same packet with the last key equal to the first: refused, at the same cost.
  if (entries >= 2) {
    std::size_t last = 3 + (entries - 1) * 6;
    pkt[last + 2] = pkt[3 + 2];
    pkt[last + 3] = pkt[3 + 3];
    pkt[last + 4] = pkt[3 + 4];
    Exact in2(pkt);
    a = Clock::now();
    res = packbin::unpack(sdict, in2.data(), in2.n, *row);
    std::printf("duplicate_last_key error=%d seconds=%.3f\n", static_cast<int>(res.error),
                seconds_since(a));
  }
  std::printf("result=%s\n", "PASS");
  delete row;
  return 0;
}

}  // namespace probe
