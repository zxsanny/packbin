// The compile-only shapes of probe.cpp (AZ-4242): `coll-<type>`, `other-row`, `other-row-unbound`
// and `nested-other-row`. run.sh builds each with -DPROBE_ONLY and its one -DSHAPE_<NAME>, so a
// shape the compiler rejects stops only its own translation unit. Included once, by probe.cpp only.
#pragma once

#include "probe_support.hpp"

#if defined(SHAPE_COLL_STD_VECTOR)
#include <vector>
#endif
#if defined(SHAPE_COLL_STD_ARRAY)
#include <array>
#endif
#if defined(SHAPE_COLL_STD_LIST)
#include <list>
#endif
#if defined(SHAPE_COLL_STD_MAP)
#include <map>
#endif
#if defined(SHAPE_COLL_STD_UNORDERED_MAP)
#include <map>
#include <unordered_map>
#endif

// coll-<type>: list-3 (dict-2) with the member of another container type. The values are filled the
// same way, so a type the package accepted would pack and unpack like the plain shape.
#if defined(SHAPE_COLL_STD_VECTOR) || defined(SHAPE_COLL_STD_ARRAY) || defined(SHAPE_COLL_C_ARRAY) || \
    defined(SHAPE_COLL_STD_LIST)
template <typename C>
std::string shown_range(C const& items) {
  std::string out = "{\"items\":[";
  bool first = true;
  for (Comment const& c : items) {
    out += (first ? "" : ",") + shown(c);
    first = false;
  }
  return out + "]}";
}
#endif

#ifdef SHAPE_COLL_STD_VECTOR
struct VectorRow {
  std::vector<Comment> items;
};
std::string shown(VectorRow const& r) { return shown_range(r.items); }
void shape_coll() {
  PROBE_SCHEME s = pb::scheme<VectorRow>(1, pb::list<&VectorRow::items>(PROBE_COMMENT));
  probe("coll-std-vector", s, VectorRow{{c1(), c2(), c3()}}, kList3);
}
#endif

#ifdef SHAPE_COLL_STD_ARRAY
struct StdArrayRow {
  std::array<Comment, 3> items;
};
std::string shown(StdArrayRow const& r) { return shown_range(r.items); }
void shape_coll() {
  PROBE_SCHEME s = pb::scheme<StdArrayRow>(1, pb::list<&StdArrayRow::items>(PROBE_COMMENT));
  probe("coll-std-array", s, StdArrayRow{{c1(), c2(), c3()}}, kList3);
}
#endif

#ifdef SHAPE_COLL_C_ARRAY
struct CArrayRow {
  Comment items[3];
};
std::string shown(CArrayRow const& r) { return shown_range(r.items); }
void shape_coll() {
  PROBE_SCHEME s = pb::scheme<CArrayRow>(1, pb::list<&CArrayRow::items>(PROBE_COMMENT));
  probe("coll-c-array", s, CArrayRow{{c1(), c2(), c3()}}, kList3);
}
#endif

#ifdef SHAPE_COLL_STD_LIST
struct StdListRow {
  std::list<Comment> items;
};
std::string shown(StdListRow const& r) { return shown_range(r.items); }
void shape_coll() {
  PROBE_SCHEME s = pb::scheme<StdListRow>(1, pb::list<&StdListRow::items>(PROBE_COMMENT));
  probe("coll-std-list", s, StdListRow{{c1(), c2(), c3()}}, kList3);
}
#endif

#if defined(SHAPE_COLL_STD_MAP) || defined(SHAPE_COLL_STD_UNORDERED_MAP)
// Printed in key order, whatever order the map keeps.
template <typename M>
std::string shown_map(M const& map) {
  std::map<std::string, Comment> sorted(map.begin(), map.end());
  std::string out = "{\"map\":{";
  bool first = true;
  for (auto const& e : sorted) {
    out += (first ? "\"" : ",\"") + e.first + "\":" + shown(e.second);
    first = false;
  }
  return out + "}}";
}
#endif

#ifdef SHAPE_COLL_STD_MAP
struct MapRow {
  std::map<std::string, Comment> map;
};
std::string shown(MapRow const& r) { return shown_map(r.map); }
void shape_coll() {
  PROBE_SCHEME s = pb::scheme<MapRow>(1, pb::dict<&MapRow::map>(PROBE_COMMENT));
  probe("coll-std-map", s, MapRow{{{"b", c2()}, {"a", c1()}}}, kDict2);
}
#endif

#ifdef SHAPE_COLL_STD_UNORDERED_MAP
struct UnorderedMapRow {
  std::unordered_map<std::string, Comment> map;
};
std::string shown(UnorderedMapRow const& r) { return shown_map(r.map); }
void shape_coll() {
  PROBE_SCHEME s = pb::scheme<UnorderedMapRow>(1, pb::dict<&UnorderedMapRow::map>(PROBE_COMMENT));
  probe("coll-std-unordered-map", s, UnorderedMapRow{{{"b", c2()}, {"a", c1()}}}, kDict2);
}
#endif

#if defined(SHAPE_OTHER_ROW) || defined(SHAPE_OTHER_ROW_UNBOUND) || defined(SHAPE_NESTED_OTHER_ROW)
// A row type other than the element's (or the scheme's), with members of the same kinds.
struct Other {
  pb::Text<4> id;
  pb::Text<4> text;
  std::uint32_t authorId = 0;
  pb::Text<4> author;
  std::uint8_t x = 0;
};
#define PROBE_OTHER_COMMENT                                                                       \
  pb::group(0, pb::utf8<&Other::id>(0), pb::utf8<&Other::text>(1), pb::u32<&Other::authorId>(2), \
            pb::utf8<&Other::author>(3))
#endif

#ifdef SHAPE_OTHER_ROW
// list-1 whose element members are declared for Other, not Comment.
void shape_other() {
  PROBE_SCHEME s = pb::scheme<ListRow>(1, pb::list<&ListRow::items>(PROBE_OTHER_COMMENT));
  probe("other-row", s, list_of(1), kList1);
}
#endif

#ifdef SHAPE_OTHER_ROW_UNBOUND
void shape_other() {
  PROBE_SCHEME s = pb::scheme<ListRow>(1, pb::list(PROBE_OTHER_COMMENT));
  probe("other-row-unbound", s, list_of(1), kList1);
}
#endif

#ifdef SHAPE_NESTED_OTHER_ROW
// C++ has no group without an anchor: a group's members are members of the row around it. The
// nearest shape is a group inside the row whose member is declared for Other.
struct NestRow {
  std::uint8_t a = 0;
  std::uint8_t x = 0;
};
std::string shown(NestRow const& r) { return "{\"a\":" + number(r.a) + ",\"x\":" + number(r.x) + "}"; }
void shape_other() {
  PROBE_SCHEME s = pb::scheme<NestRow>(1, pb::u8<&NestRow::a>(0), pb::group(1, pb::u8<&Other::x>(1)));
  probe("nested-other-row", s, NestRow{1, 2}, "010102");
}
#endif
