import 'dart:isolate';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

typedef Row = Map<String, Object?>;

Uint8List b(List<int> bytes) => Uint8List.fromList(bytes);

/// One scheme with the row it packs and the bytes TypeScript packs for the
/// same scheme and row (the field objects are shared the same way there).
final class SharedCase {
  SharedCase(this.name, this.build, this.row, this.wire);
  final String name;
  final Scheme<Row> Function() build;
  final Row row;
  final String wire;
}

// The same member list in two lists of nested rows.
Scheme<Row> twoListsOfOneBody() {
  final body = [u8(0, 'n'), sized(1, 's', 0)];
  return scheme(1, [
    list('a', nested('v', body)),
    list('b', nested('v', body)),
  ]);
}

// The review's second scheme: a shared `when` and its source.
Scheme<Row> sharedWhenBody() {
  final body = [
    u8(0, 'k'),
    when(1, eq(0, 1), [u8(1, 'x')]),
  ];
  return scheme(2, [
    list('a', nested('v', body)),
    list('b', nested('v', body)),
  ]);
}

// One `sized` in two nested rows whose counts differ in width.
Scheme<Row> sharedSized() {
  final s = sized(1, 's', 0);
  return scheme(3, [
    list('a', nested('v', [u8(0, 'n'), s])),
    list('b', nested('v', [u16(0, 'm'), s])),
  ]);
}

// One `u8` at the top level and inside a nested row with a `when` on it.
Scheme<Row> topLevelAndNested() {
  final a = u8(0, 'a');
  return scheme(4, [
    a,
    sized(1, 'sz', 0),
    list(
      'x',
      nested('v', [
        a,
        when(1, eq(0, 1), [u8(1, 'y')]),
      ]),
    ),
  ]);
}

// One member list in two dictionaries.
Scheme<Row> twoDictsOfOneBody() {
  final body = [u8(0, 'n'), sized(1, 's', 0)];
  return scheme(5, [
    dict('d', nested('v', body)),
    dict('e', nested('v', body)),
  ]);
}

// One member list in a list and in a nested row of the top level.
Scheme<Row> listAndNestedOfOneBody() {
  final body = [u8(0, 'n'), sized(1, 's', 0)];
  return scheme(6, [list('p', nested('v', body)), nested('q', body)]);
}

// One member list in a list and in a repeat.
Scheme<Row> listAndRepeatOfOneBody() {
  final body = [u8(0, 'n'), sized(1, 's', 0)];
  return scheme(7, [list('q', nested('v', body)), repeat(0, body)]);
}

final cases = <SharedCase>[
  SharedCase('one member list in two lists', twoListsOfOneBody, {
    'a': [
      {
        'n': 1,
        's': b([9]),
      },
    ],
    'b': [
      {
        'n': 2,
        's': b([7, 8]),
      },
    ],
  }, '01 0100 01 09 0100 02 07 08'),
  SharedCase('one when body in two lists', sharedWhenBody, {
    'a': [
      {'k': 1, 'x': 5},
    ],
    'b': [
      {'k': 1, 'x': 6},
      {'k': 0},
    ],
  }, '02 0100 01 05 0200 01 06 00'),
  SharedCase('one sized in two nested rows', sharedSized, {
    'a': [
      {
        'n': 1,
        's': b([9]),
      },
    ],
    'b': [
      {
        'm': 2,
        's': b([7, 8]),
      },
    ],
  }, '03 0100 01 09 0100 0200 07 08'),
  SharedCase(
    'one u8 at the top level and in a nested when',
    topLevelAndNested,
    {
      'a': 1,
      'sz': b([5]),
      'x': [
        {'a': 1, 'y': 7},
        {'a': 0},
      ],
    },
    '04 01 05 0200 01 07 00',
  ),
  SharedCase('one member list in two dictionaries', twoDictsOfOneBody, {
    'd': {
      'k1': {
        'n': 1,
        's': b([9]),
      },
    },
    'e': {
      'k2': {
        'n': 2,
        's': b([7, 8]),
      },
    },
  }, '05 0100 03106b31 01 09 0100 03106b32 02 07 08'),
  SharedCase(
    'one member list in a list and a nested row',
    listAndNestedOfOneBody,
    {
      'p': [
        {
          'n': 1,
          's': b([9]),
        },
      ],
      'q': {
        'n': 2,
        's': b([7, 8]),
      },
    },
    '06 0100 01 09 02 07 08',
  ),
  SharedCase('one member list in a list and a repeat', listAndRepeatOfOneBody, {
    'q': [
      {
        'n': 1,
        's': b([6]),
      },
    ],
    'n': [1, 2],
    's': [
      b([9]),
      b([7, 8]),
    ],
  }, '07 0100 01 06 01 09 02 07 08'),
];

/// Packs [row] and unpacks the bytes in the isolate that calls it; the packed
/// hex and what unpack read (null when it was refused).
(String, Object?) trip(SharedCase c) {
  final layout = c.build();
  final wire = pack(layout, c.row);
  return (hex(wire), unpackRow(wire, layout).row);
}

