import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';

typedef Row = Map<String, Object?>;

Scheme<Row> s(List<Field> fields) => scheme(1, fields);

Field n(int id, String name) => u8(id, name);

Scheme<Row> anchoredFlags() => s([
  n(0, 'a'),
  groupOf(1, 'g', [
    n(1, 'b'),
    flags(2, [n(2, 'c')]),
  ]),
]);

Scheme<Row> siblingAndFlags() => s([
  flags(0, [
    groupOf(0, 'g', [
      n(0, 'a'),
      flags(1, [n(1, 'c')]),
    ]),
  ]),
]);

Scheme<Row> groupSibling() => s([
  n(0, 'mode'),
  flags(1, [
    groupOf(1, 'g', [
      n(1, 'extra'),
      when(2, eq(0, 1), [n(2, 'speed')]),
    ]),
    u16(3, 'heading'),
  ]),
]);

Scheme<Row> lateSource() {
  final m = flagByte('m');
  return s([
    m,
    n(0, 'mode'),
    m.bit(
      when(1, eq(0, 1), [
        groupOf(1, 'g', [n(1, 'a')]),
      ]),
    ),
  ]);
}

/// A map row pack refuses: the field id and name the error names, and the
/// start of its reason.
final class RefusedRow {
  RefusedRow(
    this.name,
    this.build,
    this.row,
    this.field,
    this.member,
    this.reason,
  );
  final String name;
  final Scheme<Row> Function() build;
  final Row row;
  final int field;
  final String member;
  final String reason;
}

String flat(String member, String group) =>
    '$member is a member of group $group, which is not given; give the value in the group\'s Map';

final refusedRows = <RefusedRow>[
  RefusedRow(
    'a set group with a required member missing',
    siblingAndFlags,
    {
      'g': {'c': 2},
    },
    0,
    'a',
    'missing a',
  ),
  RefusedRow(
    'a when body missing from a given group',
    groupSibling,
    {
      'mode': 1,
      'g': {'extra': 4},
      'heading': 90,
    },
    2,
    'speed',
    'missing speed',
  ),
  RefusedRow(
    'a sibling missing, the group on through the when',
    groupSibling,
    {
      'mode': 1,
      'g': {'speed': 7},
      'heading': 90,
    },
    1,
    'extra',
    'missing extra',
  ),
  RefusedRow(
    'a top-level group not given',
    anchoredFlags,
    {'a': 1},
    1,
    'b',
    'missing b',
  ),
  RefusedRow(
    'a member out of range',
    anchoredFlags,
    {
      'a': 1,
      'g': {'b': 300},
    },
    1,
    'b',
    '300 does not fit in u8',
  ),
  RefusedRow(
    'a group given a number',
    anchoredFlags,
    {'a': 1, 'g': 5},
    1,
    'g',
    'expected a Map<String, Object?> for group g, got int',
  ),
  RefusedRow(
    'a group given a list',
    anchoredFlags,
    {
      'a': 1,
      'g': <int>[1],
    },
    1,
    'g',
    'expected a Map<String, Object?> for group g, got ',
  ),
  RefusedRow(
    'a group given a Map with other keys',
    anchoredFlags,
    {
      'a': 1,
      'g': <int, int>{1: 2},
    },
    1,
    'g',
    'expected a Map<String, Object?> for group g, got ',
  ),
  RefusedRow(
    'a member given flat (Go-4)',
    anchoredFlags,
    {'a': 1, 'b': 2},
    1,
    'b',
    flat('b', 'g'),
  ),
  RefusedRow(
    'a member given flat under flags (Go-4)',
    siblingAndFlags,
    {'c': 2},
    1,
    'c',
    flat('c', 'g'),
  ),
  RefusedRow(
    'a member of an inner group given flat',
    () => s([
      n(0, 'a'),
      groupOf(1, 'g', [
        groupOf(1, 'h', [n(1, 'x')]),
      ]),
    ]),
    {'a': 1, 'g': <String, Object?>{}, 'x': 5},
    1,
    'x',
    flat('x', 'h'),
  ),
  RefusedRow(
    'a member given flat inside the wrong group',
    () => s([
      n(0, 'a'),
      groupOf(1, 'g', [
        n(1, 'b'),
        groupOf(2, 'h', [n(2, 'x')]),
      ]),
    ]),
    {
      'a': 1,
      'g': {'b': 1, 'x': 5},
    },
    2,
    'x',
    flat('x', 'h'),
  ),
  RefusedRow(
    'a mark given a number',
    () => s([
      flags(0, [groupOf(0, 'mark', [])]),
    ]),
    {'mark': 1},
    0,
    'mark',
    'expected a bool for group mark, got int',
  ),
  RefusedRow(
    "a split bit's when source written after the byte names the group",
    lateSource,
    {
      'mode': 1,
      'g': {'a': 5},
    },
    1,
    'g',
    'g: a value is given, but the condition or count of its when or times is not written before the flag byte',
  ),
];

