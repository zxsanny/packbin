import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import 'parity_support.dart';

// TypeScript table `int-range.test.ts` (loops 19 to 21: every value is
// checked against its field, nothing wraps or rounds) and the `bool` rows of
// `bool-flag.test.ts`. Rows with another outcome in Dart are marked `diff`:
// a `double` is never an integer and a non-`bool` is never a `bool` (owner
// decisions Go-1 and Go-2), a Dart `int` is the 64-bit pattern of a `u64`
// (A-3), and TypeScript's `bigint` has no Dart spelling.

Field one(String kind) => switch (kind) {
  'u8' => u8(0, 'a'),
  'i8' => i8(0, 'a'),
  'u16' => u16(0, 'a'),
  'i16' => i16(0, 'a'),
  'u32' => u32(0, 'a'),
  'i32' => i32(0, 'a'),
  'u64' => u64(0, 'a'),
  'i64' => i64(0, 'a'),
  'f32' => f32(0, 'a'),
  _ => f64(0, 'a'),
};

Scheme<Row> single(String kind) => scheme(1, [one(kind)]);

/// A value that must be refused, naming `a`.
final refused = <(String, Object)>[
  ('u8', 300),
  ('u8', -1),
  ('i8', 200),
  ('i8', -129),
  ('u16', 65536),
  ('i16', -32769),
  ('i16', 32768),
  ('u32', 1 << 32),
  ('u32', -1),
  ('i32', 3000000000),
  ('i32', -2147483649),
  ('u8', 1.7),
  ('u8', double.nan),
  ('u8', true),
  ('u8', '5'),
  ('i64', 1.5),
  ('u64', '5'),
  ('f64', '1.5'),
  ('f64', 'abc'),
  ('f64', true),
  ('f32', '1.5'),
  ('f32', 1e39),
  ('f32', -1e39),
  // diff (Go-2): TypeScript refuses 1e300, Infinity, -Infinity too; a whole
  // double is refused in Dart.
  ('u8', 1e300),
  ('u8', double.infinity),
  ('u8', double.negativeInfinity),
  ('u64', 1e20),
];

/// Values that pack: (kind, value, hex).
final packs = <(String, Object, String)>[
  ('u8', 0, '0100'),
  ('u8', 255, '01ff'),
  ('i8', -128, '0180'),
  ('i8', 127, '017f'),
  ('u16', 65535, '01ffff'),
  ('i16', -32768, '010080'),
  ('u32', 4294967295, '01ffffffff'),
  ('i32', -2147483648, '0100000080'),
  ('i64', -(1 << 63), '010000000000000080'),
  ('i64', 0x7fffffffffffffff, '01ffffffffffffff7f'),
  ('u64', (1 << 53) - 1, '01ffffffffffff1f00'),
  ('i64', -((1 << 53) - 1), '01010000000000e0ff'),
  ('u64', 1 << 60, '010000000000000010'),
  ('f32', double.infinity, '010000807f'),
  ('f32', double.negativeInfinity, '01000080ff'),
  ('f32', double.nan, '010000c07f'),
  ('f32', 3.4028234663852886e38, '01ffff7f7f'),
  ('f64', 1.5, '01000000000000f83f'),
  ('f64', 1e300, '019c7500883ce4377e'),
  // A Dart int is a number for a float field, as TypeScript's number is.
  ('f64', 1, '01000000000000f03f'),
  // diff (A-3): the 64-bit pattern of -1 is 2^64 - 1; TypeScript refuses -1n
  // and writes 2^64 - 1 for 18446744073709551615n.
  ('u64', -1, '01ffffffffffffffff'),
];

