import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import 'parity_support.dart';

// TypeScript tables `loop22-novalue-count.test.ts` (U11, AZ-2410),
// `loop23-novalue-nested.test.ts` (AZ-2436) and `loop23-bigint-count.test.ts`
// (U23, AZ-2434): a bits, packed or sized member whose count the row gives
// above 0 behind a clear when is refused, naming the member and the count.

String notWritten(Object n) =>
    'v: the count c is $n in the row, but no field wrote it (the when that '
    'holds it is clear), so the member reads nothing; give the count 0, leave '
    'it out, or make the when hold';

enum Bit { split, flagsBit }

final class Member {
  const Member(this.name, this.build, this.value, this.setHex);
  final String name;
  final Field Function(int id, int countId) build;
  final Object value;
  final String setHex;
}

final members = <Member>[
  Member('bits', (id, c) => bits(id, 'v', c), [1, 0, 1], '05'),
  Member('packed', (id, c) => packed(1, id, 'v', c), [1, 0, 1], '05'),
  Member('sized', (id, c) => sized(id, 'v', c), bytesOf([1, 2, 3]), '010203'),
];

/// The member (or what holds it) behind a split bit or as the one member of a
/// combined `flags` at [id].
List<Field> behind(Bit bit, int id, Field inner) {
  if (bit == Bit.flagsBit) {
    return [
      flags(id, [inner]),
    ];
  }
  final fb = flagByte('fb');
  return [fb, fb.bit(inner)];
}

/// Row 56 with ids from [b]: mode b, c b+1, member b+2.
List<Field> body(Member m, Bit bit, int b) => [
  u8(b, 'mode'),
  when(b + 1, eq(b, 1), [u8(b + 1, 'c')]),
  ...behind(bit, b + 2, m.build(b + 2, b + 1)),
];

String bitName(Bit b) => b == Bit.split ? 'split bit' : 'combined flags';

// ---------------------------------------------------------------------------
// loop22-novalue-count: the top level.
// ---------------------------------------------------------------------------

List<Field> head() => [
  u8(0, 'mode'),
  when(1, eq(0, 1), [u8(1, 'c')]),
];

Scheme<Row> top(Member m, Bit? bit) => scheme(1, [
  ...head(),
  if (bit == null) m.build(2, 1) else ...behind(bit, 2, m.build(2, 1)),
]);

final topRows = <ParityRow>[
  for (final m in members) ...[
    for (final bit in Bit.values) ...[
      ParityRow(
        'U11 AC-1 ${m.name} ${bitName(bit)} refuses count 3, naming member and count',
        () => top(m, bit),
        {'mode': 0, 'c': 3},
        Pin.refused(notWritten(3)),
      ),
      ParityRow(
        'U11 AC-1 ${m.name} ${bitName(bit)} refuses a count of 4 given as a 64-bit number',
        () => top(m, bit),
        {'mode': 0, 'c': 4},
        Pin.refused(notWritten(4)),
      ),
      ParityRow(
        'U11 AC-2 ${m.name} ${bitName(bit)} count 0 packs the clear bit',
        () => top(m, bit),
        {'mode': 0, 'c': 0},
        const Pin.wire('010000'),
      ),
      ParityRow(
        'U11 AC-2 ${m.name} ${bitName(bit)} count left out packs the clear bit',
        () => top(m, bit),
        {'mode': 0},
        const Pin.wire('010000'),
      ),
      ParityRow(
        'U11 AC-2 ${m.name} ${bitName(bit)} a holding when with no value packs the clear bit',
        () => top(m, bit),
        {'mode': 1, 'c': 3},
        const Pin.wire('01010300'),
      ),
    ],
    for (final bit in <Bit?>[null, ...Bit.values]) ...[
      ParityRow(
        'U11 AC-3 ${m.name} ${bit == null ? 'plain' : bitName(bit)} with a value behind a clear when keeps its refusal',
        () => top(m, bit),
        {'mode': 0, 'c': 3, 'v': m.value},
        const Pin.refused('v: count c was not written'),
      ),
    ],
    ParityRow(
      'U11 AC-3 ${m.name} plain, a holding when packs',
      () => top(m, null),
      {'mode': 1, 'c': 3, 'v': m.value},
      Pin.wire('010103${m.setHex}'),
    ),
    ParityRow(
      'U11 AC-3 ${m.name} split bit, a holding when packs',
      () => top(m, Bit.split),
      {'mode': 1, 'c': 3, 'v': m.value},
      Pin.wire('01010301${m.setHex}'),
    ),
    ParityRow(
      'U11 ${m.name} plain, no value, keeps its own refusal',
      () => top(m, null),
      {'mode': 0, 'c': 3},
      const Pin.refused('v: count c was not written'),
    ),
  ],
  ParityRow('U11 packed bias -1: count 1 reads nothing and packs', packedBias, {
    'mode': 0,
    'c': 1,
  }, const Pin.wire('010000')),
  ParityRow('U11 packed bias -1: count 3 is refused as 3', packedBias, {
    'mode': 0,
    'c': 3,
  }, Pin.refused(notWritten(3))),
];

