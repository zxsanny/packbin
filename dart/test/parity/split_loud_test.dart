import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import 'parity_support.dart';

// TypeScript tables `split-form-loud-pack.test.ts` (AZ-2331) and
// `split-form-reference.test.ts` (AZ-2115), row for row.

const why =
    'a value is given, but the condition or count of its when or times is not '
    'written before the flag byte, so its bit is clear; write that field '
    'before the flag byte';

Scheme<Row> splitOf(List<Field> Function(FlagByte m) fields) {
  final m = flagByte('m');
  return scheme(1, fields(m));
}

Field speed() => when(1, eq(0, 1), [u8(1, 'speed')]);
Field mode() => u8(0, 'mode');
Field heading() => u16(2, 'heading');

// WS: the condition is written before the byte.
Scheme<Row> ws() =>
    splitOf((m) => [mode(), m, m.bit(speed()), m.bit(heading())]);
// The condition is written between the byte and the bit.
Scheme<Row> whenAfter() =>
    splitOf((m) => [m, mode(), m.bit(speed()), m.bit(heading())]);
// The condition is written by an earlier bit of the same byte.
Scheme<Row> whenInBit() =>
    splitOf((m) => [m, m.bit(mode()), m.bit(speed()), m.bit(heading())]);
// TS: the count is written before the byte.
Scheme<Row> ts() => splitOf(
  (m) => [
    u8(0, 'n'),
    m,
    m.bit(times(1, 0, [u8(1, 'pt')])),
    m.bit(heading()),
  ],
);
Scheme<Row> timesAfter() => splitOf(
  (m) => [
    m,
    u8(0, 'n'),
    m.bit(times(1, 0, [u8(1, 'pt')])),
    m.bit(heading()),
  ],
);
// The count lives in a bit of its own, so a row can leave it out.
Scheme<Row> timesSkipped() => splitOf(
  (m) => [
    m,
    m.bit(u8(0, 'n')),
    m.bit(times(1, 0, [u8(1, 'pt')])),
    m.bit(heading()),
  ],
);
Scheme<Row> timesInGroup() => splitOf(
  (m) => [
    m,
    m.bit(u8(0, 'n')),
    m.bit(
      groupOf(1, 'g', [
        times(1, 0, [u8(1, 'pt')]),
      ]),
    ),
    m.bit(heading()),
  ],
);

Scheme<Row> skippedUnderWhen() => splitOf(
  (m) => [
    mode(),
    m,
    m.bit(u8(1, 'n')),
    m.bit(
      when(2, eq(0, 1), [
        times(2, 1, [u8(2, 'pt')]),
      ]),
    ),
  ],
);

Scheme<Row> combinedWa() => scheme(1, [
  mode(),
  flags(1, [speed(), heading()]),
]);

Scheme<Row> combinedTimes() => scheme(1, [
  flags(0, [
    u8(0, 'n'),
    times(1, 0, [u8(1, 'pt')]),
  ]),
]);

