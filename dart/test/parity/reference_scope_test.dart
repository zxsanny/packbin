import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';
import 'parity_support.dart';

// TypeScript table `reference-scope.test.ts`: which field an id names, which
// fields a reference may name, the references a scheme must refuse, and eq
// by value. `eq` values and references are checked when the scheme is built.

/// One scheme the build must refuse, with TypeScript's text.
final class BuildRefusal {
  const BuildRefusal(this.id, this.build, this.reason);
  final String id;
  final Scheme<Row> Function() build;
  final String reason;
}

String notDeclared(String lead, int id) =>
    '$lead names field id $id, which is not declared earlier in the same scope';

final refusals = <BuildRefusal>[
  BuildRefusal(
    'an eq naming a sized field is a scheme error',
    () => scheme(1, [
      u8(0, 'n'),
      sized(1, 'p', 0),
      when(2, eq(1, 1), [u8(2, 'v')]),
    ]),
    'when 2: eq names field id 1 (p), which is not an integer or a bool',
  ),
  BuildRefusal(
    'an eq naming a bits field is a scheme error',
    () => scheme(1, [
      u8(0, 'n'),
      bits(1, 'p', 0),
      when(2, eq(1, 1), [u8(2, 'v')]),
    ]),
    'when 2: eq names field id 1 (p), which is not an integer or a bool',
  ),
  BuildRefusal(
    'an eq naming a packed field is a scheme error',
    () => scheme(1, [
      u8(0, 'n'),
      packed(1, 1, 'p', 0),
      when(2, eq(1, 1), [u8(2, 'v')]),
    ]),
    'when 2: eq names field id 1 (p), which is not an integer or a bool',
  ),
  BuildRefusal(
    'when naming a later field is a scheme error',
    () => scheme(1, [
      when(0, eq(1, 5), [u8(0, 'a')]),
      u8(1, 'k'),
    ]),
    'when 0: ${notDeclared('eq', 1)}',
  ),
  BuildRefusal(
    'unknown reference id is a scheme error',
    () => scheme(1, [
      u8(0, 'k'),
      when(1, eq(9, 5), [u8(1, 'a')]),
    ]),
    'when 1: ${notDeclared('eq', 9)}',
  ),
  BuildRefusal(
    'count naming itself in an element is a scheme error',
    () => scheme(1, [
      u8(0, 'n'),
      list('xs', nested('x', [sized(0, 'p', 0)])),
    ]),
    'sized 0: ${notDeclared('count', 0)}',
  ),
  BuildRefusal(
    'count naming itself in a dict element is a scheme error',
    () => scheme(1, [
      u8(0, 'n'),
      dict('d', nested('x', [sized(0, 'p', 0)])),
    ]),
    'sized 0: ${notDeclared('count', 0)}',
  ),
  BuildRefusal(
    'count naming a field inside an earlier times is a scheme error',
    () => scheme(1, [
      u8(0, 'c'),
      times(1, 0, [u8(1, 'n')]),
      sized(2, 'p', 1),
    ]),
    'sized 2: ${notDeclared('count', 1)}',
  ),
  BuildRefusal(
    'when in a times body naming a field outside it is a scheme error',
    () => scheme(1, [
      u8(0, 'n'),
      times(1, 0, [
        when(1, eq(0, 1), [u8(1, 'v')]),
      ]),
    ]),
    'when 1: ${notDeclared('eq', 0)}',
  ),
  BuildRefusal(
    'when in a repeat body naming a field outside it is a scheme error',
    () => scheme(1, [
      u8(0, 'mode'),
      repeat(1, [
        u8(1, 'a'),
        when(2, eq(0, 1), [u8(2, 'b')]),
      ]),
    ]),
    'when 2: ${notDeclared('eq', 0)}',
  ),
  BuildRefusal(
    'when in a nested group naming a field outside it is a scheme error',
    () => scheme(1, [
      u8(0, 'k'),
      u8(1, 'j'),
      nested('g', [
        u8(0, 'a'),
        when(1, eq(1, 1), [u8(1, 'b')]),
      ]),
    ]),
    'when 1: ${notDeclared('eq', 1)}',
  ),
  BuildRefusal(
    'when naming its own body is a scheme error',
    () => scheme(1, [
      when(0, eq(0, 1), [u8(0, 'a')]),
    ]),
    'when 0: ${notDeclared('eq', 0)}',
  ),
  BuildRefusal(
    'count naming a bool is a scheme error',
    () => scheme(1, [
      flags(0, [flagBool(0, 'on')]),
      times(1, 0, [u8(1, 'v')]),
    ]),
    'times 1: count names field id 0 (on), which is not an integer',
  ),
  BuildRefusal(
    'count naming a float is a scheme error',
    () => scheme(1, [f32(0, 'n'), sized(1, 'p', 0)]),
    'sized 1: count names field id 0 (n), which is not an integer',
  ),
  for (final (label, value, shown) in <(String, Object, String)>[
    ('true', true, 'true'),
    ('"1"', '1', '"1"'),
    ('[1]', [1], 'a List<int>'),
  ])
    BuildRefusal(
      'eq $label on an integer field is a scheme error',
      () => scheme(1, [
        u8(0, 'k'),
        when(1, eq(0, value), [u8(1, 'v')]),
      ]),
      "when 1 tests u8 field 0 ('k') against $shown; the value must be a "
          'whole number from 0 to 255',
    ),
];

Scheme<Row> withU64(int want) => scheme(1, [
  u64(0, 'k'),
  when(1, eq(0, want), [u8(1, 'v')]),
]);

