import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import 'parity_support.dart';

// TypeScript tables `loop20-parity-pins.test.ts` (AZ-2356, AZ-2360, AZ-2363,
// AZ-2359) and `times-count-zero-with-values.test.ts` (AZ-2335), row for row.

const droppedSplit =
    'pt: a value is given, but the condition or count of its when or times is '
    'not written before the flag byte, so its bit is clear; write that field '
    'before the flag byte';

const skippedCount =
    'pt: a value is given, but the count of its times is not written, so its '
    'bit is clear; write the count before the times';

Field pt() => u8(1, 'pt');

/// AZ-2356: a split bit whose times count is written after the flag byte.
Scheme<Row> countAfterByte() {
  final fb = flagByte('fb');
  return scheme(1, [
    fb,
    u8(0, 'n'),
    fb.bit(times(1, 0, [pt()])),
  ]);
}

/// AZ-2360: a combined flags whose first member is the count of its second.
Scheme<Row> combinedCount() => scheme(1, [
  flags(0, [
    u8(0, 'n'),
    times(1, 0, [pt()]),
  ]),
]);

Scheme<Row> combinedWhen() => scheme(1, [
  u8(0, 'mode'),
  flags(1, [
    u8(1, 'n'),
    when(2, eq(0, 1), [
      times(2, 1, [u8(2, 'pt')]),
    ]),
  ]),
]);

/// AZ-2363: a times inside a when inside a split bit; its count n sits under
/// a when that is false for mode 1.
Scheme<Row> timesInWhen({required bool flagFirst}) {
  final fb = flagByte('fb');
  return scheme(1, [
    if (flagFirst) fb,
    u8(0, 'mode'),
    when(1, eq(0, 9), [u8(1, 'n')]),
    if (!flagFirst) fb,
    fb.bit(
      when(2, eq(0, 1), [
        times(2, 1, [u8(2, 'pt')]),
      ]),
    ),
  ]);
}

/// AZ-2335 plain and combined layouts.
Scheme<Row> plainTimes() => scheme(1, [
  u8(0, 'n'),
  times(1, 0, [pt()]),
]);

Scheme<Row> insideFlags() => scheme(1, [
  u8(0, 'n'),
  flags(1, [
    times(1, 0, [pt()]),
    u16(2, 'heading'),
  ]),
]);

