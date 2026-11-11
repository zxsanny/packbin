import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';

Uint8List b(List<int> v) => Uint8List.fromList(v);

void main() {
  group('rows of a round in the map form: one list per name', () {
    test(
      'a lone value goes to every round and the longest list sets the count',
      () {
        // Arrange
        final layout = scheme(1, [
          repeat(0, [u8(0, 'a'), u8(1, 'b')]),
        ]);

        // Act
        final raw = pack(layout, {
          'a': [1, 2],
          'b': 7,
        });

        // Assert
        expect(hex(raw), '0101070207');
      },
    );

    test(
      'a null entry leaves the name out of that round and unpacks as null',
      () {
        // Arrange
        final layout = scheme(1, [
          repeat(0, [
            u8(0, 'k'),
            when(1, eq(0, 1), [u8(1, 'v')]),
          ]),
        ]);
        final row = {
          'k': [1, 2, 1],
          'v': [9, null, 4],
        };

        // Act
        final raw = pack(layout, row);
        final back = unpackRow(raw, layout).row!;

        // Assert
        expect(hex(raw), '010109020104');
        expect(back, row);
      },
    );

    test('a list shorter than the rounds under a when is read as absent', () {
      // Arrange
      final layout = scheme(1, [
        repeat(0, [
          u8(0, 'k'),
          when(1, eq(0, 1), [u8(1, 'v')]),
        ]),
      ]);

      // Act
      final raw = pack(layout, {
        'k': [1, 2],
        'v': [9],
      });

      // Assert
      expect(hex(raw), '01010902');
    });

    test('a times list longer than the count is refused naming the name', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'n'),
        times(1, 0, [u8(1, 'x')]),
      ]);

      // Act
      final error = packRefusal(
        () => pack(layout, {
          'n': 2,
          'x': [1, 2, 3],
        }),
      );

      // Assert
      expect(
        [error.name, error.reason],
        ['x', contains('3 items, times count 2')],
      );
    });

    test('a times without an entry for a plain member is a missing value', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'n'),
        times(1, 0, [u8(1, 'x')]),
      ]);

      // Act
      final error = packRefusal(
        () => pack(layout, {
          'n': 2,
          'x': [1],
        }),
      );

      // Assert
      expect(error.name, 'x');
    });

    test(
      'a lone byte buffer in a round is refused: give a list of buffers',
      () {
        // Arrange
        final layout = scheme(1, [
          u8(0, 'n'),
          times(1, 0, [u8(1, 'len'), sized(2, 'p', 1)]),
        ]);

        // Act
        final error = packRefusal(
          () => pack(layout, {
            'n': 2,
            'len': 1,
            'p': b([9]),
          }),
        );

        // Assert
        expect(
          [error.name, error.reason],
          ['p', contains('one buffer per round')],
        );
      },
    );

    test(
      'a buffer per round in a list packs, and a count in the round counts',
      () {
        // Arrange
        final layout = scheme(1, [
          u8(0, 'n'),
          times(1, 0, [u8(1, 'len'), sized(2, 'p', 1)]),
        ]);
        final row = {
          'n': 2,
          'len': [1, 2],
          'p': [
            b([9]),
            b([8, 7]),
          ],
        };

        // Act
        final raw = pack(layout, row);
        final back = unpackRow(raw, layout).row!;

        // Assert
        expect(hex(raw), '01020109020807');
        expect(back['len'], [1, 2]);
        expect(back['p'], [
          [9],
          [8, 7],
        ]);
      },
    );

    test('a count read in one round is not seen by the next round', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'n'),
        times(1, 0, [
          u8(1, 'flag'),
          when(2, eq(1, 1), [u8(2, 'len')]),
          bits(3, 'v', 2),
        ]),
      ]);

      // Act: round 1 has len 1 and one bit; round 2 skips len, so its bits have no count
      final error = unpackRow(unhex('01 02 01 01 01  00 ff'), layout).error!;

      // Assert
      expect([error.name, error.needed], ['v', 0]);
    });

    test('pack does not carry a count from one round into the next', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'n'),
        times(1, 0, [
          u8(1, 'flag'),
          when(2, eq(1, 1), [u8(2, 'len')]),
          bits(3, 'v', 2),
        ]),
      ]);
      final row = {
        'n': 2,
        'flag': [1, 0],
        'len': [1, null],
        'v': [
          [1],
          [1],
        ],
      };

      // Act
      final error = packRefusal(() => pack(layout, row));

      // Assert
      expect(
        [error.name, error.reason],
        ['v', contains('count len was not written')],
      );
    });

    test('a group in a round takes one map a round', () {
      // Arrange
      final layout = scheme(1, [
        repeat(0, [
          u8(0, 'k'),
          groupOf(1, 'mark', [u8(1, 'v')]),
        ]),
      ]);
      final row = {
        'k': [1, 2],
        'mark': [
          {'v': 7},
          {'v': 8},
        ],
      };

      // Act
      final raw = pack(layout, row);
      final back = unpackRow(raw, layout).row!;

      // Assert
      expect(hex(raw), '0101070208');
      expect(back, row);
    });

    test('a group that is not a map in a round is refused', () {
      // Arrange
      final layout = scheme(1, [
        repeat(0, [
          u8(0, 'k'),
          groupOf(1, 'mark', [u8(1, 'v')]),
        ]),
      ]);

      // Act
      final error = packRefusal(
        () => pack(layout, {
          'k': [1],
          'mark': [5],
        }),
      );

      // Assert
      expect(error.name, 'mark');
    });

    test('two-bit slots, bits and packed are lists per round', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'n'),
        times(1, 0, [
          u2([slot(1, 'a'), slot(2, 'b')]),
          u8(3, 'c'),
          bits(4, 'v', 3),
        ]),
      ]);
      final row = {
        'n': 2,
        'a': [1, 2],
        'b': [3, 0],
        'c': [3, 1],
        'v': [
          [1, 0, 1],
          [1],
        ],
      };

      // Act: round 1 slots 1 and 3 give 0d, c 3, bits 101 give 05
      final raw = pack(layout, row);
      final back = unpackRow(raw, layout).row;

      // Assert: round 2 has a 1-bit list whose count c is 1
      expect(hex(raw), '01020d0305020101');
      expect(back, row);
    });

    test('a name set after skipped rounds still has one entry per round', () {
      // Arrange
      final layout = scheme(1, [
        repeat(0, [
          u8(0, 'k'),
          when(1, eq(0, 2), [u8(1, 'v')]),
        ]),
      ]);

      // Act
      final back = unpackRow(unhex('01 01 01 02 05'), layout).row!;

      // Assert
      expect(back, {
        'k': [1, 1, 2],
        'v': [null, null, 5],
      });
    });
  });

  group('a group map given once', () {
    Scheme<Map<String, Object?>> grouped() => scheme(1, [
      repeat(0, [
        u8(0, 'k'),
        groupOf(1, 'g', [u8(1, 'v'), bytes(2, 'raw', 1)]),
      ]),
    ]);

    test('a lone group of scalars goes to every round', () {
      // Arrange
      final layout = scheme(1, [
        repeat(0, [
          u8(0, 'k'),
          groupOf(1, 'g', [u8(1, 'v')]),
        ]),
      ]);

      // Act
      final raw = pack(layout, {
        'k': [1, 2],
        'g': {'v': 7},
      });

      // Assert
      expect(hex(raw), '0101070207');
    });

    test('a lone group that holds a byte buffer is refused', () {
      // Arrange
      final layout = grouped();

      // Act
      final error = packRefusal(
        () => pack(layout, {
          'k': [1, 2],
          'g': {
            'v': 7,
            'raw': b([1]),
          },
        }),
      );

      // Assert
      expect(error.name, 'raw');
    });

    test('a group per round that holds a byte buffer packs', () {
      // Arrange
      final layout = grouped();

      // Act
      final raw = pack(layout, {
        'k': [1, 2],
        'g': [
          {
            'v': 7,
            'raw': b([1]),
          },
          {
            'v': 8,
            'raw': b([2]),
          },
        ],
      });

      // Assert
      expect(hex(raw), '01010701020802');
    });
  });
}
