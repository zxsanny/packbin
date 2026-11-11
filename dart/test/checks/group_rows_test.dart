import 'dart:isolate';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/group_schemes.dart';
import '../support/hex.dart';
import '../support/refusal.dart';

/// One map row: the scheme, the row, the hex (the TypeScript packet with the
/// group given as a nested object) and the map unpack gives; null: the row.
final class MapRow {
  MapRow(this.name, this.build, this.row, this.wire, {this.back});
  final String name;
  final Scheme<Row> Function() build;
  final Row row;
  final String wire;
  final Row? back;
}

final mapRows = <MapRow>[
  MapRow(
    'the README group: u8 a; group(g, u8 b)',
    () => s([
      n(0, 'a'),
      groupOf(1, 'g', [n(1, 'b')]),
    ]),
    {
      'a': 1,
      'g': {'b': 2},
    },
    '01 01 02',
  ),
  MapRow(
    'a top-level anchored group',
    () => s([
      groupOf(0, 'g', [n(0, 'a')]),
    ]),
    {
      'g': {'a': 1},
    },
    '01 01',
  ),
  MapRow('presence: group holding only flags', nestedFlags, {
    'g': {'n': 5},
  }, '01 01 01 05'),
  MapRow('presence: group holding only a group', nestedGroup, {
    'g': {
      'h': {'n': 5},
    },
  }, '01 01 05'),
  MapRow('presence: absent nested flags', nestedFlags, {}, '01 00'),
  MapRow('presence: absent nested group', nestedGroup, {}, '01 00'),
  MapRow('presence: sibling and nested value', siblingAndFlags, {
    'g': {'a': 1, 'c': 2},
  }, '01 01 01 01 02'),
  MapRow('presence: an empty map sets the bit', nestedFlags, {
    'g': <String, Object?>{},
  }, '01 01 00'),
  MapRow('nested: flags inside an anchored group', anchoredFlags, {
    'a': 1,
    'g': {'b': 2, 'c': 3},
  }, '01 01 02 01 03'),
  MapRow('nested: flags member left out', anchoredFlags, {
    'a': 1,
    'g': {'b': 2},
  }, '01 01 02 00'),
  MapRow('a group under flags, given', groupUnderFlags, {
    'a': 1,
    'g': {'b': 2, 'c': 3},
  }, '01 01 01 02 01 03'),
  MapRow('a group under flags, not given', groupUnderFlags, {
    'a': 1,
  }, '01 01 00'),
  MapRow('split byte in a group, both bits', splitInGroup, {
    'g': {'c': 3, 'd': 4},
  }, '01 03 03 04 00'),
  MapRow('split byte in a group, one bit', splitInGroup, {
    'g': {'d': 4},
  }, '01 02 04 00'),
  MapRow(
    'a flag byte in a group sees its own bits',
    () => s([
      flags(0, [n(0, 'a')]),
      groupOf(1, 'g', [
        flags(1, [n(1, 'b')]),
      ]),
    ]),
    {
      'g': {'b': 2},
    },
    '01 00 01 02',
  ),
  MapRow('an anchored group shares the scope, other branch', whenBranchGroup, {
    'kind': 1,
    'shape': 300,
  }, '01 01 2c 01'),
  MapRow('an anchored group shares the scope, group branch', whenBranchGroup, {
    'kind': 0,
    'g': {'shape': 5},
  }, '01 00 05'),
  MapRow(
    'a when after a group names its member',
    () => s([
      groupOf(0, 'g', [n(0, 'n')]),
      when(1, eq(0, 1), [n(1, 'v')]),
    ]),
    {
      'g': {'n': 1},
      'v': 7,
    },
    '01 01 07',
  ),
  MapRow('a when inside a group names a member outside it', whenInGroup, {
    'mode': 1,
    'g': {'speed': 7},
    'heading': 90,
  }, '01 01 03 07 5a 00'),
  MapRow(
    'a group is transparent to the flag byte scope',
    flagByteInGroup,
    {'a': 5},
    '01 01 05',
    back: {'a': 5, 'g': <String, Object?>{}},
  ),
  MapRow('a bit is numbered before the bits nested in its group', nestedBit, {
    'g': {'y': 1, 'x': 2},
  }, '01 03 01 02'),
  MapRow('the outer bit alone', nestedBit, {
    'g': {'y': 1},
  }, '01 01 01'),
  MapRow('README late when in a group', lateWhen, {
    'mode': 1,
    'g': {'d': 5, 'a': 9},
  }, '01 01 01 05 09'),
  MapRow(
    'empty group mark set',
    () => s([
      flags(0, [groupOf(0, 'mark', [])]),
    ]),
    {'mark': true},
    '01 01',
  ),
  MapRow(
    'empty group mark false',
    () => s([
      flags(0, [groupOf(0, 'mark', [])]),
    ]),
    {'mark': false},
    '01 00',
    back: {},
  ),
  MapRow(
    'empty group mark on a split bit',
    () {
      final m = flagByte('m');
      return s([m, m.bit(groupOf(0, 'mark', [])), m.bit(n(0, 'n'))]);
    },
    {'mark': true, 'n': 3},
    '01 03 03',
  ),
  MapRow('an empty group as a flags member takes no id: set', markAndN, {
    'mark': true,
    'n': 3,
  }, '01 01 03'),
  MapRow('an empty group as a flags member: not given', markAndN, {
    'n': 3,
  }, '01 00 03'),
  MapRow(
    'an empty group as a flags member: false',
    markAndN,
    {'mark': false, 'n': 3},
    '01 00 03',
    back: {'n': 3},
  ),
  MapRow('when true', whenInGroup, {
    'mode': 1,
    'g': {'speed': 7},
    'heading': 90,
  }, '01 01 03 07 5a 00'),
  MapRow('when false', whenInGroup, {
    'mode': 0,
    'heading': 90,
  }, '01 00 02 5a 00'),
  MapRow('when true without a body', whenInGroup, {
    'mode': 1,
    'heading': 90,
  }, '01 01 02 5a 00'),
  MapRow('only the when', whenInGroup, {
    'mode': 1,
    'g': {'speed': 7},
  }, '01 01 01 07'),
  MapRow(
    'a group given sets its bit although the when is false',
    whenInGroup,
    {
      'mode': 0,
      'g': {'speed': 7},
      'heading': 90,
    },
    '01 00 03 5a 00',
    back: {'mode': 0, 'g': <String, Object?>{}, 'heading': 90},
  ),
  MapRow('a sibling with the when true', groupSibling, {
    'mode': 1,
    'g': {'extra': 4, 'speed': 7},
    'heading': 90,
  }, '01 01 03 04 07 5a 00'),
  MapRow('a sibling with the when false', groupSibling, {
    'mode': 0,
    'g': {'extra': 4},
    'heading': 90,
  }, '01 00 03 04 5a 00'),
  MapRow('a group with nothing in it', groupSibling, {
    'mode': 1,
    'heading': 90,
  }, '01 01 02 5a 00'),
  MapRow(
    'a group inside a group',
    () => s([
      n(0, 'a'),
      groupOf(1, 'g', [
        groupOf(1, 'h', [n(1, 'x')]),
      ]),
    ]),
    {
      'a': 1,
      'g': {
        'h': {'x': 5},
      },
    },
    '01 01 05',
  ),
];

