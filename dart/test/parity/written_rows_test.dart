import 'dart:math';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import 'parity_support.dart';

// TypeScript tables `flag-group-presence.test.ts` (a flags group is on when
// any value inside it is present) and `when-on-written-values.test.ts` (a
// `when` and a count read what pack wrote). A group's values are a nested map
// in Dart (owner decision Go-4); the bytes are TypeScript's.

Scheme<Row> u2Only() => scheme(1, [
  flags(0, [
    groupOf(0, 'g', [
      u2([slot(0, 'p'), slot(1, 'q')]),
    ]),
  ]),
]);

Scheme<Row> bitsOnly() => scheme(1, [
  u8(0, 'n'),
  flags(1, [
    groupOf(1, 'g', [bits(1, 'b', 0)]),
  ]),
]);

Scheme<Row> sizedOnly() => scheme(1, [
  u8(0, 'n'),
  flags(1, [
    groupOf(1, 'g', [sized(1, 'd', 0)]),
  ]),
]);

Scheme<Row> packedOnly() => scheme(1, [
  u8(0, 'n'),
  flags(1, [
    groupOf(1, 'g', [packed(2, 1, 'k', 0)]),
  ]),
]);

Scheme<Row> nestedFlags() => scheme(1, [
  flags(0, [
    groupOf(0, 'g', [
      flags(0, [u8(0, 'n')]),
    ]),
  ]),
]);

Scheme<Row> nestedGroup() => scheme(1, [
  flags(0, [
    groupOf(0, 'g', [
      groupOf(0, 'h', [u8(0, 'n')]),
    ]),
  ]),
]);

Scheme<Row> siblingAndFlags() => scheme(1, [
  flags(0, [
    groupOf(0, 'g', [
      u8(0, 'a'),
      flags(1, [u8(1, 'c')]),
    ]),
  ]),
]);

