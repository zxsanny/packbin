import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import 'parity_support.dart';

// TypeScript table `loop21-parity-probes.test.ts`: rows U4 (AZ-2384), U6
// (AZ-2386) and U7 (AZ-2387).

const droppedBeforeByte =
    'pt: a value is given, but the condition or count of its when or times is '
    'not written before the flag byte, so its bit is clear; write that field '
    'before the flag byte';

String countNotWritten(int n) =>
    'pt: the count c is $n in the row, but no field wrote it (the when that '
    'holds it is clear), so its times reads no round; give the count 0, leave '
    'it out, or make the when hold';

/// U4: u8 n written after the flag byte; bit 0 { times(n) { u8 pt } }; bit 1
/// { u16 heading }.
Scheme<Row> splitCountAfterByte() {
  final fb = flagByte('fb');
  return scheme(1, [
    fb,
    u8(0, 'n'),
    fb.bit(times(1, 0, [u8(1, 'pt')])),
    fb.bit(u16(2, 'heading')),
  ]);
}

/// U6: u8 mode; when mode == 1 { u8 c }; split byte; bit 0 { times(c) { u8
/// pt } }; bit 1 { u16 heading }.
Scheme<Row> countBehindWhen() {
  final fb = flagByte('fb');
  return scheme(1, [
    u8(0, 'mode'),
    when(1, eq(0, 1), [u8(1, 'c')]),
    fb,
    fb.bit(times(2, 1, [u8(2, 'pt')])),
    fb.bit(u16(3, 'heading')),
  ]);
}

Scheme<Row> countBehindWhenCombined() => scheme(1, [
  u8(0, 'mode'),
  when(1, eq(0, 1), [u8(1, 'c')]),
  flags(2, [
    times(2, 1, [u8(2, 'pt')]),
    u16(3, 'heading'),
  ]),
]);

Scheme<Row> plainTimesBehindWhen() => scheme(1, [
  u8(0, 'mode'),
  when(1, eq(0, 1), [u8(1, 'c')]),
  times(2, 1, [u8(2, 'pt')]),
  u16(3, 'heading'),
]);

/// U7: the counted kinds behind a clear when.
final class Kind {
  const Kind(this.name, this.member, this.value, this.setHex, this.splitSetHex);
  final String name;
  final Field Function() member;
  final Object value;
  final String setHex;
  final String splitSetHex;
}

final kinds = <Kind>[
  Kind('bits', () => bits(2, 'v', 1), [1, 0, 1], '01010305', '0101030105'),
  Kind(
    'packed',
    () => packed(1, 2, 'v', 1),
    [1, 0, 1],
    '01010305',
    '0101030105',
  ),
  Kind(
    'sized',
    () => sized(2, 'v', 1),
    bytesOf([1, 2, 3]),
    '010103010203',
    '01010301010203',
  ),
];

List<Field> head() => [
  u8(0, 'mode'),
  when(1, eq(0, 1), [u8(1, 'c')]),
];

Scheme<Row> plainOf(Kind k) => scheme(1, [...head(), k.member()]);

Scheme<Row> splitOf(Kind k) {
  final fb = flagByte('fb');
  return scheme(1, [...head(), fb, fb.bit(k.member())]);
}

Scheme<Row> combinedOf(Kind k) => scheme(1, [
  ...head(),
  flags(2, [k.member()]),
]);

const notWrittenV = 'v: count c was not written';
const noValue3 =
    'v: the count c is 3 in the row, but no field wrote it (the when that '
    'holds it is clear), so the member reads nothing; give the count 0, leave '
    'it out, or make the when hold';

