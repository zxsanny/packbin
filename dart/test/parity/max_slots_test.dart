import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import 'parity_support.dart';

// TypeScript table `loop22-max-slots.test.ts` (U17, AZ-2415): the default
// maxSlots is 1,048,576, a quarter of 4,194,304, so a 4.3 MB packet costs at
// most a quarter of the unpack memory it did. The packets are the F10 and
// "wide" shapes of `reference_loop22.md` section 2, built as bytes.

/// `list items of nested item { u8 n; times(n) { 64 u8 names k0..k63 } }`.
Scheme<Row> f10([int? maxSlots]) {
  final layout = scheme(1, [
    list(
      'items',
      nested('item', [
        u8(0, 'n'),
        times(1, 0, [for (var i = 0; i < 64; i++) u8(1 + i, 'k$i')]),
      ]),
    ),
  ]);
  return maxSlots == null ? layout : layout.withLimits(maxSlots: maxSlots);
}

/// `u32 n; times(n) { 65 u8 names }`, n = 65,535, all bytes 1.
Scheme<Row> wide() => scheme(1, [
  u32(0, 'n'),
  times(1, 0, [for (var i = 0; i < 65; i++) u8(1 + i, 'k$i')]),
]);

Uint8List f10Packet() => Uint8List(3 + 65 * 65535)
  ..fillRange(0, 3 + 65 * 65535, 1)
  ..setRange(0, 3, [1, 0xff, 0xff]);

Uint8List widePacket() => Uint8List(5 + 65 * 65535)
  ..fillRange(0, 5 + 65 * 65535, 1)
  ..setRange(0, 5, [1, 0xff, 0xff, 0, 0]);

void main() {
  group('loop22-max-slots (U17)', () {
    test('U17 AC-1 a scheme built with no limits reads 65,535 rounds and '
        '1,048,576 slots', () {
      // Act
      final layout = scheme(1, [
        u32(0, 'n'),
        times(1, 0, [u8(1, 'k')]),
      ]);

      // Assert
      expect(
        [
          layout.maxRounds,
          layout.maxSlots,
          Scheme.defaultMaxRounds,
          Scheme.defaultMaxSlots,
        ],
        [65535, 1048576, 65535, 1048576],
      );
    });

    test('U17 AC-2 the F10 packet (4,259,778 bytes, 4,194,240 slots) is '
        'refused at the default, naming k0 at item 16,385', () {
      // Arrange
      final packet = f10Packet();
      var rows = 0;

      // Act
      final result = unpack(packet, [f10().on((_) => rows++)]);

      // Assert
      final e = result.error!;
      expect(packet.length, 4259778);
      expect(e.kind, ErrorKind.tooMany);
      expect([e.name, e.left], ['k0', 3194814]);
      expect(rows, 0);
    });

    test('U17 AC-3 with maxSlots raised to 4,194,304 the same packet '
        'unpacks', () {
      // Arrange
      var rows = 0;

      // Act
      final result = unpack(f10Packet(), [f10(4194304).on((_) => rows++)]);

      // Assert
      expect(result.error, isNull);
      expect(rows, 1);
    });

    test('U17 reference: the wide packet is refused at round 16,132', () {
      // Arrange
      final packet = widePacket();

      // Act
      final result = unpack(packet, [wide().on((_) {})]);

      // Assert
      final e = result.error!;
      expect(packet.length, 4259780);
      expect(e.kind, ErrorKind.tooMany);
      expect(e.left, 3211260);
    });
  });
}
