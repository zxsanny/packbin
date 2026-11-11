import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import 'parity_support.dart';

// TypeScript tables `repeat-short-optional.test.ts` (U3, AZ-2383) and
// `times-longer-list.test.ts` (AZ-2335 follow-up), row for row. A list for a
// round name holds `null` where TypeScript's holds `undefined`.

String short(String member, int items, int count) =>
    '$member: $items items, repeat count $count; give one entry per round, '
    'null where the member is absent';

/// repeat { u8 w; flags { u8 v } }
Scheme<Row> optionalU8() => scheme(1, [
  repeat(0, [
    u8(0, 'w'),
    flags(1, [u8(1, 'v')]),
  ]),
]);

Scheme<Row> boolsRepeat() => scheme(1, [
  repeat(0, [
    u8(0, 'w'),
    flags(1, [flagBool(1, 'on')]),
  ]),
]);

Scheme<Row> splitRepeat() {
  final fb = flagByte('m');
  return scheme(1, [
    repeat(0, [u8(0, 'w'), fb, fb.bit(u8(1, 'v'))]),
  ]);
}

Scheme<Row> groupedRepeat() => scheme(1, [
  repeat(0, [
    u8(0, 'w'),
    flags(1, [
      groupOf(1, 'g', [u8(1, 'v')]),
    ]),
  ]),
]);

Scheme<Row> slotsRepeat() => scheme(1, [
  repeat(0, [
    u8(0, 'w'),
    flags(1, [
      u2([slot(1, 'p'), slot(2, 'q')]),
    ]),
  ]),
]);

Scheme<Row> whenRepeatFlags() => scheme(1, [
  repeat(0, [
    u8(0, 'w'),
    flags(1, [
      when(1, eq(0, 1), [u8(1, 'v')]),
    ]),
  ]),
]);

final shortRows = <ParityRow>[
  ParityRow(
    'U3 AC-1 the U3 row {w: [1, 2], v: [5]} is refused naming v',
    optionalU8,
    {
      'w': [1, 2],
      'v': [5],
    },
    Pin.refused(short('v', 1, 2)),
  ),
  ParityRow(
    'U3 AC-1 three rounds and two entries is refused the same way',
    optionalU8,
    {
      'w': [1, 2, 3],
      'v': [5, null],
    },
    Pin.refused(short('v', 2, 3)),
  ),
  ParityRow('U3 AC-1 a bool is refused the same way', boolsRepeat, {
    'w': [1, 2],
    'on': [true],
  }, Pin.refused(short('on', 1, 2))),
  ParityRow('U3 AC-1 a split bit is refused the same way', splitRepeat, {
    'w': [1, 2],
    'v': [5],
  }, Pin.refused(short('v', 1, 2))),
  ParityRow(
    'U3 AC-1 a group member (one map a round) is refused the same way',
    groupedRepeat,
    {
      'w': [1, 2],
      'g': [
        {'v': 5},
      ],
    },
    Pin.refused(short('g', 1, 2)),
  ),
  ParityRow('U3 AC-1 a u2 slot is refused the same way', slotsRepeat, {
    'w': [1, 2],
    'p': [1],
    'q': [2, 3],
  }, Pin.refused(short('p', 1, 2))),
  ParityRow(
    'U3 AC-1 a when under flags is refused the same way',
    whenRepeatFlags,
    {
      'w': [1, 1],
      'v': [5],
    },
    Pin.refused(short('v', 1, 2)),
  ),
  ParityRow(
    'U3 AC-1 in a combined flags the short member is the one named',
    () => scheme(1, [
      repeat(0, [
        flags(0, [u8(0, 'a'), u8(1, 'b')]),
      ]),
    ]),
    {
      'a': [1],
      'b': [5, 6],
    },
    Pin.refused(short('a', 1, 2)),
  ),
  ParityRow(
    'U3 AC-2 the full list packs to the bytes the short list gave before',
    optionalU8,
    {
      'w': [1, 2],
      'v': [5, null],
    },
    const Pin.wire('010101050200'),
  ),
  ParityRow(
    'U3 AC-2 both entries',
    optionalU8,
    {
      'w': [1, 2],
      'v': [5, 6],
    },
    const Pin.wire('01010105020106'),
    roundTrip: true,
  ),
  ParityRow('U3 AC-2 no entry', optionalU8, {
    'w': [1, 2],
  }, const Pin.wire('0101000200')),
  ParityRow('U3 AC-2 an empty list', optionalU8, {
    'w': [1, 2],
    'v': <int>[],
  }, const Pin.wire('0101000200')),
  ParityRow('U3 AC-2 a lone value', optionalU8, {
    'w': [1, 2],
    'v': 5,
  }, const Pin.wire('01010105020105')),
  ParityRow(
    'U3 AC-2 the bool full list sets the bit only where it is true',
    boolsRepeat,
    {
      'w': [1, 2],
      'on': [true, null],
    },
    const Pin.wire('0101010200'),
  ),
  ParityRow(
    'U3 a times keeps its short-list rule under flags',
    () => scheme(1, [
      u8(0, 'c'),
      times(1, 0, [
        flags(1, [u8(1, 'v')]),
      ]),
    ]),
    {
      'c': 2,
      'v': [5],
    },
    const Pin.wire('0102010500'),
  ),
  ParityRow(
    'U3 a member under a when outside flags keeps its short list',
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
    'U3 a required member keeps its own error for a short list',
    () => scheme(1, [
      repeat(0, [u8(0, 'a'), u8(1, 'b')]),
    ]),
    {
      'a': [1, 2],
      'b': [3],
    },
    const Pin.refused('missing b'),
  ),
  ParityRow(
    'U3 a short list for the required member beside an optional one is missing, not repeat count',
    optionalU8,
    {
      'w': [1],
      'v': [5, 6],
    },
    const Pin.refused('missing w'),
  ),
];