final loudRows = <ParityRow>[
  ParityRow(
    'AZ-2331 AC-1 a when condition written after the byte, body given, is '
    'refused naming the body member',
    whenAfter,
    {'mode': 1, 'speed': 7, 'heading': 90},
    const Pin.refused('speed: $why'),
  ),
  ParityRow(
    'AZ-2331 AC-1 a when condition written by an earlier bit, body given, is '
    'refused',
    whenInBit,
    {'mode': 1, 'speed': 7, 'heading': 90},
    const Pin.refused('speed: $why'),
  ),
  ParityRow(
    'AZ-2331 AC-1 a times count written after the byte, values given, is '
    'refused naming the value',
    timesAfter,
    {
      'n': 2,
      'pt': [5, 6],
      'heading': 90,
    },
    const Pin.refused('pt: $why'),
  ),
  ParityRow(
    'AZ-2331 AC-2 a times whose count field was skipped, values given, is '
    'refused',
    timesSkipped,
    {
      'pt': [5],
      'heading': 90,
    },
    const Pin.refused('pt: $why'),
  ),
  ParityRow(
    'AZ-2331 AC-2 the same inside a group of the bit is refused',
    timesInGroup,
    {
      'g': {
        'pt': [5],
      },
      'heading': 90,
    },
    const Pin.refused('times: count n was not written'),
  ),
  ParityRow(
    'AZ-2331 a condition written after the byte with no body given still '
    'packs',
    whenAfter,
    {'mode': 1, 'heading': 90},
    const Pin.wire('0102015a00'),
  ),
  ParityRow(
    'AZ-2331 a count written after the byte with no values given still packs',
    timesAfter,
    {'n': 0, 'heading': 90},
    const Pin.wire('0102005a00'),
  ),
  ParityRow(
    'AZ-2331 a skipped count with no value given still packs',
    timesSkipped,
    {'heading': 90},
    const Pin.wire('01045a00'),
  ),
  ParityRow(
    'AZ-2331 AC-3 a false condition with a body given is dropped without an '
    'error (reference row)',
    ws,
    {'mode': 0, 'speed': 7, 'heading': 90},
    const Pin.wire('0100025a00'),
    back: {'mode': 0, 'heading': 90},
  ),
  ParityRow(
    'AZ-2331 AC-3 a false condition written after the byte, body given, is '
    'dropped without an error',
    whenAfter,
    {'mode': 0, 'speed': 7, 'heading': 90},
    const Pin.wire('0102005a00'),
  ),
  ParityRow(
    'AZ-2331 AC-4 the reference row with the source before the byte: true',
    ws,
    {'mode': 1, 'speed': 7, 'heading': 90},
    const Pin.wire('010103075a00'),
  ),
  ParityRow(
    'AZ-2331 AC-4 the reference row with the source before the byte: no body',
    ws,
    {'mode': 1, 'heading': 90},
    const Pin.wire('0101025a00'),
  ),
  ParityRow('AZ-2331 AC-4 split times, 0 rounds', ts, {
    'n': 0,
    'heading': 90,
  }, const Pin.wire('0100025a00')),
  ParityRow('AZ-2331 AC-4 split times, 1 round', ts, {
    'n': 1,
    'pt': [5],
    'heading': 90,
  }, const Pin.wire('010103055a00')),
  ParityRow(
    'AZ-2331 AC-4 split times, 2 rounds',
    ts,
    {
      'n': 2,
      'pt': [5, 6],
      'heading': 90,
    },
    const Pin.wire('01020305065a00'),
    roundTrip: true,
  ),
  ParityRow('AZ-2331 AC-4 split times, only the times', ts, {
    'n': 2,
    'pt': [5, 6],
  }, const Pin.wire('0102010506')),
  ParityRow(
    'AZ-2331 AC-4 a list that disagrees with count 0 keeps its error',
    ts,
    {
      'n': 0,
      'pt': [5],
      'heading': 90,
    },
    const Pin.refused('pt: 1 items, times count 0'),
  ),
  ParityRow('AZ-2331 AC-4 a short list keeps its error', ts, {
    'n': 2,
    'pt': [5],
    'heading': 90,
  }, const Pin.refused('missing pt')),
  ParityRow(
    'AZ-2331 combined flags: a false body with a body given is dropped',
    combinedWa,
    {'mode': 0, 'speed': 7, 'heading': 90},
    const Pin.wire('0100025a00'),
  ),
  ParityRow(
    'AZ-2331 combined flags: a skipped count packs the clear bit',
    combinedTimes,
    {},
    const Pin.wire('0100'),
  ),
  ParityRow('AZ-2331 combined flags: a given count packs', combinedTimes, {
    'n': 2,
    'pt': [5, 6],
  }, const Pin.wire('0103020506')),
  ParityRow(
    'AZ-2331 combined flags: a skipped count with values is refused',
    combinedTimes,
    {
      'pt': [5],
    },
    const Pin.prefix(
      'pt: a value is given, but the count of its times is not written',
    ),
  ),
  ParityRow(
    'AZ-2331 a value outside the range names the member (when body)',
    ws,
    {'mode': 1, 'speed': 300, 'heading': 90},
    const Pin.names('speed'),
  ),
  ParityRow(
    'AZ-2331 a value outside the range names the member (times body)',
    ts,
    {
      'n': 1,
      'pt': [300],
      'heading': 90,
    },
    const Pin.names('pt'),
  ),
  ParityRow(
    'AZ-2331 review B2 a skipped count under a when inside a split bit is '
    'refused',
    skippedUnderWhen,
    {
      'mode': 1,
      'pt': [5],
    },
    const Pin.refused('pt: $why'),
  ),
  ParityRow(
    'AZ-2331 review B2 a false condition packs the clear bit',
    skippedUnderWhen,
    {
      'mode': 0,
      'pt': [5],
    },
    const Pin.wire('010000'),
  ),
  ParityRow(
    'AZ-2331 review B7 an empty list under a skipped count packs (in a when)',
    skippedUnderWhen,
    {'mode': 1, 'pt': <int>[]},
    const Pin.wire('010100'),
  ),
  ParityRow(
    'AZ-2331 review B7 an empty list under a skipped count packs (bare)',
    timesSkipped,
    {'pt': <int>[], 'heading': 90},
    const Pin.wire('01045a00'),
  ),
];

Scheme<Row> reference() {
  final m = flagByte('m');
  return scheme(1, [
    u8(0, 'sid'),
    m,
    when(1, eq(0, 9), [u8(1, 'shape')]),
    m.bit(u16(2, 'heading')),
  ]);
}

final referenceRows = <ParityRow>[
  ParityRow(
    'AZ-2115 AC-1 the reference row packs to 010901045a00',
    reference,
    {'sid': 9, 'shape': 4, 'heading': 90},
    const Pin.wire('010901045a00'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2115 AC-1 the short row packs to 010100',
    reference,
    {'sid': 1},
    const Pin.wire('010100'),
    roundTrip: true,
  ),
];

void main() {
  group('split-form-loud-pack (AZ-2331)', () => runParity(loudRows));
  group('split-form-reference (AZ-2115)', () => runParity(referenceRows));
}
