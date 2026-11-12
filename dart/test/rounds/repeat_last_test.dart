import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';
import '../support/repeat_last.dart';

// AZ-4217, contract repeat-last 1.0.1: a repeat is the last thing a packet
// reads. A scheme that breaks the rule is refused when it is built; a repeat
// that is last builds and packs the bytes it packed before. These are the
// schemes of map rows; the typed rows are in repeat_last_typed_test.dart.

/// The element row of the list and dict cases: `u8 mode; repeat { u8 v }`.
NestedField<Row> modeThenRepeat() => nested('item', [u8(0, 'mode'), rounds(1)]);

// The refused cases R1 to R9 of the contract.
final List<Refused> contractCases = [
  (
    name: 'R1 a field after the repeat',
    fields: () => [rounds(0), u8(1, 'x')],
    text: followedText(0, 'x'),
  ),
  (
    name: 'R2 a field after the when that holds the repeat',
    fields: () => [
      u8(0, 'k'),
      when(1, eq(0, 1), [rounds(1)]),
      u8(2, 'x'),
    ],
    text: followedText(1, 'x'),
  ),
  (
    name: 'R3 a field after the flags that holds the repeat',
    fields: () => [
      flags(0, [rounds(0)]),
      u8(1, 'x'),
    ],
    text: followedText(0, 'x'),
  ),
  (
    name: 'R4 a field after the nested row that holds the repeat',
    fields: () => [
      nested('m', [rounds(0)]),
      u8(0, 'x'),
    ],
    text: followedText(0, 'x'),
  ),
  (
    name: 'R4 a field after the anchored group that holds the repeat',
    fields: () => [
      groupOf(0, 'm', [rounds(0)]),
      u8(1, 'x'),
    ],
    text: followedText(0, 'x'),
  ),
  (
    name: 'R5 a second repeat',
    fields: () => [
      rounds(0),
      repeat(1, [u8(1, 'w')]),
    ],
    text: followedText(0, 'repeat 1'),
  ),
  (
    name: 'R6 a field under a when that cannot hold with the repeat\'s when',
    fields: () => [
      u8(0, 'k'),
      when(1, eq(0, 1), [rounds(1)]),
      when(2, eq(0, 2), [u8(2, 'x')]),
    ],
    text: followedText(1, 'x'),
  ),
  (
    name: 'R7 a repeat in a list element',
    fields: () => [list('items', modeThenRepeat())],
    text: inElementText(1),
  ),
  (
    name: 'R8 a repeat in a dict element',
    fields: () => [dict('d', modeThenRepeat())],
    text: inElementText(1),
  ),
  (
    name: 'R9 a repeat in a times round keeps the text of the nesting rule',
    fields: () => [
      u8(0, 'k'),
      times(1, 0, [rounds(1)]),
    ],
    text: nestingText(1),
  ),
];

/// A scheme that builds, the row it packs, and the packet.
typedef Kept = ({
  String name,
  Scheme<Row> Function() build,
  Row row,
  String packet,
});

// AC-2: the cases K1 to K5 of the contract.
final List<Kept> kept = [
  (
    name: 'K1 a repeat after a field',
    build: () => scheme(1, [u8(0, 'x'), rounds(1)]),
    row: {
      'x': 9,
      'v': [5, 6],
    },
    packet: '01090506',
  ),
  (
    name: 'K2 a repeat that is the last thing in a when that nothing follows',
    build: () => scheme(1, [
      u8(0, 'k'),
      when(1, eq(0, 1), [rounds(1)]),
    ]),
    row: {
      'k': 1,
      'v': [5, 6],
    },
    packet: '01010506',
  ),
  (
    name: 'K3 a repeat that is the last member of a flags that nothing follows',
    build: () => scheme(1, [
      flags(0, [u8(0, 'x'), rounds(1)]),
    ]),
    row: {
      'x': 9,
      'v': [5, 6],
    },
    packet: '0103090506',
  ),
  (
    name: 'K4 a times with a field after it',
    build: () => scheme(1, [
      u8(0, 'k'),
      times(1, 0, [u8(1, 'v')]),
      u8(2, 'x'),
    ]),
    row: {
      'k': 2,
      'v': [5, 6],
      'x': 9,
    },
    packet: '0102050609',
  ),
  (
    name: 'K5 a bool bit of an earlier flag byte after the repeat (split form)',
    build: () {
      final fb = flagByte('fb');
      return scheme(1, [
        fb,
        fb.bit(u8(0, 'x')),
        rounds(1),
        fb.bit(flagBool(2, 'on')),
      ]);
    },
    row: {
      'x': 9,
      'v': [5, 6],
      'on': true,
    },
    packet: '0103090506',
  ),
];