Scheme<Row> nestedWhen() => scheme(1, [
  u8(0, 'kind'),
  nested('g', [
    u8(0, 'inner'),
    when(1, eq(0, 5), [u8(1, 'extra')]),
  ]),
]);

final rows = <ParityRow>[
  ParityRow('when in a nested group uses the group\'s ids: apart', nestedWhen, {
    'kind': 5,
    'g': {'inner': 9, 'extra': 7},
  }, const Pin.wire('010509')),
  ParityRow(
    'when in a nested group uses the group\'s ids: same',
    nestedWhen,
    {
      'kind': 5,
      'g': {'inner': 5, 'extra': 7},
    },
    const Pin.wire('01050507'),
    roundTrip: true,
  ),
  ParityRow(
    'a count names a field inside an earlier when',
    () => scheme(1, [
      u8(0, 'k'),
      when(1, eq(0, 1), [u8(1, 'n')]),
      sized(2, 'p', 1),
    ]),
    {
      'k': 1,
      'n': 1,
      'p': bytesOf([7]),
    },
    const Pin.wire('01010107'),
    roundTrip: true,
  ),
  ParityRow(
    'a count names a field inside an earlier flags',
    () => scheme(1, [
      flags(0, [u8(0, 'n')]),
      sized(1, 'p', 0),
    ]),
    {
      'n': 1,
      'p': bytesOf([7]),
    },
    const Pin.wire('01010107'),
    roundTrip: true,
  ),
  ParityRow(
    'a count names a field inside an earlier anchored group',
    () => scheme(1, [
      groupOf(0, 'g', [u8(0, 'n')]),
      sized(1, 'p', 0),
    ]),
    {
      'g': {'n': 1},
      'p': bytesOf([7]),
    },
    const Pin.wire('010107'),
    roundTrip: true,
  ),
  ParityRow(
    'a u2 slot is an integer a count and an eq can name',
    () => scheme(1, [
      u2([slot(0, 'a'), slot(1, 'b')]),
      sized(2, 'p', 0),
      when(3, eq(1, 1), [u8(3, 'v')]),
    ]),
    {
      'a': 2,
      'b': 1,
      'p': bytesOf([7, 8]),
      'v': 9,
    },
    const Pin.wire('0106070809'),
    roundTrip: true,
  ),
  ParityRow(
    'u64 when matches on unpack',
    () => withU64(1),
    {'k': 1, 'v': 9},
    const Pin.wire('01010000000000000009'),
    roundTrip: true,
  ),
  ParityRow(
    'a u64 value that differs from eq leaves the group out',
    () => withU64(1),
    {'k': 2, 'v': 9},
    const Pin.wire('010200000000000000'),
    back: {'k': 2},
  ),
  ParityRow(
    'a bool eq value still needs true: on',
    () => scheme(1, [
      flags(0, [flagBool(0, 'on')]),
      when(1, eq(0, true), [u16(1, 'v')]),
    ]),
    {'on': true, 'v': 3},
    const Pin.wire('01010300'),
    roundTrip: true,
  ),
  ParityRow(
    'a bool eq value still needs true: off',
    () => scheme(1, [
      flags(0, [flagBool(0, 'on')]),
      when(1, eq(0, true), [u16(1, 'v')]),
    ]),
    {'on': false},
    const Pin.wire('0100'),
  ),
];

void main() {
  group('reference-scope: references the scheme must refuse', () {
    final ids = <String>{};
    for (final r in refusals) {
      if (!ids.add(r.id)) fail('duplicate row id ${r.id}');
      test(r.id, () {
        // Act
        final error = refusal(r.build);

        // Assert
        expect(
          error.reason,
          r.reason,
          reason: 'the refusal text; the Dart type words follow the Dart type',
        );
      });
    }
  });

  group('reference-scope: which field an id names', () {
    runParity(rows);

    test(
      'when in a nested group is read from the group\'s field on unpack',
      () {
        // Arrange
        final layout = nestedWhen();

        // Act
        final same = unpackedRow(layout, '01050507');
        final apart = unpackedRow(layout, '010509');

        // Assert
        expect((same['g']! as Row)['extra'], 7);
        expect((apart['g']! as Row).containsKey('extra'), isFalse);
      },
    );

    test('a field object shared by two schemes binds in each scheme on its '
        'own', () {
      // Arrange
      final payload = sized(1, 'p', 0);
      final first = scheme(1, [u8(0, 'n'), payload]);
      final second = scheme(2, [u8(0, 'm'), payload]);

      // Act
      final a = outcome(first, {
        'n': 2,
        'p': bytesOf([1, 2]),
      });
      final b = outcome(second, {
        'm': 1,
        'p': bytesOf([9]),
      });

      // Assert
      expect([a, b], ['01020102', '020109']);
    });

    test('a when in a repeat body names a field of the same round', () {
      // Arrange
      final layout = scheme(1, [
        repeat(0, [
          u8(0, 'k'),
          when(1, eq(0, 1), [u8(1, 'v')]),
        ]),
      ]);

      // Act
      final row = unpackedRow(layout, '01010700');

      // Assert
      expect(row['k'], [1, 0]);
      expect(row['v'], [7, null]);
    });

    test('eq compares integers by value: the 64-bit value of a u64', () {
      // Arrange
      final layout = withU64(1);

      // Act
      final back = unpackRow(unhex('01010000000000000009'), layout).row!;

      // Assert
      expect(back, {'k': 1, 'v': 9});
    });
  });
}
