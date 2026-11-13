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

/// Builds timed per shape: the build allocates, so one build is decided by a
/// single garbage-collection pause or a lost time slice on a busy host, which
/// the CPU load factor does not see (loop 121: 869 ms in the pool, under the
/// bound alone). A quadratic walk is slow in every build, so the best of three
/// still fails it.
const _builds = 3;

/// The scheme of the last build and the shortest of [_builds] builds, each
/// of fields made fresh outside the timed section.
(Scheme<Map<String, Object?>>, Duration) _bestBuild(
  List<Field> Function() build,
) {
  Scheme<Map<String, Object?>>? layout;
  Duration? best;
  for (var i = 0; i < _builds; i++) {
    final fields = build();
    final watch = Stopwatch()..start();
    layout = scheme(1, fields);
    watch.stop();
    if (best == null || watch.elapsed < best) best = watch.elapsed;
  }
  return (layout!, best!);
}

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
        final bound = LoadBound(_nominal);

        // Act
        final (layout, best) = _bestBuild(build);

        // Assert
        expect(layout.typeNumber, 1);
        expectWithin(best, bound, what: '$name (best of $_builds builds)');
      });
    }
  });
}