Scheme<Row> packedBias() {
  final fb = flagByte('fb');
  return scheme(1, [...head(), fb, fb.bit(packed(1, 2, 'v', 1, bias: -1))]);
}

// ---------------------------------------------------------------------------
// loop23-novalue-nested: the six positions of row 56.
// ---------------------------------------------------------------------------

Object valueOf(Member m) => m.value;

/// A position: its scheme, the rows refused, and the rows that pack as at
/// HEAD (count 0, left out, a holding inner when with no value and with the
/// value) with their wires.
final class Position {
  const Position(
    this.name,
    this.ac,
    this.layout,
    this.refused,
    this.unchanged,
    this.wires,
  );
  final String name;
  final String ac;
  final Scheme<Row> Function(Member, Bit) layout;
  final List<Row> Function(Member) refused;
  final List<Row> Function(Member) unchanged;
  final List<String> Function(Member) wires;
}

final positions = <Position>[
  Position(
    'the row 56 body inside a group',
    'AC-1',
    (m, bit) => scheme(1, [groupOf(0, 'g', body(m, bit, 0))]),
    (_) => [
      {
        'g': {'mode': 0, 'c': 3},
      },
    ],
    (m) => [
      {
        'g': {'mode': 0, 'c': 0},
      },
      {
        'g': {'mode': 0},
      },
      {
        'g': {'mode': 1, 'c': 3},
      },
      {
        'g': {'mode': 1, 'c': 3, 'v': m.value},
      },
    ],
    (m) => ['010000', '010000', '01010300', '01010301${m.setHex}'],
  ),
  Position(
    'a bit that holds a group holding the member',
    'AC-1',
    (m, bit) => scheme(1, [
      ...head(),
      ...behind(bit, 2, groupOf(2, 'g', [m.build(2, 1)])),
    ]),
    (_) => [
      {'mode': 0, 'c': 3},
    ],
    (m) => [
      {'mode': 0, 'c': 0},
      {'mode': 0},
      {'mode': 1, 'c': 3},
      {
        'mode': 1,
        'c': 3,
        'g': {'v': m.value},
      },
    ],
    (m) => ['010000', '010000', '01010300', '01010301${m.setHex}'],
  ),
  Position(
    'the row 56 body inside an outer holding when',
    'AC-2',
    (m, bit) => scheme(1, [u8(0, 'o'), when(1, eq(0, 1), body(m, bit, 1))]),
    (_) => [
      {'o': 1, 'mode': 0, 'c': 3},
    ],
    (m) => [
      {'o': 1, 'mode': 0, 'c': 0},
      {'o': 1, 'mode': 0},
      {'o': 1, 'mode': 1, 'c': 3},
      {'o': 1, 'mode': 1, 'c': 3, 'v': m.value},
    ],
    (m) => ['01010000', '01010000', '0101010300', '0101010301${m.setHex}'],
  ),
  Position(
    'a bit that holds a holding when around the member',
    'AC-2',
    (m, bit) => scheme(1, [
      u8(0, 'o'),
      u8(1, 'mode'),
      when(2, eq(1, 1), [u8(2, 'c')]),
      ...behind(bit, 3, when(3, eq(0, 1), [m.build(3, 2)])),
    ]),
    (_) => [
      {'o': 1, 'mode': 0, 'c': 3},
    ],
    (m) => [
      {'o': 1, 'mode': 0, 'c': 0},
      {'o': 1, 'mode': 0},
      {'o': 1, 'mode': 1, 'c': 3},
      {'o': 1, 'mode': 1, 'c': 3, 'v': m.value},
    ],
    (m) => ['01010000', '01010000', '0101010300', '0101010301${m.setHex}'],
  ),
  Position(
    'a times round body',
    'AC-3',
    (m, bit) => scheme(1, [u8(0, 'n'), times(1, 0, body(m, bit, 1))]),
    (_) => [
      {
        'n': 1,
        'mode': [0],
        'c': [3],
      },
      {
        'n': 2,
        'mode': [1, 0],
        'c': [0, 3],
      },
    ],
    (m) => [
      {
        'n': 2,
        'mode': [1, 0],
        'c': [0, 0],
      },
      {
        'n': 1,
        'mode': [0],
      },
      {
        'n': 1,
        'mode': [1],
        'c': [3],
      },
      {
        'n': 1,
        'mode': [1],
        'c': [3],
        'v': [m.value],
      },
    ],
    (m) => [
      '01020100000000',
      '01010000',
      '0101010300',
      '0101010301${m.setHex}',
    ],
  ),
  Position(
    'a repeat round body',
    'AC-3',
    (m, bit) => scheme(1, [repeat(0, body(m, bit, 0))]),
    (_) => [
      {
        'mode': [0],
        'c': [3],
      },
      {
        'mode': [1, 0],
        'c': [0, 3],
      },
    ],
    (m) => [
      {
        'mode': [1, 0],
        'c': [0, 0],
      },
      {
        'mode': [0],
      },
      {
        'mode': [1],
        'c': [3],
      },
      {
        'mode': [1],
        'c': [3],
        'v': [m.value],
      },
    ],
    (m) => ['010100000000', '010000', '01010300', '01010301${m.setHex}'],
  ),
];

