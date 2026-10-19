// AZ-2666 audit probe, mode text-fuzz: random and mutated string fields through the decoder
// itself (full, small and no sink) and through unpack of six schemes (see audit41_probe.cpp).

#include "probe_common.hpp"
#include "text_decode.hpp"

namespace probe {

namespace {

struct TextSeeds {
  std::vector<Bytes> fields;  // whole string fields (varint + payload)
};

TextSeeds load_text_seeds(std::string const& fix) {
  TextSeeds s;
  for (auto const& r : rows(fix + "/text/vectors.txt")) {
    if ((r[0] == "enc" || r[0] == "alt") && r.size() >= 4)
      s.fields.push_back(hex(r[3]));
    else if (r[0] == "bad" && r.size() >= 4)
      s.fields.push_back(hex(r[3]));
    else if (r[0] == "bad" && r.size() == 3)
      s.fields.push_back(Bytes{});
  }
  return s;
}

// A string field: a mutated vector, or a synthetic compact or raw payload with its count.
Bytes gen_field(Rng& r, TextSeeds const& seeds) {
  unsigned pick = static_cast<unsigned>(r.below(10));
  if (pick < 4 && !seeds.fields.empty()) {
    Bytes b = seeds.fields[r.below(seeds.fields.size())];
    if (r.chance(85))
      mutate(r, b);
    return b;
  }
  Bytes payload;
  std::size_t len = r.chance(10) ? 1 + r.below(2000) : 1 + r.below(64);
  if (pick < 8) {
    std::uint8_t pad = static_cast<std::uint8_t>(r.below(8));
    std::uint8_t mode = static_cast<std::uint8_t>(r.chance(90) ? r.below(4) : r.below(8));
    payload.push_back(static_cast<std::uint8_t>(pad << 5 | mode << 2 | r.below(4)));
    unsigned style = static_cast<unsigned>(r.below(4));
    for (std::size_t i = 1; i < len; ++i)
      payload.push_back(style == 0   ? 0xFF
                        : style == 1 ? 0x00
                        : style == 2 ? static_cast<std::uint8_t>(0xF0 | r.below(16))
                                     : r.byte());
    if (pad != 0 && r.chance(70))
      payload.back() = static_cast<std::uint8_t>(payload.back() & ~((1u << pad) - 1));
  } else {
    payload.push_back(r.chance(90) ? 0x10 : r.byte());
    for (std::size_t i = 1; i < len; ++i) {
      std::uint8_t c = r.chance(70) ? static_cast<std::uint8_t>(0x20 + r.below(0x5F)) : r.byte();
      payload.push_back(c);
    }
  }
  Bytes f;
  std::size_t count = payload.size();
  if (r.chance(5))
    count = count + r.below(5) - 2;
  if (r.chance(3)) {
    f.push_back(static_cast<std::uint8_t>(count | 0x80));
    f.push_back(static_cast<std::uint8_t>(count >> 7));
    f.push_back(0);  // a non-minimal 3-byte form
  } else {
    put_varint(f, count);
  }
  f.insert(f.end(), payload.begin(), payload.end());
  return f;
}

// The payload of a field when its count is minimal and fits; empty otherwise.
bool payload_of(Bytes const& f, Bytes& out) {
  std::size_t n = 0, k = 0;
  for (; k < 3; ++k) {
    if (k >= f.size())
      return false;
    n |= static_cast<std::size_t>(f[k] & 0x7F) << (7 * k);
    if ((f[k] & 0x80) == 0) {
      if (k > 0 && f[k] == 0)
        return false;
      break;
    }
  }
  if (k == 3 || n == 0 || f.size() - (k + 1) < n)
    return false;
  out.assign(f.begin() + static_cast<long>(k + 1), f.begin() + static_cast<long>(k + 1 + n));
  return true;
}

R1* g_r1 = new R1;

}  // namespace

int text_fuzz(std::string const& fix, std::uint64_t seed, double budget) {
  TextSeeds seeds = load_text_seeds(fix);
  Rng r(seed);
  std::size_t calls = 0, accepted = 0, refused = 0, packets = 0, packets_ok = 0;
  std::size_t max_out = 0;
  double max_ratio = 0;
  Slowest slow_direct, slow_unpack;
  auto t0 = Clock::now();
  std::uint8_t* out65535 = new std::uint8_t[65535];
  while (seconds_since(t0) < budget) {
    for (int burst = 0; burst < 256; ++burst) {
      Bytes f = gen_field(r, seeds);
      Bytes pl;
      if (payload_of(f, pl)) {
        // Direct: the decoder with a full sink, a small sink and no sink.
        Exact in(pl);
        std::size_t cap = r.chance(50) ? 65535 : 1 + r.below(32);
        std::uint8_t* out = cap == 65535 ? out65535 : new std::uint8_t[cap];
        txt::Sink sink{out, cap};
        auto ta = Clock::now();
        bool ok = txt::decode_payload(in.data(), in.n, sink);
        slow_direct.see(seconds_since(ta), pl);
        txt::Sink count_only{nullptr, txt::kMaxText};
        bool ok2 = txt::decode_payload(in.data(), in.n, count_only);
        ++calls;
        if (ok != ok2 || (ok && count_only.len != sink.len))
          fail_note("sink_disagrees", pl);
        if (ok) {
          ++accepted;
          if (sink.len > txt::kMaxText || sink.len > 6 * pl.size() + 8)
            fail_note("expansion_bound", pl);
          if (!sink.over && !txt::valid_utf8(out, sink.len))
            fail_note("output_not_utf8", pl);
          if (sink.over != (sink.len > cap))
            fail_note("over_flag", pl);
          max_out = std::max(max_out, sink.len);
          max_ratio = std::max(max_ratio, static_cast<double>(sink.len) / pl.size());
        } else {
          ++refused;
        }
        if (cap != 65535)
          delete[] out;
      }
      // Through unpack: a packet of one of six schemes, sometimes with damage on top.
      Bytes pkt;
      std::uint8_t type = static_cast<std::uint8_t>(r.chance(95) ? 1 + r.below(6) : r.byte());
      pkt.push_back(type);
      if (type == 1 || type == 3) {
        pkt.insert(pkt.end(), f.begin(), f.end());
      } else if (type == 2) {
        pkt.insert(pkt.end(), f.begin(), f.end());
        pkt.push_back(r.byte());
      } else {
        std::size_t items = r.chance(90) ? r.below(10) : r.below(65536);
        pkt.push_back(static_cast<std::uint8_t>(items));
        pkt.push_back(static_cast<std::uint8_t>(items >> 8));
        std::size_t emit = std::min<std::size_t>(items, 12);
        Bytes same = gen_field(r, seeds);
        for (std::size_t i = 0; i < emit; ++i) {
          Bytes g = r.chance(30) ? same : gen_field(r, seeds);  // repeats make duplicate keys
          pkt.insert(pkt.end(), g.begin(), g.end());
          if (type >= 5)
            pkt.push_back(r.byte());
        }
      }
      if (r.chance(10))
        mutate(r, pkt);
      Exact pin(pkt);
      static R2 r2;
      static R3 r3;
      static R4 r4;
      static R5 r5;
      auto none = [](auto&) {};
      auto tb = Clock::now();
      packbin::Result res = packbin::unpack(pin.data(), pin.n, packbin::on(s1, *g_r1, none),
                                            packbin::on(s2, r2, none), packbin::on(s3, r3, none),
                                            packbin::on(s4, r4, none), packbin::on(s5, r5, none),
                                            packbin::on(s6, r3, none));
      slow_unpack.see(seconds_since(tb), pkt);
      ++packets;
      if (res.ok()) {
        ++packets_ok;
        if (pkt[0] == 1) {
          std::size_t n = g_r1->s.len;
          if (!txt::valid_utf8(reinterpret_cast<std::uint8_t const*>(g_r1->s.data), n))
            fail_note("text_member_not_utf8", pkt);
          if (n > 6 * pkt.size() + 8)
            fail_note("text_member_expansion", pkt);
        }
        if (pkt[0] == 2 && r2.p.len != 0 &&
            (r2.p.data < pin.data() || r2.p.data + r2.p.len > pin.data() + pin.n))
          fail_note("packed_outside_input", pkt);
        if (pkt[0] == 5) {
          for (std::uint16_t a = 0; a < r5.d.count; ++a)
            for (std::uint16_t b = a + 1; b < r5.d.count; ++b)
              if (r5.d.items[a].key.len == r5.d.items[b].key.len &&
                  std::memcmp(r5.d.items[a].key.data, r5.d.items[b].key.data,
                              r5.d.items[a].key.len) == 0)
                fail_note("duplicate_key_accepted", pkt);
        }
      }
    }
  }
  std::printf("mode=text-fuzz seed=%llu seconds=%.1f\n", static_cast<unsigned long long>(seed),
              seconds_since(t0));
  std::printf("direct_calls=%zu accepted=%zu refused=%zu max_text=%zu max_bytes_per_payload_byte=%.3f\n",
              calls, accepted, refused, max_out, max_ratio);
  std::printf("unpack_calls=%zu unpack_ok=%zu\n", packets, packets_ok);
  std::printf("slowest_direct_us=%.1f (payload %zu B) slowest_unpack_us=%.1f (packet %zu B)\n",
              slow_direct.t * 1e6, slow_direct.input.size(), slow_unpack.t * 1e6,
              slow_unpack.input.size());
  std::printf("peak_rss_kb=%ld failures=%d\nresult=%s\n", peak_rss_kb(), g_fail,
              g_fail == 0 ? "PASS" : "FAIL");
  delete[] out65535;
  return g_fail == 0 ? 0 : 1;
}

}  // namespace probe
