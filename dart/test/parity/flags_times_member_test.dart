import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import 'parity_support.dart';

// TypeScript table `flags-times-repeat-member.test.ts` (shapes TA, TS, TG, T2,
// RA, R2). A group's values are a nested map in Dart (owner decision Go-4):
// the bytes are TypeScript's, the row shape is not.

// ---------------------------------------------------------------------------
// flags-times-repeat-member
// ---------------------------------------------------------------------------

Field n() => u8(0, 'n');
Field pt(int id) => u8(id, 'pt');
Field head(int id) => u16(id, 'heading');

Scheme<Row> ta() => scheme(1, [
  n(),
  flags(1, [
    times(1, 0, [pt(1)]),
    head(2),
  ]),
]);

Scheme<Row> ts() {
  final fb = flagByte('m');
  return scheme(1, [
    n(),
    fb,
    fb.bit(times(1, 0, [pt(1)])),
    fb.bit(head(2)),
  ]);
}

Scheme<Row> tg() => scheme(1, [
  n(),
  flags(1, [
    groupOf(1, 'g', [
      times(1, 0, [pt(1)]),
    ]),
    head(2),
  ]),
]);

Scheme<Row> t2() => scheme(1, [
  n(),
  flags(1, [
    times(1, 0, [pt(1), u8(2, 'pu')]),
    head(3),
  ]),
]);

Scheme<Row> ra() => scheme(1, [
  u8(0, 'mode'),
  flags(1, [
    head(1),
    repeat(2, [pt(2)]),
  ]),
]);

Scheme<Row> r2() => scheme(1, [
  u8(0, 'mode'),
  flags(1, [
    head(1),
    repeat(2, [pt(2), u8(3, 'pu')]),
  ]),
]);

final timesShapes = <(String, Scheme<Row> Function())>[
  ('flags', ta),
  ('split', ts),
  ('group', tg),
];

/// For the group shape, `pt` goes into the map `g` (the round's list).
Row inGroup(String kind, Row row) {
  if (kind != 'group' || !row.containsKey('pt')) return row;
  final out = {...row}..remove('pt');
  out['g'] = {'pt': row['pt']};
  return out;
}

