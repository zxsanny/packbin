import 'package:packbin/packbin.dart';
import 'package:test/test.dart';

import '../support/hex.dart';

Scheme<Map<String, Object?>> s(List<Field> fields) => scheme(1, fields);

Field n(int id, String name) => u8(id, name);

List<Field> nine() => [for (var i = 0; i < 9; i++) n(i, 'f$i')];

/// Schemes the TypeScript tests build; each is packed to the bytes TypeScript
/// gives, or, with no [wire], only round-tripped (the TypeScript test only
/// builds it).
final class Built {
  Built(this.name, this.build, this.row, this.wire);
  final String name;
  final Scheme<Map<String, Object?>> Function() build;
  final Map<String, Object?> row;
  final String? wire;
}

final builtRows = <Built>[
  Built(
    'alternate when branches share a name',
    () => s([
      n(0, 'kind'),
      when(1, eq(0, 0), [n(1, 'shape')]),
      when(2, eq(0, 1), [u16(2, 'shape')]),
    ]),
    {'kind': 1, 'shape': 300},
    '01012c01',
  ),
  Built(
    'a name outside every when and once inside one',
    () => s([
      n(0, 'kind'),
      n(1, 'shape'),
      when(2, eq(0, 1), [u16(2, 'shape')]),
    ]),
    {'kind': 1, 'shape': 7},
    '0101070700',
  ),
  Built(
    'a name in a when after one outside',
    () => s([
      n(0, 'kind'),
      when(1, eq(0, 1), [n(1, 'shape')]),
      n(2, 'shape'),
    ]),
    {'kind': 0, 'shape': 7},
    '010007',
  ),
  Built(
    'a flag byte handle is no member name',
    () {
      final a = flagByte('a');
      return s([a, a.bit(n(0, 'a'))]);
    },
    {'a': 3},
    '010103',
  ),
  Built(
    'a when inside a group names a field outside it',
    () => s([
      n(0, 'k'),
      groupOf(1, 'g', [
        n(1, 'a'),
        when(2, eq(0, 5), [n(2, 'extra')]),
      ]),
    ]),
    {
      'k': 5,
      'g': {'a': 9, 'extra': 7},
    },
    '01050907',
  ),
  Built(
    'a when after a group names its member',
    () => s([
      groupOf(0, 'g', [n(0, 'n')]),
      when(1, eq(0, 1), [n(1, 'v')]),
    ]),
    {
      'g': {'n': 1},
      'v': 7,
    },
    '010107',
  ),
  Built(
    'an anchored group in a when shares the scope',
    () => s([
      n(0, 'kind'),
      when(1, eq(0, 0), [
        groupOf(1, 'g', [n(1, 'shape')]),
      ]),
      when(2, eq(0, 1), [u16(2, 'shape')]),
    ]),
    {'kind': 1, 'shape': 300},
    '01012c01',
  ),
  Built(
    'members of different groups with distinct names',
    () => s([
      n(0, 'a'),
      groupOf(1, 'first', [n(1, 'b')]),
      groupOf(2, 'second', [n(2, 'c')]),
    ]),
    {
      'a': 1,
      'first': {'b': 2},
      'second': {'c': 3},
    },
    '01010203',
  ),
  Built(
    'a flag byte read inside a bit numbers its own bits',
    () {
      final earlier = flagByte('earlier');
      return s([
        earlier,
        earlier.bit(flags(0, [earlier.bit(n(0, 'nested'))])),
      ]);
    },
    {'nested': 3},
    null,
  ),
  Built(
    'a flag bit under a when finds the byte of the scope around it',
    () {
      final fb = flagByte('fb');
      return s([
        n(0, 'k'),
        fb,
        when(1, eq(0, 1), [fb.bit(n(1, 'a'))]),
      ]);
    },
    {'k': 1, 'a': 4},
    '01010104',
  ),
  Built(
    'eight members of one flags',
    () => s([flags(0, nine().take(8).toList())]),
    {'f7': 7},
    '018007',
  ),
  Built(
    'a handle read twice numbers the bits of each read from 0',
    () {
      final m = flagByte('m');
      return s([m, m.bit(n(0, 'a')), m, m.bit(n(1, 'b'))]);
    },
    {'a': 1, 'b': 2},
    '0101010102',
  ),
  Built(
    'a handle shared by two schemes numbers the bits of each from 0',
    () {
      final m = flagByte('m');
      s([m, m.bit(n(0, 'x'))]);
      return s([m, m.bit(n(0, 'x'))]);
    },
    {'x': 5},
    '010105',
  ),
  Built(
    'bits take their numbers from the scheme order, not the order of the calls',
    () {
      final m = flagByte('m');
      final late = m.bit(n(1, 'b'));
      final early = m.bit(n(0, 'a'));
      return s([m, early, late]);
    },
    {'b': 2},
    '010202',
  ),
];

void main() {
  group('the schemes the TypeScript tests build', () {
    for (final b in builtRows) {
      test('${b.name} builds and packs the TypeScript bytes', () {
        // Arrange
        final layout = b.build();

        // Act
        final raw = pack(layout, b.row);
        final back = unpackRow(raw, layout);
        final again = pack(layout, back.row!);

        // Assert
        expect(back.ok, isTrue);
        expect(hex(again), hex(raw));
        final wire = b.wire;
        if (wire != null) expect(hex(raw), wire);
      });
    }
  });

  group('a scheme of map rows given bound fields', () {
    test('ignores the bindings: TypeScript has none, the row is the map', () {
      // Arrange
      final layout = scheme(1, [
        u8(0, 'a').bind<Probe>(get: (r) => r.touched++, set: (r, v) {}),
        u8(1, 'b'),
      ]);

      // Act
      final raw = pack(layout, {'a': 1, 'b': 2});
      final back = unpackRow(raw, layout).row;

      // Assert
      expect(hex(raw), '010102');
      expect(back, {'a': 1, 'b': 2});
    });
  });
}

class Probe {
  int touched = 0;
}
