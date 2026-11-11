import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/position.dart';

class Other {
  int n = 0;
}

/// The scheme error [body] throws; fails when the scheme is built.
PackbinError refusal(Object Function() body) {
  try {
    body();
    fail('the scheme was built');
  } on PackbinException catch (e) {
    return e.error;
  }
}

PackbinError refused(int? field, String name, String reason) => PackbinError(
  ErrorKind.schemeError,
  field: field,
  name: name,
  reason: reason,
);

void main() {
  group('the scheme checks the walker relies on', () {
    test('a type number outside 0..255 is refused', () {
      // Act
      final high = refusal(() => scheme(256, [u8(0, 'n')]));
      final low = refusal(() => scheme(-1, [u8(0, 'n')]));

      // Assert
      expect(high, refused(null, '', 'type number 256: expected 0..255'));
      expect(low, refused(null, '', 'type number -1: expected 0..255'));
    });

    test(
      'a gap, a repeated id and an anchor that is not the next id are refused',
      () {
        // Act
        final gap = refusal(() => scheme(1, [u8(0, 'a'), u8(2, 'b')]));
        final repeated = refusal(() => scheme(1, [u8(0, 'a'), u8(0, 'b')]));
        final anchor = refusal(
          () => scheme(1, [
            u8(0, 'a'),
            flags(2, [u8(1, 'b')]),
          ]),
        );

        // Assert
        expect(gap, refused(2, 'b', 'field id: expected 1, got 2'));
        expect(repeated, refused(0, 'b', 'field id: expected 1, got 0'));
        expect(anchor, refused(2, 'b', 'field id: expected 1, got 2'));
      },
    );

    test('a bool outside flags is refused', () {
      // Act
      final top = refusal(() => scheme(1, [flagBool(0, 'on')]));
      final inWhen = refusal(
        () => scheme(1, [
          u8(0, 'mode'),
          when(1, eq(0, 1), [flagBool(1, 'on')]),
        ]),
      );

      // Assert
      expect(
        top,
        refused(
          0,
          'on',
          'bool on: allowed only directly inside flags or a flag bit; move it into flags',
        ),
      );
      expect(inWhen.field, 1);
    });

    test('a ninth flags member and a ninth bit of a flag byte are refused', () {
      // Arrange
      final m = flagByte('m');

      // Act
      final combined = refusal(
        () => scheme(1, [
          flags(0, [for (var i = 0; i < 9; i++) u8(i, 'f$i')]),
        ]),
      );
      final split = refusal(
        () => scheme(1, [m, for (var i = 0; i < 9; i++) m.bit(u8(i, 'f$i'))]),
      );

      // Assert
      expect(
        combined,
        refused(0, 'f0', 'flags: ninth bit (f8); a flag byte holds 8 bits'),
      );
      expect(
        split,
        refused(
          8,
          'f8',
          'flag byte "m": ninth bit (f8); a flag byte holds 8 bits',
        ),
      );
    });

    test('a flag bit whose byte is not read earlier in its scope is refused', () {
      // Arrange
      final m = flagByte('m');

      // Act
      final never = refusal(() => scheme(1, [m.bit(u8(0, 'a'))]));
      final later = refusal(() => scheme(1, [m.bit(u8(0, 'a')), m]));
      final inWhen = refusal(
        () => scheme(1, [
          u8(0, 'mode'),
          when(1, eq(0, 1), [m]),
          m.bit(u8(1, 'a')),
        ]),
      );

      // Assert
      final reason =
          'flag bit 0 (a): its flag byte is not read earlier in the same scope';
      expect(
        [never, later],
        [refused(0, 'a', reason), refused(0, 'a', reason)],
      );
      expect(inWhen, refused(1, 'a', reason));
    });

    test('a when names an earlier integer or bool of its scope', () {
      // Act
      final later = refusal(
        () => scheme(1, [
          when(0, eq(0, 1), [u8(0, 'a')]),
        ]),
      );
      final float = refusal(
        () => scheme(1, [
          f32(0, 'x'),
          when(1, eq(0, 1), [u8(1, 'a')]),
        ]),
      );
      final boolFalse = refusal(
        () => scheme(1, [
          flags(0, [flagBool(0, 'on')]),
          when(1, eq(0, false), [u8(1, 'a')]),
        ]),
      );
      final fraction = refusal(
        () => scheme(1, [
          u8(0, 'mode'),
          when(1, eq(0, 1.0), [u8(1, 'a')]),
        ]),
      );

      // Assert
      expect(
        later,
        refused(
          0,
          'a',
          'when 0: eq names field id 0, which is not declared earlier in the same scope',
        ),
      );
      expect(
        float,
        refused(
          1,
          'a',
          'when 1: eq names field id 0 (x), which is not an integer or a bool',
        ),
      );
      expect(
        boolFalse,
        refused(
          1,
          'a',
          'when 1: eq names bool field id 0 (on) and accepts only true, not false',
        ),
      );
      expect(
        fraction,
        refused(
          1,
          'a',
          "when 1 tests u8 field 0 ('mode') against 1.0; the value must be a whole number",
        ),
      );
    });

    test('a negative fixed bytes size is refused', () {
      // Act
      final error = refusal(() => scheme(1, [bytes(0, 'b', -1)]));

      // Assert
      expect(error, refused(0, 'b', 'bytes size -1: expected 0 or more'));
    });

    test('a typed scheme needs every value field bound to its row type', () {
      // Act
      final unbound = refusal(() => rowScheme(1, Other.new, [u8(0, 'n')]));
      final foreign = refusal(
        () => rowScheme(0x40, Other.new, positionFields()),
      );

      // Assert
      expect(
        unbound,
        refused(
          0,
          'n',
          'n: a scheme of Other rows needs every value field bound with bind',
        ),
      );
      expect(
        foreign,
        refused(
          0,
          'sid',
          "sid: bound to Position, but the scheme's row is Other",
        ),
      );
    });

    test('a refusal reads as one line naming the field', () {
      // Act
      final error = refusal(() => scheme(1, [u8(0, 'a'), u8(2, 'b')]));

      // Assert
      expect(
        error.toString(),
        'packbin: invalid scheme at field 2 (b): field id: expected 1, got 2',
      );
      expect(error.kind.term, 'scheme_error');
    });
  });
}
