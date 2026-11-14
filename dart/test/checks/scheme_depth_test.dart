import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/depth_schemes.dart';
import '../support/hex.dart';
import '../support/refusal.dart';

// AZ-4301 (contract scheme-depth): a scheme nested more than 256 levels is
// refused when it is built, before any walk that recurses.

/// One container kind: the fields of a chain [depth] deep, and the row.
typedef Chain = (List<Field>, Row) Function(int depth);

Chain _when = (d) => (whenChain(d), {'a': 1, 'b': 7});
Chain _nested = (d) => (groupChain(d), groupRow(d));
Chain _list = (d) => elementChain(d, dictForm: false);
Chain _dict = (d) => elementChain(d, dictForm: true);

final Map<String, Chain> _packable = {
  'when': _when,
  'nested': _nested,
  'list element rows': _list,
  'dict element rows': _dict,
};

/// Kinds that are only refused here: a chain of them does not pack, but the
/// depth is checked before every other rule.
final Map<String, List<Field> Function(int)> _refusedOnly = {
  'anchored group': (d) {
    var inner = <Field>[u8(0, 'b')];
    for (var i = 0; i < d; i++) {
      inner = [groupOf(0, 'g$i', inner)];
    }
    return inner;
  },
  'flags': (d) {
    var inner = <Field>[flagBool(0, 'b')];
    for (var i = 0; i < d; i++) {
      inner = [flags(0, inner)];
    }
    return inner;
  },
  'repeat': (d) {
    var inner = <Field>[u8(0, 'b')];
    for (var i = 0; i < d; i++) {
      inner = [repeat(0, inner)];
    }
    return inner;
  },
  'times': (d) {
    var inner = <Field>[u8(1, 'b')];
    for (var i = 0; i < d; i++) {
      inner = [times(1, 0, inner)];
    }
    return [u8(0, 'n'), ...inner];
  },
};

void main() {
  group('a scheme nested 256 levels builds, packs and unpacks', () {
    for (final MapEntry(key: kind, value: chain) in _packable.entries) {
      test('$kind: 256 levels at the default stack (AC-2)', () {
        // Arrange
        final (fields, row) = chain(256);
        final layout = scheme(1, fields);

        // Act
        final packed = pack(layout, row);
        final back = unpackRow(packed, layout);

        // Assert
        expect(back.error, isNull);
        // The matcher's deep equality stops at 100 levels; the rows print
        // every key and value in order, so the text is the whole value.
        expect(back.row.toString(), row.toString());
        expect(pack(layout, back.row!), packed);
      });
    }

    test('when and nested pack the bytes of the contract (AC-2)', () {
      // Arrange
      final whens = scheme(1, whenChain(256));
      final groups = scheme(1, groupChain(256));

      // Act
      final fromWhen = hex(pack(whens, {'a': 1, 'b': 7}));
      final fromGroup = hex(pack(groups, groupRow(256)));

      // Assert
      expect(fromWhen, '010107');
      expect(fromGroup, '0107');
    });
  });

  group('a scheme nested deeper than 256 levels is refused when built', () {
    for (final MapEntry(key: kind, value: chain) in _packable.entries) {
      for (final depth in [257, 1000, 50000]) {
        test('$kind: $depth levels (AC-1)', () {
          // Arrange
          final (fields, _) = chain(depth);
          final watch = Stopwatch()..start();

          // Act
          final error = refusal(() => scheme(1, fields));

          // Assert
          expect(error.toString(), depthRefusal);
          expect(error.field, isNull);
          expect(error.reason, contains('the limit is 256'));
          expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
        });
      }
    }

    for (final MapEntry(key: kind, value: chain) in _refusedOnly.entries) {
      test('$kind: 257 levels (AC-1)', () {
        // Arrange
        final fields = chain(257);

        // Act
        final error = refusal(() => scheme(1, fields));

        // Assert
        expect(error.toString(), depthRefusal);
      });
    }

    test('a typed row scheme is refused the same way (AC-1)', () {
      // Arrange
      final fields = whenChain(257);

      // Act
      final error = refusal(
        () => rowScheme(1, () => <String, Object?>{}, fields),
      );

      // Assert
      expect(error.toString(), depthRefusal);
    });

    test('the depth is checked before another rule of the scheme (AC-1)', () {
      // Arrange: a ninth flag bit at the bottom of a 257-level chain.
      var inner = <Field>[
        flags(0, [for (var i = 0; i < 9; i++) u8(i, 'f$i')]),
      ];
      for (var i = 0; i < 257; i++) {
        inner = [when(1, eq(0, 1), inner)];
      }

      // Act
      final error = refusal(() => scheme(1, [u8(0, 'a'), ...inner]));

      // Assert
      expect(error.toString(), depthRefusal);
    });
  });

  group('the boundary of the limit', () {
    for (final MapEntry(key: kind, value: chain) in _packable.entries) {
      test('$kind: 256 builds and 257 is refused (AC-1)', () {
        // Arrange
        final (at, _) = chain(256);
        final (over, _) = chain(257);

        // Act
        final built = scheme(1, at);
        final error = refusal(() => scheme(1, over));

        // Assert
        expect(built, isNotNull);
        expect(error.toString(), depthRefusal);
      });
    }

    test('an empty innermost container counts as a level (AC-1)', () {
      // Arrange
      Field chain(int depth) {
        Field inner = groupOf(0, 'e', []);
        for (var i = 1; i < depth; i++) {
          inner = flags(0, [inner]);
        }
        return inner;
      }

      // Act
      final built = scheme(1, [chain(256)]);
      final error = refusal(() => scheme(1, [chain(257)]));

      // Assert
      expect(built, isNotNull);
      expect(error.toString(), depthRefusal);
    });

    test(
      'the depth is the longest path, not the count of containers (AC-1)',
      () {
        // Arrange: a wide scheme of 1,000 shallow containers.
        final fields = <Field>[
          u8(0, 'a'),
          for (var i = 1; i <= 1000; i++) when(i, eq(0, 1), [u8(i, 'b$i')]),
        ];

        // Act
        final built = scheme(1, fields);

        // Assert
        expect(built, isNotNull);
      },
    );
  });
}