final rows = <ParityRow>[
  ParityRow(
    'AZ-2356 AC-1 a list with count 0 after the byte is refused naming pt',
    countAfterByte,
    {
      'n': 0,
      'pt': [5, 6],
    },
    const Pin.refused('pt: 2 items, times count 0'),
  ),
  ParityRow('AZ-2356 AC-2 a lone scalar packs zero rounds', countAfterByte, {
    'n': 0,
    'pt': 5,
  }, const Pin.wire('010000')),
  ParityRow(
    'AZ-2360 AC-1 values are refused naming the member',
    combinedCount,
    {
      'pt': [5, 6],
    },
    const Pin.refused(skippedCount),
  ),
  ParityRow('AZ-2360 AC-1 a lone scalar is a value too', combinedCount, {
    'pt': 5,
  }, const Pin.prefix('pt: a value is given')),
  ParityRow(
    'AZ-2360 AC-2 no values pack the bit clear',
    combinedCount,
    {},
    const Pin.wire('0100'),
  ),
  ParityRow('AZ-2360 AC-2 an empty list packs the bit clear', combinedCount, {
    'pt': <int>[],
  }, const Pin.wire('0100')),
  ParityRow('AZ-2360 AC-2 the counted list packs', combinedCount, {
    'n': 2,
    'pt': [5, 6],
  }, const Pin.wire('0103020506')),
  ParityRow(
    'AZ-2360 a times under a when inside combined flags is refused the same way',
    combinedWhen,
    {
      'mode': 1,
      'pt': [5],
    },
    const Pin.prefix(
      'pt: a value is given, but the count of its times is not written',
    ),
  ),
  ParityRow('AZ-2360 a false when stays silent', combinedWhen, {
    'mode': 0,
    'pt': [5],
  }, const Pin.wire('010000')),
  ParityRow(
    'AZ-2363 AC-1 values with the count never written are refused',
    () => timesInWhen(flagFirst: false),
    {
      'mode': 1,
      'pt': [5, 6],
    },
    const Pin.refused(droppedSplit),
  ),
  ParityRow(
    'AZ-2363 AC-1 the same with the when condition written after the byte',
    () => timesInWhen(flagFirst: true),
    {
      'mode': 1,
      'pt': [5, 6],
    },
    const Pin.refused(droppedSplit),
  ),
  ParityRow(
    'AZ-2363 AC-1 after the byte, no values pack the clear bit',
    () => timesInWhen(flagFirst: true),
    {'mode': 1},
    const Pin.wire('010001'),
  ),
  ParityRow(
    'AZ-2363 AC-1 after the byte, a false condition packs the clear bit',
    () => timesInWhen(flagFirst: true),
    {
      'mode': 2,
      'pt': [5, 6],
    },
    const Pin.wire('010002'),
  ),
  for (final (name, build, wire) in [
    ('outside flags', plainTimes, '0100'),
    ('inside flags', insideFlags, '0100025a00'),
  ]) ...[
    ParityRow(
      'AZ-2335 AC-1 count 0 with a list of one value is refused ($name)',
      build,
      {
        'n': 0,
        'pt': [5],
        'heading': 90,
      },
      const Pin.refused('pt: 1 items, times count 0'),
    ),
    ParityRow(
      'AZ-2335 AC-2 count 0 without values writes zero rounds ($name)',
      build,
      {'n': 0, 'heading': 90},
      Pin.wire(name == 'outside flags' ? '0100' : wire),
    ),
    ParityRow(
      'AZ-2335 AC-2 count 0 with an empty list writes zero rounds ($name)',
      build,
      {'n': 0, 'pt': <int>[], 'heading': 90},
      Pin.wire(name == 'outside flags' ? '0100' : wire),
    ),
  ],
  ParityRow(
    'AZ-2335 a lone scalar with count 0 writes zero rounds',
    plainTimes,
    {'n': 0, 'pt': 5},
    const Pin.wire('0100'),
  ),
  ParityRow(
    'AZ-2335 count 0 with a list for the second of two round names names it',
    () => scheme(1, [
      u8(0, 'n'),
      times(1, 0, [pt(), u8(2, 'pu')]),
    ]),
    {
      'n': 0,
      'pu': [6],
    },
    const Pin.refused('pu: 1 items, times count 0'),
  ),
];

void main() {
  group('loop20-parity-pins and times-count-zero-with-values', () {
    runParity(rows);

    // AZ-2359 AC-1: a numeric enum member is a plain number in TypeScript;
    // a Dart enum case is no int, so it is refused (Go-2) while its integer
    // value packs. A documented difference (see parity_differences.md).
    test(
      'AZ-2359 AC-1 the integer of a numeric enum packs, the case is refused',
      () {
        // Arrange
        final layout = scheme(1, [u8(0, 'level')]);

        // Act
        final wire = outcome(layout, {'level': Level.high.value});
        final enumCase = outcome(layout, {'level': Level.high});

        // Assert
        expect(wire, '01c8');
        expect(enumCase, 'refused: expected an integer for u8, got Level');
        expect(lastRefusedName, 'level');
      },
    );

    test('AZ-2359 AC-1 a string is refused naming the field', () {
      // Act
      final text = outcome(scheme(1, [u8(0, 'level')]), {'level': 'fast'});

      // Assert
      expect(text, 'refused: expected an integer for u8, got String');
      expect(lastRefusedName, 'level');
    });
  });
}

enum Level {
  low(7),
  high(200);

  const Level(this.value);
  final int value;
}