/// Wrong packets and rows over [count] round trips of a group row.
int groupTrips(Scheme<Row> layout, int count) {
  var wrong = 0;
  for (var i = 0; i < count; i++) {
    final raw = pack(layout, {
      'a': 1,
      'g': {'b': 2, 'c': 3},
    });
    final back = unpackRow(raw, layout).row;
    final g = back?['g'];
    if (hex(raw) != '0101020103' ||
        back?['a'] != 1 ||
        g is! Map<String, Object?> ||
        g['b'] != 2 ||
        g['c'] != 3) {
      wrong++;
    }
  }
  return wrong;
}

void main() {
  group('an anchored group is a nested map both ways', () {
    for (final r in mapRows) {
      test('${r.name} packs the TypeScript hex and unpacks to its map', () {
        // Arrange
        final layout = r.build();

        // Act
        final raw = pack(layout, r.row);
        final back = readRow(layout, r.wire);
        final again = pack(layout, back);

        // Assert
        expect(hex(raw), r.wire.replaceAll(' ', ''));
        expect(back, r.back ?? r.row);
        expect(hex(again), r.wire.replaceAll(' ', ''));
      });
    }

    test('a group given as a Map<String, int> is read', () {
      // Arrange
      final layout = anchoredFlags();
      final inner = <String, int>{'b': 2, 'c': 3};

      // Act
      final raw = pack(layout, {'a': 1, 'g': inner});

      // Assert
      expect(hex(raw), '0101020103');
    });

    test('a map built by jsonDecode is a group map', () {
      // Arrange
      final layout = anchoredFlags();
      final row = <String, dynamic>{
        'a': 1,
        'g': <String, dynamic>{'b': 2},
      };

      // Act
      final raw = pack(layout, row);

      // Assert
      expect(hex(raw), '01010200');
    });

    test('a short packet inside a group names the field', () {
      // Arrange
      final layout = anchoredFlags();

      // Act
      final result = unpackRow(unhex('010102'), layout);

      // Assert
      expect(result.row, isNull);
      expect(result.error, isNotNull);
      expect(result.error!.kind, ErrorKind.short);
      expect(
        [result.error!.field, result.error!.needed, result.error!.left],
        [2, 1, 0],
      );
    });

    test('a group read twice by one scheme gives each call its own map', () {
      // Arrange
      final layout = anchoredFlags();

      // Act
      final first = readRow(layout, '0101020103');
      final second = readRow(layout, '01010200');

      // Assert
      expect(first['g'], {'b': 2, 'c': 3});
      expect(second['g'], {'b': 2});
    });

    test('a scheme with a group is used from four isolates', () async {
      // Arrange
      final layout = anchoredFlags();

      // Act
      final wrong = await Future.wait([
        for (var i = 0; i < 4; i++) Isolate.run(() => groupTrips(layout, 2000)),
      ]);

      // Assert
      expect(wrong, [0, 0, 0, 0]);
    });
  });
}
