import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/timing.dart';

// AZ-4217 (non-functional, performance): the rule that a repeat is the last
// thing a packet reads is one walk of the scheme. The cost follows the size of
// the scheme, whatever its shape: a long run of siblings that write nothing
// is not walked once per sibling.

const _siblings = 16000;

/// A time that the build of [_siblings] fields takes in under a hundred
/// milliseconds on an idle host, the first build of a process included; a
/// walk per sibling takes a second or more.
const _nominal = Duration(milliseconds: 300);

/// `u8 a`, then [_siblings] `when`s each holding a zero-width `bytes`, which
/// write nothing, then `repeat { u8 v }`: the repeat is last, so it builds.
List<Field> _emptyWhensThenRepeat() => [
  u8(0, 'a'),
  for (var i = 1; i <= _siblings; i++) when(i, eq(0, 1), [bytes(i, 'e$i', 0)]),
  repeat(_siblings + 1, [u8(_siblings + 1, 'v')]),
];

/// `u8 a`, then [_siblings] `when`s each holding a `repeat` of a zero-width
/// `bytes`: no byte follows any of them, so it builds.
List<Field> _whensOfRepeats() => [
  u8(0, 'a'),
  for (var i = 1; i <= _siblings; i++)
    when(i, eq(0, 1), [
      repeat(i, [bytes(i, 'e$i', 0)]),
    ]),
];

void main() {
  group('AZ-4217 performance: the rule is one walk of the scheme', () {
    final shapes = <String, List<Field> Function()>{
      '$_siblings sibling whens that write nothing, then a repeat':
          _emptyWhensThenRepeat,
      '$_siblings sibling whens that each hold a repeat that writes nothing '
              'after it':
          _whensOfRepeats,
    };
    for (final MapEntry(key: name, value: build) in shapes.entries) {
      test('$name build in a time that follows their number', () {
        // Arrange
        final fields = build();
        final bound = LoadBound(_nominal);

        // Act
        final watch = Stopwatch()..start();
        final layout = scheme(1, fields);
        watch.stop();

        // Assert
        expect(layout.typeNumber, 1);
        expectWithin(watch.elapsed, bound, what: name);
      });
    }
  });
}
