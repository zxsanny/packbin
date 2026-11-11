import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';
import 'parity_support.dart';

// TypeScript tables `duplicate-names.test.ts`, `empty-round-body.test.ts`
// (AZ-2390, F33) and `borrowed-count.test.ts`, row for row where the shapes
// exist in Dart. A TypeScript unanchored `group` is the nested row of Dart.

String emptyBody(String word, int id) =>
    '$word $id: the body holds no member; a round of it would charge no slot '
    'and write nothing';

/// A scheme the build must refuse: the reason, and the member it names.
final class Refused {
  const Refused(this.id, this.build, this.member, [this.reason]);
  final String id;
  final Scheme<Row> Function() build;
  final String member;
  final String? reason;
}

final refusals = <Refused>[
  Refused(
    'duplicate-names AC-1 the same name twice at one level is refused',
    () => scheme(1, [u8(0, 'a'), u8(1, 'a')]),
    'a',
  ),
  Refused(
    'duplicate-names AC-2 two times bodies sharing a name are refused',
    () => scheme(1, [
      u8(0, 'n'),
      times(1, 0, [u8(1, 'v')]),
      u8(2, 'm'),
      times(3, 2, [u8(3, 'v')]),
    ]),
    'v',
  ),
  Refused(
    'duplicate-names AC-3 a repeat member named like a top-level field is '
        'refused',
    () => scheme(1, [
      u8(0, 'k'),
      repeat(1, [u8(1, 'k')]),
    ]),
    'k',
  ),
  Refused(
    'duplicate-names AC-4 a flags member named like a top-level field is '
        'refused',
    () => scheme(1, [
      u8(0, 'a'),
      flags(1, [u8(1, 'a')]),
    ]),
    'a',
  ),
  Refused(
    'duplicate-names an anchored group member named like an outer member is '
        'refused',
    () => scheme(1, [
      u8(0, 'a'),
      groupOf(1, 'g', [u8(1, 'a')]),
    ]),
    'a',
  ),
  Refused(
    'duplicate-names a name twice outside every when is refused after a when '
        'that shares it',
    () => scheme(1, [
      u8(0, 'kind'),
      when(1, eq(0, 0), [u8(1, 'shape')]),
      u8(2, 'shape'),
      u8(3, 'shape'),
    ]),
    'shape',
  ),
  Refused(
    'duplicate-names a name twice inside one nested row is refused',
    () => scheme(1, [
      nested('g', [u8(0, 'a'), u8(1, 'a')]),
    ]),
    'a',
  ),
  Refused(
    'duplicate-names TS-F2 a name twice at the top of a list element is '
        'refused',
    () => scheme(1, [
      list('pts', nested('g', [u8(0, 'a'), u8(1, 'a')])),
    ]),
    'a',
  ),
  Refused(
    'duplicate-names TS-F2 a nested anchored group inside a dict element '
        'sharing a member is refused',
    () => scheme(1, [
      dict(
        'm',
        nested('g', [
          u8(0, 'a'),
          groupOf(1, 'h', [u8(1, 'a')]),
        ]),
      ),
    ]),
    'a',
  ),
  Refused(
    'duplicate-names AC-6 the group-versus-outside refusal',
    () => scheme(1, [
      u8(0, 'sid'),
      groupOf(1, 'g', [u8(1, 'sid')]),
    ]),
    'sid',
  ),
  Refused(
    'empty-round-body AC-1 repeat with no member names the repeat',
    () => scheme(1, [repeat(0, [])]),
    '',
    emptyBody('repeat', 0),
  ),
  Refused(
    'empty-round-body AC-1 times with no member names the times',
    () => scheme(1, [u8(0, 'n'), times(1, 0, [])]),
    '',
    emptyBody('times', 1),
  ),
  Refused(
    'empty-round-body AC-1 a body of only a when with no member is empty',
    () => scheme(1, [
      repeat(0, [when(0, eq(0, 1), [])]),
    ]),
    '',
    emptyBody('repeat', 0),
  ),
  Refused(
    'empty-round-body AC-1 a body of a when inside a when is empty',
    () => scheme(1, [
      repeat(0, [
        when(0, eq(0, 1), [when(0, eq(0, 2), [])]),
      ]),
    ]),
    '',
    emptyBody('repeat', 0),
  ),
  Refused(
    'empty-round-body AC-1 empty under flags',
    () => scheme(1, [
      flags(0, [repeat(0, [])]),
    ]),
    '',
    emptyBody('repeat', 0),
  ),
  Refused(
    'empty-round-body AC-1 empty under a flag bit',
    () {
      final fb = flagByte('m');
      return scheme(1, [fb, fb.bit(repeat(0, []))]);
    },
    '',
    emptyBody('repeat', 0),
  ),
  Refused(
    'empty-round-body AC-1 empty under a when',
    () => scheme(1, [
      u8(0, 'm'),
      when(1, eq(0, 1), [repeat(1, [])]),
    ]),
    '',
    emptyBody('repeat', 1),
  ),
  Refused(
    'empty-round-body AC-1 empty in a nested row',
    () => scheme(1, [
      nested('g', [repeat(0, [])]),
    ]),
    '',
    emptyBody('repeat', 0),
  ),
  Refused(
    'empty-round-body AC-1 empty in a list item',
    () => scheme(1, [
      list('xs', nested('item', [repeat(0, [])])),
    ]),
    '',
    emptyBody('repeat', 0),
  ),
  Refused(
    'empty-round-body AC-2 the F33 request shape fails at build',
    () => scheme(1, [
      list('items', nested('item', [u32(0, 'n'), times(1, 0, [])])),
    ]),
    '',
    emptyBody('times', 1),
  ),
];

