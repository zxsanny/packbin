import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/depth_schemes.dart';
import '../support/refusal.dart';

// AZ-4306 and AZ-4307 (contract scheme-depth): a node that two parents share
// is measured once, and a flag bit adds no level of its own.

/// The levels of the diamond of the speed test and its time bound.
const _diamondLevels = 60;
const _diamondLimit = Duration(seconds: 1);

void main() {
  group('a field shared by two parents is measured once', () {
    test('a diamond of 60 levels is refused at once (AZ-4306 AC-1)', () {
      // Arrange
      final fields = diamondChain(_diamondLevels);
      final watch = Stopwatch()..start();

      // Act
      final error = refusal(() => scheme(1, fields));

      // Assert: the leaf is held twice, so the id rule refuses it.
      expect(error.toString(), contains('field id: expected'));
      expect(watch.elapsed, lessThan(_diamondLimit));
    });

    for (final shallowFirst in [true, false]) {
      final order = shallowFirst
          ? 'shared chain listed before the path'
          : 'shared chain listed after the path';
      test('a shared chain used deeper later is measured at its deepest '
          '($order, AZ-4306 AC-3)', () {
        // Arrange: 100 shared rows; the path adds 156 or 157 levels above.
        final at = sharedChain(
          path: 156,
          shared: 100,
          shallowFirst: shallowFirst,
        );
        final over = sharedChain(
          path: 157,
          shared: 100,
          shallowFirst: shallowFirst,
        );

        // Act
        final built = scheme(1, at);
        final error = refusal(() => scheme(1, over));

        // Assert
        expect(built, isNotNull);
        expect(error.toString(), depthRefusal);
      });
    }
  });

  group('a flag bit adds no level (AZ-4307)', () {
    test('129 whens that each hold a flag-byte bit build; 257 are refused', () {
      // Arrange: 129 whens and 129 bits would count 258 if a bit were a level.
      final at = flagBitWhenChain(129);
      final over = flagBitWhenChain(257);

      // Act
      final built = scheme(1, at);
      final error = refusal(() => scheme(1, over));

      // Assert
      expect(built, isNotNull);
      expect(error.toString(), depthRefusal);
    });

    test('a flag-byte bit over 256 flags builds; over 257 it is refused', () {
      // Arrange: with the bit as a level the 256 flags would count 257.
      final at = flagBitOverFlags(256);
      final over = flagBitOverFlags(257);

      // Act
      final built = scheme(1, at);
      final error = refusal(() => scheme(1, over));

      // Assert
      expect(built, isNotNull);
      expect(error.toString(), depthRefusal);
    });
  });
}
