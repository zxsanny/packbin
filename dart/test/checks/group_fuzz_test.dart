import 'dart:math';
import 'dart:typed_data';

import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/group_schemes.dart';

void main() {
  group('unpack of a scheme with groups never throws on input', () {
    final layouts = <String, Scheme<Row>>{
      'anchored flags': anchoredFlags(),
      'group under flags': groupUnderFlags(),
      'nested flags': nestedFlags(),
      'when in a group': whenInGroup(),
      'sibling': groupSibling(),
      'split in a group': splitInGroup(),
      'late when': lateWhen(),
      'nested bit': nestedBit(),
      'flag byte in a group': flagByteInGroup(),
      'mark': markAndN(),
    };

    for (final MapEntry(key: name, value: layout) in layouts.entries) {
      test('$name: 5,000 random packets give a row or an error', () {
        // Arrange
        final random = Random(7);
        var read = 0;

        // Act
        for (var i = 0; i < 5000; i++) {
          final bytes = Uint8List(random.nextInt(9));
          for (var j = 0; j < bytes.length; j++) {
            bytes[j] = random.nextInt(256);
          }
          if (bytes.isNotEmpty) bytes[0] = layout.typeNumber;
          final result = unpackRow(bytes, layout);
          expect(result.row == null, result.error != null);
          if (result.ok) {
            read++;
            // Assert: a row read packs again, and that packet reads the same row.
            final again = unpackRow(pack(layout, result.row!), layout);
            expect(again.row, result.row, reason: '$bytes');
          }
        }
        expect(read, greaterThan(0));
      });
    }
  });
}