final rows = <ParityRow>[
  for (final (kind, value) in refused)
    ParityRow('refused: $kind $value', () => single(kind), {
      'a': value,
    }, const Pin.names('a')),
  for (final (kind, value, wire) in packs)
    ParityRow('packs: $kind $value', () => single(kind), {
      'a': value,
    }, Pin.wire(wire)),
  ParityRow(
    'big-endian fields keep their byte order',
    () => scheme(1, [be(u16(0, 'a'))]),
    {'a': 0x1234},
    const Pin.wire('011234'),
    roundTrip: true,
  ),
  ParityRow(
    'big-endian fields are checked: u16',
    () => scheme(1, [be(u16(0, 'a'))]),
    {'a': 65536},
    const Pin.names('a'),
  ),
  ParityRow(
    'big-endian fields are checked: i32',
    () => scheme(1, [be(i32(0, 'a'))]),
    {'a': 1 << 31},
    const Pin.names('a'),
  ),
  ParityRow(
    'every container position is checked: a when body',
    () => scheme(1, [
      u8(0, 'k'),
      when(1, eq(0, 1), [u8(1, 'a')]),
    ]),
    {'k': 1, 'a': 256},
    const Pin.names('a'),
  ),
  ParityRow(
    'every container position is checked: flags',
    () => scheme(1, [
      flags(0, [u8(0, 'a')]),
    ]),
    {'a': -1},
    const Pin.names('a'),
  ),
  ParityRow(
    'every container position is checked: a repeat',
    () => scheme(1, [
      repeat(0, [u8(0, 'a')]),
    ]),
    {
      'a': [1, 2, 256],
    },
    const Pin.names('a'),
  ),
  ParityRow(
    'every container position is checked: a times',
    () => scheme(1, [
      u8(0, 'n'),
      times(1, 0, [u8(1, 'a')]),
    ]),
    {
      'n': 2,
      'a': [1, 300],
    },
    const Pin.names('a'),
  ),
  ParityRow(
    'every container position is checked: a list item',
    () => scheme(1, [list('a', u16(0, 'x'))]),
    {
      'a': [1, 70000],
    },
    const Pin.prefix('a[1]: '),
  ),
  ParityRow(
    'every container position is checked: a dict value',
    () => scheme(1, [dict('m', u8(0, 'a'))]),
    {
      'm': {'k': 256},
    },
    const Pin.prefix('m[k]: '),
  ),
  // bool-flag
  ParityRow(
    'bool false leaves the flag bit clear',
    () => scheme(1, [
      flags(0, [flagBool(0, 'on')]),
    ]),
    {'on': false},
    const Pin.wire('0100'),
  ),
  ParityRow(
    'bool true sets the flag bit and round-trips',
    () => scheme(1, [
      flags(0, [flagBool(0, 'on')]),
    ]),
    {'on': true},
    const Pin.wire('0101'),
    roundTrip: true,
  ),
  ParityRow(
    'bool left out leaves the flag bit clear',
    () => scheme(1, [
      flags(0, [flagBool(0, 'on')]),
    ]),
    {},
    const Pin.wire('0100'),
    back: <String, Object?>{},
  ),
  // diff (Go-1): TypeScript packs 0100 for `on: 1` and `on: "yes"`.
  ParityRow(
    'diff bool 1 is refused naming the field',
    () => scheme(1, [
      flags(0, [flagBool(0, 'on')]),
    ]),
    {'on': 1},
    const Pin.refused('expected a bool for on, got int'),
  ),
  ParityRow(
    'diff bool "yes" is refused naming the field',
    () => scheme(1, [
      flags(0, [flagBool(0, 'on')]),
    ]),
    {'on': 'yes'},
    const Pin.refused('expected a bool for on, got String'),
  ),
  ParityRow(
    'split form bool true',
    () {
      final m = flagByte('m');
      return scheme(1, [m, m.bit(flagBool(0, 'on'))]);
    },
    {'on': true},
    const Pin.wire('0101'),
    roundTrip: true,
  ),
  ParityRow(
    'empty group mark true',
    () => scheme(1, [
      flags(0, [groupOf(0, 'mark', [])]),
    ]),
    {'mark': true},
    const Pin.wire('0101'),
    roundTrip: true,
  ),
  ParityRow(
    'empty group mark false',
    () => scheme(1, [
      flags(0, [groupOf(0, 'mark', [])]),
    ]),
    {'mark': false},
    const Pin.wire('0100'),
  ),
];

void main() {
  group('int-range and bool-flag', () {
    runParity(rows);

    test('diff: a whole double for an integer field is refused (Go-2)', () {
      // Act
      final got = outcome(single('u8'), {'a': 5.0});

      // Assert
      expect(got, 'refused: expected an integer for u8, got double');
    });

    test('diff: a u64 of -1 packs as the 64-bit pattern 2^64 - 1 (A-3)', () {
      // Act
      final got = outcome(single('u64'), {'a': -1});

      // Assert
      expect(got, '01ffffffffffffffff');
      expect(unpackedRow(single('u64'), got), {'a': -1});
    });

    test('diff: negative zero is a double, so it is refused (Go-2)', () {
      // Act
      final got = outcome(single('u8'), {'a': -0.0});

      // Assert
      expect(got, 'refused: expected an integer for u8, got double');
    });

    test('diff: a u64 or i64 given as a double is refused, not wrapped', () {
      // Act
      final a = outcome(single('i64'), {'a': 5.0});
      final b = outcome(single('u64'), {'a': 2.0 * (1 << 62)});

      // Assert
      expect(a, startsWith('refused: expected an integer for i64'));
      expect(b, startsWith('refused: expected an integer for u64'));
    });

    test('diff: a BigInt is no value for a number field', () {
      // Act
      final got = outcome(single('f64'), {'a': BigInt.one});
      final int = outcome(single('u8'), {'a': BigInt.from(5)});

      // Assert
      expect(got, startsWith('refused: expected a number for f64'));
      expect(int, startsWith('refused: expected an integer for u8'));
    });

    test('diff: a whole double in a u2 slot, in bits and in packed is refused '
        '(Go-2)', () {
      // Arrange
      final slots = scheme(1, [
        u2([slot(0, 'a'), slot(1, 'b')]),
      ]);
      final counted = scheme(1, [u8(0, 'n'), bits(1, 'v', 0)]);

      // Act
      final slot3 = outcome(slots, {'a': 3.0, 'b': 1});
      final item1 = outcome(counted, {
        'n': 1,
        'v': [1.0],
      });

      // Assert
      expect(slot3, startsWith('refused: a: '));
      expect(item1, startsWith('refused: v: item 0 is 1.0'));
    });

    test('unpacked rows pack again: 64-bit and floats', () {
      // Arrange
      final layout = scheme(1, [
        u64(0, 'big'),
        i64(1, 'neg'),
        u32(2, 'mid'),
        f32(3, 's'),
        f64(4, 'd'),
      ]);
      final first = outcome(layout, {
        'big': 1 << 60,
        'neg': -5,
        'mid': 4294967295,
        's': 1.5,
        'd': double.nan,
      });

      // Act
      final row = unpackedRow(layout, first);

      // Assert
      expect(row['big'], 1 << 60);
      expect(outcome(layout, row), first);
    });
  });
}
