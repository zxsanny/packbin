import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';

void main() {
  group('rounds under flags', () {
    test('a repeat refuses a short non-empty list under flags', () {
      // Arrange
      final layout = scheme(1, [
        repeat(0, [
          u8(0, 'w'),
          flags(1, [u8(1, 'v')]),
        ]),
      ]);

      // Act
      final error = packRefusal(
        () => pack(layout, {
          'w': [1, 2],
          'v': [5],
        }),
      );

      // Assert
      expect(
        [error.name, error.reason],
        ['v', contains('1 items, repeat count 2')],
      );
    });

    test(
      'a repeat takes a null entry under flags and a times a short list',
      () {
        // Arrange
        final inRepeat = scheme(1, [
          repeat(0, [
            u8(0, 'w'),
            flags(1, [u8(1, 'v')]),
          ]),
        ]);
        final inTimes = scheme(1, [
          u8(0, 'c'),
          times(1, 0, [
            flags(1, [u8(1, 'v')]),
          ]),
        ]);

        // Act
        final a = pack(inRepeat, {
          'w': [1, 2],
          'v': [5, null],
        });
        final b = pack(inTimes, {
          'c': 2,
          'v': [5],
        });

        // Assert
        expect([hex(a), hex(b)], ['010101050200', '0102010500']);
      },
    );

    test('flags with a times or a repeat member', () {
      // Arrange
      final timesLayout = scheme(1, [
        u8(0, 'n'),
        flags(1, [
          times(1, 0, [u8(1, 'pt')]),
          u16(2, 'heading'),
        ]),
      ]);
      final repeatLayout = scheme(1, [
        u8(0, 'mode'),
        flags(1, [
          u16(1, 'heading'),
          repeat(2, [u8(2, 'pt')]),
        ]),
      ]);

      // Act
      final wires = [
        hex(pack(timesLayout, {'n': 0, 'pt': <int>[], 'heading': 90})),
        hex(
          pack(timesLayout, {
            'n': 1,
            'pt': [5],
            'heading': 90,
          }),
        ),
        hex(
          pack(timesLayout, {
            'n': 2,
            'pt': [5, 6],
            'heading': 90,
          }),
        ),
        hex(pack(repeatLayout, {'mode': 1, 'heading': 90})),
        hex(
          pack(repeatLayout, {
            'mode': 1,
            'heading': 90,
            'pt': [5],
          }),
        ),
        hex(
          pack(repeatLayout, {
            'mode': 1,
            'heading': 90,
            'pt': [5, 6],
          }),
        ),
      ];

      // Assert
      expect(wires, [
        '0100025a00',
        '010103055a00',
        '01020305065a00',
        '0101015a00',
        '0101035a0005',
        '0101035a000506',
      ]);
    });

    test('the same packets unpack to the rows they came from', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'n'),
        flags(1, [
          times(1, 0, [u8(1, 'pt')]),
          u16(2, 'heading'),
        ]),
      ]);

      // Act
      final row = unpackRow(unhex('01020305065a00'), layout).row!;

      // Assert
      expect(row, {
        'n': 2,
        'pt': [5, 6],
        'heading': 90,
      });
    });

    test('a split flag byte before the count refuses the times value it would drop', () {
      // Arrange
      final m = flagByte('m');
      final layout = scheme(1, [
        m,
        u8(0, 'n'),
        m.bit(times(1, 0, [u8(1, 'pt')])),
      ]);

      // Act
      final error = packRefusal(
        () => pack(layout, {
          'n': 1,
          'pt': [4],
        }),
      );

      // Assert
      expect(error.reason, contains('not written before the flag byte'));
    });

    test('a combined flags refuses a times value whose count is unwritten', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'mode'),
        when(1, eq(0, 1), [u8(1, 'c')]),
        flags(2, [
          times(2, 1, [u8(2, 'pt')]),
          u16(3, 'heading'),
        ]),
      ]);

      // Act
      final error = packRefusal(
        () => pack(layout, {
          'mode': 0,
          'pt': [4],
          'heading': 90,
        }),
      );

      // Assert
      expect(error.name, 'pt');
    });
  });
}
