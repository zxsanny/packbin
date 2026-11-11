import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';
import '../support/position.dart';
import '../support/repo.dart';

class Ping {
  int code = 0;
}

Scheme<Ping> pingScheme() => rowScheme(2, Ping.new, [
  u8(0, 'code').bind<Ping>(get: (r) => r.code, set: (r, v) => r.code = v),
]);

void main() {
  group('first-byte dispatch', () {
    test('the first byte picks the handler, which gets the typed row', () {
      // Arrange
      Position? position;
      Ping? ping;
      Map<String, Object?>? note;
      final handlers = [
        positionScheme().on((row) => position = row),
        pingScheme().on((row) => ping = row),
        scheme(3, [u16(0, 'id')]).on((row) => note = row),
      ];

      // Act
      final first = unpack(unhex(goldenHex()), handlers);
      final second = unpack(unhex('0207'), handlers);
      final third = unpack(unhex('030500'), handlers);

      // Assert
      expect([first.ok, second.ok, third.ok], [true, true, true]);
      expect(
        [position!.lat, ping!.code, note],
        [
          500000000,
          7,
          {'id': 5},
        ],
      );
      expect(identical(first.row, position), isTrue);
    });

    test('a refused packet calls no handler', () {
      // Arrange
      var calls = 0;
      final handlers = [
        positionScheme().on((_) => calls++),
        pingScheme().on((_) => calls++),
      ];

      // Act
      final short = unpack(unhex('02'), handlers);
      final trailing = unpack(unhex('020700'), handlers);
      final unknown = unpack(unhex('0907'), handlers);

      // Assert
      expect(calls, 0);
      expect(
        [short.error, trailing.error, unknown.error],
        const [
          PackbinError(
            ErrorKind.short,
            field: 0,
            name: 'code',
            needed: 1,
            left: 0,
          ),
          PackbinError(ErrorKind.trailing, left: 1),
          PackbinError(ErrorKind.unknownType, actual: 9),
        ],
      );
    });

    test(
      'two handlers with one type number are refused before any byte is read',
      () {
        // Arrange
        final handlers = [
          pingScheme().on((_) {}),
          positionScheme().on((_) {}),
          pingScheme().on((_) {}),
        ];

        // Act
        Object? thrown;
        try {
          unpack(unhex('0207'), handlers);
        } on PackbinException catch (e) {
          thrown = e.error;
        }

        // Assert
        expect(
          thrown,
          const PackbinError(
            ErrorKind.schemeError,
            reason: 'duplicate type number 2',
          ),
        );
      },
    );

    test('an empty handler list is refused', () {
      // Act
      Object? thrown;
      try {
        unpack(unhex('0207'), []);
      } on PackbinException catch (e) {
        thrown = e.error;
      }

      // Assert
      expect(
        thrown,
        const PackbinError(
          ErrorKind.schemeError,
          reason: 'unpack needs at least one handler',
        ),
      );
    });

    test('type numbers 0 and 255 dispatch', () {
      // Arrange
      final low = scheme(0, [u8(0, 'n')]);
      final high = scheme(255, [u8(0, 'n')]);
      final seen = <int>[];
      final handlers = [
        low.on((row) => seen.add(0)),
        high.on((row) => seen.add(255)),
      ];

      // Act
      unpack(pack(high, {'n': 1}), handlers);
      unpack(pack(low, {'n': 1}), handlers);

      // Assert
      expect(seen, [255, 0]);
      expect(hex(pack(high, {'n': 1})), 'ff01');
    });
  });
}
