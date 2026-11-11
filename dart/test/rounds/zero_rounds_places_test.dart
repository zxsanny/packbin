import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

// AL-6 (loop 100): a map row unpacked from a packet with 0 rounds has no key
// for the names of the round, wherever the round stands; a group or nested
// map that holds only such rounds stays as `{}`. Each canonical packet packs
// again to the same bytes. The 15 places and the TypeScript results were read
// by running typescript/src/index.ts (TypeScript's flat groups show no key at
// all; Dart keeps the group's own key, Go-4).

typedef Row = Map<String, Object?>;

/// A place: the scheme, the packet, the row unpack gives.
typedef Place = (Scheme<Row> Function(), String, Row);

Scheme<Row> flagged(List<Field> Function(FlagByte byte) fields) {
  final byte = flagByte('m');
  return scheme(1, fields(byte));
}

final places = <String, Place>{
  'a repeat of 0 rounds': (
    () => scheme(1, [
      repeat(0, [u8(0, 'a'), u8(1, 'b')]),
    ]),
    '01',
    <String, Object?>{},
  ),
  'b times with count 0': (
    () => scheme(1, [
      u8(0, 'n'),
      times(1, 0, [u8(1, 'a'), u8(2, 'b')]),
      u8(3, 'tail'),
    ]),
    '010007',
    {'n': 0, 'tail': 7},
  ),
  'c1 times in an anchored group': (
    () => scheme(1, [
      u8(0, 'n'),
      groupOf(1, 'g', [
        times(1, 0, [u8(1, 'a')]),
      ]),
      u8(2, 'tail'),
    ]),
    '010007',
    {'n': 0, 'g': <String, Object?>{}, 'tail': 7},
  ),
  'c2 repeat in an anchored group': (
    () => scheme(1, [
      u8(0, 'n'),
      groupOf(1, 'g', [
        repeat(1, [u8(1, 'a')]),
      ]),
    ]),
    '0100',
    {'n': 0, 'g': <String, Object?>{}},
  ),
  'c3 times in a nested row': (
    () => scheme(1, [
      u8(0, 'z'),
      nested('g', [
        u8(0, 'n'),
        times(1, 0, [u8(1, 'a')]),
      ]),
      u8(1, 'tail'),
    ]),
    '01010007',
    {
      'z': 1,
      'g': {'n': 0},
      'tail': 7,
    },
  ),
  'c4 repeat in a nested row': (
    () => scheme(1, [
      u8(0, 'z'),
      nested('g', [
        repeat(0, [u8(0, 'a')]),
      ]),
    ]),
    '0101',
    {'z': 1, 'g': <String, Object?>{}},
  ),
  'c5 times under a when that holds': (
    () => scheme(1, [
      u8(0, 'k'),
      when(1, eq(0, 1), [
        u8(1, 'n'),
        times(2, 1, [u8(2, 'a')]),
      ]),
      u8(3, 'tail'),
    ]),
    '01010007',
    {'k': 1, 'n': 0, 'tail': 7},
  ),
  'c6 repeat under a when that holds': (
    () => scheme(1, [
      u8(0, 'k'),
      when(1, eq(0, 1), [
        repeat(1, [u8(1, 'a')]),
      ]),
    ]),
    '0101',
    {'k': 1},
  ),
  'c7 times under flags': (
    () => scheme(1, [
      u8(0, 'n'),
      flags(1, [
        times(1, 0, [u8(1, 'a')]),
        u8(2, 'h'),
      ]),
    ]),
    '01000209',
    {'n': 0, 'h': 9},
  ),
  'c8 repeat under flags': (
    () => scheme(1, [
      u8(0, 'm'),
      flags(1, [
        u8(1, 'h'),
        repeat(2, [u8(2, 'a')]),
      ]),
    ]),
    '01010109',
    {'m': 1, 'h': 9},
  ),
  'c9 times under a split flag bit': (
    () => flagged(
      (b) => [
        u8(0, 'n'),
        b,
        b.bit(times(1, 0, [u8(1, 'a')])),
        b.bit(u8(2, 'h')),
      ],
    ),
    '01000209',
    {'n': 0, 'h': 9},
  ),
  'c10 repeat under a split flag bit': (
    () => flagged(
      (b) => [
        u8(0, 'm'),
        b,
        b.bit(u8(1, 'h')),
        b.bit(repeat(2, [u8(2, 'a')])),
      ],
    ),
    '01010109',
    {'m': 1, 'h': 9},
  ),
  'c11 times in a list element': (
    () => scheme(1, [
      list(
        'xs',
        nested('it', [
          u8(0, 'n'),
          times(1, 0, [u8(1, 'a')]),
        ]),
      ),
    ]),
    '010200000105',
    {
      'xs': [
        {'n': 0},
        {
          'n': 1,
          'a': [5],
        },
      ],
    },
  ),
  'c12 a when inside a group': (
    () => scheme(1, [
      u8(0, 'k'),
      groupOf(1, 'g', [
        when(1, eq(0, 1), [
          u8(1, 'n'),
          times(2, 1, [u8(2, 'a')]),
        ]),
      ]),
    ]),
    '010100',
    {
      'k': 1,
      'g': {'n': 0},
    },
  ),
  'c13 a group under flags with its bit clear': (
    () => scheme(1, [
      u8(0, 'n'),
      flags(1, [
        groupOf(1, 'g', [
          times(1, 0, [u8(1, 'a')]),
        ]),
        u8(2, 'h'),
      ]),
    ]),
    '01000209',
    {'n': 0, 'h': 9},
  ),
};

void main() {
  group('0 rounds in a map row', () {
    places.forEach((name, place) {
      final (build, packet, expected) = place;
      test('$name: no round key, and the packet packs again', () {
        // Arrange
        final s = build();

        // Act
        final got = unpackRow(unhex(packet), s);
        final again = pack(s, got.row!);

        // Assert
        expect(got.row, expected);
        expect(hex(again), packet);
      });
    });

    test(
      'c7, c8 and c13: a set bit over 0 rounds is read as TypeScript reads it',
      () {
        // Arrange: the bit is set but the count is 0, so pack never writes it
        final c7 = places['c7 times under flags']!.$1();
        final c8 = places['c8 repeat under flags']!.$1();
        final c13 = places['c13 a group under flags with its bit clear']!.$1();

        // Act
        final seven = unpackRow(unhex('01000309'), c7);
        final eight = unpackRow(unhex('01010309'), c8);
        final thirteen = unpackRow(unhex('01000309'), c13);

        // Assert: the first two repack with the bit cleared, as TypeScript does
        expect(seven.row, {'n': 0, 'h': 9});
        expect(hex(pack(c7, seven.row!)), '01000209');
        expect(eight.row, {'m': 1, 'h': 9});
        expect(hex(pack(c8, eight.row!)), '01010109');
        // The group is given, so its bit is set (TypeScript has no g key here)
        expect(thirteen.row, {'n': 0, 'g': <String, Object?>{}, 'h': 9});
        expect(hex(pack(c13, thirteen.row!)), '01000309');
      },
    );

    test('a map row holds no key for either name of the round', () {
      // Arrange
      final s = places['b times with count 0']!.$1();

      // Act
      final map = unpackRow(unhex('010007'), s).row!;

      // Assert: the typed rows keep their empty list (typed_rounds_test.dart)
      expect(map.containsKey('a'), isFalse);
      expect(map.containsKey('b'), isFalse);
    });
  });
}
