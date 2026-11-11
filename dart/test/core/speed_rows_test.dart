import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../../tool/speed.dart';
import '../support/hex.dart';
import '../support/repo.dart';

void main() {
  group('AC-8 the rows the compiled speed program measures', () {
    test('the round-trip row is the AC-1 row', () {
      // Act
      final raw = pack(targetScheme(), goldenTarget());

      // Assert
      expect(hex(raw), goldenHex());
    });

    test('the frame is 40 bytes and unpacks to the row that was packed', () {
      // Arrange
      final packet = framePacket();

      // Act
      final row = unpackRow(packet, frameScheme()).row!;

      // Assert
      expect(packet.length, 40);
      expect(
        [
          row.sid,
          row.heading,
          row.speed,
          row.altitude,
          row.time,
          row.climb,
          row.range,
          row.battery,
        ],
        [7, 90, 12, -40, 1790000000000, 1.5, 1234.5, 4100],
      );
    });

    test('both measured loops give right rows', () {
      // Act
      final trips = timeRoundTrips();
      final frames = timeFrameUnpacks();

      // Assert
      expect(trips, isNonNegative);
      expect(frames, isNonNegative);
    });
  });
}
