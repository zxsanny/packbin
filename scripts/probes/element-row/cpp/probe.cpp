// Probe of AZ-4242: a list or dict whose element is a row of required members (no flag byte per
// element). It builds each shape of ../README.md with the public API, packs the values given there
// and unpacks its own bytes. One line per shape: package, shape, build, pack, unpack (tab
// separated). It asserts nothing: it prints what happens.
//
// Forms. The plain shape name is a list or dict BOUND to a member (`list<&ListRow::items>(element)`),
// the only form that can pack values. `<shape>-unbound` is the same list or dict without a member
// (`list(element)`): unpack reads and skips it, and pack has no member to write it from. The element
// row is a group of unbound fields in both forms: a C++ list or dict element is always written
// unbound (fields_counted.hpp), so the element members name no row type. With -DPROBE_CONSTEXPR and
// one -DSHAPE_<NAME> the translation unit holds that one bound shape as a constant
// (`constexpr auto s = ...`), where a refused scheme does not compile.
//
// Compile-only shapes. `coll-<type>` (a bound list or dict member of another container type),
// `other-row`, `other-row-unbound` and `nested-other-row` are built with -DPROBE_ONLY and one
// -DSHAPE_<NAME>, one translation unit each, so a shape the compiler rejects does not stop the
// others; `run.sh` prints such a shape as `n/a: does not compile: <first error>`.
// They are in probe_compiled.hpp; the rows, values and output helpers are in probe_support.hpp.
//
// C++ rows are structs; a string member is a Text<N>. The package has no text for a failure: a
// `Result` is printed as its members. `probe <shape>` prints one shape (`run.sh` starts one process
// per shape, so a crash is its own line); `probe <shape> reference` instead unpacks the TypeScript
// bytes of the shape with its scheme and reports on stderr whether they read.
#include "probe_support.hpp"

#if !defined(PROBE_CONSTEXPR) && !defined(PROBE_ONLY)
#define SHAPE_LIST_0
#define SHAPE_LIST_1
#define SHAPE_LIST_3
#define SHAPE_DICT_2
#define SHAPE_WHEN
#define SHAPE_TIMES
#define SHAPE_UNBOUND
#define SHAPE_NULL
#endif

#if defined(SHAPE_LIST_0) || defined(SHAPE_LIST_1) || defined(SHAPE_LIST_3)
void list_shape(char const* shape, std::size_t n, char const* reference) {
  PROBE_SCHEME s = pb::scheme<ListRow>(1, pb::list<&ListRow::items>(PROBE_COMMENT));
  probe(shape, s, list_of(n), reference);
}
#endif

#ifdef SHAPE_LIST_0
void shape_list_0() { list_shape("list-0", 0, kList0); }
#endif
#ifdef SHAPE_LIST_1
void shape_list_1() { list_shape("list-1", 1, kList1); }
#endif
#ifdef SHAPE_LIST_3
void shape_list_3() { list_shape("list-3", 3, kList3); }
#endif

#ifdef SHAPE_DICT_2
void shape_dict_2() {
  PROBE_SCHEME s = pb::scheme<DictRow>(1, pb::dict<&DictRow::map>(PROBE_COMMENT));
  probe("dict-2", s, dict_values(), kDict2);
}
#endif

#ifdef SHAPE_WHEN
void shape_when() {
  PROBE_SCHEME s = pb::scheme<WhenRow>(1, pb::list<&WhenRow::items>(PROBE_WHEN_ITEM));
  probe("when", s, when_values(), kWhen);
}
#endif

#ifdef SHAPE_TIMES
void shape_times() {
  PROBE_SCHEME s = pb::scheme<TimesRow>(1, pb::list<&TimesRow::items>(PROBE_TIMES_ITEM));
  probe("times", s, times_values(), kTimes);
}
#endif

#ifdef SHAPE_UNBOUND
// The unbound forms: the scheme has the same wire layout and no member to pack from.
void unbound_list(char const* shape, std::size_t n, char const* reference) {
  auto s = pb::scheme<ListRow>(1, pb::list(PROBE_COMMENT));
  probe(shape, s, list_of(n), reference);
}

