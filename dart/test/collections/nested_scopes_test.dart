import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';

typedef Row = Map<String, Object?>;

/// Packs [row], checks the bytes are [wire], unpacks them and packs the row
/// read again.
void roundTrip(Scheme<Row> layout, Row row, String wire) {
  final packed = pack(layout, row);
  expect(hex(packed), wire);
  final back = readRow(layout, wire);
  expect(hex(pack(layout, back)), wire);
}

void main() {
  group('the items of a list or dict are rows of their own '
      '(the TypeScript rows of list-element-kinds.test.ts)', () {
    test('list of a nested row of two members', () {
      // Arrange
      final layout = scheme(1, [
        list('pts', nested('p', [u8(0, 'a'), u8(1, 'b')])),
      ]);

      // Act and Assert
      roundTrip(layout, {
        'pts': [
          {'a': 1, 'b': 2},
          {'a': 3, 'b': 4},
        ],
      }, '01020001020304');
    });

    test('dict of a nested row', () {
      // Arrange
      final layout = scheme(1, [
        dict('m', nested('p', [u8(0, 'a'), u8(1, 'b')])),
      ]);

      // Act and Assert
      roundTrip(layout, {
        'm': {
          'y': {'a': 3, 'b': 4},
          'x': {'a': 1, 'b': 2},
        },
      }, '01020002107801020210790304');
    });

    test('list of flags: an item whose members are all absent is one byte', () {
      // Arrange
      final layout = scheme(1, [
        list(
          'pts',
          nested('p', [
            flags(0, [u8(0, 'a'), u16(1, 'b')]),
          ]),
        ),
      ]);

      // Act and Assert
      roundTrip(layout, {
        'pts': [
          {'a': 1},
          <String, Object?>{},
          {'b': 2},
        ],
      }, '010300010100020200');
    });

    test('list of leaf', () {
      // Arrange
      final layout = scheme(1, [list('t', u8(0, 'p'))]);

      // Act and Assert
      roundTrip(layout, {
        't': [1, 2],
      }, '0102000102');
    });

    test('list of list of nested row', () {
      // Arrange
      final layout = scheme(1, [
        list('t', list('u', nested('g', [u8(0, 'a')]))),
      ]);

      // Act and Assert
      roundTrip(layout, {
        't': [
          [
            {'a': 1},
          ],
        ],
      }, '010100010001');
    });

    test('an anchored group inside the element', () {
      // Arrange
      final layout = scheme(1, [
        list(
          't',
          nested('g', [
            u8(0, 'a'),
            groupOf(1, 'q', [u8(1, 'b')]),
          ]),
        ),
      ]);

      // Act and Assert
      roundTrip(layout, {
        't': [
          {
            'a': 1,
            'q': {'b': 2},
          },
        ],
      }, '0101000102');
    });

    test('a when inside the element reads the element, not the row around', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'a'),
        list(
          't',
          nested('g', [
            u8(0, 'a'),
            when(1, eq(0, 1), [u8(1, 'b')]),
          ]),
        ),
      ]);

      // Act and Assert
      roundTrip(layout, {
        'a': 1,
        't': [
          {'a': 1, 'b': 2},
          {'a': 0},
        ],
      }, '01010200010200');
    });

    test('a times inside the element counts by a field of the element', () {
      // Arrange
      final layout = scheme(1, [
        list(
          't',
          nested('g', [
            u8(0, 'a'),
            times(1, 0, [u8(1, 'b')]),
          ]),
        ),
      ]);

      // Act and Assert
      roundTrip(layout, {
        't': [
          {
            'a': 2,
            'b': [3, 4],
          },
        ],
      }, '010100020304');
    });

    test(
      'a split flag byte inside the element is read again for each item',
      () {
        // Arrange
        final m = flagByte('m');
        final layout = scheme(1, [
          list('t', nested('g', [m, m.bit(u8(0, 'c')), m.bit(u16(1, 'd'))])),
        ]);

        // Act and Assert
        roundTrip(layout, {
          't': [
            {'c': 1, 'd': 2},
            {'d': 3},
            <String, Object?>{},
            {'c': 4},
          ],
        }, '01040003010200020300000104');
      },
    );

    test('a count in a nested row is the nested row\'s own: sized', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'n'),
        nested('p', [u8(0, 'len'), sized(1, 'data', 0)]),
      ]);
      final row = <String, Object?>{
        'n': 9,
        'p': {
          'len': 2,
          'data': Uint8List.fromList([5, 6]),
        },
      };

      // Act and Assert
      expect(hex(pack(layout, row)), '0109020506');
      expect(readRow(layout, '0109020506')['p'], row['p']);
    });

    test('a nested row may repeat a name of the row around it', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'a'),
        nested('g', [u8(0, 'a')]),
      ]);

      // Act and Assert
      roundTrip(layout, {
        'a': 1,
        'g': {'a': 2},
      }, '010102');
    });

    test('a nested row under flags is set when it is given', () {
      // Arrange
      final layout = scheme(1, [
        flags(0, [
          nested('g', [u8(0, 'a')]),
          u8(0, 'b'),
        ]),
      ]);

      // Act and Assert
      roundTrip(layout, {
        'g': {'a': 5},
        'b': 6,
      }, '01030506');
      expect(hex(pack(layout, {'b': 6})), '010206');
    });

    test('an empty dictionary is a value; null is no value', () {
      // Arrange
      final layout = scheme(1, [
        flags(0, [dict('m', u8(0, 'v')), list('xs', u8(0, 'x'))]),
      ]);

      // Act
      final empty = pack(layout, {'m': <String, Object?>{}});
      final none = pack(layout, {'m': null});
      final back = readRow(layout, hex(empty));

      // Assert
      expect(hex(empty), '01010000');
      expect(hex(none), '0100');
      expect(back, {'m': <String, Object?>{}});
    });

    test('a list under a when that is false is not written, and not read', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'mode'),
        when(1, eq(0, 1), [list('xs', u8(0, 'x'))]),
      ]);

      // Act
      final off = pack(layout, {
        'mode': 0,
        'xs': [1],
      });
      final on = pack(layout, {
        'mode': 1,
        'xs': [7],
      });

      // Assert
      expect(hex(off), '0100');
      expect(readRow(layout, '0100'), {'mode': 0});
      expect(hex(on), '0101010007');
      expect(readRow(layout, hex(on)), {
        'mode': 1,
        'xs': [7],
      });
    });

    test('lists in a repeat round: one list a round', () {
      // Arrange
      final layout = scheme(1, [
        repeat(0, [u8(0, 'k'), list('xs', u8(0, 'x'))]),
      ]);
      final row = <String, Object?>{
        'k': [1, 2],
        'xs': [
          [5],
          [6, 7],
        ],
      };

      // Act and Assert
      roundTrip(layout, row, '01010100050202000607');
    });

    test('a nested map given once goes to every round', () {
      // Arrange
      final layout = scheme(1, [
        repeat(0, [
          u8(0, 'k'),
          nested('p', [u8(0, 'a')]),
        ]),
      ]);
      final row = <String, Object?>{
        'k': [1, 2],
        'p': {'a': 9},
      };

      // Act
      final wire = pack(layout, row);

      // Assert
      expect(hex(wire), '0101090209');
    });

    test('a lone dictionary for a dict name of a round is refused', () {
      // Arrange
      final layout = scheme(1, [
        repeat(0, [u8(0, 'k'), dict('d', u8(0, 'v'))]),
      ]);

      // Act
      final error = packRefusal(
        () => pack(layout, {
          'k': [1, 2],
          'd': {'a': 1},
        }),
      );

      // Assert
      expect(error.name, 'd');
      expect(error.reason, contains('one dictionary per round'));
    });

    test('one dictionary per round in a list packs', () {
      // Arrange
      final layout = scheme(1, [
        repeat(0, [u8(0, 'k'), dict('d', u8(0, 'v'))]),
      ]);
      final row = <String, Object?>{
        'k': [1, 2],
        'd': [
          {'a': 1},
          {'b': 2},
        ],
      };

      // Act and Assert
      roundTrip(layout, row, '010101000210610102010002106202');
    });
  });
}
