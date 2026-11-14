// AZ-4303 (contract scheme-depth.md 1.0.1): a scheme nested deeper than 256 levels is refused when
// it is built, first and without recursion. Run-time tables are filled by loops (scheme_depth_chains.hpp);
// the chains of exactly 256 levels are `constexpr` schemes, so they also prove that the compiler's own
// limit of 512 nested calls does not stop a scheme at the limit. The constant form of the refusal is
// tests/compile-fail/scheme_depth_*.cpp. Host-only.

#include "packbin/codec.hpp"

#include "check.hpp"
#include "scheme_depth_chains.hpp"

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

using check::expect;
using depth_chain::Shape;
namespace pb = packbin;

namespace {

// GCC 16 at -O2 reports a false -Warray-bounds for the copy of a node into a run-time table (see
// source_kinds_host_tests.cpp); the suppression covers this file only.
#pragma GCC diagnostic ignored "-Warray-bounds"

constexpr std::size_t kLimit = 256;

bool is_depth_refusal(pb::Result const& r) {
  return r.error == pb::Error::SchemeInvalid && r.needed == kLimit;
}

// What the first entry past the limit names: the `when` (1), the group (0); a list and a dict have no id.
template <Shape S>
constexpr int past_limit_id() {
  return S == Shape::When ? 1 : S == Shape::Group ? 0 : -1;
}

template <Shape S>
void boundary_is_256() {
  // Arrange: the chain of 256 and of 257 levels, built by a loop
  // Act
  pb::Result at_limit = depth_chain::status_at<S, 256>();
  pb::Result over = depth_chain::status_at<S, 257>();
  // Assert
  expect(at_limit.ok(), "AZ-4303 AC-1 256 levels build");
  expect(is_depth_refusal(over) && over.field == past_limit_id<S>(),
         "AZ-4303 AC-1 257 levels are SchemeInvalid with needed 256 at the first entry past the limit");
}

template <Shape S, std::size_t Depth>
double refused_seconds() {
  // Arrange
  auto start = std::chrono::steady_clock::now();
  // Act
  pb::Result r = depth_chain::status_at<S, Depth>();
  double took = std::chrono::duration<double>(std::chrono::steady_clock::now() - start).count();
  // Assert
  expect(is_depth_refusal(r), "AZ-4303 AC-1 a deep chain is refused with the depth status");
  return took;
}

void deep_chains_are_refused_fast_without_a_crash() {
  // 50,000 levels crashed in detail::resolve before the limit (loop 125). A dict level takes two
  // table entries and a span is 16 bits, so a dict chain stops at 5,000 here.
  double slowest = 0;
  for (double t : {refused_seconds<Shape::When, 1000>(), refused_seconds<Shape::When, 5000>(),
                   refused_seconds<Shape::When, 50000>(), refused_seconds<Shape::Group, 1000>(),
                   refused_seconds<Shape::Group, 5000>(), refused_seconds<Shape::Group, 50000>(),
                   refused_seconds<Shape::List, 1000>(), refused_seconds<Shape::List, 50000>(),
                   refused_seconds<Shape::Dict, 1000>(), refused_seconds<Shape::Dict, 5000>()})
    slowest = t > slowest ? t : slowest;
  expect(slowest < 5.0, "AZ-4303 AC-1 every deep chain is refused within 5 seconds");
}

// A table of kinds in preorder, written by a loop: begin and end nest, a leaf is one entry.
struct Tree {
  std::vector<pb::Field> t;
  std::vector<std::size_t> open;