/// The clear inner when itself: nothing of the member is written or looked
/// at.
Scheme<Row> insideClearWhen(Member m, Bit bit) => scheme(1, [
  u8(0, 'o'),
  when(1, eq(0, 1), [
    u8(1, 'mode'),
    when(2, eq(1, 1), [u8(2, 'c'), ...behind(bit, 3, m.build(3, 2))]),
  ]),
]);

final nestedRows = <ParityRow>[
  for (final p in positions)
    for (final m in members)
      for (final bit in Bit.values) ...[
        for (final (i, row) in p.refused(m).indexed)
          ParityRow(
            'U11 ${p.ac} ${p.name}: ${m.name} ${bitName(bit)} refuses row ${i + 1}',
            () => p.layout(m, bit),
            row,
            Pin.refused(notWritten(3)),
          ),
        for (final (i, row) in p.unchanged(m).indexed)
          ParityRow(
            'U11 AC-4 ${p.name}: ${m.name} ${bitName(bit)} unchanged row ${i + 1}',
            () => p.layout(m, bit),
            row,
            Pin.wire(p.wires(m)[i]),
          ),
      ],
  for (final m in members)
    for (final bit in Bit.values)
      ParityRow(
        'U11 a member inside the clear inner when is a silent skip: ${m.name} ${bitName(bit)}',
        () => insideClearWhen(m, bit),
        {'o': 1, 'mode': 0, 'c': 3},
        const Pin.wire('010100'),
      ),
];

// ---------------------------------------------------------------------------
// loop23-bigint-count: U23. A Dart int is exact to 2^63 - 1, so counts above
// 2^53 are real counts (as Go and Python); TypeScript's bigint is an int.
// ---------------------------------------------------------------------------

final bigMembers = <(String, Field Function())>[
  ('bits', () => bits(2, 'v', 1)),
  ('packed', () => packed(1, 2, 'v', 1)),
  ('packed bias -1', () => packed(1, 2, 'v', 1, bias: -1)),
  ('sized', () => sized(2, 'v', 1)),
];

Scheme<Row> bigLayout(Field Function() member, Bit bit) =>
    scheme(1, [...head(), ...behind(bit, 2, member())]);

const bigCounts = <(int, String)>[
  (1 << 60, '1152921504606846976'),
  ((1 << 53) + 1, '9007199254740993'),
  (1 << 53, '9007199254740992'),
  (3, '3'),
  ((1 << 53) - 1, '9007199254740991'),
];

/// Values TypeScript packs the clear bit for: not above 0, or not a count.
final notCounts = <(String, Object?)>[
  ('0n', 0),
  ('3.5', 3.5),
  ('-1', -1),
  ('"3"', '3'),
  ('NaN', double.nan),
  ('true', true),
  ('null', null),
  ('-2^60n', -(1 << 60)),
];

final bigRows = <ParityRow>[
  for (final (name, member) in bigMembers)
    for (final bit in Bit.values) ...[
      for (final (c, shown) in bigCounts)
        ParityRow(
          'U23 AC-1 $name ${bitName(bit)}: a count of $shown is refused, naming member and count',
          () => bigLayout(member, bit),
          {'mode': 0, 'c': c},
          Pin.refused(notWritten(shown)),
        ),
      for (final (label, c) in notCounts)
        ParityRow(
          'U23 AC-2 $name ${bitName(bit)}: a count of $label packs the clear bit',
          () => bigLayout(member, bit),
          {'mode': 0, 'c': c},
          const Pin.wire('010000'),
        ),
      ParityRow(
        'U23 AC-2 $name ${bitName(bit)}: left out packs the clear bit',
        () => bigLayout(member, bit),
        {'mode': 0},
        const Pin.wire('010000'),
      ),
    ],
  // U6 split: TypeScript packs the clear bit for a bigint times count above
  // 2^53; the other packages refuse it, and so does Dart (see
  // parity_differences.md).
];

void main() {
  group('loop22-novalue-count (U11)', () => runParity(topRows));
  group('loop23-novalue-nested (U11 positions)', () => runParity(nestedRows));
  group('loop23-bigint-count (U23)', () => runParity(bigRows));

  group('U6 split: a times count above 2^53 behind a clear when', () {
    final timesCount = [
      for (final bit in Bit.values)
        (
          bitName(bit),
          () => scheme(1, [
            ...head(),
            ...behind(bit, 2, times(2, 1, [u8(2, 'pt')])),
          ]),
        ),
    ];
    for (final (label, build) in timesCount) {
      test('a count of 2^60 is refused naming pt and the count ($label)', () {
        // Act
        final got = outcome(build(), {'mode': 0, 'c': 1 << 60});

        // Assert
        expect(
          got,
          'refused: pt: the count c is 1152921504606846976 in the row, but no '
          'field wrote it (the when that holds it is clear), so its times '
          'reads no round; give the count 0, leave it out, or make the when '
          'hold',
        );
      });
    }
  });
}
