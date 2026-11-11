import 'dart:typed_data';

import 'package:packbin/src/frame/frame_results.dart';
import 'package:packbin/src/frame/frame_types.dart';
import 'package:packbin/src/frame/mac_key.dart';
import 'package:packbin/src/frame/replay_window.dart';
import 'package:test/test.dart';

import 'frame_vectors.dart';

// AZ-4142: the replay window, exact over 64 unsigned bits (a Dart int is
// signed and wraps, so the window holds BigInt), and the parts of the
// MAC-only call. The 17-step table of the contract is in the vector file.

final BigInt max = (BigInt.one << 64) - BigInt.one;
BigInt n(int value) => BigInt.from(value);
List<BigInt> state(ReplayWindow w) => [w.top, w.bits];

void main() {
  group('replay window', () {
    test('the window slides and forgets like the contract table', () {
      // Arrange
      final window = ReplayWindow();

      // Act
      for (final counter in [10, 12, 9, 200]) {
        window.commit(n(counter));
      }

      // Assert
      expect(state(window), [n(200), BigInt.one]);
      expect(window.check(n(136)), Freshness.tooOld);
      expect(window.check(n(137)), Freshness.fresh);
      expect(window.check(n(200)), Freshness.duplicate);
      expect(window.check(n(201)), Freshness.fresh);
    });

    test('counters at 2^63 and 2^64 - 1 are exact and never wrap', () {
      // Arrange
      final window = ReplayWindow(n(5), BigInt.zero);
      final high = BigInt.one << 63;

      // Act
      final same = window.check(n(5));
      window.commit(high);
      final afterHigh = state(window);
      final belowHigh = window.check(high - BigInt.one);
      window.commit(max - BigInt.one);
      window.commit(max);

      // Assert
      expect(same, Freshness.fresh);
      expect(afterHigh, [high, BigInt.one]);
      expect(belowHigh, Freshness.fresh);
      expect(state(window), [max, n(3)]);
      expect(window.check(max - BigInt.one), Freshness.duplicate);
      expect(window.check(max - n(64)), Freshness.tooOld);
      expect(window.check(max - n(63)), Freshness.fresh);
      expect(window.check(BigInt.zero), Freshness.tooOld);
      window.commit(BigInt.zero);
      expect(state(window), [max, n(3)]);
    });

    test(
      'bit 63 is kept by a shift of one and nothing above 64 bits stays',
      () {
        // Arrange
        final top = BigInt.one << 63;
        final window = ReplayWindow(n(100), top | BigInt.one);

        // Act
        window.commit(n(101));
        final kept = window.bits;
        window.commit(n(165));

        // Assert
        expect(kept, n(3));
        expect(state(window), [n(165), BigInt.one]);
      },
    );

    test('check never changes the state', () {
      // Arrange
      final window = ReplayWindow(n(7), n(5));

      // Act
      final results = [
        window.check(n(7)),
        window.check(n(6)),
        window.check(n(3)),
      ];

      // Assert
      expect(results, [Freshness.duplicate, Freshness.fresh, Freshness.fresh]);
      expect(state(window), [n(7), n(5)]);
    });

    test(
      'a value outside 0 to 2^64 - 1 is a RangeError and changes nothing',
      () {
        // Arrange
        final window = ReplayWindow(n(7), n(5));

        // Act and assert
        for (final bad in [-BigInt.one, BigInt.one << 64]) {
          expect(ReplayWindow.isCounter(bad), isFalse);
          expect(() => window.check(bad), throwsRangeError);
          expect(() => window.commit(bad), throwsRangeError);
          expect(() => ReplayWindow(bad, BigInt.one), throwsRangeError);
          expect(() => ReplayWindow(BigInt.one, bad), throwsRangeError);
        }
        expect(ReplayWindow.isCounter(max), isTrue);
        expect(state(window), [n(7), n(5)]);
        expect(ReplayWindow.size, 64);
      },
    );
  });

  group('MAC-only call', () {
    final rows = loadFixture();
    final row = rowOf(rows, 'mac.len0.parts3');
    MacKey derive() => MacKey.derive(
      bytes(row, 'key'),
      number(row, 'epoch'),
      bytes(row, 'label'),
    )!;

    test('no part, one empty part and three empty parts give the same tag', () {
      // Arrange
      final mac = derive();
      final empty = Uint8List(0);

      // Act
      final tags = [
        for (final parts in [
          <Uint8List>[],
          [empty],
          [empty, empty, empty],
        ])
          hex((mac.tag(parts, 4) as MacTag).tag),
      ];

      // Assert
      expect(tags.toSet(), {row['tag']});
    });

    test('a shorter tag is the start of a longer one and is a fresh copy', () {
      // Arrange
      final mac = derive();
      final message = [
        Uint8List.fromList([1, 2, 3]),
      ];

      // Act
      final full = (mac.tag(message, 32) as MacTag).tag;
      final short = (mac.tag(message, 8) as MacTag).tag;
      short[0] ^= 0xff;
      final again = (mac.tag(message, 8) as MacTag).tag;

      // Assert
      expect(full, hasLength(32));
      expect(hex(again), hex(Uint8List.sublistView(full, 0, 8)));
      expect(mac.epoch, number(row, 'epoch'));
    });

    test('a tag of the wrong message or the wrong split order is refused', () {
      // Arrange
      final mac = derive();
      final a = Uint8List.fromList([1, 2]);
      final b = Uint8List.fromList([3]);
      final tag = (mac.tag([a, b], 16) as MacTag).tag;

      // Act
      final joined = mac.verify([
        Uint8List.fromList([1, 2, 3]),
      ], tag);
      final swapped = mac.verify([b, a], tag);
      final other = mac.verify([a], tag);

      // Assert
      expect(joined, isTrue);
      expect(swapped, isFalse);
      expect(other, isFalse);
    });
  });
}