// AC-1 (unit row 2): a field after the repeat that cannot write a byte does
// not count.
final List<Kept> noByteAfter = [
  (
    name: 'a bool member of the flags after the repeat',
    build: () => scheme(1, [
      flags(0, [u8(0, 'x'), rounds(1), flagBool(2, 'on')]),
    ]),
    row: {
      'x': 9,
      'v': [5, 6],
      'on': true,
    },
    packet: '0107090506',
  ),
  (
    name: 'a zero-width bytes',
    build: () => scheme(1, [rounds(0), bytes(1, 'z', 0)]),
    row: {
      'v': [5, 6],
      'z': Uint8List(0),
    },
    packet: '010506',
  ),
  (
    name: 'a when that holds only a zero-width bytes',
    build: () => scheme(1, [
      u8(0, 'k'),
      rounds(1),
      when(2, eq(0, 1), [bytes(2, 'z', 0)]),
    ]),
    row: {
      'k': 1,
      'v': [5, 6],
      'z': Uint8List(0),
    },
    packet: '01010506',
  ),
  (
    name: 'a nested row that holds only a zero-width bytes',
    build: () => scheme(1, [
      rounds(0),
      nested('m', [bytes(0, 'z', 0)]),
    ]),
    row: {
      'v': [5, 6],
      'm': {'z': Uint8List(0)},
    },
    packet: '010506',
  ),
  (
    name: 'a times whose body holds only a zero-width bytes, with no round',
    build: () => scheme(1, [
      u8(0, 'n'),
      rounds(1),
      times(2, 0, [bytes(2, 'z', 0)]),
    ]),
    row: {
      'n': 0,
      'v': [5, 6],
    },
    packet: '01000506',
  ),
];

// The rule is about a repeat that something follows: a `times` has a count,
// and a nested row is looked into only for what follows the repeat.
final List<Kept> untouched = [
  (
    name: 'a repeat in a nested row that is the last field',
    build: () => scheme(1, [
      u8(0, 'x'),
      nested('m', [rounds(0)]),
    ]),
    row: {
      'x': 9,
      'm': {
        'v': [5, 6],
      },
    },
    packet: '01090506',
  ),
  (
    name: 'a times in a nested row of a times round',
    build: () => scheme(1, [
      u8(0, 'k'),
      times(1, 0, [
        nested('m', [
          u8(0, 'n'),
          times(1, 0, [u8(1, 'v')]),
        ]),
      ]),
    ]),
    row: {
      'k': 2,
      'm': [
        {
          'n': 2,
          'v': [5, 6],
        },
        {
          'n': 1,
          'v': [7],
        },
      ],
    },
    packet: '01020205060107',
  ),
];

void itKeeps(List<Kept> cases) {
  for (final c in cases) {
    test('${c.name} builds, packs ${c.packet} and reads the values back', () {
      // Arrange
      final layout = c.build();

      // Act
      final wire = pack(layout, c.row);
      final back = readRow(layout, hex(wire));

      // Assert
      expect(hex(wire), c.packet);
      expect(back, c.row);
    });
  }
}

void main() {
  // AC-1: the refused cases R1 to R9 of the contract, with map rows.
  group('AZ-4217 AC-1 a repeat that is not the last thing read is refused '
      'when the scheme is built', () {
    itRefuses(contractCases);
  });

  // AC-1: the rules that ran before this one run first and keep their texts.
  group('AZ-4217 AC-1 the empty-body rule runs before the repeat rule', () {
    test('an empty repeat with a field after it is refused for its body', () {
      // Arrange
      List<Field> build() => [repeat(0, []), u8(0, 'x')];

      // Act
      final error = refusal(() => scheme(1, build()));

      // Assert
      expect(
        error.toString(),
        'packbin: invalid scheme at field 0 (repeat 0): repeat 0: the body '
        'holds no member; a round of it would charge no slot and write '
        'nothing',
      );
    });
  });

  // AC-2: K1 to K5 of the contract.
  group('AZ-4217 AC-2 a repeat that is the last thing read', () {
    itKeeps(kept);
  });

  // AC-1 (unit row 2).
  group('AZ-4217 AC-1 a field after the repeat that cannot write a byte', () {
    itKeeps(noByteAfter);
  });

  // AC-4: nothing else changes.
  group('AZ-4217 AC-4 a scheme the rule does not name', () {
    itKeeps(untouched);
  });
}