final class Item {
  int n = 0;
  Uint8List s = Uint8List(0);
}

final class Two {
  List<Item> a = [];
  List<Item> b = [];
}

/// The first review scheme with typed rows: one member list in two lists.
Scheme<Two> typedTwoLists() {
  final body = [
    u8(0, 'n').bind<Item>(get: (i) => i.n, set: (i, v) => i.n = v),
    sized(1, 's', 0).bind<Item>(get: (i) => i.s, set: (i, v) => i.s = v),
  ];
  return rowScheme<Two>(1, Two.new, [
    list(
      'a',
      nestedRow<Item>('v', Item.new, body),
    ).bind<Two>(get: (t) => t.a, set: (t, v) => t.a = v),
    list(
      'b',
      nestedRow<Item>('v', Item.new, body),
    ).bind<Two>(get: (t) => t.b, set: (t, v) => t.b = v),
  ]);
}

final class Rec {
  int a = 0;
  Uint8List sz = Uint8List(0);
  int? y;
  List<Rec> x = [];
}

/// A typed `u8` shared by the top level and a nested row of the same row type,
/// with a `when` on it.
Scheme<Rec> typedTopLevelAndNested() {
  final a = u8(0, 'a').bind<Rec>(get: (r) => r.a, set: (r, v) => r.a = v);
  return rowScheme<Rec>(4, Rec.new, [
    a,
    sized(1, 'sz', 0).bind<Rec>(get: (r) => r.sz, set: (r, v) => r.sz = v),
    list(
      'x',
      nestedRow<Rec>('v', Rec.new, [
        a,
        when(1, eq(0, 1), [
          u8(1, 'y').bind<Rec>(get: (r) => r.y, set: (r, v) => r.y = v),
        ]),
      ]),
    ).bind<Rec>(get: (r) => r.x, set: (r, v) => r.x = v),
  ]);
}

void main() {
  group('R1 a field shared by two places of one scheme', () {
    for (final c in cases) {
      test(
        '${c.name}: pack and unpack give TypeScript\'s bytes and the row',
        () {
          // Arrange
          final layout = c.build();

          // Act
          final wire = pack(layout, c.row);
          final got = unpackRow(wire, layout);

          // Assert
          expect(hex(wire), c.wire.replaceAll(' ', ''));
          expect(got.error, isNull);
          expect(got.row, c.row);
        },
      );

      test('${c.name}: the same in an isolate', () async {
        // Act
        final (wire, row) = await Isolate.run(() => trip(c));

        // Assert
        expect(wire, c.wire.replaceAll(' ', ''));
        expect(row, c.row);
      });
    }

    test('one member list builds two schemes, each numbered on its own', () {
      // Arrange
      final body = [u8(0, 'n'), sized(1, 's', 0)];
      final first = scheme(1, [list('a', nested('v', body))]);
      final second = scheme(2, [u8(0, 'z'), list('b', nested('v', body))]);
      final row = {
        'a': [
          {
            'n': 1,
            's': b([9]),
          },
        ],
      };

      // Act
      final wire = pack(first, row);
      final other = pack(second, {
        'z': 3,
        'b': [
          {
            'n': 2,
            's': b([7, 8]),
          },
        ],
      });

      // Assert
      expect(hex(wire), '0101000109');
      expect(hex(other), '02030100020708');
      expect(hex(pack(first, row)), hex(wire));
    });

    test('a typed row with one member list in two lists packs and unpacks', () {
      // Arrange
      final layout = typedTwoLists();
      final row = Two()
        ..a = [
          Item()
            ..n = 1
            ..s = b([9]),
        ]
        ..b = [
          Item()
            ..n = 2
            ..s = b([7, 8]),
        ];

      // Act
      final wire = pack(layout, row);
      final got = unpackRow(wire, layout).row!;

      // Assert
      expect(hex(wire), '01 0100 01 09 0100 02 07 08'.replaceAll(' ', ''));
      expect([for (final i in got.a) i.n], [1]);
      expect(got.a[0].s, b([9]));
      expect([for (final i in got.b) i.n], [2]);
      expect(got.b[0].s, b([7, 8]));
    });

    test('a typed u8 shared by the top level and a nested when', () {
      // Arrange
      final layout = typedTopLevelAndNested();
      final row = Rec()
        ..a = 1
        ..sz = b([5])
        ..x = [
          Rec()
            ..a = 1
            ..y = 7,
          Rec()..a = 0,
        ];

      // Act
      final wire = pack(layout, row);
      final got = unpackRow(wire, layout).row!;

      // Assert
      expect(hex(wire), '04 01 05 0200 01 07 00'.replaceAll(' ', ''));
      expect(got.a, 1);
      expect(got.sz, b([5]));
      expect([for (final r in got.x) (r.a, r.y)], [(1, 7), (0, null)]);
    });
  });
}