// ---------------------------------------------------------------------------
// times-longer-list
// ---------------------------------------------------------------------------

Scheme<Row> one() => scheme(1, [
  u8(0, 'a'),
  times(1, 0, [u8(1, 'x')]),
]);
Scheme<Row> two() => scheme(1, [
  u8(0, 'a'),
  times(1, 0, [u8(1, 'x'), u8(2, 'y')]),
]);
Scheme<Row> under() => scheme(1, [
  u8(0, 'a'),
  times(1, 0, [
    u8(1, 'k'),
    when(2, eq(1, 1), [u8(2, 'v')]),
  ]),
]);

final longerRows = <ParityRow>[
  ParityRow(
    'AC-1 a longer list is refused, naming the member, the items and the count',
    one,
    {
      'a': 2,
      'x': [1, 2, 3],
    },
    const Pin.refused('x: 3 items, times count 2'),
  ),
  ParityRow('AC-2 count zero refuses a one-item list', one, {
    'a': 0,
    'x': [1],
  }, const Pin.refused('x: 1 items, times count 0')),
  ParityRow('AC-2 count zero packs an empty list', one, {
    'a': 0,
    'x': <int>[],
  }, const Pin.wire('0100')),
  ParityRow('AC-2 count zero packs an absent list', one, {
    'a': 0,
  }, const Pin.wire('0100')),
  ParityRow('AC-3 any member of the body is checked: a second field', two, {
    'a': 2,
    'x': [1, 2],
    'y': [3, 4, 5],
  }, const Pin.refused('y: 3 items, times count 2')),
  ParityRow(
    'AC-3 any member of the body is checked: a member under when',
    under,
    {
      'a': 1,
      'k': [1],
      'v': [7, 8],
    },
    const Pin.refused('v: 2 items, times count 1'),
  ),
  ParityRow(
    'AC-3 any member of the body is checked: under flags',
    () => scheme(1, [
      u8(0, 'a'),
      times(1, 0, [
        flags(1, [u8(1, 'p'), u8(2, 'q')]),
      ]),
    ]),
    {
      'a': 1,
      'p': [1],
      'q': [2, 3],
    },
    const Pin.refused('q: 2 items, times count 1'),
  ),
  ParityRow(
    'AC-3 any member of the body is checked: under an anchored group',
    () => scheme(1, [
      u8(0, 'a'),
      times(1, 0, [
        groupOf(1, 'g', [u8(1, 'p')]),
      ]),
    ]),
    {
      'a': 1,
      'g': [
        {'p': 1},
        {'p': 2},
      ],
    },
    const Pin.names('g'),
  ),
  ParityRow(
    'AC-3 any member of the body is checked: under an unanchored group',
    () => scheme(1, [
      u8(0, 'a'),
      times(1, 0, [
        nested('g', [u8(0, 'p')]),
      ]),
    ]),
    {
      'a': 1,
      'g': [
        {'p': 1},
        {'p': 2},
      ],
    },
    const Pin.names('g'),
  ),
  ParityRow(
    'AC-4 an exact list',
    one,
    {
      'a': 2,
      'x': [1, 2],
    },
    const Pin.wire('01020102'),
    roundTrip: true,
  ),
  ParityRow('AC-4 a lone scalar goes to every round', one, {
    'a': 2,
    'x': 5,
  }, const Pin.wire('01020505')),
  ParityRow('AC-4 a lone scalar, one round', one, {
    'a': 1,
    'x': 5,
  }, const Pin.wire('010105')),
  ParityRow(
    'AC-4 two members',
    two,
    {
      'a': 2,
      'x': [1, 2],
      'y': [3, 4],
    },
    const Pin.wire('010201030204'),
    roundTrip: true,
  ),
  ParityRow('AC-4 a member under a when', under, {
    'a': 2,
    'k': [1, 0],
    'v': [7],
  }, const Pin.wire('0102010700')),
  ParityRow('AC-4 a shorter list is still the missing-member error', one, {
    'a': 2,
    'x': [1],
  }, const Pin.refused('missing x')),
];

void main() {
  group('repeat-short-optional (U3)', () => runParity(shortRows));
  group('times-longer-list', () => runParity(longerRows));
}
