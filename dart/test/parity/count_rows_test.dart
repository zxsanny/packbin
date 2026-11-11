import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import 'parity_support.dart';

// TypeScript table `u64-count.test.ts` (AZ-2308 follow-up, TS-F4): sized,
// packed and times counted by a u64 or an i64. A Dart `int` is exact to
// 2^63 - 1 and a u64 above it is a negative `int`, so the counts TypeScript
// reads as 0 (`needed` 0) are a short read with the count as `needed` (as
// Go) or `bad_value` (a negative count); see parity_differences.md.

typedef Build = Scheme<Row> Function(bool signed);

Field count(bool signed) => signed ? i64(0, 'n') : u64(0, 'n');

final kinds = <(String, Build, String, String, Row)>[
  (
    'sized',
    (s) => scheme(1, [count(s), sized(1, 'p', 0)]),
    '616263',
    'p',
    {
      'n': 3,
      'p': bytesOf([0x61, 0x62, 0x63]),
    },
  ),
  (
    'packed',
    (s) => scheme(1, [count(s), packed(2, 1, 'p', 0)]),
    '24',
    'p',
    {
      'n': 3,
      'p': [0, 1, 2],
    },
  ),
  (
    'times',
    (s) => scheme(1, [
      count(s),
      times(1, 0, [u8(1, 'x')]),
    ]),
    '010203',
    'x',
    {
      'n': 3,
      'x': [1, 2, 3],
    },
  ),
];

const count3 = '0300000000000000';
const count2p53 = '0000000000002000';
const countMax = 'ffffffffffffffff';
const countMaxSafe = 'ffffffffffff1f00';

/// The short read a real count ends in: [name] sized wants the count in
/// bytes, packed (width 2) a quarter of it rounded up, and a times reads its
/// rounds until the buffer ends (one byte short, nothing left).
String shortRead(String name, String field, int n, int leftBytes) {
  final needed = switch (name) {
    'sized' => n,
    'packed' => (n >> 2) + (n & 3 != 0 ? 1 : 0),
    _ => 1,
  };
  return 'short_packet $field $needed ${name == 'times' ? 0 : leftBytes}';
}

String error(Scheme<Row> layout, String wire) {
  final e = unpackRow(unhex(wire), layout).error!;
  return '${e.kind.term} ${e.name} ${e.needed} ${e.left}';
}

void main() {
  group('u64-count', () {
    for (final (name, build, body, field, row) in kinds) {
      final leftBytes = body.length ~/ 2;
      test('AC-1 $name counted by a u64 is unpacked and packed again', () {
        // Arrange
        final layout = build(false);
        final wire = '01$count3$body';

        // Act
        final back = unpackedRow(layout, wire);
        final again = outcome(layout, back);
        final fromRow = outcome(layout, row);

        // Assert
        expect(back['n'], 3);
        expect(again, wire);
        expect(fromRow, wire);
      });

      test(
        'AC-2 $name with a u64 count of 2^53 is a short read, not a throw',
        () {
          // Act
          final got = error(build(false), '01$count2p53$body');

          // Assert
          expect(got, shortRead(name, field, 1 << 53, leftBytes));
        },
      );

      test('AC-2 $name with a u64 count of 2^64 - 1 is bad_value (a negative '
          'int)', () {
        // Act
        final got = error(build(false), '01$countMax$body');

        // Assert
        expect(got, startsWith('bad_value $field'));
      });

      test('AC-2 $name refuses a count past 2^53 on pack', () {
        // Act
        final got = outcome(build(false), {...row, 'n': 1 << 53});

        // Assert
        expect(got, startsWith('refused: '));
      });

      for (final (label, wire, realCount) in <(String, String, int?)>[
        ('-1', countMax, null),
        ('i64 min', '0000000000000080', null),
        ('2^63-1', 'ffffffffffffff7f', 0x7fffffffffffffff),
      ]) {
        test('TS-F4 $name counted by an i64 of $label is an error value on '
            'unpack', () {
          // Act
          final got = error(build(true), '01$wire$body');

          // Assert
          expect(
            got,
            realCount == null
                ? startsWith('bad_value $field')
                : shortRead(name, field, realCount, leftBytes),
          );
        });
      }

      for (final n in [-1, -(1 << 63), 0x7fffffffffffffff]) {
        test('TS-F4 $name counted by an i64 of $n is a refusal on pack', () {
          // Act
          final got = outcome(build(true), {...row, 'n': n});

          // Assert
          expect(got, startsWith('refused: '));
        });
      }
    }

    test('AC-2 the largest exact count (2^53 - 1) reads as a count, so sized '
        'reports the bytes it lacks', () {
      // Act
      final got = error(kinds[0].$2(false), '01${countMaxSafe}61');

      // Assert
      expect(got, shortRead('sized', 'p', (1 << 53) - 1, 1));
    });
  });
}