void main() {
  group('a row pack refuses, naming the field', () {
    for (final r in refusedRows) {
      test('${r.name} is refused and no bytes come back', () {
        // Arrange
        final layout = r.build();

        // Act
        final error = packRefusal(() => pack(layout, r.row));

        // Assert
        expect(error.field, r.field);
        expect(error.name, r.member);
        expect(error.reason, startsWith(r.reason));
      });
    }

    test('the flat key beside the given map is not read', () {
      // Arrange
      final layout = siblingAndFlags();

      // Act
      final nested = pack(layout, {
        'g': {'a': 1, 'c': 2},
      });
      final beside = pack(layout, {
        'g': {'a': 1, 'c': 2},
        'c': 9,
      });

      // Assert
      expect(hex(nested), '0101010102');
      expect(hex(beside), hex(nested));
    });

    test('a split bit whose when source is false drops the group silently', () {
      // Arrange
      final layout = lateSource();

      // Act
      final quiet = pack(layout, {
        'mode': 0,
        'g': {'a': 5},
      });

      // Assert
      expect(hex(quiet), '010000');
    });

    test('a wrong group is refused before any field is written', () {
      // Arrange
      final layout = s([
        n(0, 'a'),
        flags(1, [
          groupOf(1, 'g', [n(1, 'b')]),
        ]),
        n(2, 'z'),
      ]);

      // Act
      final error = packRefusal(
        () => pack(layout, {'a': 1, 'g': 'x', 'z': 300}),
      );

      // Assert
      expect(error.name, 'g');
    });

    test('a group under a false when is checked too', () {
      // Arrange
      final layout = s([
        n(0, 'mode'),
        when(1, eq(0, 1), [
          groupOf(1, 'g', [n(1, 'b')]),
        ]),
      ]);

      // Act
      final error = packRefusal(() => pack(layout, {'mode': 0, 'g': 5}));
      final fine = pack(layout, {'mode': 0});

      // Assert
      expect(error.name, 'g');
      expect(hex(fine), '0100');
    });
  });

  group('a group given to a scheme of typed rows', () {
    test('a group with members refuses a binding of its own', () {
      // Act
      final error = refusal(
        () => rowScheme(1, Cell.new, [
          groupOf(0, 'g', [
            cellInt(0, 'a'),
          ]).bind<Cell>(get: (r) => true, set: (r, v) {}),
        ]),
      );

      // Assert
      expect(error.field, 0);
      expect(error.name, 'g');
      expect(
        error.reason,
        'group g: only a group with no member binds a value; bind its members',
      );
    });

    test('an empty group in a typed scheme needs a binding', () {
      // Act
      final error = refusal(
        () => rowScheme(1, Cell.new, [
          flags(0, [groupOf(0, 'mark', [])]),
        ]),
      );

      // Assert
      expect(error.field, 0);
      expect(error.name, 'mark');
      expect(
        error.reason,
        'mark: a presence mark in a scheme of Cell rows is bound with groupOf(anchor, name, []).bind to a bool',
      );
    });

    test('a member of a group bound to another row type is refused', () {
      // Act
      final error = refusal(
        () => rowScheme(1, Cell.new, [
          groupOf(0, 'g', [
            u8(0, 'a').bind<Other>(get: (r) => r.n, set: (r, v) => r.n = v),
          ]),
        ]),
      );

      // Assert
      expect(error.name, 'a');
      expect(error.reason, "a: bound to Other, but the scheme's row is Cell");
    });
  });
}

class Cell {
  int? a;
  int? b;
  bool? mark;
}

class Other {
  int? n;
}

Field cellInt(int id, String name) => u8(id, name).bind<Cell>(
  get: (r) => name == 'a' ? r.a : r.b,
  set: (r, v) => name == 'a' ? r.a = v : r.b = v,
);
