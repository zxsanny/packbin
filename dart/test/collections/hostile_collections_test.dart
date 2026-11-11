import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/refusal.dart';
import '../support/repo.dart';

typedef Row = Map<String, Object?>;

/// The packet hex of the case [id] in fixtures/hostile/cases.txt.
String caseHex(String id) {
  for (final line in repoText('fixtures/hostile/cases.txt').split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length == 4 && parts[0] == id) return parts[3];
  }
  fail('no case $id');
}

PackbinError unpackError(Scheme<Row> layout, String id) {
  final result = unpackRow(unhex(caseHex(id)), layout);
  expect(result.row, isNull, reason: id);
  return result.error!;
}

void main() {
  group('the hostile cases that a list, a dict or a text reaches', () {
    final names = scheme(1, [dict('m', u8(0, 'v'))]);

    test('invalid_utf8 is bad_value', () {
      // Arrange
      final layout = scheme(1, [utf8Field(0, 'name')]);

      // Act
      final error = unpackError(layout, 'invalid_utf8');

      // Assert
      expect(error.kind.term, 'bad_value');
    });

    test('invalid_utf8_dict_key is bad_value', () {
      // Arrange and Act
      final error = unpackError(names, 'invalid_utf8_dict_key');

      // Assert
      expect(error.kind.term, 'bad_value');
    });

    for (final id in [
      'dict_keys_out_of_order',
      'dict_keys_repeated',
      'dict_keys_repeated_forms',
    ]) {
      test('$id is bad_value', () {
        // Arrange and Act
        final error = unpackError(names, id);

        // Assert
        expect(error.kind.term, 'bad_value');
      });
    }

    test('oversize_list_count is short_packet', () {
      // Arrange
      final layout = scheme(1, [list('xs', u8(0, 'x'))]);

      // Act
      final error = unpackError(layout, 'oversize_list_count');

      // Assert
      expect(error.kind.term, 'short_packet');
    });

    test('pack_lone_utf8_under_times_over_budget is a pack error', () {
      // Arrange
      final layout = scheme(1, [
        u32(0, 'n'),
        times(1, 0, [utf8Field(1, 's')]),
      ]);

      // Act
      final error = packRefusal(
        () => pack(layout, {'n': 65535, 's': 'q' * 65535}),
      );

      // Assert
      expect(error.reason, contains('16777216'));
    });

    Scheme<Row> itemsWithTimes(Field body) => scheme(1, [
      list(
        'items',
        nested('item', [
          u32(0, 'n'),
          times(1, 0, [body]),
        ]),
      ),
    ]);

    test('pack_element_times_over_budget is a pack error naming k', () {
      // Arrange
      final layout = itemsWithTimes(u64(1, 'k'));
      final items = [
        for (var i = 0; i < 40; i++) {'n': 65535, 'k': 5},
      ];

      // Act
      final error = packRefusal(() => pack(layout, {'items': items}));

      // Assert
      expect(error.name, 'k');
      expect(
        error.reason,
        'k: the rounds would hold 1048577 slots, above the limit of 1048576 slots',
      );
    });

    test('pack_element_times_over_bytes_budget is a pack error', () {
      // Arrange
      final layout = itemsWithTimes(utf8Field(1, 's'));
      final items = [
        for (var i = 0; i < 16; i++) {'n': 65535, 's': 'q' * 16},
      ];

      // Act
      final error = packRefusal(() => pack(layout, {'items': items}));

      // Assert
      expect(error.reason, contains('16777216'));
    });
  });
}
