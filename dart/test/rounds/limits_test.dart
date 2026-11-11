import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/refusal.dart';

/// A packet of the type byte and [rest] bytes of [value].
Uint8List packet(int rest, [int value = 1]) {
  final out = Uint8List(rest + 1)..fillRange(0, rest + 1, value);
  out[0] = 1;
  return out;
}

/// A `repeat` of [names] u8 members named f0, f1, and so on.
Scheme<Map<String, Object?>> wide(int names) => scheme(1, [
  repeat(0, [for (var i = 0; i < names; i++) u8(i, 'f$i')]),
]);

void main() {
  group('the default round and slot limits on unpack', () {
    test('65535 rounds of a repeat are read', () {
      // Arrange
      final layout = wide(1);

      // Act
      final result = unpackRow(packet(65535), layout);

      // Assert
      expect((result.row!['f0'] as List).length, 65535);
    });

    test('65536 rounds are refused as too_many, before the round is read', () {
      // Arrange
      final layout = wide(1);

      // Act
      final result = unpackRow(packet(65536), layout);

      // Assert
      expect(result.row, isNull);
      expect(
        [result.error!.kind, result.error!.needed, result.error!.left],
        [ErrorKind.tooMany, 0, 1],
      );
    });

    test('a times refuses the round past the limit, not the count', () {
      // Arrange
      final layout = scheme(1, [
        u32(0, 'n'),
        times(1, 0, [u8(1, 'x')]),
      ]);
      final raw = Uint8List(4 + 70000 + 1)..[0] = 1;
      // 70000 = 0x11170, little-endian: 70 11 01 00
      raw.setRange(1, 5, [0x70, 0x11, 0x01, 0x00]);

      // Act
      final result = unpackRow(raw, layout);

      // Assert
      expect(result.error!.kind, ErrorKind.tooMany);
      expect(result.error!.name, 'x');
    });

    test('rounds of 16 names fit the slot limit at 65535 rounds', () {
      // Arrange
      final layout = wide(16);

      // Act
      final result = unpackRow(packet(16 * 65535), layout);

      // Assert
      expect(result.ok, isTrue);
    });

    test('rounds of 17 names pass the slot limit before 65535 rounds', () {
      // Arrange
      final layout = wide(17);

      // Act
      final result = unpackRow(packet(17 * 61681), layout);

      // Assert
      expect(result.error!.kind, ErrorKind.tooMany);
      expect(result.error!.reason, contains('1048576 slots'));
    });
  });

  group('the default limits on pack', () {
    Scheme<Map<String, Object?>> timesOf(int names) => scheme(1, [
      u32(0, 'n'),
      times(1, 0, [for (var i = 0; i < names; i++) u8(i + 1, 'f$i')]),
    ]);
    Map<String, Object?> lone(int n, int names) => {
      'n': n,
      for (var i = 0; i < names; i++) 'f$i': 1,
    };

    test('a times count above 65535 is refused before any round', () {
      // Arrange
      final layout = timesOf(1);

      // Act
      final error = packRefusal(() => pack(layout, lone(65536, 1)));

      // Assert
      expect(error.reason, contains('above the limit of 65535 rounds'));
    });

    test('a times count of 65535 packs', () {
      // Arrange
      final layout = timesOf(1);

      // Act
      final raw = pack(layout, lone(65535, 1));

      // Assert
      expect(raw.length, 1 + 4 + 65535);
    });

    test('a repeat list above 65535 entries is refused naming the member', () {
      // Arrange
      final layout = wide(1);

      // Act
      final error = packRefusal(
        () => pack(layout, {'f0': List<int>.filled(65536, 1)}),
      );

      // Assert
      expect(
        [error.name, error.reason],
        ['f0', contains('the repeat count is 65536')],
      );
    });

    test('rounds past the slot limit are refused as unpack would', () {
      // Arrange
      final layout = timesOf(17);

      // Act
      final error = packRefusal(() => pack(layout, lone(65535, 17)));

      // Assert
      expect(error.reason, contains('1048576 slots'));
    });

    test('a packet past 16,777,216 bytes is refused', () {
      // Arrange
      final layout = scheme(1, [
        u32(0, 'n'),
        times(1, 0, [u16(1, 'len'), sized(2, 'p', 1)]),
      ]);
      final shared = Uint8List(300);
      final row = {
        'n': 65535,
        'len': 300,
        'p': List<Uint8List>.filled(65535, shared),
      };

      // Act
      final error = packRefusal(() => pack(layout, row));

      // Assert
      expect(error.reason, contains('above the limit of 16777216 bytes'));
    });
  });
}
