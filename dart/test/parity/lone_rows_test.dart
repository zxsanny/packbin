import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import 'parity_support.dart';

// TypeScript tables `lone-bytes-in-round.test.ts` (AZ-2332) and
// `lone-dict-in-round.test.ts` (AZ-2308): a lone byte buffer or dictionary
// for a name of a round is refused; a list with one per round packs.

const loneBuffer =
    'a byte buffer in a repeat or times round needs a list with one buffer per '
    'round';
const loneDict =
    'd: a dictionary in a repeat or times round needs a list with one '
    'dictionary per round';

Scheme<Row> timesBytes() => scheme(1, [
  u8(0, 'n'),
  times(1, 0, [bytes(1, 'b', 2)]),
]);
Scheme<Row> repeatBytes() => scheme(1, [
  repeat(0, [bytes(0, 'b', 2)]),
]);
Scheme<Row> timesSized() => scheme(1, [
  u8(0, 'n'),
  times(1, 0, [u8(1, 'c'), sized(2, 's', 1)]),
]);
Scheme<Row> inTimes() => scheme(1, [
  u8(0, 'n'),
  times(1, 0, [dict('d', utf8Field(0, 'e'))]),
]);
Scheme<Row> inRepeat() => scheme(1, [
  repeat(0, [dict('d', utf8Field(0, 'e'))]),
]);

final rows = <ParityRow>[
  ParityRow(
    'AZ-2332 AC-1 a lone buffer for a bytes name in a times is refused naming '
    'the member',
    timesBytes,
    {
      'n': 2,
      'b': bytesOf([1, 2]),
    },
    const Pin.refused('b: $loneBuffer'),
  ),
  ParityRow(
    'AZ-2332 AC-1 a lone buffer for a one-round times is refused too',
    timesBytes,
    {
      'n': 1,
      'b': bytesOf([1, 2]),
    },
    const Pin.refused('b: $loneBuffer'),
  ),
  ParityRow(
    'AZ-2332 AC-1 a lone buffer for a bytes name in a repeat is refused',
    repeatBytes,
    {
      'b': bytesOf([1, 2]),
    },
    const Pin.refused('b: $loneBuffer'),
  ),
  ParityRow(
    'AZ-2332 AC-1 a lone buffer for a sized name in a times is refused even '
    'when its length fits',
    timesSized,
    {
      'n': 1,
      'c': 1,
      's': bytesOf([9]),
    },
    const Pin.refused('s: $loneBuffer'),
  ),
  ParityRow(
    'AZ-2332 AC-1 a lone buffer for a name under a when, a group and a flags '
    'of the round is refused',
    () => scheme(1, [
      u8(0, 'n'),
      times(1, 0, [
        u8(1, 'k'),
        flags(2, [
          groupOf(2, 'g', [
            when(2, eq(1, 2), [bytes(2, 'b', 2)]),
          ]),
        ]),
      ]),
    ]),
    {
      'n': 2,
      'k': [2, 2],
      'g': {
        'b': bytesOf([9, 9]),
      },
    },
    const Pin.names('b'),
  ),
  ParityRow(
    'AZ-2332 AC-2 a list with one buffer per round packs: times',
    timesBytes,
    {
      'n': 2,
      'b': [
        bytesOf([1, 2]),
        bytesOf([3, 4]),
      ],
    },
    const Pin.wire('010201020304'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2332 AC-2 a list with one buffer per round packs: repeat',
    repeatBytes,
    {
      'b': [
        bytesOf([1, 2]),
        bytesOf([3, 4]),
      ],
    },
    const Pin.wire('0101020304'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2332 AC-2 a list with one buffer per round packs: sized',
    timesSized,
    {
      'n': 2,
      'c': [1, 1],
      's': [
        bytesOf([9]),
        bytesOf([8]),
      ],
    },
    const Pin.wire('010201090108'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2332 AC-2 a list with one buffer per round packs: one round',
    timesBytes,
    {
      'n': 1,
      'b': [
        bytesOf([1, 2]),
      ],
    },
    const Pin.wire('01010102'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2332 a lone string for a utf8 name still goes to every round',
    () => scheme(1, [
      u8(0, 'n'),
      times(1, 0, [utf8Field(1, 's')]),
    ]),
    {'n': 2, 's': 'ab'},
    const Pin.wire('01020310616203106162'),
  ),
  ParityRow(
    'AZ-2332 a bytes field outside a round still takes one buffer',
    () => scheme(1, [bytes(0, 'b', 2)]),
    {
      'b': bytesOf([1, 2]),
    },
    const Pin.wire('010102'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2308 AC-2 a lone dictionary for a dict name in a times round is '
    'refused, naming the member',
    inTimes,
    {
      'n': 2,
      'd': {'a': 'x'},
    },
    const Pin.refused(loneDict),
  ),
  ParityRow(
    'AZ-2308 AC-2 a lone dictionary in a repeat round is refused',
    inRepeat,
    {
      'd': {'a': 'x'},
    },
    const Pin.refused(loneDict),
  ),
  ParityRow(
    'AZ-2308 AC-3 a list with one dictionary per round packs: times',
    inTimes,
    {
      'n': 2,
      'd': [
        {'a': 'x'},
        {'b': 'y'},
      ],
    },
    const Pin.wire('010201000210610210780100021062021079'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2308 AC-3 a list with one dictionary per round packs: repeat',
    inRepeat,
    {
      'd': [
        {'a': 'x'},
        {'b': 'y'},
      ],
    },
    const Pin.wire('0101000210610210780100021062021079'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2308 a dictionary outside a round still packs',
    () => scheme(1, [dict('d', utf8Field(0, 'e'))]),
    {
      'd': {'a': 'x'},
    },
    const Pin.wire('010100021061021078'),
    roundTrip: true,
  ),
  ParityRow(
    'AZ-2308 a lone string for a utf8 name in a round still broadcasts',
    () => scheme(1, [
      u8(0, 'n'),
      times(1, 0, [utf8Field(1, 's')]),
    ]),
    {'n': 2, 's': 'a'},
    const Pin.wire('0102021061021061'),
  ),
];

void main() {
  group('lone-bytes-in-round and lone-dict-in-round', () => runParity(rows));
}
