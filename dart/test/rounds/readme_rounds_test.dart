import 'dart:convert';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';

/// One README example: its scheme, the row, and the README hex.
typedef Example = (
  String,
  Scheme<Map<String, Object?>>,
  Map<String, Object?>,
  String,
);

Scheme<Map<String, Object?>> routeScheme() => scheme(0x34, [
  u16(0, 'sid'),
  u16(1, 'name'),
  flags(2, [u16(2, 'unit'), flagBool(3, 'straight'), u16(4, 'routeId')]),
  u8(5, 'count'),
  packed(2, 6, 'kinds', 5),
  times(7, 5, [i32(7, 'lat'), i32(8, 'lon')]),
  when(9, eq(3, true), [packed(1, 9, 'mask', 5, bias: -1)]),
]);

const routeHex = '3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101';

final routeRow = <String, Object?>{
  'sid': 16,
  'name': 21,
  'straight': true,
  'routeId': 45,
  'count': 2,
  'kinds': [1, 3],
  'lat': [500000000, 500010000],
  'lon': [300000000, 300010000],
  'mask': [1],
};

final examples = <Example>[
  (
    'repeat: two points',
    scheme(1, [
      repeat(0, [i32(0, 'lat'), i32(1, 'lon')]),
    ]),
    {
      'lat': [10, 30],
      'lon': [20, 40],
    },
    '010a000000140000001e00000028000000',
  ),
  (
    'repeat: a when in the round, one entry short',
    scheme(1, [
      repeat(0, [
        u8(0, 'k'),
        when(1, eq(0, 1), [u8(1, 'v')]),
      ]),
    ]),
    {
      'k': [1, 2],
      'v': [9, null],
    },
    '01010902',
  ),
  (
    'sized: count 3 and uav',
    scheme(1, [u16(0, 'n'), sized(1, 'payload', 0)]),
    {'n': 3, 'payload': Uint8List.fromList(utf8.encode('uav'))},
    '010300756176',
  ),
  (
    'two-bit slots 0 1 2 3',
    scheme(1, [
      u2([slot(0, 'a'), slot(1, 'b'), slot(2, 'c'), slot(3, 'd')]),
    ]),
    {'a': 0, 'b': 1, 'c': 2, 'd': 3},
    '01e4',
  ),
  (
    'two-bit slots: one slot of 1',
    scheme(1, [
      u2([slot(0, 'a')]),
    ]),
    {'a': 1},
    '0101',
  ),
  (
    'bits: eight 1-bits',
    scheme(1, [u8(0, 'n'), bits(1, 'segs', 0)]),
    {
      'n': 8,
      'segs': [1, 1, 1, 1, 1, 1, 1, 1],
    },
    '0108ff',
  ),
  (
    'bits: nine spill into a second byte',
    scheme(1, [u8(0, 'n'), bits(1, 'segs', 0)]),
    {
      'n': 9,
      'segs': [1, 1, 1, 1, 1, 1, 1, 1, 1],
    },
    '0109ff01',
  ),
  (
    'packed: width 2, values 0 1 2 3',
    scheme(1, [u8(0, 'n'), packed(2, 1, 'kinds', 0)]),
    {
      'n': 4,
      'kinds': [0, 1, 2, 3],
    },
    '0104e4',
  ),
  (
    'packed: width 1, bias -1, count 9',
    scheme(1, [u8(0, 'n'), packed(1, 1, 'legs', 0, bias: -1)]),
    {
      'n': 9,
      'legs': [1, 1, 1, 1, 1, 1, 1, 1],
    },
    '0109ff',
  ),
  (
    'packed: width 1, bias -1, count 1 writes no bitset bytes',
    scheme(1, [u8(0, 'n'), packed(1, 1, 'legs', 0, bias: -1)]),
    {'n': 1, 'legs': <int>[]},
    '0101',
  ),
  (
    'times: two points then a tail',
    scheme(1, [
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
    '01020a000000140000001e0000002800000007',
  ),
  ('route: packed and times together', routeScheme(), routeRow, routeHex),
];

void main() {
  group('README round examples', () {
    for (final (name, layout, row, wire) in examples) {
      test('$name: packs to the README hex and unpacks back', () {
        // Arrange
        final want = wire;

        // Act
        final raw = pack(layout, row);
        final back = unpackRow(unhex(want), layout);
        final again = pack(layout, back.row!);

        // Assert
        expect(hex(raw), want);
        expect(back.error, isNull);
        expect(hex(again), want);
      });
    }

    test('the sized payload unpacks to the three bytes of uav', () {
      // Arrange
      final layout = scheme(1, [u16(0, 'n'), sized(1, 'payload', 0)]);

      // Act
      final row = unpackRow(unhex('010300756176'), layout).row!;

      // Assert
      expect(row['payload'], [0x75, 0x61, 0x76]);
    });

    test(
      'the route unpacks to its fields, and a clear bool drops the mask',
      () {
        // Arrange
        final layout = routeScheme();

        // Act
        final row = unpackRow(unhex(routeHex), layout).row!;
        final cleared = {...row, 'straight': false};

        // Assert
        expect(row['kinds'], [1, 3]);
        expect(row['lat'], [500000000, 500010000]);
        expect(row['mask'], [1]);
        expect(
          hex(pack(layout, cleared)),
          '3410001500042d00020d0065cd1d00a3e111108ccd1d10cae111',
        );
      },
    );

    test(
      'the route cut inside the second longitude names lon and the bytes',
      () {
        // Arrange
        final layout = routeScheme();
        final cut = unhex(routeHex).sublist(0, 24);

        // Act
        final error = unpackRow(cut, layout).error!;

        // Assert
        expect([error.name, error.needed, error.left], ['lon', 4, 2]);
      },
    );

    test('a refused example packs nothing: a payload of the wrong length', () {
      // Arrange
      final layout = scheme(1, [u16(0, 'n'), sized(1, 'payload', 0)]);

      // Act
      final error = packRefusal(
        () => pack(layout, {'n': 3, 'payload': Uint8List(2)}),
      );

      // Assert
      expect(error.name, 'payload');
    });
  });
}
