import 'dart:convert';
import 'dart:typed_data';

import 'package:packbin/src/text/text.dart';
import 'package:test/test.dart';

import 'text_vectors.dart';

/// AC-1 and AC-4 (AZ-4137): every row of fixtures/text/vectors.txt run by
/// the standalone codec.
void main() {
  final rows = loadTextRows();
  List<TextRow> of(String kind) => rows.where((r) => r.kind == kind).toList();

  test('rows: every kind the tests run is in the file, and no other', () {
    // Arrange
    final counts = <String, int>{};

    // Act
    for (final row in rows) {
      counts[row.kind] = (counts[row.kind] ?? 0) + 1;
    }

    // Assert
    expect(counts.keys.toSet(), {'enc', 'alt', 'bad', 'ref', 'flip'});
    expect(counts['enc'], greaterThanOrEqualTo(300));
    expect(counts['alt'], greaterThanOrEqualTo(5));
    expect(counts['bad'], greaterThanOrEqualTo(30));
    expect(counts['ref'], 4);
    expect(counts['flip'], greaterThanOrEqualTo(20));
  });

  test('enc: encode gives exactly the row bytes', () {
    // Arrange
    final mismatches = <String>[];
    var ran = 0;

    // Act
    for (final row in of('enc')) {
      final text = row.text;
      if (hex(utf8.encode(text)) != hex(row.textBytes)) {
        mismatches.add('${row.id}: the row text is not what the test encodes');
      }
      final field = encodeText(text);
      if (hex(field) != hex(row.bytes)) {
        mismatches.add('${row.id}: ${hex(field)}');
      }
      ran++;
    }

    // Assert
    expect(mismatches, isEmpty);
    expect(ran, greaterThan(0));
  });

  test('enc and alt: decode gives the row text and uses every byte', () {
    // Arrange
    final mismatches = <String>[];
    final ran = {'enc': 0, 'alt': 0};

    // Act
    for (final row in [...of('enc'), ...of('alt')]) {
      final field = row.bytes;
      final read = decodeText(field);
      if (read is! TextValue ||
          hex(utf8.encode(read.value)) != hex(row.textBytes) ||
          read.next != field.length) {
        mismatches.add('${row.id}: $read');
      }
      ran[row.kind] = ran[row.kind]! + 1;
    }

    // Assert
    expect(mismatches, isEmpty);
    expect(ran['enc'], greaterThan(0));
    expect(ran['alt'], greaterThan(0));
  });

  test('alt: the row field is not what the encoder writes', () {
    // Arrange
    final same = <String>[];
    var ran = 0;

    // Act
    for (final row in of('alt')) {
      final field = encodeText(row.text);
      if (hex(field) == hex(row.bytes)) same.add(row.id);
      ran++;
    }

    // Assert
    expect(same, isEmpty);
    expect(ran, greaterThan(0));
  });

  test('bad: decode gives the error value of the row kind', () {
    // Arrange
    final mismatches = <String>[];
    var ran = 0;

    // Act
    for (final row in of('bad')) {
      final read = decodeText(row.bytes);
      if (read is! TextFailure || read.kind.name != row.rest[0]) {
        mismatches.add('${row.id}: wanted ${row.rest[0]}, got $read');
      }
      ran++;
    }

    // Assert
    expect(mismatches, isEmpty);
    expect(ran, greaterThan(0));
  });

  test('flip: a flipped payload bit gives a string that ends before the 5a, '
      'or an error value', () {
    // Arrange
    final byId = {for (final row in of('enc')) row.id: row};
    final mismatches = <String>[];
    var ran = 0;
    var strings = 0;
    var errors = 0;

    // Act
    for (final row in of('flip')) {
      final field = byId[row.rest[0]]!.bytes;
      final header = field[0] < 0x80 ? 1 : 2;
      for (var byte = header; byte < field.length; byte++) {
        for (var bit = 0; bit < 8; bit++) {
          final damaged = Uint8List(field.length + 1)
            ..setAll(0, field)
            ..[field.length] = 0x5a;
          damaged[byte] ^= 1 << bit;
          final read = decodeText(damaged);
          if (read is TextValue) {
            strings++;
            if (read.next != field.length || damaged[read.next] != 0x5a) {
              mismatches.add('${row.id} byte $byte bit $bit: ${read.next}');
            }
          } else {
            errors++;
          }
        }
      }
      ran++;
    }

    // Assert
    expect(mismatches, isEmpty);
    expect(ran, greaterThan(0));
    expect(strings, greaterThan(0));
    expect(errors, greaterThan(0));
  });

  test('ref: the strings of each ring packet decode in place and encode '
      'back to the packet', () {
    // Arrange: the strings of each packet in wire order (dictionary keys
    // ascend by their UTF-8 bytes), from scripts/text/gen_vectors.py
    const expected = <String, List<String>>{
      'ref.user': [
        'zxsanny', 'user', 'dispatcher', 'channel', 'read', 'map', 'read', //
        'gps_fix', 'set', 'edit', 'store', 'read', 'write',
      ],
      'ref.user_ua': [
        'Олександр', 'диспетчер', 'Оператор', 'канал', 'читати', 'карта', //
        'читати', 'правити',
      ],
      'ref.nested': [
        'map', 'op', 'gps_fix', 'store', 'op', 'read', 'op', 'write', //
      ],
      'ref.nested_mixed': [
        'store', 'op', 'ЧИТАТИ', 'Карта', 'note', 'увага 48.46, 35.04', //
        'op', 'gps_fix',
      ],
    };
    var ran = 0;

    for (final row in of('ref')) {
      final packet = row.bytes;
      final walk = RingWalk(packet);

      // Act
      if (row.id.startsWith('ref.user')) {
        walk.userPacket();
      } else {
        walk.nestedPacket();
      }

      // Assert
      expect(walk.failure, isNull, reason: row.id);
      expect(walk.offset, packet.length, reason: row.id);
      expect(walk.strings, expected[row.id], reason: row.id);
      expect(hex(walk.rebuilt.takeBytes()), hex(packet), reason: row.id);
      ran++;
    }
    expect(ran, 4);
  });
}

