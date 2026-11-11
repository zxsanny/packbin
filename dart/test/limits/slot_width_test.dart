import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import 'limit_support.dart';

// AZ-4139 AC-2 (DT-5): the width of a round is the number of distinct names
// it can hold, as the README's Untrusted input section counts them, and pack
// and unpack charge it alike.

/// One round shape: its members, the row of [rounds] rounds, and its width.
class Shape {
  Shape(this.label, this.body, this.rows, this.width);

  final String label;
  final List<Field> Function() body;
  final Row Function(int rounds) rows;
  final int width;
}

List<int> ones(int n) => List.filled(n, 1);

List<Row> maps(int n, Row each) => List.generate(n, (_) => each);

final shapes = <Shape>[
  Shape(
    'one slot for each value field',
    () => [u8(0, 'a'), u8(1, 'b'), u8(2, 'c')],
    (n) => {'a': ones(n), 'b': ones(n), 'c': ones(n)},
    3,
  ),
  Shape(
    'a name inside a when counts whether or not the condition holds',
    () => [
      u8(0, 'k'),
      when(1, eq(0, 1), [u8(1, 'v')]),
    ],
    (n) => {'k': List.filled(n, 0)},
    2,
  ),
  Shape(
    'an anchored group: its members, not its own name',
    () => [
      groupOf(0, 'g', [u8(0, 'x'), u8(1, 'y')]),
    ],
    (n) => {
      'g': maps(n, {'x': 1, 'y': 2}),
    },
    2,
  ),
  Shape(
    'a flags: its members, not the flag byte',
    () => [
      flags(0, [u8(0, 'a'), u8(1, 'b')]),
    ],
    (n) => {'a': ones(n), 'b': ones(n)},
    2,
  ),
  Shape(
    'a nested row charges the width of its own members apart from the names around it',
    () => [
      u8(0, 'x'),
      nested('g', [u8(0, 'x'), u8(1, 'y')]),
    ],
    (n) => {
      'x': ones(n),
      'g': maps(n, {'x': 1, 'y': 2}),
    },
    3,
  ),
  Shape(
    'a list and a dict are one slot each however many items they hold',
    () => [list('xs', u8(0, 'e')), dict('m', u8(0, 'e'))],
    (n) => {
      'xs': List.generate(n, (_) => [1, 2, 3]),
      'm': maps(n, {'a': 1, 'b': 2}),
    },
    2,
  ),
  Shape(
    'each slot of a u2 is one',
    () => [
      u2([slot(0, 's0'), slot(1, 's1')]),
    ],
    (n) => {'s0': List.filled(n, 1), 's1': List.filled(n, 2)},
    2,
  ),
  Shape(
    'a split flag byte is no slot, its bit member is one',
    () {
      final fb = flagByte('m');
      return [u8(0, 'k'), fb, fb.bit(u8(1, 'v'))];
    },
    (n) => {'k': ones(n), 'v': ones(n)},
    2,
  ),
  Shape(
    'a name declared by two branches of a when is one slot',
    () => [
      u8(0, 'k'),
      when(1, eq(0, 1), [u8(1, 'v')]),
      when(2, eq(0, 2), [u8(2, 'v')]),
    ],
    (n) => {'k': List.filled(n, 0)},
    2,
  ),
];

void main() {
  group('one width in pack and unpack', () {
    for (final shape in shapes) {
      group(shape.label, () {
        final w = shape.width;
        Scheme<Row> at(int slots) =>
            scheme(1, [repeat(0, shape.body())]).withLimits(maxSlots: slots);

        test('a round of $w slots fits maxSlots $w, a second one does not', () {
          // Arrange
          final layout = at(w);
          final two = pack(at(2 * w), shape.rows(2));

          // Act
          final one = pack(layout, shape.rows(1));
          final packRefused = packError(() => pack(layout, shape.rows(2)));
          final unpackOne = unpackRow(one, layout);
          final unpackTwo = unpackRow(two, layout);

          // Assert
          expect(unpackOne.ok, isTrue);
          expect(
            packRefused,
            contains(
              'the rounds would hold ${2 * w} slots, above the limit of $w slots',
            ),
          );
          expect(unpackTwo.error!.kind, ErrorKind.tooMany);
          expect(unpackTwo.error!.needed, 0);
          expect(
            unpackTwo.error!.reason,
            contains(
              'the rounds would hold ${2 * w} slots, above the limit of $w slots',
            ),
          );
        });

        test('maxSlots ${w - 1} refuses even the first round, on pack and unpack', () {
          // Arrange
          final one = pack(at(w), shape.rows(1));
          final narrow = at(w - 1);

          // Act
          final packRefused = packError(() => pack(narrow, shape.rows(1)));
          final unpackRefused = unpackRow(one, narrow);

          // Assert
          expect(
            packRefused,
            contains(
              'the rounds would hold $w slots, above the limit of ${w - 1} slots',
            ),
          );
          expect(unpackRefused.error!.kind, ErrorKind.tooMany);
          expect(
            unpackRefused.error!.reason,
            contains('the rounds would hold $w slots'),
          );
        });
      });
    }
  });
}

/// The reason of the pack error [body] throws.
String packError(Object Function() body) {
  try {
    body();
  } on PackbinException catch (e) {
    return e.reason;
  }
  fail('the row was packed');
}