Scheme<Row> shapes() => scheme(1, [
  u8(0, 'kind'),
  when(1, eq(0, 0), [u8(1, 'shape')]),
  when(2, eq(0, 1), [u16(2, 'shape')]),
]);

final rows = <ParityRow>[
  ParityRow(
    'duplicate-names AC-5 alternate when branches keep sharing a name',
    shapes,
    {'kind': 1, 'shape': 300},
    const Pin.wire('01012c01'),
    roundTrip: true,
  ),
  ParityRow(
    'duplicate-names AC-5 alternate when branches inside a repeat round',
    () => scheme(1, [
      repeat(0, [
        u8(0, 'k'),
        when(1, eq(0, 0), [u8(1, 's')]),
        when(2, eq(0, 1), [u16(2, 's')]),
      ]),
    ]),
    {
      'k': [0, 1],
      's': [7, 300],
    },
    const Pin.wire('010007012c01'),
    roundTrip: true,
  ),
  ParityRow(
    'duplicate-names a name outside every when and once inside one builds '
    '(option B)',
    () => scheme(1, [
      u8(0, 'kind'),
      u8(1, 'shape'),
      when(2, eq(0, 1), [u16(2, 'shape')]),
    ]),
    {'kind': 1, 'shape': 7},
    const Pin.wire('0101070700'),
  ),
  ParityRow(
    'duplicate-names AC-6 an element named like a top-level field builds and '
    'packs',
    () => scheme(1, [u8(0, 'a'), list('xs', u8(0, 'a'))]),
    {
      'a': 7,
      'xs': [1, 2],
    },
    const Pin.wire('010702000102'),
  ),
  ParityRow(
    'duplicate-names AC-6 a nested element member named like a top-level '
    'field builds and packs',
    () => scheme(1, [
      u8(0, 'a'),
      list('pts', nested('p', [u8(0, 'a'), u8(1, 'b')])),
    ]),
    {
      'a': 7,
      'pts': [
        {'a': 1, 'b': 2},
      ],
    },
    const Pin.wire('010701000102'),
  ),
  ParityRow(
    'duplicate-names two elements may use the same member names',
    () => scheme(1, [
      list('xs', nested('p', [u8(0, 'a')])),
      dict('ys', nested('q', [u8(0, 'a')])),
    ]),
    {
      'xs': [
        {'a': 1},
      ],
      'ys': {
        'k': {'a': 2},
      },
    },
    const Pin.wire('01010001010002106b02'),
  ),
  ParityRow(
    'empty-round-body AC-3 a body with one u8 builds and packs: repeat',
    () => scheme(1, [
      repeat(0, [u8(0, 'k')]),
    ]),
    {
      'k': [7, 8],
    },
    const Pin.wire('010708'),
    roundTrip: true,
  ),
  ParityRow(
    'empty-round-body AC-3 a body with one u8 builds and packs: times',
    () => scheme(1, [
      u8(0, 'n'),
      times(1, 0, [u8(1, 'k')]),
    ]),
    {
      'n': 2,
      'k': [7, 8],
    },
    const Pin.wire('01020708'),
    roundTrip: true,
  ),
  ParityRow(
    'empty-round-body a flag byte alone is a member: it writes a byte',
    () {
      final fb = flagByte('m');
      return scheme(1, [
        repeat(0, [fb]),
      ]);
    },
    {},
    const Pin.wire('01'),
  ),
  ParityRow(
    'empty-round-body a flags with no member is a member: its flag byte is '
    'a byte',
    () => scheme(1, [
      repeat(0, [flags(0, [])]),
    ]),
    {},
    const Pin.wire('01'),
  ),
  ParityRow(
    'empty-round-body an empty group under flags is a member: the flags '
    'writes a byte',
    () => scheme(1, [
      repeat(0, [
        flags(0, [groupOf(0, 'g', [])]),
      ]),
    ]),
    {
      'g': [true, null],
    },
    const Pin.wire('010100'),
  ),
  ParityRow(
    'empty-round-body a zero-width bytes is a member: it names a slot per '
    'round, so maxSlots bounds the rounds',
    () => scheme(1, [
      u8(0, 'n'),
      times(1, 0, [bytes(1, 'v', 0)]),
    ]).withLimits(maxSlots: 5),
    {
      'n': 10,
      'v': [for (var i = 0; i < 10; i++) Uint8List(0)],
    },
    const Pin.refused(
      'v: the rounds would hold 6 slots, above the limit of 5 slots',
    ),
  ),
];