void shape_list_0_unbound() { unbound_list("list-0-unbound", 0, kList0); }
void shape_list_1_unbound() { unbound_list("list-1-unbound", 1, kList1); }
void shape_list_3_unbound() { unbound_list("list-3-unbound", 3, kList3); }

void shape_dict_2_unbound() {
  auto s = pb::scheme<DictRow>(1, pb::dict(PROBE_COMMENT));
  probe("dict-2-unbound", s, dict_values(), kDict2);
}

void shape_when_unbound() {
  auto s = pb::scheme<WhenRow>(1, pb::list(PROBE_WHEN_ITEM));
  probe("when-unbound", s, when_values(), kWhen);
}

void shape_times_unbound() {
  auto s = pb::scheme<TimesRow>(1, pb::list(PROBE_TIMES_ITEM));
  probe("times-unbound", s, times_values(), kTimes);
}
#endif

#ifdef SHAPE_NULL
// C++ has no null member and no null item; the reasons are in the line.
void shape_null_member() {
  na("null-member",
     "no null member: an element member is written unbound and a Text<N> always holds a string (len 0 is the "
     "empty string)");
}

void shape_null_item() {
  na("null-item",
     "no null item: an Array<T, N> holds its first count items by value; no pointer or Opt<T> item binds a list "
     "element (bind_element)");
}
#endif

#include "probe_compiled.hpp"

struct Shape {
  char const* name;
  void (*run)();
};

Shape const shapes[] = {
#ifdef SHAPE_LIST_0
    {"list-0", &shape_list_0},
#endif
#ifdef SHAPE_LIST_1
    {"list-1", &shape_list_1},
#endif
#ifdef SHAPE_LIST_3
    {"list-3", &shape_list_3},
#endif
#ifdef SHAPE_DICT_2
    {"dict-2", &shape_dict_2},
#endif
#ifdef SHAPE_WHEN
    {"when", &shape_when},
#endif
#ifdef SHAPE_TIMES
    {"times", &shape_times},
#endif
#ifdef SHAPE_UNBOUND
    {"list-0-unbound", &shape_list_0_unbound},
    {"list-1-unbound", &shape_list_1_unbound},
    {"list-3-unbound", &shape_list_3_unbound},
    {"dict-2-unbound", &shape_dict_2_unbound},
    {"when-unbound", &shape_when_unbound},
    {"times-unbound", &shape_times_unbound},
#endif
#ifdef SHAPE_NULL
    {"null-member", &shape_null_member},
    {"null-item", &shape_null_item},
#endif
#ifdef SHAPE_COLL_STD_VECTOR
    {"coll-std-vector", &shape_coll},
#endif
#ifdef SHAPE_COLL_STD_ARRAY
    {"coll-std-array", &shape_coll},
#endif
#ifdef SHAPE_COLL_C_ARRAY
    {"coll-c-array", &shape_coll},
#endif
#ifdef SHAPE_COLL_STD_LIST
    {"coll-std-list", &shape_coll},
#endif
#ifdef SHAPE_COLL_STD_MAP
    {"coll-std-map", &shape_coll},
#endif
#ifdef SHAPE_COLL_STD_UNORDERED_MAP
    {"coll-std-unordered-map", &shape_coll},
#endif
#ifdef SHAPE_OTHER_ROW
    {"other-row", &shape_other},
#endif
#ifdef SHAPE_OTHER_ROW_UNBOUND
    {"other-row-unbound", &shape_other},
#endif
#ifdef SHAPE_NESTED_OTHER_ROW
    {"nested-other-row", &shape_other},
#endif
};

int main(int argc, char** argv) {
  if (argc == 2 || (argc == 3 && std::strcmp(argv[2], "reference") == 0)) {
    g_reference = argc == 3;
    for (Shape const& shape : shapes) {
      if (std::strcmp(shape.name, argv[1]) == 0) {
        shape.run();
        return 0;
      }
    }
  }
  std::fprintf(stderr, "usage: probe <shape> [reference]; this build holds:");
  for (Shape const& shape : shapes)
    std::fprintf(stderr, " %s", shape.name);
  std::fprintf(stderr, "\n");
  return 2;
}
