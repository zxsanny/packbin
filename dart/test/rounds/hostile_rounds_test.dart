import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

Scheme<Map<String, Object?>> route() => scheme(0x34, [
  u16(0, 'sid'),
  u16(1, 'name'),
  flags(2, [u16(2, 'unit'), flagBool(3, 'straight'), u16(4, 'routeId')]),
  u8(5, 'count'),
  packed(2, 6, 'kinds', 5),
  times(7, 5, [i32(7, 'lat'), i32(8, 'lon')]),
  when(9, eq(3, true), [packed(1, 9, 'mask', 5, bias: -1)]),
]);

Scheme<Map<String, Object?>> batch() => scheme(1, [
  u8(0, 'n'),
  times(1, 0, [
    u8(1, 'len'),
    sized(2, 'p', 1),
    u2([slot(3, 'a'), slot(4, 'b'), slot(5, 'c')]),
    bits(6, 'v', 1),
  ]),
  repeat(7, [u16(7, 'tail')]),
]);

Scheme<Map<String, Object?>> flagRounds() => scheme(1, [
  u8(0, 'k'),
  flags(1, [
    repeat(1, [
      u8(1, 'w'),
      flags(2, [u8(2, 'v')]),
    ]),
    u8(3, 'z'),
  ]),
]);

/// Round trips of the route in an isolate; the count of wrong packets.
int routeTrips(Scheme<Map<String, Object?>> layout, int count) {
  var wrong = 0;
  final row = <String, Object?>{
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
  for (var i = 0; i < count; i++) {
    final raw = pack(layout, row);
    final back = unpackRow(raw, layout);
    if (hex(raw) != '3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101' ||
        back.row == null ||
        hex(pack(layout, back.row!)) != hex(raw)) {
      wrong++;
    }
  }
  return wrong;
}

void main() {
  group('unpack never throws on input bytes (rounds and counted kinds)', () {
    test(
      'random packets on every round scheme give a row or an error value',
      () {
        // Arrange
        final layouts = [route(), batch(), flagRounds()];
        final random = Random(4136);
        var thrown = 0;
        var refused = 0;

        // Act
        for (var i = 0; i < 30000; i++) {
          final bytes = Uint8List(random.nextInt(48) + 1);
          for (var j = 0; j < bytes.length; j++) {
            bytes[j] = random.nextInt(256);
          }
          final layout = layouts[i % layouts.length];
          bytes[0] = layout.typeNumber;
          try {
            final result = unpackRow(bytes, layout);
            if (result.ok != (result.row != null)) thrown++;
            if (!result.ok) refused++;
          } on Object {
            thrown++;
          }
        }

        // Assert
        expect(thrown, 0);
        expect(refused, greaterThan(0));
      },
    );

    test('every prefix and every one-byte change of a valid packet is read or refused', () {
      // Arrange
      final layout = route();
      final valid = unhex(
        '3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101',
      );
      var thrown = 0;

      // Act
      for (var cut = 1; cut <= valid.length; cut++) {
        try {
          unpackRow(valid.sublist(0, cut), layout);
        } on Object {
          thrown++;
        }
      }
      for (var at = 1; at < valid.length; at++) {
        for (final v in [0, 1, 0x7f, 0x80, 0xff]) {
          final copy = Uint8List.fromList(valid)..[at] = v;
          try {
            unpackRow(copy, layout);
          } on Object {
            thrown++;
          }
        }
      }

      // Assert
      expect(thrown, 0);
    });

    test('a count of 4294967295 on each counted kind returns at once', () {
      // Arrange
      final kinds = [
        scheme(1, [u32(0, 'n'), sized(1, 'v', 0)]),
        scheme(1, [u32(0, 'n'), bits(1, 'v', 0)]),
        scheme(1, [u32(0, 'n'), packed(2, 1, 'v', 0)]),
        scheme(1, [
          u32(0, 'n'),
          times(1, 0, [u8(1, 'v')]),
        ]),
      ];
      final raw = unhex('01ffffffff00');
      final watch = Stopwatch()..start();

      // Act
      final errors = [for (final k in kinds) unpackRow(raw, k).error!];

      // Assert
      expect(errors.map((e) => e.kind), everyElement(ErrorKind.short));
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('a round that reads no byte makes no progress', () {
    test(
      'a repeat of a zero-width bytes ends and the byte left is trailing',
      () {
        // Arrange
        final layout = scheme(1, [
          repeat(0, [bytes(0, 'e', 0)]),
        ]);

        // Act
        final error = unpackRow(unhex('01ff'), layout).error!;

        // Assert
        expect([error.kind, error.left], [ErrorKind.trailing, 1]);
      },
    );

    test('a times of a zero-width bytes with a count of 65535 is refused', () {
      // Arrange
      final layout = scheme(1, [
        u16(0, 'n'),
        times(1, 0, [bytes(1, 'e', 0)]),
      ]);

      // Act
      final result = unpackRow(unhex('01ffff'), layout);

      // Assert
      expect(result.row, isNull);
      expect([result.error!.name, result.error!.needed], ['e', 0]);
    });
  });

  group('a split flag byte keeps its own bits in every round', () {
    test('a byte read in each round reads its bits from that round', () {
      // Arrange
      final m = flagByte('m');
      final layout = scheme(1, [
        repeat(0, [m, m.bit(u8(0, 'a')), m.bit(u8(1, 'b'))]),
      ]);

      // Act
      final raw = pack(layout, {
        'a': [1, null],
        'b': [null, 2],
      });
      final back = unpackRow(raw, layout).row!;

      // Assert
      expect(hex(raw), '0101010202');
      expect(back, {
        'a': [1, null],
        'b': [null, 2],
      });
    });
  });

  group('a built scheme with rounds works across isolates', () {
    test('4 isolates each round trip the route 2,000 times', () async {
      // Arrange
      final layout = route();

      // Act
      final wrong = await Future.wait([
        for (var i = 0; i < 4; i++) Isolate.run(() => routeTrips(layout, 2000)),
      ]);

      // Assert
      expect(wrong, [0, 0, 0, 0]);
    });
  });
}
