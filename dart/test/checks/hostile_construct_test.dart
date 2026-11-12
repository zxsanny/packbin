import 'package:test/test.dart';

import '../hostile/hostile_cases.dart';
import '../hostile/hostile_constructs.dart';
import '../support/refusal.dart';

void main() {
  group('the construct cases of the shared hostile vectors', () {
    final cases = [
      for (final c in hostileCases())
        if (c.stage == 'construct') c,
    ];

    test('every construct case has a scheme here, and no scheme is stale', () {
      // Arrange
      final ids = [for (final c in cases) c.id];

      // Act
      final unknown = [
        for (final id in ids)
          if (!hostileConstructs.containsKey(id)) id,
      ];
      final stale = [
        for (final id in hostileConstructs.keys)
          if (!ids.contains(id)) id,
      ];

      // Assert
      expect(unknown, isEmpty);
      expect(stale, isEmpty);
      expect(ids, hasLength(24));
    });

    for (final c in cases) {
      final entry = hostileConstructs[c.id];
      if (entry == null) continue;
      test('${c.id} is refused at construction, naming the field', () {
        // Arrange and Act
        final error = refusal(entry.build);

        // Assert
        expect(c.accepts('scheme_error'), isTrue);
        expect(error.kind.term, 'scheme_error');
        expect(error.field, entry.field);
        expect(error.name, isNotEmpty);
      });
    }
  });
}
