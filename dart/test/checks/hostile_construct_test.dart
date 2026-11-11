import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/refusal.dart';
import '../support/repo.dart';

typedef Build = Object Function();

Field n(int id, String name) => u8(id, name);

/// The schemes of the `construct` cases of `fixtures/hostile/cases.txt` that
/// the Dart package can write today, and the field each refusal names.
final builders = <String, (Build, int?)>{
  'nine_flag_bits': (
    () => scheme(1, [
      flags(0, [for (var i = 0; i < 9; i++) n(i, 'f$i')]),
    ]),
    0,
  ),
  'nine_flag_bits_split': (
    () {
      final fb = flagByte('fb');
      return scheme(1, [fb, for (var i = 0; i < 9; i++) fb.bit(n(i, 'f$i'))]);
    },
    8,
  ),
  'when_names_later_field': (
    () => scheme(1, [
      n(0, 'a'),
      when(1, eq(2, 1), [n(1, 'b')]),
      n(2, 'c'),
    ]),
    1,
  ),
  'bool_outside_flags': (() => scheme(1, [n(0, 'a'), flagBool(1, 'on')]), 1),
  'empty_group_outside_flags': (
    () => scheme(1, [n(0, 'a'), groupOf(1, 'mark', [])]),
    1,
  ),
  'eq_bool_false': (
    () => scheme(1, [
      flags(0, [flagBool(0, 'on')]),
      when(1, eq(0, false), [n(1, 'v')]),
    ]),
    1,
  ),
  'eq_out_of_range': (
    () => scheme(1, [
      n(0, 'a'),
      when(1, eq(0, 300), [n(1, 'v')]),
    ]),
    1,
  ),
  'count_names_later_field': (
    () => scheme(1, [sized(0, 'payload', 1), u16(1, 'n')]),
    0,
  ),
  'when_names_outer_field_in_repeat': (
    () => scheme(1, [
      u8(0, 'mode'),
      repeat(1, [
        when(1, eq(0, 1), [u8(1, 'v')]),
      ]),
    ]),
    1,
  ),
  'construct_empty_times_body': (
    () => scheme(1, [u8(0, 'n'), times(1, 0, [])]),
    1,
  ),
  'construct_empty_repeat_body': (() => scheme(1, [repeat(0, [])]), 0),
  'construct_empty_when_times_body': (
    () => scheme(1, [
      u8(0, 'mode'),
      u8(1, 'c'),
      times(2, 1, [when(2, eq(0, 1), [])]),
    ]),
    2,
  ),
  'construct_empty_when_repeat_body': (
    () => scheme(1, [
      u8(0, 'mode'),
      repeat(1, [when(1, eq(0, 1), [])]),
    ]),
    1,
  ),
  'construct_empty_round_body_list_element': (
    () => scheme(1, [
      list('items', nested('item', [u8(0, 'n'), times(1, 0, [])])),
    ]),
    1,
  ),
  'construct_empty_nested_when_body': (
    () => scheme(1, [
      u8(0, 'mode'),
      u8(1, 'c'),
      times(2, 1, [
        when(2, eq(0, 1), [when(2, eq(0, 1), [])]),
      ]),
    ]),
    2,
  ),
};

/// Cases a later task builds: none is left, and the test fails on a construct
/// case that is neither here nor in [builders].
final deferred = <String, String>{};

/// The `construct` rows of the file: id and the outcome terms accepted.
List<(String, List<String>)> constructCases() {
  final rows = <(String, List<String>)>[];
  for (final line in repoText('fixtures/hostile/cases.txt').split('\n')) {
    final text = line.trim();
    if (text.isEmpty || text.startsWith('#')) continue;
    final parts = text.split(RegExp(r'\s+'));
    if (parts.length == 4 && parts[1] == 'construct') {
      rows.add((parts[0], parts[2].split('|')));
    }
  }
  return rows;
}

void main() {
  group('the construct cases of the shared hostile vectors', () {
    final cases = constructCases();

    test('every construct case is built here or deferred to a named task', () {
      // Arrange
      final ids = [for (final (id, _) in cases) id];

      // Act
      final unknown = [
        for (final id in ids)
          if (!builders.containsKey(id) && !deferred.containsKey(id)) id,
      ];
      final stale = [
        for (final id in [...builders.keys, ...deferred.keys])
          if (!ids.contains(id)) id,
      ];

      // Assert
      expect(unknown, isEmpty);
      expect(stale, isEmpty);
      expect(ids, hasLength(15));
    });

    for (final (id, terms) in cases) {
      final entry = builders[id];
      if (entry == null) continue;
      test('$id is refused at construction, naming the field', () {
        // Arrange
        final (build, field) = entry;

        // Act
        final error = refusal(build);

        // Assert
        expect(terms, contains('scheme_error'));
        expect(error.kind.term, 'scheme_error');
        expect(error.field, field);
        expect(error.name, isNotEmpty);
      });
    }
  });
}