final presenceRows = <ParityRow>[
  ParityRow(
    'AC-1 a u2-only group sets its bit and round-trips',
    u2Only,
    {
      'g': {'p': 1, 'q': 2},
    },
    const Pin.wire('010109'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-1 an anchored bits-only group sets its bit and round-trips',
    bitsOnly,
    {
      'n': 8,
      'g': {
        'b': [1, 0, 1, 0, 1, 0, 1, 0],
      },
    },
    const Pin.wire('01080155'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-1 a sized-only group sets its bit and round-trips',
    sizedOnly,
    {
      'n': 1,
      'g': {
        'd': bytesOf([9]),
      },
    },
    const Pin.wire('01010109'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-1 a packed-only group sets its bit and round-trips',
    packedOnly,
    {
      'n': 2,
      'g': {
        'k': [1, 2],
      },
    },
    const Pin.wire('01020109'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-1 a group holding only flags packs',
    nestedFlags,
    {
      'g': {'n': 5},
    },
    const Pin.wire('01010105'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-1 a group holding only a nested group packs',
    nestedGroup,
    {
      'g': {
        'h': {'n': 5},
      },
    },
    const Pin.wire('010105'),
    roundTrip: true,
  ),
  ParityRow(
    'an absent group keeps its bit clear: u2',
    u2Only,
    {},
    const Pin.wire('0100'),
  ),
  ParityRow('an absent group keeps its bit clear: bits', bitsOnly, {
    'n': 1,
  }, const Pin.wire('010100')),
  ParityRow('an absent group keeps its bit clear: sized', sizedOnly, {
    'n': 1,
  }, const Pin.wire('010100')),
  ParityRow('an absent group keeps its bit clear: packed', packedOnly, {
    'n': 1,
  }, const Pin.wire('010100')),
  ParityRow(
    'an absent group keeps its bit clear: nested flags',
    nestedFlags,
    {},
    const Pin.wire('0100'),
  ),
  ParityRow(
    'an absent group keeps its bit clear: nested group',
    nestedGroup,
    {},
    const Pin.wire('0100'),
  ),
  ParityRow(
    'AC-2 a nested container with a value and a missing sibling fails naming '
    'the sibling',
    siblingAndFlags,
    {
      'g': {'c': 2},
    },
    const Pin.names('a'),
  ),
  ParityRow(
    'AC-2 a u2 group with one slot set fails naming the slot that is missing',
    u2Only,
    {
      'g': {'p': 1},
    },
    const Pin.names('q'),
  ),
  ParityRow(
    'a u2 group with only its second slot set is on, and fails naming the '
    'first slot',
    u2Only,
    {
      'g': {'q': 1},
    },
    const Pin.names('p'),
  ),
  ParityRow(
    'AC-2 the sibling and the nested value together still pack',
    siblingAndFlags,
    {
      'g': {'a': 1, 'c': 2},
    },
    const Pin.wire('0101010102'),
    roundTrip: true,
  ),
];

// when-on-written-values

/// `p; when(p == 0) { n }; <tail>`: a count or a second when names `n`,
/// which the first when can skip.
Scheme<Row> skipN(Field tail) => scheme(1, [
  u8(0, 'p'),
  when(1, eq(0, 0), [u8(1, 'n')]),
  tail,
]);

Scheme<Row> skipWhen() => skipN(when(2, eq(1, 0), [u8(2, 'v')]));

Scheme<Row> roundChain() => scheme(1, [
  repeat(0, [
    u8(0, 'k'),
    when(1, eq(0, 1), [u8(1, 'a')]),
    when(2, eq(1, 5), [u8(2, 'b')]),
  ]),
]);

final writtenRows = <ParityRow>[
  ParityRow(
    'AC-1 a when on a field that another when skipped does not match',
    skipWhen,
    {'p': 1, 'n': 0, 'v': 4},
    const Pin.wire('0101'),
    back: {'p': 1},
  ),
  ParityRow(
    'AC-1 the same chain writes both bodies when the first when matches',
    skipWhen,
    {'p': 0, 'n': 0, 'v': 4},
    const Pin.wire('01000004'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-2 a when on a field skipped in the round does not match',
    roundChain,
    {
      'k': [0],
      'a': [5],
      'b': [3],
    },
    const Pin.wire('0100'),
    back: {
      'k': [0],
      'a': [null],
      'b': [null],
    },
  ),
  ParityRow(
    'AC-3 a sibling when in a round still reads the earlier field',
    () => scheme(1, [
      repeat(0, [
        u8(0, 'k'),
        when(1, eq(0, 1), [u8(1, 'v')]),
      ]),
    ]),
    {
      'k': [1, 2],
      'v': [9],
    },
    const Pin.wire('01010902'),
  ),
  ParityRow(
    'AC-4 a sized count that names a skipped field throws naming it',
    () => skipN(sized(2, 'data', 1)),
    {
      'p': 1,
      'n': 2,
      'data': bytesOf([1, 2]),
    },
    const Pin.refused('data: count n was not written'),
  ),
  ParityRow(
    'AC-4 a bits count that names a skipped field throws naming it',
    () => skipN(bits(2, 'data', 1)),
    {
      'p': 1,
      'n': 2,
      'data': [1, 0],
    },
    const Pin.refused('data: count n was not written'),
  ),
  ParityRow(
    'AC-4 a packed count that names a skipped field throws naming it',
    () => skipN(packed(2, 2, 'data', 1)),
    {
      'p': 1,
      'n': 2,
      'data': [1, 2],
    },
    const Pin.refused('data: count n was not written'),
  ),
  ParityRow(
    'AC-4 a times count that names a skipped field throws naming it',
    () => skipN(times(2, 1, [u8(2, 'x')])),
    {
      'p': 1,
      'n': 2,
      'x': [1, 2],
    },
    const Pin.refused('times: count n was not written'),
  ),
  ParityRow(
    'AC-4 a count that names a skipped field inside a round throws naming it',
    () => scheme(1, [
      repeat(0, [
        u8(0, 'k'),
        when(1, eq(0, 1), [u8(1, 'n')]),
        packed(2, 2, 'data', 1),
      ]),
    ]),
    {
      'k': [0],
      'n': [3],
      'data': [
        [1, 2, 3],
      ],
    },
    const Pin.refused('data: count n was not written'),
  ),
  ParityRow(
    'AC-4 a sized count that names a field written earlier is unchanged',
    () => skipN(sized(2, 'data', 1)),
    {
      'p': 0,
      'n': 2,
      'data': bytesOf([7, 8]),
    },
    const Pin.wire('0100020708'),
  ),
  ParityRow(
    'AC-4 a bits count that names a field written earlier is unchanged',
    () => skipN(bits(2, 'data', 1)),
    {
      'p': 0,
      'n': 2,
      'data': [1, 0],
    },
    const Pin.wire('01000201'),
  ),
  ParityRow(
    'AC-4 a packed count that names a field written earlier is unchanged',
    () => skipN(packed(2, 2, 'data', 1)),
    {
      'p': 0,
      'n': 2,
      'data': [1, 2],
    },
    const Pin.wire('01000209'),
  ),
  ParityRow(
    'AC-4 a times count that names a field written earlier is unchanged',
    () => skipN(times(2, 1, [u8(2, 'x')])),
    {
      'p': 0,
      'n': 2,
      'x': [5, 6],
    },
    const Pin.wire(
      '010002'
      '0506',
    ),
  ),
  ParityRow(
    'AC-5 a when on a set flag bit still matches',
    () => scheme(1, [
      flags(0, [flagBool(0, 'on')]),
      when(1, eq(0, true), [u8(1, 'v')]),
    ]),
    {'on': true, 'v': 7},
    const Pin.wire('010107'),
    roundTrip: true,
  ),
  ParityRow(
    'a when on an unwritten field never matches (flag bit clear)',
    () => scheme(1, [
      flags(0, [u8(0, 'a')]),
      when(1, eq(0, 0), [u8(1, 'b')]),
    ]),
    {'b': 7},
    const Pin.wire('0100'),
    back: <String, Object?>{},
  ),
  ParityRow(
    'a when on an unwritten field never matches (field skipped by a when)',
    skipWhen,
    {'p': 1, 'v': 4},
    const Pin.wire('0101'),
    back: {'p': 1},
  ),
];

void main() {
  group('flag-group-presence', () => runParity(presenceRows));
  group('when-on-written-values', () {
    runParity(writtenRows);

    test('AC-3 the golden bytes are unchanged', () {
      // Arrange
      final position = scheme(0x40, [
        u16(0, 'sid'),
        i32(1, 'lat'),
        i32(2, 'lon'),
        u8(3, 'profile'),
        flags(4, [u16(4, 'heading'), u8(5, 'speed'), i16(6, 'altitude')]),
      ]);

      // Act
      final wire = hex(
        pack(position, {
          'sid': 1,
          'lat': 500000000,
          'lon': 300000000,
          'profile': 1,
        }),
      );

      // Assert
      expect(wire, '4001000065cd1d00a3e1110100');
    });

    // A seeded chain of whens over small values, so bodies are skipped and
    // matched often; each when tests an earlier field that an earlier when
    // may have skipped. Pack never writes what its own unpack cannot read.
    const names = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l'];
    test(
      'AC-1 a top-level chain reads back what was written (10,000 rows)',
      () {
        // Arrange
        final rand = Random(2197);
        var checked = 0;

        for (var n = 0; n < 500; n++) {
          final fields = <Field>[u8(0, names[0])];
          final used = <String>[names[0]];
          var id = 1;
          final count = 2 + rand.nextInt(4);
          for (var i = 0; i < count; i++) {
            final tested = rand.nextInt(id);
            final anchor = id;
            final body = <Field>[];
            final inside = 1 + rand.nextInt(2);
            for (var j = 0; j < inside; j++) {
              final name = names[used.length];
              used.add(name);
              body.add(u8(id + j, name));
            }
            id += inside;
            fields.add(when(anchor, eq(tested, rand.nextInt(3)), body));
          }
          final layout = scheme(1, fields);
          for (var r = 0; r < 20; r++) {
            final row = <String, Object?>{
              for (final name in used) name: rand.nextInt(3),
            };

            // Act
            final wire = pack(layout, row);
            final back = unpackRow(wire, layout);
            checked++;

            // Assert
            expect(back.error, isNull, reason: '$row -> ${hex(wire)}');
            expect(hex(pack(layout, back.row!)), hex(wire));
          }
        }
        expect(checked, 10000);
      },
    );

    test('AC-2 a round chain reads back what was written', () {
      // Arrange
      final rand = Random(2198);

      for (var n = 0; n < 500; n++) {
        final layout = scheme(1, [
          repeat(0, [
            u8(0, 'a'),
            when(1, eq(0, rand.nextInt(3)), [u8(1, 'b')]),
            when(2, eq(rand.nextInt(2), rand.nextInt(3)), [u8(2, 'c')]),
          ]),
        ]);
        for (var r = 0; r < 20; r++) {
          final rounds = 1 + rand.nextInt(3);
          List<int> list() => [
            for (var i = 0; i < rounds; i++) rand.nextInt(3),
          ];
          final row = <String, Object?>{'a': list(), 'b': list(), 'c': list()};

          // Act
          final wire = pack(layout, row);
          final back = unpackRow(wire, layout);

          // Assert
          expect(back.error, isNull, reason: '$row -> ${hex(wire)}');
          expect(hex(pack(layout, back.row!)), hex(wire));
        }
      }
    });
  });
}