final rows = <ParityRow>[
  ParityRow(
    'U4 AC-1 the body absent packs flag 02, n = 2, heading',
    splitCountAfterByte,
    {'n': 2, 'heading': 90},
    const Pin.wire('0102025a00'),
  ),
  ParityRow('U4 AC-1 the body [] packs the same bytes', splitCountAfterByte, {
    'n': 2,
    'pt': <int>[],
    'heading': 90,
  }, const Pin.wire('0102025a00')),
  ParityRow(
    'U4 AC-1 count 0 after the byte with the body absent packs a clear bit too',
    splitCountAfterByte,
    {'n': 0, 'heading': 90},
    const Pin.wire('0102005a00'),
  ),
  ParityRow(
    'U4 AC-2 the body present is refused: the count is written after the byte',
    splitCountAfterByte,
    {
      'n': 2,
      'pt': [5, 6],
      'heading': 90,
    },
    const Pin.refused(droppedBeforeByte),
  ),
  ParityRow(
    'U6 AC-1 count 1, body absent: refused naming the member',
    countBehindWhen,
    {'mode': 0, 'c': 1, 'heading': 90},
    Pin.refused(countNotWritten(1)),
  ),
  ParityRow('U6 AC-1 count 1, body []: refused the same way', countBehindWhen, {
    'mode': 0,
    'c': 1,
    'pt': <int>[],
    'heading': 90,
  }, Pin.refused(countNotWritten(1))),
  ParityRow(
    'U6 AC-1 count 2 in the combined flags form is refused the same way',
    countBehindWhenCombined,
    {'mode': 0, 'c': 2, 'heading': 90},
    Pin.refused(countNotWritten(2)),
  ),
  ParityRow('U6 AC-2 count 0 packs as before', countBehindWhen, {
    'mode': 0,
    'c': 0,
    'heading': 90,
  }, const Pin.wire('0100025a00')),
  ParityRow('U6 AC-2 the count left out packs as before', countBehindWhen, {
    'mode': 0,
    'heading': 90,
  }, const Pin.wire('0100025a00')),
  ParityRow(
    'U6 AC-2 values given with the count never written keep their own error',
    countBehindWhen,
    {
      'mode': 0,
      'c': 2,
      'pt': [5, 6],
      'heading': 90,
    },
    const Pin.refused(droppedBeforeByte),
  ),
  ParityRow(
    'U6 AC-2 a holding when packs the rounds as before',
    countBehindWhen,
    {
      'mode': 1,
      'c': 1,
      'pt': [5],
      'heading': 90,
    },
    const Pin.wire('01010103055a00'),
  ),
  ParityRow(
    'U6 AC-2 a plain times behind a clear when is refused at count 1',
    plainTimesBehindWhen,
    {'mode': 0, 'c': 1, 'heading': 90},
    const Pin.refused('times: count c was not written'),
  ),
  ParityRow(
    'U6 AC-2 a plain times behind a clear when is refused at count 0',
    plainTimesBehindWhen,
    {'mode': 0, 'c': 0, 'heading': 90},
    const Pin.refused('times: count c was not written'),
  ),
  for (final k in kinds) ...[
    for (final (position, build) in <(String, Scheme<Row> Function(Kind))>[
      ('plain', plainOf),
      ('split bit', splitOf),
      ('combined flags', combinedOf),
    ])
      ParityRow(
        'U7 AC-1 ${k.name} $position refuses the value, naming the member',
        () => build(k),
        {'mode': 0, 'c': 3, 'v': k.value},
        const Pin.refused(notWrittenV),
      ),
    ParityRow(
      'U7 AC-2 ${k.name} plain, a holding when packs as before',
      () => plainOf(k),
      {'mode': 1, 'c': 3, 'v': k.value},
      Pin.wire(k.setHex),
    ),
    ParityRow(
      'U7 AC-2 ${k.name} split bit, a holding when packs as before',
      () => splitOf(k),
      {'mode': 1, 'c': 3, 'v': k.value},
      Pin.wire(k.splitSetHex),
    ),
    for (final (position, build) in <(String, Scheme<Row> Function(Kind))>[
      ('split bit', splitOf),
      ('combined flags', combinedOf),
    ]) ...[
      ParityRow(
        'U7 ${k.name} $position, no value, count 3: refused since loop 22 (U11)',
        () => build(k),
        {'mode': 0, 'c': 3},
        const Pin.refused(noValue3),
      ),
      ParityRow(
        'U7 ${k.name} $position, no value, count 0: a clear bit',
        () => build(k),
        {'mode': 0, 'c': 0},
        const Pin.wire('010000'),
      ),
    ],
  ],
];

void main() {
  group('loop21-parity-probes', () {
    runParity(rows);

    test('U6 a refusal at a plain times leads with the word times and names '
        'its first member', () {
      // Act
      final got = outcome(plainTimesBehindWhen(), {
        'mode': 0,
        'c': 1,
        'heading': 90,
      });

      // Assert
      expect(got, 'refused: times: count c was not written');
      expect(lastRefusedName, 'pt');
    });
  });
}