final timesRows = <ParityRow>[
  for (final (kind, build) in timesShapes) ...[
    ParityRow(
      'AC-4 $kind times 0 rounds',
      build,
      {'n': 0, 'heading': 90},
      const Pin.wire('0100025a00'),
      back: backOf2(kind, {'n': 0, 'heading': 90}),
    ),
    ParityRow(
      'AC-4 $kind times 1 round',
      build,
      inGroup(kind, {
        'n': 1,
        'pt': [5],
        'heading': 90,
      }),
      const Pin.wire('010103055a00'),
      back: backOf2(kind, {
        'n': 1,
        'pt': [5],
        'heading': 90,
      }),
    ),
    ParityRow(
      'AC-4 $kind times 2 rounds',
      build,
      inGroup(kind, {
        'n': 2,
        'pt': [5, 6],
        'heading': 90,
      }),
      const Pin.wire('01020305065a00'),
      back: backOf2(kind, {
        'n': 2,
        'pt': [5, 6],
        'heading': 90,
      }),
    ),
    ParityRow(
      'AC-4 $kind list shorter than the count',
      build,
      inGroup(kind, {
        'n': 2,
        'pt': [5],
        'heading': 90,
      }),
      const Pin.names('pt'),
    ),
    ParityRow('AC-4 $kind body values missing', build, {
      'n': 1,
      'heading': 90,
    }, const Pin.names('pt')),
    ParityRow(
      'AC-4 $kind count 0 with a list given',
      build,
      inGroup(kind, {
        'n': 0,
        'pt': [5],
        'heading': 90,
      }),
      const Pin.names('pt'),
    ),
    ParityRow(
      'AC-4 $kind list longer than the count',
      build,
      inGroup(kind, {
        'n': 1,
        'pt': [5, 6],
        'heading': 90,
      }),
      const Pin.names('pt'),
    ),
  ],
  ParityRow(
    'AC-4 times only',
    ta,
    {
      'n': 2,
      'pt': [5, 6],
    },
    const Pin.wire('0102010506'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-4 count only',
    ta,
    {'n': 0},
    const Pin.wire('010000'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-4 two values, one round',
    t2,
    {
      'n': 1,
      'pt': [5],
      'pu': [6],
      'heading': 90,
    },
    const Pin.wire('01010305065a00'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-4 two values, two rounds',
    t2,
    {
      'n': 2,
      'pt': [5, 6],
      'pu': [7, 8],
      'heading': 90,
    },
    const Pin.wire('010203050706085a00'),
    roundTrip: true,
  ),
  ParityRow('AC-4 second body value missing', t2, {
    'n': 1,
    'pt': [5],
    'heading': 90,
  }, const Pin.names('pu')),
  ParityRow(
    'AC-4 repeat 0 rounds',
    ra,
    {'mode': 1, 'heading': 90},
    const Pin.wire('0101015a00'),
    back: {'mode': 1, 'heading': 90},
  ),
  ParityRow(
    'AC-4 repeat 1 round',
    ra,
    {
      'mode': 1,
      'pt': [5],
      'heading': 90,
    },
    const Pin.wire('0101035a0005'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-4 repeat 2 rounds',
    ra,
    {
      'mode': 1,
      'pt': [5, 6],
      'heading': 90,
    },
    const Pin.wire('0101035a000506'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-4 repeat only',
    ra,
    {
      'mode': 1,
      'pt': [5, 6],
    },
    const Pin.wire('0101020506'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-4 repeat none, only mode',
    ra,
    {'mode': 1},
    const Pin.wire('010100'),
    back: {'mode': 1},
  ),
  ParityRow(
    'AC-4 repeat two values, one round',
    r2,
    {
      'mode': 1,
      'pt': [5],
      'pu': [6],
      'heading': 90,
    },
    const Pin.wire('0101035a000506'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-4 repeat two values, two rounds',
    r2,
    {
      'mode': 1,
      'pt': [5, 6],
      'pu': [7, 8],
      'heading': 90,
    },
    const Pin.wire('0101035a0005070608'),
    roundTrip: true,
  ),
  ParityRow('AC-4 repeat second body value missing', r2, {
    'mode': 1,
    'pt': [5],
    'heading': 90,
  }, const Pin.names('pu')),
  ParityRow(
    'AC-4 count in the scope written',
    () => scheme(1, [
      u8(0, 'p'),
      flags(1, [
        times(1, 0, [pt(1)]),
        head(2),
      ]),
    ]),
    {
      'p': 1,
      'pt': [5],
      'heading': 90,
    },
    const Pin.wire('010103055a00'),
    roundTrip: true,
  ),
  ParityRow(
    'AC-4 count member skipped, times bit clear',
    () => scheme(1, [
      flags(0, [
        u8(0, 'n'),
        times(1, 0, [pt(1)]),
        head(2),
      ]),
    ]),
    {'heading': 90},
    const Pin.wire('01045a00'),
    roundTrip: true,
  ),
];

/// What unpack gives for a times row: a clear bit (no round) gives no key.
Row backOf2(String kind, Row row) => inGroup(kind, row);

final timesUnpackOnly = <UnpackRow>[
  for (final (kind, build) in timesShapes)
    UnpackRow(
      'AC-5 $kind old packet',
      build,
      '0100025a00',
      backOf2(kind, {'n': 0, 'heading': 90}),
    ),
  UnpackRow('AC-5 repeat old packet', ra, '0101015a00', {
    'mode': 1,
    'heading': 90,
  }),
  UnpackRow(
    'AC-5 repeat two values read from the wire',
    r2,
    '0101035a0005060708',
    {
      'mode': 1,
      'pt': [5, 7],
      'pu': [6, 8],
      'heading': 90,
    },
  ),
];

void main() {
  group('flags-times-repeat-member', () {
    runParity(timesRows, timesUnpackOnly);
  });
}