/// Walks a ring packet by hand (the scheme walker is a later task): a type
/// byte, then 2-byte little-endian counts and string fields. Every string is
/// decoded in place and encoded again into [rebuilt].
final class RingWalk {
  RingWalk(this.packet) {
    rebuilt.addByte(packet[0]);
  }

  final Uint8List packet;
  final BytesBuilder rebuilt = BytesBuilder();
  final List<String> strings = [];
  int offset = 1;
  TextFailure? failure;

  /// A string, a list of strings, a dictionary of string to list of strings.
  void userPacket() {
    _string();
    _strings();
    for (var pairs = _count(); pairs > 0; pairs--) {
      _string();
      _strings();
    }
  }

  /// A dictionary of string to a list of dictionaries of string to string.
  void nestedPacket() {
    for (var keys = _count(); keys > 0; keys--) {
      _string();
      for (var rows = _count(); rows > 0; rows--) {
        for (var pairs = _count(); pairs > 0; pairs--) {
          _string();
          _string();
        }
      }
    }
  }

  void _strings() {
    for (var n = _count(); n > 0; n--) {
      _string();
    }
  }

  int _count() {
    if (failure != null) return 0;
    if (offset + 2 > packet.length) {
      failure = TextFailure(TextRefusal.short, 2, packet.length - offset);
      return 0;
    }
    final count = packet[offset] | (packet[offset + 1] << 8);
    rebuilt.add(packet.sublist(offset, offset + 2));
    offset += 2;
    return count;
  }

  void _string() {
    if (failure != null) return;
    switch (decodeText(packet, offset)) {
      case TextValue(:final value, :final next):
        strings.add(value);
        rebuilt.add(encodeText(value));
        offset = next;
      case final TextFailure f:
        failure = f;
    }
  }
}