  void begin(pb::Kind k) {
    pb::Field f;
    f.kind = k;
    open.push_back(t.size());
    t.push_back(f);
  }
  void leaf() { t.push_back(pb::Field{}); }
  void end() {
    t[open.back()].span = static_cast<std::uint16_t>(t.size() - open.back());
    open.pop_back();
  }
  void chain(pb::Kind outer, pb::Kind inner, int pairs) {
    for (int i = 0; i < pairs; ++i) {
      begin(outer);
      begin(inner);
    }
  }
  void close(int n) {
    for (int i = 0; i < n; ++i)
      end();
  }
  bool clean = true;  // false once a check left a `ref` that is not -1
  // True when the depth check refuses the table.
  bool too_deep() {
    pb::detail::Check c{};
    pb::detail::check_depth(t.data(), t.size(), c);
    for (auto const& f : t)
      clean = clean && f.ref == -1;
    return c.failed;
  }
};

void kinds_count_by_the_contract() {
  // Arrange and Act per row: pairs of (outer, inner) kinds around a leaf
  Tree list_group_128;
  list_group_128.chain(pb::Kind::List, pb::Kind::Group, 128);
  list_group_128.leaf();
  list_group_128.close(256);
  Tree list_group_129;
  list_group_129.chain(pb::Kind::List, pb::Kind::Group, 129);
  list_group_129.leaf();
  list_group_129.close(258);
  Tree flags_256;  // a flag bit adds no level: the flags above it counted
  flags_256.chain(pb::Kind::Flags, pb::Kind::FlagBit, 256);
  flags_256.leaf();
  flags_256.close(512);
  Tree flags_257;
  flags_257.chain(pb::Kind::Flags, pb::Kind::FlagBit, 257);
  flags_257.leaf();
  flags_257.close(514);
  Tree rounds_256;  // repeat and times each count one level
  rounds_256.chain(pb::Kind::Repeat, pb::Kind::Times, 128);
  rounds_256.leaf();
  rounds_256.close(256);
  Tree rounds_257;
  rounds_257.chain(pb::Kind::Repeat, pb::Kind::Times, 128);
  rounds_257.begin(pb::Kind::Group);
  rounds_257.leaf();
  rounds_257.close(257);
  Tree empty_256;  // an empty innermost container counts as a level
  empty_256.chain(pb::Kind::Group, pb::Kind::When, 127);
  empty_256.begin(pb::Kind::Group);
  empty_256.begin(pb::Kind::When);
  empty_256.close(2);
  empty_256.close(254);
  Tree empty_257;
  empty_257.chain(pb::Kind::Group, pb::Kind::When, 128);
  empty_257.begin(pb::Kind::Group);
  empty_257.close(1);
  empty_257.close(256);
  // Assert
  expect(!list_group_128.too_deep(), "AZ-4303 AC-1 a list that holds a group is two levels: 128 of them build");
  expect(list_group_129.too_deep(), "AZ-4303 AC-1 129 lists that hold a group are 258 levels");
  expect(!flags_256.too_deep(), "AZ-4303 AC-1 a flag bit adds no level: 256 flags build");
  expect(flags_257.too_deep(), "AZ-4303 AC-1 257 flags are refused");
  expect(!rounds_256.too_deep(), "AZ-4303 AC-1 repeat and times each count one level");
  expect(rounds_257.too_deep(), "AZ-4303 AC-1 a group in 256 rounds is 257 levels");
  expect(!empty_256.too_deep(), "AZ-4303 AC-1 an empty innermost container is a level: 256 build");
  expect(empty_257.too_deep(), "AZ-4303 AC-1 an empty innermost container is a level: 257 are refused");
  expect(list_group_128.clean && list_group_129.clean && flags_256.clean && flags_257.clean &&
             rounds_256.clean && rounds_257.clean && empty_256.clean && empty_257.clean,
         "AZ-4303 NFR the check leaves every ref as it found it");
}

void depth_is_the_longest_path_not_the_total() {
  // Arrange: two chains of 256 one after the other at the top, and a branch inside a chain
  Tree twice;
  for (int k = 0; k < 2; ++k) {
    twice.chain(pb::Kind::Group, pb::Kind::When, 128);
    twice.leaf();
    twice.close(256);
  }
  Tree branches_256;  // 100 levels, then two branches of 156 levels
  Tree branches_257;  // the second branch is one level deeper
  for (auto* tree : {&branches_256, &branches_257}) {
    int second = tree == &branches_256 ? 156 : 157;
    tree->chain(pb::Kind::Group, pb::Kind::Group, 50);
    tree->chain(pb::Kind::When, pb::Kind::When, 78);
    tree->leaf();
    tree->close(156);
    tree->chain(pb::Kind::Group, pb::Kind::Group, second / 2);
    if (second % 2 != 0)
      tree->begin(pb::Kind::Group);
    tree->leaf();
    tree->close(second);
    tree->close(100);
  }
  // Act and Assert
  expect(!twice.too_deep(), "AZ-4303 AC-1 the depth starts again at the top after a chain closes");
  expect(!branches_256.too_deep(), "AZ-4303 AC-1 two branches that reach 256 each build");
  expect(branches_257.too_deep(), "AZ-4303 AC-1 the deeper branch decides: 257 is refused");
  expect(twice.clean && branches_256.clean && branches_257.clean,
         "AZ-4303 NFR the check leaves every ref as it found it");
}

// 256 levels written in source, so the compiler's own limit is part of the test.
struct Chain {
  std::uint8_t a = 0;
  std::uint8_t b = 0;
};

constexpr auto when_256 = pb::scheme<Chain>(1, pb::u8<&Chain::a>(0),
                                            depth_chain::whens<256>(pb::u8<&Chain::b>(1)));
constexpr auto group_256 = pb::scheme<Chain>(1, depth_chain::groups<256>(pb::u8<&Chain::b>(0)));

struct ListChain {
  depth_chain::ListLayers<256>::type xs;
};
constexpr auto list_256 =
    pb::scheme<ListChain>(1, pb::list<&ListChain::xs>(depth_chain::inner_lists<255>()));

template <int D>
void fill(typename depth_chain::ListLayers<D>::type& a) {
  a.count = 1;
  if constexpr (D == 1)
    a.items[0] = 7;
  else
    fill<D - 1>(a.items[0]);
}

template <int D>
bool holds(typename depth_chain::ListLayers<D>::type const& a) {
  if constexpr (D == 1)
    return a.count == 1 && a.items[0] == 7;
  else
    return a.count == 1 && holds<D - 1>(a.items[0]);
}

std::string hex_of(std::vector<std::uint8_t> const& b, std::size_t n) {
  static char const digits[] = "0123456789abcdef";
  std::string out;
  for (std::size_t i = 0; i < n; ++i) {
    out += digits[b[i] >> 4];
    out += digits[b[i] & 15];
  }
  return out;
}

void chains_of_256_levels_pack_and_unpack() {
  // Arrange
  std::vector<std::uint8_t> buf(4096);
  Chain row;
  row.a = 1;
  row.b = 7;
  // Act: when
  auto when_packed = pb::pack(when_256, row, buf.data(), buf.size());
  std::string when_hex = hex_of(buf, when_packed.offset);
  Chain when_back;
  auto when_read = pb::unpack(when_256, buf.data(), when_packed.offset, when_back);
  // Act: group
  auto group_packed = pb::pack(group_256, row, buf.data(), buf.size());
  std::string group_hex = hex_of(buf, group_packed.offset);
  Chain group_back;
  auto group_read = pb::unpack(group_256, buf.data(), group_packed.offset, group_back);
  // Assert
  expect(pb::validate(when_256).ok() && when_packed.ok() && when_hex == "010107",
         "AZ-4303 AC-2 256 nested whens build and pack 010107");
  expect(when_read.ok() && when_back.a == 1 && when_back.b == 7,
         "AZ-4303 AC-2 256 nested whens unpack to the same value");
  expect(pb::validate(group_256).ok() && group_packed.ok() && group_hex == "0107",
         "AZ-4303 AC-2 256 nested groups build and pack 0107");
  expect(group_read.ok() && group_back.b == 7, "AZ-4303 AC-2 256 nested groups unpack to the same value");
}

void list_chain_of_256_levels_packs_and_unpacks() {
  // Arrange
  std::vector<std::uint8_t> buf(4096);
  ListChain row;
  fill<256>(row.xs);
  // Act
  auto packed = pb::pack(list_256, row, buf.data(), buf.size());
  ListChain back;
  auto read = pb::unpack(list_256, buf.data(), packed.offset, back);
  bool same = read.ok() && holds<256>(back.xs);
  // Assert
  expect(pb::validate(list_256).ok() && packed.ok() && packed.offset == 1 + 256 * 2 + 1,
         "AZ-4303 AC-2 256 nested list element rows build and pack one count per level and the value");
  expect(same, "AZ-4303 AC-2 256 nested list element rows unpack to the same value");
}

void dict_chain_of_256_levels_packs_and_unpacks() {
  // Arrange: one shared array (scheme_depth_chains.hpp): count 1, the key "k", the value 7
  auto& table = depth_chain::shared_dict_chain<513>(256);
  depth_chain::Level& level = depth_chain::shared_level();
  level.m.count = 1;
  level.m.items[0].key.len = 1;
  level.m.items[0].key.data[0] = 'k';
  level.m.items[0].value = 7;
  std::vector<std::uint8_t> buf(8192);
  // Act
  auto packed = pb::pack(table, level, buf.data(), buf.size());
  level.m.items[0].value = 0;
  auto read = pb::unpack(table, buf.data(), packed.offset, level);
  // Assert
  expect(table.status.ok() && packed.ok() && packed.offset == 1 + 256 * 5 + 1,
         "AZ-4303 AC-2 256 nested dict element rows build and pack a count and a key per level and the value");
  expect(read.ok() && level.m.items[0].value == 7,
         "AZ-4303 AC-2 256 nested dict element rows unpack the same value");
}

}  // namespace

int run_core_scheme_depth_host_tests() {
  boundary_is_256<Shape::When>();
  boundary_is_256<Shape::Group>();
  boundary_is_256<Shape::List>();
  boundary_is_256<Shape::Dict>();
  deep_chains_are_refused_fast_without_a_crash();
  kinds_count_by_the_contract();
  depth_is_the_longest_path_not_the_total();
  chains_of_256_levels_pack_and_unpack();
  list_chain_of_256_levels_packs_and_unpacks();
  dict_chain_of_256_levels_packs_and_unpacks();
  return check::failures();
}