// borrowed-count

const routeHex = '3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101';

Scheme<Row> route() => scheme(0x34, [
  u16(0, 'sid'),
  u16(1, 'name'),
  flags(2, [u16(2, 'unit'), flagBool(3, 'straight'), u16(4, 'routeId')]),
  u8(5, 'count'),
  packed(2, 6, 'kinds', 5),
  times(7, 5, [i32(7, 'lat'), i32(8, 'lon')]),
  when(9, eq(3, true), [packed(1, 9, 'mask', 5, bias: -1)]),
]);

final countRows = <ParityRow>[
  ParityRow(
    'borrowed-count width 2 four values are one byte',
    () => scheme(1, [u8(0, 'n'), packed(2, 1, 'kinds', 0)]),
    {
      'n': 4,
      'kinds': [0, 1, 2, 3],
    },
    const Pin.wire('0104e4'),
    roundTrip: true,
  ),
  ParityRow(
    'borrowed-count width 1 bias minus one writes eight bits',
    () => scheme(1, [u8(0, 'n'), packed(1, 1, 'kinds', 0, bias: -1)]),
    {
      'n': 9,
      'kinds': [1, 1, 1, 1, 1, 1, 1, 1],
    },
    const Pin.wire('0109ff'),
    roundTrip: true,
  ),
  ParityRow(
    'borrowed-count width 1 bias minus one writes none for an empty list',
    () => scheme(1, [u8(0, 'n'), packed(1, 1, 'kinds', 0, bias: -1)]),
    {'n': 1, 'kinds': <int>[]},
    const Pin.wire('0101'),
    roundTrip: true,
  ),
  ParityRow(
    'borrowed-count length mismatch names the field',
    () => scheme(1, [u8(0, 'n'), packed(2, 1, 'kinds', 0)]),
    {
      'n': 2,
      'kinds': [1],
    },
    const Pin.names('kinds'),
  ),
  ParityRow(
    'borrowed-count times stops so the next field is read',
    () => scheme(1, [
      u8(0, 'n'),
      times(1, 0, [i32(1, 'lat'), i32(2, 'lon')]),
      u8(3, 'tail'),
    ]),
    {
      'n': 2,
      'lat': [10, 30],
      'lon': [20, 40],
      'tail': 7,
    },
    const Pin.wire('01020a000000140000001e0000002800000007'),
    roundTrip: true,
  ),
];

void main() {
  group('duplicate-names and empty-round-body: schemes the build refuses', () {
    final ids = <String>{};
    for (final r in refusals) {
      if (!ids.add(r.id)) fail('duplicate row id ${r.id}');
      test(r.id, () {
        // Act
        final error = refusal(r.build);

        // Assert
        if (r.reason != null) expect(error.reason, r.reason);
        if (r.member.isNotEmpty) {
          expect(
            '${error.name} ${error.reason}',
            contains(r.member),
            reason: 'the refusal names ${r.member}',
          );
        }
      });
    }
  });

  group('duplicate-names, empty-round-body: rows', () => runParity(rows));

  group('borrowed-count', () {
    runParity(countRows);

    test(
      'the route matches the fixture, packs again and rejects a short tail',
      () {
        // Arrange
        final layout = route();
        final raw = unhex(routeHex);

        // Act
        final got = unpackRow(raw, layout).row!;
        final again = hex(pack(layout, got));
        final short = unpackRow(Uint8List.sublistView(raw, 0, 24), layout);

        // Assert
        expect(got['sid'], 16);
        expect(got['name'], 21);
        expect(got.containsKey('unit'), isFalse);
        expect(got['straight'], true);
        expect(got['routeId'], 45);
        expect(got['count'], 2);
        expect(got['kinds'], [1, 3]);
        expect(got['lat'], [500000000, 500010000]);
        expect(got['lon'], [300000000, 300010000]);
        expect(got['mask'], [1]);
        expect(again, routeHex);
        final e = short.error!;
        expect(
          [e.kind, e.name, e.needed, e.left],
          [ErrorKind.short, 'lon', 4, 2],
        );
      },
    );

    test('the route with straight false clears its bit and skips the mask', () {
      // Arrange
      final layout = route();
      final got = unpackRow(unhex(routeHex), layout).row!;

      // Act
      final wire = hex(pack(layout, {...got, 'straight': false}));
      final back = unpackRow(unhex(wire), layout).row!;

      // Assert
      expect(wire, '3410001500042d00020d0065cd1d00a3e111108ccd1d10cae111');
      expect(back.containsKey('straight'), isFalse);
      expect(back.containsKey('mask'), isFalse);
    });
  });
}
